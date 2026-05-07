// ChargingMonitor.swift
//
// Watches power source changes via IOPSNotificationCreateRunLoopSource.
// When the user plugs in, we briefly "peek" the notch — expand it for
// 4 seconds with a charging animation + current battery %. Then
// auto-collapse.

import Foundation
import Combine
import IOKit.ps

final class ChargingMonitor: ObservableObject {
    @Published var isCharging: Bool = false
    @Published var batteryPercent: Int = 100
    @Published var peeking: Bool = false

    private var runLoopSource: CFRunLoopSource?
    private var peekTimer: Timer?

    func start() {
        refresh()
        let context = Unmanaged.passUnretained(self).toOpaque()
        guard let source = IOPSNotificationCreateRunLoopSource({ context in
            guard let context = context else { return }
            let me = Unmanaged<ChargingMonitor>.fromOpaque(context).takeUnretainedValue()
            DispatchQueue.main.async { me.handlePowerChange() }
        }, context)?.takeRetainedValue() else { return }
        self.runLoopSource = source
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .defaultMode)
    }

    private func handlePowerChange() {
        let wasCharging = isCharging
        refresh()
        if !wasCharging && isCharging {
            // Just plugged in → peek
            peeking = true
            peekTimer?.invalidate()
            peekTimer = Timer.scheduledTimer(withTimeInterval: 4.0, repeats: false) { [weak self] _ in
                self?.peeking = false
            }
        }
    }

    private func refresh() {
        guard let snap = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
              let sources = IOPSCopyPowerSourcesList(snap)?.takeRetainedValue() as? [CFTypeRef]
        else { return }
        for src in sources {
            guard let info = IOPSGetPowerSourceDescription(snap, src)?.takeUnretainedValue()
                    as? [String: Any] else { continue }
            if let cap = info[kIOPSCurrentCapacityKey] as? Int {
                batteryPercent = cap
            }
            if let state = info[kIOPSPowerSourceStateKey] as? String {
                isCharging = (state == kIOPSACPowerValue)
            }
        }
    }

    deinit {
        if let s = runLoopSource { CFRunLoopSourceInvalidate(s) }
    }
}
