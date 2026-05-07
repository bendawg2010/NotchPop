// NotchPopApp.swift — main entry point.
//
// We do NOT use a SwiftUI WindowGroup; the entire UI is a single
// floating, transparent NSWindow that hugs the MacBook notch and
// expands on hover. SwiftUI is the renderer, AppKit is the host.
//
// The app runs as `LSUIElement = true` (no Dock icon, no menu bar),
// configurable from System Settings if we add a settings window
// later. A menubar item provides quit/settings access.

import SwiftUI

@main
struct NotchPopApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        // Empty scene — AppDelegate owns the real window. SwiftUI's
        // App protocol requires *some* Scene, so we give it a settings
        // scene that's never opened in v1.
        Settings {
            SettingsView()
        }
    }
}
