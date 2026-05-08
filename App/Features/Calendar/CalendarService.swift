// CalendarService.swift
//
// Surfaces the user's upcoming events from EventKit for the Calendar
// peek pane. Owns access-permission state, today's filtered/sorted
// event list (capped at 6), and refresh on EKEventStoreChanged plus a
// 5-minute fallback timer. All published mutations hop to .main.

import Foundation
import Combine
import EventKit

final class CalendarService: ObservableObject {

    enum PermissionState {
        case notDetermined
        case granted
        case denied
    }

    @Published var todaysEvents: [EKEvent] = []
    @Published var permissionState: PermissionState = .notDetermined

    private let store = EKEventStore()
    private var changeObserver: NSObjectProtocol?
    private var fallbackTimer: Timer?

    /// Cap on number of events surfaced for the Calendar peek pane.
    private let eventCap = 6

    deinit {
        if let token = changeObserver {
            NotificationCenter.default.removeObserver(token)
        }
        fallbackTimer?.invalidate()
    }

    /// Kick off permission flow + initial load. Safe to call repeatedly
    /// (the "Click to enable" pill calls back into this).
    func start() {
        let status = EKEventStore.authorizationStatus(for: .event)

        switch status {
        case .notDetermined:
            requestAccess()
        case .authorized:
            updatePermission(.granted)
            installRefreshHooks()
            reload()
        case .denied, .restricted:
            updatePermission(.denied)
        case .fullAccess:
            updatePermission(.granted)
            installRefreshHooks()
            reload()
        case .writeOnly:
            // Write-only access can't read events for the peek list, so
            // we surface this as "denied" for read purposes. The user
            // can still upgrade in System Settings.
            updatePermission(.denied)
        @unknown default:
            updatePermission(.denied)
        }
    }

    // MARK: - Access

    private func requestAccess() {
        if #available(macOS 14, *) {
            store.requestFullAccessToEvents { [weak self] granted, _ in
                self?.handleAccessResult(granted: granted)
            }
        } else {
            store.requestAccess(to: .event) { [weak self] granted, _ in
                self?.handleAccessResult(granted: granted)
            }
        }
    }

    private func handleAccessResult(granted: Bool) {
        if granted {
            updatePermission(.granted)
            DispatchQueue.main.async { [weak self] in
                self?.installRefreshHooks()
                self?.reload()
            }
        } else {
            updatePermission(.denied)
        }
    }

    private func updatePermission(_ state: PermissionState) {
        DispatchQueue.main.async { [weak self] in
            self?.permissionState = state
        }
    }

    // MARK: - Refresh hooks

    private func installRefreshHooks() {
        // Idempotent — don't double-subscribe if start() is called again.
        if changeObserver == nil {
            changeObserver = NotificationCenter.default.addObserver(
                forName: .EKEventStoreChanged,
                object: store,
                queue: .main
            ) { [weak self] _ in
                self?.reload()
            }
        }
        if fallbackTimer == nil {
            // 5-minute fallback handles wall-clock drift (events
            // ending, midnight rollover) when EventKit doesn't fire.
            fallbackTimer = Timer.scheduledTimer(withTimeInterval: 300,
                                                 repeats: true) { [weak self] _ in
                self?.reload()
            }
        }
    }

    // MARK: - Load

    private func reload() {
        let cal = Calendar.current
        let now = Date()
        guard let endOfDay = cal.date(bySettingHour: 23, minute: 59, second: 59, of: now) else {
            return
        }
        // If we've already passed end-of-day (rare race), bail out.
        guard endOfDay > now else {
            DispatchQueue.main.async { [weak self] in
                self?.todaysEvents = []
            }
            return
        }

        let predicate = store.predicateForEvents(withStart: now,
                                                 end: endOfDay,
                                                 calendars: nil)
        let raw = store.events(matching: predicate)
        let upcoming = raw
            .filter { ($0.endDate ?? $0.startDate) > now }
            .sorted { ($0.startDate ?? .distantFuture) < ($1.startDate ?? .distantFuture) }
        let capped = Array(upcoming.prefix(eventCap))

        DispatchQueue.main.async { [weak self] in
            self?.todaysEvents = capped
        }
    }
}
