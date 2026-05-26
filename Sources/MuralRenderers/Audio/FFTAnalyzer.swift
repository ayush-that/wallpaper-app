import Accelerate
import Foundation

/// 1024-point Hann-windowed real FFT producing log-spaced magnitude bins in
/// [0, 1]. Output feeds `livelyAudioListener(arr)` in audio-reactive
/// web/shader wallpapers.
///
/// Holds a `FFTSetup` opaque pointer that must be released in `deinit`, so
/// this is a `final class`. It is NOT `Sendable` — callers must serialise
/// access (e.g. wrap in an actor or dedicated queue).
public final class FFTAnalyzer {
    private let length = 1024
    private let log2N: vDSP_Length = 10 // log2(1024)
    private let fftSetup: FFTSetup
    private var window: [Float]

    public init() {
        guard let setup = vDSP_create_fftsetup(log2N, FFTRadix(FFT_RADIX2)) else {
            preconditionFailure("vDSP_create_fftsetup failed for log2N=10")
        }
        fftSetup = setup
        var window = [Float](repeating: 0, count: length)
        vDSP_hann_window(&window, vDSP_Length(length), Int32(vDSP_HANN_NORM))
        self.window = window
    }

    deinit {
        vDSP_destroy_fftsetup(fftSetup)
    }

    /// Returns `bandCount` log-spaced magnitude bins in [0, 1].
    /// `samples` MUST be exactly 1024 elements (use `AudioRingBuffer.latest(count: 1024)`).
    public func analyze(samples: [Float], sampleRate: Float, bandCount: Int) -> [Float] {
        precondition(samples.count == length, "samples must be exactly \(length); got \(samples.count)")
        precondition(bandCount > 0, "bandCount must be positive")

        // Hann-window the input.
        var windowed = samples
        vDSP_vmul(samples, 1, window, 1, &windowed, 1, vDSP_Length(length))

        // Real FFT into split-complex.
        let half = length / 2
        var real = [Float](repeating: 0, count: half)
        var imag = [Float](repeating: 0, count: half)
        var magnitudes = [Float](repeating: 0, count: half)

        real.withUnsafeMutableBufferPointer { realPtr in
            imag.withUnsafeMutableBufferPointer { imagPtr in
                var split = DSPSplitComplex(realp: realPtr.baseAddress!, imagp: imagPtr.baseAddress!)
                windowed.withUnsafeBufferPointer { ptr in
                    ptr.baseAddress!.withMemoryRebound(to: DSPComplex.self, capacity: half) { complexPtr in
                        vDSP_ctoz(complexPtr, 2, &split, 1, vDSP_Length(half))
                    }
                }
                vDSP_fft_zrip(fftSetup, &split, 1, log2N, FFTDirection(FFT_FORWARD))
                vDSP_zvmags(&split, 1, &magnitudes, 1, vDSP_Length(half))
            }
        }

        // sqrt to get magnitudes (vDSP_zvmags returns squared values).
        var sqrtMagnitudes = [Float](repeating: 0, count: half)
        var halfInt32 = Int32(half)
        vvsqrtf(&sqrtMagnitudes, magnitudes, &halfInt32)

        // Log-spaced binning from 20 Hz to min(20 kHz, Nyquist).
        let nyquist = sampleRate / 2
        let minHz: Float = 20
        let maxHz = Swift.min(nyquist, 20000)
        var bands = [Float](repeating: 0, count: bandCount)
        let logMin = log10(minHz)
        let logMax = log10(maxHz)
        let logRange = logMax - logMin

        for bandIndex in 0 ..< bandCount {
            let logLo = logMin + logRange * Float(bandIndex) / Float(bandCount)
            let logHi = logMin + logRange * Float(bandIndex + 1) / Float(bandCount)
            let loHz = pow(10, logLo)
            let hiHz = pow(10, logHi)
            let lo = Swift.max(0, Int(loHz / nyquist * Float(half)))
            let hi = Swift.min(half, Swift.max(lo + 1, Int(hiHz / nyquist * Float(half))))
            var accumulator: Float = 0
            for binIndex in lo ..< hi {
                accumulator += sqrtMagnitudes[binIndex]
            }
            let denom = Float(hi - lo) * Float(half)
            bands[bandIndex] = denom > 0 ? Swift.min(1, accumulator / denom) : 0
        }
        return bands
    }
}
