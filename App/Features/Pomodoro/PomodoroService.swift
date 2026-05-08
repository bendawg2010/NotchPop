// PomodoroService.swift
//
// Built-in focus timer. Standard 25/5 pomodoro cycle with a long
// (15min) break every 4 sessions. Durations are user-configurable.
// Persists session count + custom durations via UserDefaults so
// streaks survive a relaunch.

import AppKit
import Combine
import UserNotifications

enum PomodoroPhase: String, CaseIterable {
    case idle, focus, shortBreak, longBreak
    var label: String {
        switch self {
        case .idle:       return "Ready"
        case .focus:      return "Focus"
        case .shortBreak: return "Short break"
        case .longBreak:  return "Long break"
        }
    }
    var emoji: String {
        switch self {
        case .idle:       return "🍅"
        case .focus:      return "🍅"
        case .shortBreak: return "☕"
        case .longBreak:  return "🌴"
        }
    }
}

final class PomodoroService: ObservableObject {
    @Published var phase: PomodoroPhase = .idle
    @Published var remaining: TimeInterval = 25 * 60
    @Published var totalDuration: TimeInterval = 25 * 60
    @Published var running: Bool = false
    @Published var sessionsToday: Int = 0

    // User-configurable durations (in minutes). Defaults are the
    // canonical pomodoro: 25 focus / 5 short / 15 long.
    @Published var focusMinutes: Int = 25 {
        didSet {
            UserDefaults.standard.set(focusMinutes, forKey: "np.pom.focus")
            if phase == .idle { remaining = TimeInterval(focusMinutes * 60); totalDuration = remaining }
        }
    }
    @Published var shortBreakMinutes: Int = 5 {
        didSet { UserDefaults.standard.set(shortBreakMinutes, forKey: "np.pom.short") }
    }
    @Published var longBreakMinutes: Int = 15 {
        didSet { UserDefaults.standard.set(longBreakMinutes, forKey: "np.pom.long") }
    }
    @Published var sessionsBeforeLongBreak: Int = 4 {
        didSet { UserDefaults.standard.set(sessionsBeforeLongBreak, forKey: "np.pom.cycle") }
    }
    /// Automatically begin the next phase when one ends, with no
    /// click required. On = "deep flow"; off = "I want a button".
    @Published var autoStartNextPhase: Bool = false {
        didSet { UserDefaults.standard.set(autoStartNextPhase, forKey: "np.pom.autoStart") }
    }
    /// In strict mode the user can't pause a focus session. Skip and
    /// reset are still available so they're not trapped.
    @Published var strictMode: Bool = false {
        didSet { UserDefaults.standard.set(strictMode, forKey: "np.pom.strict") }
    }
    /// Daily session goal (just for display; doesn't gate anything).
    @Published var dailyGoal: Int = 8 {
        didSet { UserDefaults.standard.set(dailyGoal, forKey: "np.pom.goal") }
    }

    private var timer: Timer?
    private var lastSessionDate: Date = Date()

    init() {
        let d = UserDefaults.standard
        focusMinutes      = (d.object(forKey: "np.pom.focus") as? Int) ?? 25
        shortBreakMinutes = (d.object(forKey: "np.pom.short") as? Int) ?? 5
        longBreakMinutes  = (d.object(forKey: "np.pom.long")  as? Int) ?? 15
        sessionsBeforeLongBreak = (d.object(forKey: "np.pom.cycle") as? Int) ?? 4
        autoStartNextPhase = (d.object(forKey: "np.pom.autoStart") as? Bool) ?? false
        strictMode = (d.object(forKey: "np.pom.strict") as? Bool) ?? false
        dailyGoal = (d.object(forKey: "np.pom.goal") as? Int) ?? 8
        // Reset session count if a new day has begun
        let lastDay = (d.object(forKey: "np.pom.dayStamp") as? String) ?? ""
        let today = Self.dayStamp()
        if lastDay == today {
            sessionsToday = d.integer(forKey: "np.pom.sessions")
        } else {
            sessionsToday = 0
            d.set(today, forKey: "np.pom.dayStamp")
            d.set(0, forKey: "np.pom.sessions")
        }
        // Initial remaining = full focus
        remaining = TimeInterval(focusMinutes * 60)
        totalDuration = remaining

        // Notification permission for "session complete" alerts
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    // MARK: - Controls
    func start() {
        if phase == .idle {
            phase = .focus
            remaining = TimeInterval(focusMinutes * 60)
            totalDuration = remaining
        }
        running = true
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.tick()
        }
    }

