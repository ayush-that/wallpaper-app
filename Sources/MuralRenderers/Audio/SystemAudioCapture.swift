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

    /// Diagnostic counters — log every ~1s of audio frames so we can see if
    /// SCStream is delivering buffers at all and what their levels look like.
    private let diag = DiagnosticCounters()

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
        // NOTE: `excludesCurrentProcessAudio = true` was suppressing audio
        // delivery entirely on macOS 26.5 in observed testing — leave it false
        // until we revisit on a known-good macOS version.
        config.excludesCurrentProcessAudio = false
        config.sampleRate = 48000
        config.channelCount = 2
        // SCK requires at least one visual output type even when we only care
        // about audio. macOS 26.5 also rejected `minimumFrameInterval` of
        // 1 fps in some experiments — bump to 30 fps to match Apple sample
        // defaults; we still discard the video frames.
        config.width = 64
        config.height = 64
        config.minimumFrameInterval = CMTime(value: 1, timescale: 30)
        config.queueDepth = 6

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
        var absSum: Float = 0
        var absMax: Float = 0
        for frameIndex in 0 ..< frameCount {
            var accumulator: Float = 0
            for channelIndex in 0 ..< channels {
                accumulator += floats[frameIndex * channels + channelIndex]
            }
            let value = accumulator / Float(channels)
            mono[frameIndex] = value
            let absValue = abs(value)
            absSum += absValue
            if absValue > absMax { absMax = absValue }
        }
        ring.write(mono)

        // Periodic diagnostic. Logs roughly once per second of captured audio.
        // Format hints describe the buffer layout SCK gave us so we can spot
        // misinterpretation (planar vs interleaved, sample-rate mismatch, etc.).
        diag.record(
            frames: frameCount,
            channels: channels,
            absSum: absSum,
            absMax: absMax,
            mNumberBuffers: Int(audioBufferList.mNumberBuffers),
            mNumberChannels: Int(firstBuffer.mNumberChannels),
            asbd: asbd,
            log: log
        )
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

/// Lock-protected rolling diagnostic. Emits an info log roughly once per second
/// of captured audio so we can verify SCStream is actually delivering signal.
private final class DiagnosticCounters: @unchecked Sendable {
    private let lock = NSLock()
    private var framesSinceLastLog = 0
    private var absSumSinceLastLog: Double = 0
    private var absMaxSinceLastLog: Float = 0
    private var lastLogTime: TimeInterval = 0

    func record(
        frames: Int,
        channels: Int,
        absSum: Float,
        absMax: Float,
        mNumberBuffers: Int,
        mNumberChannels: Int,
        asbd: AudioStreamBasicDescription,
        log: Logger
    ) {
        lock.lock()
        framesSinceLastLog += frames
        absSumSinceLastLog += Double(absSum)
        if absMax > absMaxSinceLastLog { absMaxSinceLastLog = absMax }
        let now = CACurrentMediaTime()
        let shouldEmit = now - lastLogTime > 1.0 && framesSinceLastLog > 0
        let snapshot: (Int, Double, Float, TimeInterval)? = shouldEmit
            ? (framesSinceLastLog, absSumSinceLastLog, absMaxSinceLastLog, now - lastLogTime)
            : nil
        if shouldEmit {
            framesSinceLastLog = 0
            absSumSinceLastLog = 0
            absMaxSinceLastLog = 0
            lastLogTime = now
        }
        lock.unlock()

        guard let (totalFrames, totalSum, peakMax, window) = snapshot else { return }
        let average = totalSum / Double(max(totalFrames, 1))
        log.info(
            // swiftformat:disable next:wrap
            "SCStream audio diag: window=\(window, format: .fixed(precision: 2))s frames=\(totalFrames) channels=\(channels) buffers=\(mNumberBuffers) bufCh=\(mNumberChannels) sr=\(asbd.mSampleRate) bitsPerCh=\(asbd.mBitsPerChannel) bytesPerFrame=\(asbd.mBytesPerFrame) formatID=\(asbd.mFormatID) flags=\(asbd.mFormatFlags) absMax=\(peakMax, format: .fixed(precision: 5)) absAvg=\(average, format: .fixed(precision: 6))"
        )
    }
}
