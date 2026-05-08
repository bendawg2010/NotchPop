// CountdownTimerService.swift
//
// Single-shot countdown timer (separate from Pomodoro — Pomodoro is
// a phased focus/break cycle; this is "set 7 minutes for the oven").
// Persists the most-recently-set duration so reopening the tab
// remembers what you typically use.

import AppKit
import Combine
import UserNotifications

final class CountdownTimerService: ObservableObject {
    /// User-set duration in seconds. Only matters at start; the timer
    /// counts down from this each run.
    @Published var setDuration: TimeInterval = 5 * 60 {
        didSet { UserDefaults.standard.set(setDuration, forKey: "np.timer.duration") }
    }
    @Published var remaining: TimeInterval = 5 * 60
    @Published var running: Bool = false

    private var endDate: Date?
    private var ticker: Timer?

    init() {
        let saved = UserDefaults.standard.double(forKey: "np.timer.duration")
        if saved > 0 {
            setDuration = saved
            remaining = saved
        }
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    func start() {
        if remaining <= 0 { remaining = setDuration }
        endDate = Date().addingTimeInterval(remaining)
        running = true
        ticker?.invalidate()
        ticker = Timer.scheduledTimer(withTimeInterval: 0.2, repeats: true) { [weak self] _ in
            self?.tick()
        }
    }

    func pause() {
        running = false
        ticker?.invalidate()
        ticker = nil
    }

    func toggle() { running ? pause() : start() }

    func reset() {
        ticker?.invalidate()
        ticker = nil
        running = false
        endDate = nil
        remaining = setDuration
    }

    /// Increment / decrement the set duration in 30s steps. Disabled
    /// while running to avoid weird mid-flight resets.
    func nudge(by seconds: TimeInterval) {
        guard !running else { return }
        let new = max(30, min(60 * 60, setDuration + seconds))
        setDuration = new
        remaining = new
    }

    private func tick() {
        guard let end = endDate else { return }
        let r = end.timeIntervalSinceNow
        if r <= 0 {
            remaining = 0
            ticker?.invalidate()
            ticker = nil
            running = false
            notifyDone()
            // Auto-reset back to the set duration so the next press of
            // play immediately starts a fresh run.
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
                guard let self = self else { return }
                self.endDate = nil
                self.remaining = self.setDuration
            }
        } else {
            remaining = r
        }
    }

    private func notifyDone() {
        // Same sound system as Pomodoro — see TimerSound.swift. Honors
        // np.sound toggle + np.timerSoundName preference.
        TimerSound.play()
        // Fire the user-configurable Connections trigger.
        NotificationCenter.default.post(
            name: ConnectionTrigger.countdownEnd.notificationName, object: nil)
        let c = UNMutableNotificationContent()
        c.title = "Timer done"
        c.body = "Your \(formatDuration(setDuration)) timer just finished."
        c.sound = .default
        let req = UNNotificationRequest(identifier: UUID().uuidString,
                                        content: c, trigger: nil)
        UNUserNotificationCenter.current().add(req)
    }

    var progress: Double {
        guard setDuration > 0 else { return 0 }
        return 1 - (remaining / setDuration)
    }

    var formatted: String {
        let total = Int(ceil(remaining))
        let h = total / 3600
        let m = (total % 3600) / 60
        let s = total % 60
        if h > 0 { return String(format: "%d:%02d:%02d", h, m, s) }
        return String(format: "%d:%02d", m, s)
    }

    private func formatDuration(_ d: TimeInterval) -> String {
        let total = Int(d)
        let h = total / 3600
        let m = (total % 3600) / 60
        let s = total % 60
        if h > 0 { return "\(h)h \(m)m" }
        if m > 0 { return "\(m)m\(s > 0 ? " \(s)s" : "")" }
        return "\(s)s"
    }
}