    /// Manually pick which phase the user wants to start in (instead
    /// of being forced into Focus). Called by the phase picker buttons
    /// in the Pomodoro pane.
    func selectPhase(_ newPhase: PomodoroPhase) {
        guard newPhase != phase else { return }
        timer?.invalidate()
        timer = nil
        running = false
        phase = newPhase
        switch newPhase {
        case .focus:
            remaining = TimeInterval(focusMinutes * 60)
        case .shortBreak:
            remaining = TimeInterval(shortBreakMinutes * 60)
        case .longBreak:
            remaining = TimeInterval(longBreakMinutes * 60)
        case .idle:
            remaining = TimeInterval(focusMinutes * 60)
        }
        totalDuration = remaining
    }

    func pause() {
        // Strict mode disallows pausing during a focus session.
        if strictMode && phase == .focus { return }
        running = false
        timer?.invalidate()
        timer = nil
    }

    /// True if the current phase can be paused right now (false if
    /// strict mode is on during a focus block — surfaces in the UI
    /// so the button can be disabled).
    var canPause: Bool { !(strictMode && phase == .focus) }

    func toggle() { running ? pause() : start() }

    func skip() {
        // Jump to end-of-phase without crediting a focus session
        let counted = (phase == .focus)
        finishPhase(creditSession: counted)
    }

    func reset() {
        timer?.invalidate()
        timer = nil
        running = false
        phase = .idle
        remaining = TimeInterval(focusMinutes * 60)
        totalDuration = remaining
    }

    // MARK: - Internals
    private func tick() {
        remaining = max(0, remaining - 1)
        if remaining <= 0 {
            finishPhase(creditSession: phase == .focus)
        }
    }

    private func finishPhase(creditSession: Bool) {
        timer?.invalidate()
        timer = nil
        running = false
        let completedPhase = phase
        if creditSession {
            sessionsToday += 1
            UserDefaults.standard.set(sessionsToday, forKey: "np.pom.sessions")
            UserDefaults.standard.set(Self.dayStamp(), forKey: "np.pom.dayStamp")
        }
        // Decide what comes next
        switch completedPhase {
        case .focus:
            if sessionsToday > 0 && sessionsToday % sessionsBeforeLongBreak == 0 {
                phase = .longBreak
                remaining = TimeInterval(longBreakMinutes * 60)
            } else {
                phase = .shortBreak
                remaining = TimeInterval(shortBreakMinutes * 60)
            }
        case .shortBreak, .longBreak:
            phase = .focus
            remaining = TimeInterval(focusMinutes * 60)
        case .idle:
            return
        }
        totalDuration = remaining
        notifyCompleted(of: completedPhase)
        if autoStartNextPhase {
            // Brief pause so the notification fires before timer ticks.
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { [weak self] in
                self?.start()
            }
        }
    }

    private func notifyCompleted(of completed: PomodoroPhase) {
        // Respects the user's "Sound on timer end" toggle + sound choice
        // in Settings → Pomodoro. No-op if they've muted notifications.
        TimerSound.play()
        let content = UNMutableNotificationContent()
        switch completed {
        case .focus:
            content.title = "Focus complete · \(sessionsToday) today"
            content.body  = "Break time. \(phase.emoji) \(Int(remaining/60))-min " +
                            (phase == .longBreak ? "long break" : "break")
        case .shortBreak, .longBreak:
            content.title = "Break over"
            content.body  = "Back to focus 🍅"
        case .idle:
            return
        }
        content.sound = .default
        let req = UNNotificationRequest(identifier: UUID().uuidString,
                                        content: content, trigger: nil)
        UNUserNotificationCenter.current().add(req)
    }

    // MARK: - Computed
    var progress: Double {
        guard totalDuration > 0 else { return 0 }
        return 1 - (remaining / totalDuration)
    }
    var formattedTime: String {
        let m = Int(remaining) / 60
        let s = Int(remaining) % 60
        return String(format: "%d:%02d", m, s)
    }

    // MARK: - Helpers
    private static func dayStamp() -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f.string(from: Date())
    }
}
