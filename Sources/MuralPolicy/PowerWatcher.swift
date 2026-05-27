import Foundation
import IOKit.ps
import OSLog

/// Watches battery and Low Power Mode state. Fires `onChange(onBattery, lowPower)`
/// once on `start()` (initial state), then again on every transition. Stop the
/// watcher before dropping it so observers are removed and the IOPS run-loop
/// source is released.
@MainActor
public final class PowerWatcher {
    public typealias Callback = @Sendable @MainActor (_ onBattery: Bool, _ lowPower: Bool) -> Void

    private let log = Log.logger("PowerWatcher")
    private var lpmObserver: NSObjectProtocol?
    private var iopsSource: CFRunLoopSource?
    private var forwarder: PowerForwarder?

    public init() {}

    public func isOnBattery() -> Bool {
        guard let blob = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
              let sources = IOPSCopyPowerSourcesList(blob)?.takeRetainedValue() as? [CFTypeRef]
        else { return false }
        for source in sources {
            guard let info = IOPSGetPowerSourceDescription(blob, source)?.takeUnretainedValue() as? [String: Any] else {
                continue
            }
            if let state = info[kIOPSPowerSourceStateKey as String] as? String,
               state == kIOPSBatteryPowerValue
            {
                return true
            }
        }
        return false
    }

    public func isLowPowerMode() -> Bool {
        ProcessInfo.processInfo.isLowPowerModeEnabled
    }

    public func start(_ onChange: @escaping Callback) {
        // Fire current state once at registration so callers don't have to
        // separately query before the first notification arrives.
        onChange(isOnBattery(), isLowPowerMode())

        lpmObserver = NotificationCenter.default.addObserver(
            forName: .NSProcessInfoPowerStateDidChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            guard let self else { return }
            MainActor.assumeIsolated {
                onChange(self.isOnBattery(), self.isLowPowerMode())
            }
        }

        let forwarder = PowerForwarder { [weak self] in
            guard let self else { return }
            // IOPS callback fires on the run-loop source's thread (we install on main).
            // Still hop explicitly to be safe.
            DispatchQueue.main.async {
                MainActor.assumeIsolated {
                    onChange(self.isOnBattery(), self.isLowPowerMode())
                }
            }
        }
        self.forwarder = forwarder

        let context = UnsafeMutableRawPointer(Unmanaged.passUnretained(forwarder).toOpaque())
        let callback: IOPowerSourceCallbackType = { ctx in
            guard let ctx else { return }
            let forwarder = Unmanaged<PowerForwarder>.fromOpaque(ctx).takeUnretainedValue()
            forwarder.fire()
        }
        if let source = IOPSNotificationCreateRunLoopSource(callback, context)?.takeRetainedValue() {
            CFRunLoopAddSource(CFRunLoopGetMain(), source, .defaultMode)
            iopsSource = source
            log.info("IOPS run-loop source installed")
        } else {
            log.error("IOPSNotificationCreateRunLoopSource returned nil")
        }
    }

    public func stop() {
        if let lpmObserver {
            NotificationCenter.default.removeObserver(lpmObserver)
        }
        lpmObserver = nil
        if let iopsSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), iopsSource, .defaultMode)
        }
        iopsSource = nil
        forwarder = nil
    }
}

/// Bridge for the C IOPS callback. We can't pass a Swift closure directly into
/// `IOPowerSourceCallbackType`; instead we stash the closure on this class and
/// give the C side an opaque pointer to it. The class is retained by the
/// watcher's `forwarder` property; the C side holds an unretained reference.
private final class PowerForwarder: @unchecked Sendable {
    let onChange: () -> Void
    init(_ onChange: @escaping () -> Void) {
        self.onChange = onChange
    }

    func fire() {
        onChange()
    }
}
