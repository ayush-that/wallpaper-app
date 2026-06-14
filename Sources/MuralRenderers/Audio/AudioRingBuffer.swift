import Foundation
import os.lock

/// Lock-protected ring of `Float` samples. Producer (`SystemAudioCapture`'s
/// SCStream callback) writes from a background queue; consumer
/// (`AudioPipeline`'s FFT tick) reads from a different background queue.
///
/// `latest(count:)` returns a fixed-size window padded at the FRONT (oldest
/// end) with zeros so the FFT input length is always constant.
///
/// Thread-safety is provided by `OSAllocatedUnfairLock<State>`, which is
/// `Sendable`. Combined with `let`-only stored properties, this class is
/// auto-`Sendable` without needing `@unchecked`.
public final class AudioRingBuffer: Sendable {
    public let capacity: Int

    private struct State {
        var buffer: [Float]
        var head: Int = 0 // next write index
        var filled: Int = 0
    }

    private let state: OSAllocatedUnfairLock<State>

    public init(capacity: Int) {
        precondition(capacity > 0, "AudioRingBuffer capacity must be positive")
        self.capacity = capacity
        state = OSAllocatedUnfairLock(initialState: State(
            buffer: Array(repeating: 0, count: capacity)
        ))
    }

    /// Appends `samples` to the ring. When the buffer wraps, the oldest
    /// samples are overwritten.
    public func write(_ samples: [Float]) {
        guard !samples.isEmpty else { return }
        let cap = capacity
        state.withLock { state in
            for sample in samples {
                state.buffer[state.head] = sample
                state.head = (state.head + 1) % cap
                if state.filled < cap { state.filled += 1 }
            }
        }
    }

    /// Returns up to `count` most-recent samples in chronological order
    /// (oldest first, newest last). Returns fewer if the buffer is underfilled.
    public func read(count: Int) -> [Float] {
        let cap = capacity
        return state.withLock { state in
            let take = min(count, state.filled)
            guard take > 0 else { return [] }
            var out: [Float] = []
            out.reserveCapacity(take)
            let start = (state.head - take + cap) % cap
            for offset in 0 ..< take {
                out.append(state.buffer[(start + offset) % cap])
            }
            return out
        }
    }

    /// Returns exactly `count` samples; zero-pads at the FRONT if underfilled.
    /// Canonical input for FFT; the analyzer always wants a fixed-size window.
    public func latest(count: Int) -> [Float] {
        let real = read(count: count)
        guard real.count < count else { return real }
        return Array(repeating: 0, count: count - real.count) + real
    }
}
