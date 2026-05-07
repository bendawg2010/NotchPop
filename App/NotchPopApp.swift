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
        // The notch itself is rendered by AppDelegate's NotchWindow.
        // The Settings scene is what Cmd+, opens (and what the menubar
        // 'Settings…' item triggers). We pass the live viewModel so
        // the customization toggles affect the running notch.
        Settings {
            SettingsView(viewModel: appDelegate.viewModel)
        }
    }
}
