import Accelerate
@testable import Mural
import XCTest

final class FFTAnalyzerTests: XCTestCase {
    private let sampleRate: Float = 48000

    private func makeSine(frequency: Float, length: Int = 1024) -> [Float] {
        (0 ..< length).map { i in sin(2 * .pi * frequency * Float(i) / sampleRate) }
    }

    func test_silence_produces_near_zero_bins() {
        let analyzer = FFTAnalyzer()
        let samples = [Float](repeating: 0, count: 1024)
        let bins = analyzer.analyze(samples: samples, sampleRate: sampleRate, bandCount: 128)
        XCTAssertEqual(bins.count, 128)
        XCTAssertLessThan(bins.max() ?? 1, 0.001)
    }

    func test_1khz_sine_produces_peak_in_mid_band() throws {
        let analyzer = FFTAnalyzer()
        let samples = makeSine(frequency: 1000)
        let bins = analyzer.analyze(samples: samples, sampleRate: sampleRate, bandCount: 128)
        XCTAssertEqual(bins.count, 128)
        let peakIndex = try XCTUnwrap(try bins.firstIndex(of: XCTUnwrap(bins.max())))
        // 1 kHz in log[20, 20_000] -> ~mid range; bin index 50..95 is the safe window.
        XCTAssertTrue(
            (50 ... 95).contains(peakIndex),
            "expected peak in mid-band; got bin \(peakIndex) value \(bins[peakIndex])"
        )
    }

    func test_low_frequency_sine_peaks_in_first_quarter() throws {
        let analyzer = FFTAnalyzer()
        let samples = makeSine(frequency: 80)
        let bins = analyzer.analyze(samples: samples, sampleRate: sampleRate, bandCount: 128)
        let peakIndex = try XCTUnwrap(try bins.firstIndex(of: XCTUnwrap(bins.max())))
        XCTAssertLessThan(peakIndex, 32, "80Hz should peak in the lowest quarter; got \(peakIndex)")
    }

    func test_all_bins_clamped_to_unit_interval() {
        // Saturate input - every sample at full amplitude.
        let analyzer = FFTAnalyzer()
        let samples = [Float](repeating: 1.0, count: 1024)
        let bins = analyzer.analyze(samples: samples, sampleRate: sampleRate, bandCount: 128)
        for value in bins {
            XCTAssertGreaterThanOrEqual(value, 0)
            XCTAssertLessThanOrEqual(value, 1)
        }
    }

    func test_returns_requested_band_count() {
        let analyzer = FFTAnalyzer()
        let samples = makeSine(frequency: 440)
        XCTAssertEqual(analyzer.analyze(samples: samples, sampleRate: sampleRate, bandCount: 64).count, 64)
        XCTAssertEqual(analyzer.analyze(samples: samples, sampleRate: sampleRate, bandCount: 32).count, 32)
        XCTAssertEqual(analyzer.analyze(samples: samples, sampleRate: sampleRate, bandCount: 256).count, 256)
    }

    func test_analyzer_is_reusable_across_calls() {
        let analyzer = FFTAnalyzer()
        // Reuse - verify no state leakage between calls.
        let silence = analyzer.analyze(
            samples: [Float](repeating: 0, count: 1024),
            sampleRate: sampleRate,
            bandCount: 128
        )
        let sine = analyzer.analyze(
            samples: makeSine(frequency: 1000),
            sampleRate: sampleRate,
            bandCount: 128
        )
        XCTAssertLessThan(silence.max() ?? 1, 0.001)
        XCTAssertGreaterThan(sine.max() ?? 0, 0.001)
    }
}
