import AVFoundation
import CoreGraphics
import CoreMedia
import Foundation
import OSLog
import ScreenCaptureKit

/// Captures system-mix audio via `ScreenCaptureKit`'s `SCStream`. Buffers are
/// copied out of the SCK callback into an owned `[Float]` and handed to the
/// injected `AudioRingBuffer` before the callback returns — see the buffer-
/// escape invariant in `docs/research/03-swift-apis-reference.md` §3.8.
///
/// Requires the user to grant Screen Recording permission in System Settings
/// (TCC). The first `start()` triggers the prompt; subsequent denials require
/// the deep-link onboarding handled in Phase 6 Task 8. `preflight()` mirrors
/// `CGPreflightScreenCaptureAccess` so callers can check before invoking.
@MainActor
public final class SystemAudioCapture: NSObject, SCStreamOutput, SCStreamDelegate {
    public enum PreflightResult: Sendable { case granted, denied, unknown }

    public let ring: AudioRingBuffer
    private let log = Log.logger("SystemAudio")
    private let queue = DispatchQueue(label: "app.mural.audio.capture")
    private var stream: SCStream?

    public init(ring: AudioRingBuffer) {
        self.ring = ring
        super.init()
    }

    public static func preflight() -> PreflightResult {
        CGPreflightScreenCaptureAccess() ? .granted : .denied
    }

    /// Starts capturing system audio. Idempotent: a second call while already
    /// running returns immediately. Throws if no shareable display is found or
    /// SCK rejects the configuration (e.g. TCC denial).
    public func start() async throws {
        if stream != nil { return }

        let content = try await SCShareableContent.excludingDesktopWindows(
            false,
            onScreenWindowsOnly: true
        )
        guard let display = content.displays.first else {
            throw SystemAudioCaptureError.noDisplay
        }
        let filter = SCContentFilter(
            display: display,
            excludingApplications: [],
            exceptingWindows: []
        )

        let config = SCStreamConfiguration()
        config.capturesAudio = true
        config.excludesCurrentProcessAudio = true
        config.sampleRate = 48000
        config.channelCount = 2
        // SCK requires at least one visual output type even when we only care
        // about audio; keep it cheap (32×32 @ 1 fps).
        config.width = 32
        config.height = 32
        config.minimumFrameInterval = CMTime(value: 1, timescale: 1)
        config.queueDepth = 4

        let stream = SCStream(filter: filter, configuration: config, delegate: self)
        try stream.addStreamOutput(self, type: .audio, sampleHandlerQueue: queue)
        try stream.addStreamOutput(self, type: .screen, sampleHandlerQueue: queue)
        try await stream.startCapture()
        self.stream = stream
        log.info("System audio capture started.")
    }

    public func stop() async {
        guard let stream else { return }
        try? await stream.stopCapture()
        self.stream = nil
        log.info("System audio capture stopped.")
    }

    // MARK: - SCStreamOutput

    public nonisolated func stream(
        _: SCStream,
        didOutputSampleBuffer sampleBuffer: CMSampleBuffer,
        of outputType: SCStreamOutputType
    ) {
        guard outputType == .audio else { return }
        guard CMSampleBufferIsValid(sampleBuffer),
              let formatDesc = CMSampleBufferGetFormatDescription(sampleBuffer),
              let asbd = CMAudioFormatDescriptionGetStreamBasicDescription(formatDesc)?.pointee
        else { return }

        // CRITICAL: copy data out BEFORE the callback returns. We get a retained
        // block buffer here, but we still copy into our owned [Float] before
        // handing to the ring — never let the SCK pointer escape downstream.
        var blockBuffer: CMBlockBuffer?
        var audioBufferList = AudioBufferList(
            mNumberBuffers: 1,
            mBuffers: AudioBuffer(mNumberChannels: 0, mDataByteSize: 0, mData: nil)
        )
        let status = CMSampleBufferGetAudioBufferListWithRetainedBlockBuffer(
            sampleBuffer,
            bufferListSizeNeededOut: nil,
            bufferListOut: &audioBufferList,
            bufferListSize: MemoryLayout<AudioBufferList>.size,
            blockBufferAllocator: nil,
            blockBufferMemoryAllocator: nil,
            flags: 0,
            blockBufferOut: &blockBuffer
        )
        guard status == noErr else { return }
        defer { blockBuffer = nil }

        let firstBuffer = audioBufferList.mBuffers
        guard let raw = firstBuffer.mData else { return }
        let byteCount = Int(firstBuffer.mDataByteSize)
        let channels = Int(asbd.mChannelsPerFrame)
        guard channels > 0 else { return }
        let frameCount = byteCount / MemoryLayout<Float32>.size / channels
        guard frameCount > 0 else { return }

        let floats = UnsafeBufferPointer<Float32>(
            start: raw.assumingMemoryBound(to: Float32.self),
            count: frameCount * channels
        )

        var mono = [Float](repeating: 0, count: frameCount)
        for frameIndex in 0 ..< frameCount {
            var accumulator: Float = 0
            for channelIndex in 0 ..< channels {
                accumulator += floats[frameIndex * channels + channelIndex]
            }
            mono[frameIndex] = accumulator / Float(channels)
        }
        ring.write(mono)
    }

    // MARK: - SCStreamDelegate

    public nonisolated func stream(_: SCStream, didStopWithError error: any Error) {
        log.error("SCStream stopped with error: \(error.localizedDescription, privacy: .public)")
    }
}

public enum SystemAudioCaptureError: Error, Equatable {
    case noDisplay
    case permissionDenied
}
