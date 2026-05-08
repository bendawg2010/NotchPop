// ConnectionsService.swift
//
// Tiny "when X happens, do Y" automation engine. The user defines
// connections in Settings → Connections; the service listens for the
// trigger events from elsewhere in the app (Pomodoro phase changes,
// charging start, music start, etc.) and runs the matching actions.
//
// Triggers map to events posted on the default NotificationCenter
// under names exposed via Notification.Name extensions in this file.
// Other modules post the trigger names; ConnectionsService observes
// and dispatches.
//
// Actions are intentionally simple — anything more powerful belongs
// in macOS Shortcuts.app or AppleScript:
//   • launch_app: open a macOS app by file path
//   • open_url:   open a URL in the default browser
//   • run_shortcut: run a macOS Shortcuts shortcut by name (via
//                   `shortcuts run "<name>"` shell)
//   • play_sound: play a TimerSound choice — useful as a "ping me
//                  when this happens" notifier without writing a
//                  custom AppleScript
//
// Persistence: stored in UserDefaults under "np.connections" as JSON.
// Each connection has a UUID, so removing/reordering is straight-
// forward.

import AppKit
import Combine
import Foundation

enum ConnectionTrigger: String, Codable, CaseIterable, Identifiable {
    case pomodoroFocusStart    = "pomodoro_focus_start"
    case pomodoroFocusEnd      = "pomodoro_focus_end"
    case pomodoroBreakStart    = "pomodoro_break_start"
    case pomodoroBreakEnd      = "pomodoro_break_end"
    case countdownEnd          = "countdown_end"
    case chargingStart         = "charging_start"
    case musicStart            = "music_start"
    case musicEnd              = "music_end"
    case appLaunched           = "app_launched"

    var id: String { rawValue }

    var label: String {
        switch self {
        case .pomodoroFocusStart: return "Pomodoro focus starts"
        case .pomodoroFocusEnd:   return "Pomodoro focus ends"
        case .pomodoroBreakStart: return "Pomodoro break starts"
        case .pomodoroBreakEnd:   return "Pomodoro break ends"
        case .countdownEnd:       return "Countdown timer ends"
        case .chargingStart:      return "Charging starts"
        case .musicStart:         return "Music starts playing"
        case .musicEnd:           return "Music stops playing"
        case .appLaunched:        return "NotchPop launches"
        }
    }

    var notificationName: Notification.Name {
        Notification.Name("np.trigger.\(rawValue)")
    }
}

enum ConnectionAction: String, Codable, CaseIterable, Identifiable {
    case launchApp    = "launch_app"
    case openURL      = "open_url"
    case runShortcut  = "run_shortcut"
    case playSound    = "play_sound"
    case copyText     = "copy_text"

    var id: String { rawValue }

    var label: String {
        switch self {
        case .launchApp:    return "Launch an app"
        case .openURL:      return "Open a URL"
        case .runShortcut:  return "Run a macOS Shortcut"
        case .playSound:    return "Play a sound"
        case .copyText:     return "Copy text to clipboard"
        }
    }

    var argLabel: String {
        switch self {
        case .launchApp:    return "App path (or drop an app here)"
        case .openURL:      return "URL"
        case .runShortcut:  return "Shortcut name"
        case .playSound:    return "Sound name (e.g. Glass)"
        case .copyText:     return "Text"
        }
    }
}

struct Connection: Identifiable, Codable, Equatable {
    let id: UUID
    var trigger: ConnectionTrigger
    var action: ConnectionAction
    var arg: String           // app path / URL / shortcut name / sound / text
    var enabled: Bool

    init(id: UUID = UUID(),
         trigger: ConnectionTrigger,
         action: ConnectionAction,
         arg: String,
         enabled: Bool = true) {
        self.id = id
        self.trigger = trigger
        self.action = action
        self.arg = arg
        self.enabled = enabled
    }
}

final class ConnectionsService: ObservableObject {
    private static let key = "np.connections"

    @Published var connections: [Connection] = [] {
        didSet { persist() }
    }

    private var observers: [NSObjectProtocol] = []

    init() {
        restore()
        installObservers()
    }

    deinit {
        for o in observers { NotificationCenter.default.removeObserver(o) }
    }

    /// Subscribe to all trigger notifications. Other parts of the app
    /// post these whenever the corresponding event happens (e.g.
    /// PomodoroService posts pomodoroFocusStart on phase enter).
    private func installObservers() {
        for trigger in ConnectionTrigger.allCases {
            let obs = NotificationCenter.default.addObserver(
                forName: trigger.notificationName,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                self?.fireTrigger(trigger)
            }
            observers.append(obs)
        }
    }

    /// Run every enabled connection that matches this trigger.
    private func fireTrigger(_ trigger: ConnectionTrigger) {
        let toRun = connections.filter { $0.enabled && $0.trigger == trigger }
        guard !toRun.isEmpty else { return }
        NSLog("NotchPop: connections — firing \(toRun.count) for \(trigger.rawValue)")
        for c in toRun { run(c) }
    }

    private func run(_ c: Connection) {
        switch c.action {
        case .launchApp:
            let url = URL(fileURLWithPath: c.arg)
            NSWorkspace.shared.openApplication(at: url,
                                                configuration: NSWorkspace.OpenConfiguration(),
                                                completionHandler: nil)
        case .openURL:
            var raw = c.arg.trimmingCharacters(in: .whitespaces)
            if !raw.contains("://") { raw = "https://" + raw }
            if let url = URL(string: raw) { NSWorkspace.shared.open(url) }
        case .runShortcut:
            // Use `shortcuts run` (built into macOS Monterey+). Run
            // detached so we don't block the main thread waiting.
            let task = Process()
            task.launchPath = "/usr/bin/shortcuts"
            task.arguments = ["run", c.arg]
            try? task.run()
        case .playSound:
            TimerSound.playRaw(name: c.arg.isEmpty ? TimerSound.defaultChoice : c.arg)
        case .copyText:
            let pb = NSPasteboard.general
            pb.clearContents()
            pb.setString(c.arg, forType: .string)
        }
    }

    // MARK: - CRUD

    func add(_ connection: Connection) {
        connections.append(connection)
    }

    func remove(_ connection: Connection) {
        connections.removeAll { $0.id == connection.id }
    }

    func toggle(_ connection: Connection) {
        guard let i = connections.firstIndex(where: { $0.id == connection.id }) else { return }
        connections[i].enabled.toggle()
    }

    func update(_ connection: Connection) {
        guard let i = connections.firstIndex(where: { $0.id == connection.id }) else { return }
        connections[i] = connection
    }

    // MARK: - Persistence

    private func persist() {
        guard let data = try? JSONEncoder().encode(connections) else { return }
        UserDefaults.standard.set(data, forKey: Self.key)
    }

    private func restore() {
        guard let data = UserDefaults.standard.data(forKey: Self.key),
              let decoded = try? JSONDecoder().decode([Connection].self, from: data)
        else { return }
        self.connections = decoded
    }

    /// Manually fire a trigger from the Settings UI for testing.
    func testFire(_ trigger: ConnectionTrigger) {
        NotificationCenter.default.post(name: trigger.notificationName, object: nil)
    }
}
