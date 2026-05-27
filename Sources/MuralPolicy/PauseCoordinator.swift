import Foundation
import OSLog

/// Tracks the set of active pause reasons per display and drives
/// `renderer.pause()/resume()` on edge transitions. The coordinator does NOT
/// know which renderer belongs to which display — `lookup` is injected by the
/// owner (AppDelegate hands it a `WallpaperEngine.renderer(for:)` closure).
///
/// All mutation goes through `add` / `remove` / `clear`. Reading is via
/// `reasons(for:)`. Internally locked via `OSAllocatedUnfairLock` so watchers
/// can post from any queue.
public final class PauseCoordinator: @unchecked Sendable {
    public typealias RendererLookup = @Sendable (String) -> WallpaperRenderer?

    private let log = Log.logger("PauseCoordinator")
    private let lookup: RendererLookup
    private let state: OSAllocatedUnfairLock<[String: PauseReason]>

    public init(lookup: @escaping RendererLookup) {
        self.lookup = lookup
        state = OSAllocatedUnfairLock(initialState: [:])
    }

    /// Adds a reason for the given display. If the display had no reasons
    /// before this call, the renderer's `pause()` is invoked. Idempotent —
    /// adding the same reason again is a no-op.
    public func add(_ reason: PauseReason, for displayUUID: String) {
        let transitionedToPaused: Bool = state.withLock { table in
            let prior = table[displayUUID] ?? []
            let next = prior.union(reason)
            table[displayUUID] = next
            return prior.isEmpty && !next.isEmpty
        }
        if transitionedToPaused {
            log.info(
                "display \(displayUUID, privacy: .public) paused: \(reason.rawValue)"
            )
            Task { @MainActor [lookup] in lookup(displayUUID)?.pause() }
        }
    }

    /// Removes a reason for the given display. If removing this reason leaves
    /// the display with no remaining reasons, the renderer's `resume()` is
    /// invoked. Idempotent.
    public func remove(_ reason: PauseReason, for displayUUID: String) {
        let transitionedToResumed: Bool = state.withLock { table in
            let prior = table[displayUUID] ?? []
            let next = prior.subtracting(reason)
            if next.isEmpty {
                table.removeValue(forKey: displayUUID)
            } else {
                table[displayUUID] = next
            }
            return !prior.isEmpty && next.isEmpty
        }
        if transitionedToResumed {
            log.info("display \(displayUUID, privacy: .public) resumed")
            Task { @MainActor [lookup] in lookup(displayUUID)?.resume() }
        }
    }

    /// Reads the current set of reasons for a display.
    public func reasons(for displayUUID: String) -> PauseReason {
        state.withLock { $0[displayUUID] ?? [] }
    }

    /// Clears all pause reasons for a display — e.g. on hot-unplug, when we
    /// no longer track that display.
    public func clear(displayUUID: String) {
        let transitioned: Bool = state.withLock { table in
            let had = table[displayUUID] ?? []
            if had.isEmpty { return false }
            table.removeValue(forKey: displayUUID)
            return true
        }
        if transitioned {
            Task { @MainActor [lookup] in lookup(displayUUID)?.resume() }
        }
    }

    public var trackedDisplayCount: Int {
        state.withLock { $0.count }
    }
}
