import Foundation
@testable import Mural
import XCTest

@MainActor
final class PlaylistSchedulerTests: XCTestCase {
    func test_disabled_playlist_does_not_pick() async throws {
        let captured = LockedBox<[UUID]>(value: [])
        let scheduler = PlaylistScheduler { picked in
            captured.mutate { $0.append(picked) }
        }
        let playlist = Playlist(
            name: "off",
            wallpaperIDs: [UUID()],
            strategy: .interval(seconds: 0.1),
            enabled: false
        )
        scheduler.start(playlist: playlist)
        try await Task.sleep(nanoseconds: 200_000_000)
        scheduler.stop()
        XCTAssertTrue(captured.get().isEmpty, "disabled playlist must not invoke onPick")
    }

    func test_empty_playlist_does_not_pick() async throws {
        let captured = LockedBox<[UUID]>(value: [])
        let scheduler = PlaylistScheduler { picked in
            captured.mutate { $0.append(picked) }
        }
        let playlist = Playlist(
            name: "empty",
            wallpaperIDs: [],
            strategy: .interval(seconds: 0.1)
        )
        scheduler.start(playlist: playlist)
        try await Task.sleep(nanoseconds: 200_000_000)
        scheduler.stop()
        XCTAssertTrue(captured.get().isEmpty)
    }

    func test_interval_strategy_picks_in_order_then_wraps() async throws {
        let ids = [UUID(), UUID(), UUID()]
        let captured = LockedBox<[UUID]>(value: [])
        let scheduler = PlaylistScheduler { picked in
            captured.mutate { $0.append(picked) }
        }
        let playlist = Playlist(
            name: "ordered",
            wallpaperIDs: ids,
            strategy: .interval(seconds: 0.1)
        )
        scheduler.start(playlist: playlist)
        try await Task.sleep(nanoseconds: 450_000_000) // ~4 ticks
        scheduler.stop()
        let log = captured.get()
        XCTAssertGreaterThanOrEqual(log.count, 3)
        XCTAssertEqual(log[0], ids[0])
        XCTAssertEqual(log[1], ids[1])
        XCTAssertEqual(log[2], ids[2])
        if log.count >= 4 {
            XCTAssertEqual(log[3], ids[0], "interval strategy must wrap to start after last")
        }
    }

    func test_shuffle_picks_all_wallpapers_before_repeating() async throws {
        let ids = [UUID(), UUID(), UUID(), UUID()]
        let seen = LockedBox<Set<UUID>>(value: [])
        let scheduler = PlaylistScheduler { picked in
            seen.mutate { $0.insert(picked) }
        }
        scheduler.start(playlist: Playlist(
            name: "shuffled",
            wallpaperIDs: ids,
            strategy: .shuffle(seconds: 0.05)
        ))
        try await Task.sleep(nanoseconds: 400_000_000) // ~8 ticks — at least one full cycle
        scheduler.stop()
        XCTAssertEqual(seen.get(), Set(ids), "shuffle must eventually visit every wallpaper")
    }

    func test_timeOfDay_with_empty_slots_returns_first_wallpaper() {
        let ids = [UUID(), UUID()]
        let captured = LockedBox<[UUID]>(value: [])
        let scheduler = PlaylistScheduler { picked in
            captured.mutate { $0.append(picked) }
        }
        // .timeOfDay polls every 60s; immediate tick fires synchronously.
        scheduler.start(playlist: Playlist(
            name: "tod",
            wallpaperIDs: ids,
            strategy: .timeOfDay(slots: [])
        ))
        scheduler.stop()
        let log = captured.get()
        XCTAssertEqual(log.count, 1)
        XCTAssertEqual(log[0], ids[0])
    }

    func test_timeOfDay_picks_slot_nearest_to_now() {
        let earlyID = UUID()
        let lateID = UUID()
        let nowComponents = Calendar.current.dateComponents([.hour, .minute], from: Date())
        let nowHour = nowComponents.hour ?? 0
        // Place one slot exactly at "now", one slot 6 hours away.
        let nearSlot = TimeOfDaySlot(
            hour: nowHour,
            minute: nowComponents.minute ?? 0,
            wallpaperID: earlyID
        )
        let farSlot = TimeOfDaySlot(
            hour: (nowHour + 6) % 24,
            minute: 0,
            wallpaperID: lateID
        )

        let captured = LockedBox<[UUID]>(value: [])
        let scheduler = PlaylistScheduler { picked in
            captured.mutate { $0.append(picked) }
        }
        scheduler.start(playlist: Playlist(
            name: "tod",
            wallpaperIDs: [earlyID, lateID],
            strategy: .timeOfDay(slots: [nearSlot, farSlot])
        ))
        scheduler.stop()
        XCTAssertEqual(captured.get(), [earlyID])
    }

    func test_stop_prevents_further_ticks() async throws {
        let ids = [UUID(), UUID()]
        let count = LockedBox<Int>(value: 0)
        let scheduler = PlaylistScheduler { _ in
            count.mutate { $0 += 1 }
        }
        scheduler.start(playlist: Playlist(
            name: "x",
            wallpaperIDs: ids,
            strategy: .interval(seconds: 0.05)
        ))
        try await Task.sleep(nanoseconds: 120_000_000) // ~3 ticks
        let snapshot = count.get()
        scheduler.stop()
        try await Task.sleep(nanoseconds: 120_000_000)
        XCTAssertEqual(count.get(), snapshot, "no ticks may fire after stop()")
    }

    func test_start_replaces_prior_schedule() async throws {
        let firstIDs = [UUID(), UUID(), UUID()]
        let secondIDs = [UUID(), UUID()]
        let captured = LockedBox<[UUID]>(value: [])
        let scheduler = PlaylistScheduler { picked in
            captured.mutate { $0.append(picked) }
        }
        scheduler.start(playlist: Playlist(
            name: "first",
            wallpaperIDs: firstIDs,
            strategy: .interval(seconds: 0.05)
        ))
        try await Task.sleep(nanoseconds: 70_000_000)
        scheduler.start(playlist: Playlist(
            name: "second",
            wallpaperIDs: secondIDs,
            strategy: .interval(seconds: 0.05)
        ))
        try await Task.sleep(nanoseconds: 120_000_000)
        scheduler.stop()
        let log = captured.get()
        // The second .start must reset cursor + only pick from secondIDs from then on.
        XCTAssertTrue(log.contains(firstIDs[0]))
        XCTAssertTrue(log.suffix(2).allSatisfy(secondIDs.contains))
    }
}

private final class LockedBox<T: Sendable>: @unchecked Sendable {
    private let lock = NSLock()
    private var value: T

    init(value: T) {
        self.value = value
    }

    func get() -> T {
        lock.lock()
        defer { lock.unlock() }
        return value
    }

    func set(_ new: T) {
        lock.lock()
        value = new
        lock.unlock()
    }

    func mutate(_ body: (inout T) -> Void) {
        lock.lock()
        defer { lock.unlock() }
        body(&value)
    }
}
