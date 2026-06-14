import Foundation
import OSLog

/// `FFTAnalyzer`'s instance state is effectively immutable after `init`: the
/// Hann `window` and `fftSetup` pointer are set once and never mutated;
/// `analyze(...)` only touches local stack copies. That makes it safe to share
/// across queues. We scope this `@unchecked Sendable` conformance here (where
/// the cross-queue capture happens) rather than in `FFTAnalyzer.swift`.
extension FFTAnalyzer: @unchecked Sendable {}

/// Orchestrates system audio capture into FFT bins broadcast at ~60 Hz.
///
/// Owns the `AudioRingBuffer`, `SystemAudioCapture`, `FFTAnalyzer`, and an
/// `AudioBroadcaster`. A `DispatchSourceTimer` ticks on a background queue,
/// pulls the latest 1024 samples, runs FFT to 128 log-spaced bins, and hops
/// to main to publish through the broadcaster.
@MainActor
public final class AudioPipeline {
    public let ring = AudioRingBuffer(capacity: 4096)
    public let broadcaster = AudioBroadcaster()

    private let log = Log.logger("AudioPipeline")
    private let capture: SystemAudioCapture
    private let analyzer = FFTAnalyzer()
    private let timerQueue = DispatchQueue(label: "app.mural.audio.tick")
    private var tickTimer: DispatchSourceTimer?
    private var isRunning = false

    public init() {
        capture = SystemAudioCapture(ring: ring)
    }

    public func start() async throws {
        guard !isRunning else { return }
        try await capture.start()
        startTickTimer()
        isRunning = true
        log.info("AudioPipeline started.")
    }

    public func stop() async {
        guard isRunning else { return }
        tickTimer?.cancel()
        tickTimer = nil
        await capture.stop()
        isRunning = false
        log.info("AudioPipeline stopped.")
    }

    /// Test/debug seam: push synthetic bins through the broadcaster without
    /// running the actual capture pipeline. Bypasses the timer and FFT.
    public func publishForTests(bins: [Float]) {
        broadcaster.publish(bins)
    }

    private func startTickTimer() {
        let timer = DispatchSource.makeTimerSource(queue: timerQueue)
        timer.schedule(deadline: .now(), repeating: 1.0 / 60.0)
        // Capture locals to avoid retaining `self` strongly in the timer
        // closure. `analyzer` is only ever touched from `timerQueue`, so its
        // `@unchecked Sendable` conformance is safe in practice.
        let ring = ring
        let analyzer = analyzer
        let broadcaster = broadcaster
        timer.setEventHandler {
            let samples = ring.latest(count: 1024)
            let bins = analyzer.analyze(samples: samples, sampleRate: 48000, bandCount: 128)
            DispatchQueue.main.async {
                broadcaster.publish(bins)
            }
        }
        timer.resume()
        tickTimer = timer
    }
}
