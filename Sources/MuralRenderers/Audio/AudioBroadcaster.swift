import Foundation
import os.lock

/// Pub-sub fan-out for FFT bins. `AudioPipeline` publishes 128 bins at ~60 Hz;
/// wallpaper renderers subscribe via `subscribe(_:)` and unsubscribe via the
/// returned `Token`. Subscribers receive on the publisher's queue (typically
/// main); handlers should be cheap.
///
/// `publish` snapshots the handler map under the lock, then invokes each
/// handler OUTSIDE the lock. This avoids deadlock if a handler subscribes or
/// unsubscribes during dispatch.
///
/// `@unchecked Sendable` is justified: `OSAllocatedUnfairLock` serialises every
/// access; the inner `[Token: Handler]` is only mutated inside `withLock`. The
/// compiler can't prove this because `Handler` is a closure typealias, so we
/// constrain it with `@Sendable` so each handler crosses isolation safely.
public final class AudioBroadcaster: @unchecked Sendable {
    public typealias Token = UUID
    public typealias Handler = @Sendable ([Float]) -> Void

    private let state: OSAllocatedUnfairLock<[Token: Handler]>

    public init() {
        state = OSAllocatedUnfairLock(initialState: [:])
    }

    @discardableResult
    public func subscribe(_ handler: @escaping Handler) -> Token {
        let token = Token()
        state.withLock { subs in subs[token] = handler }
        return token
    }

    public func unsubscribe(_ token: Token) {
        state.withLock { subs in
            _ = subs.removeValue(forKey: token)
        }
    }

    public func publish(_ bins: [Float]) {
        let snapshot: [Handler] = state.withLock { subs in Array(subs.values) }
        for handler in snapshot {
            handler(bins)
        }
    }

    public var subscriberCount: Int {
        state.withLock { subs in subs.count }
    }
}
