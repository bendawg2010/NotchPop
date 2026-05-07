// LaunchAtLogin.swift
//
// Toggle "open NotchPop automatically at login" via Apple's modern
// SMAppService API (macOS 13+). The user sees a checkbox in our
// Settings; the actual registration happens here. macOS shows the
// app in System Settings → General → Login Items so users can
// also disable it from there.

import AppKit
import ServiceManagement

enum LaunchAtLogin {
    /// True if NotchPop is currently registered to start at login.
    static var isEnabled: Bool {
        if #available(macOS 13.0, *) {
            return SMAppService.mainApp.status == .enabled
        }
        return false
    }

    /// Register or unregister. Returns true on success.
    @discardableResult
    static func setEnabled(_ enabled: Bool) -> Bool {
        guard #available(macOS 13.0, *) else { return false }
        do {
            if enabled {
                if SMAppService.mainApp.status != .enabled {
                    try SMAppService.mainApp.register()
                }
            } else {
                if SMAppService.mainApp.status == .enabled {
                    try SMAppService.mainApp.unregister()
                }
            }
            return true
        } catch {
            // Common failures: the user clicked Allow once but later
            // toggled it off in System Settings; or the app isn't in
            // /Applications yet. Surface as a system alert.
            DispatchQueue.main.async {
                let alert = NSAlert()
                alert.messageText = "Couldn't \(enabled ? "enable" : "disable") launch at login"
                alert.informativeText = error.localizedDescription
                    + "\n\nTip: make sure NotchPop is in /Applications, then try again."
                alert.alertStyle = .warning
                alert.addButton(withTitle: "OK")
                alert.runModal()
            }
            return false
        }
    }
}
