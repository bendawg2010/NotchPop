// SettingsWindowController.swift
//
// SwiftUI's `Settings { ... }` Scene works fine for normal apps —
// macOS auto-installs the "Settings…" menu item and wires Cmd+, to
// `NSApp.showSettingsWindow:`. For LSUIElement (menu-bar) apps with
// no NSMainMenu, that wiring isn't installed, so calling
// `NSApp.sendAction(showSettingsWindow:)` silently goes nowhere.
//
// This controller bypasses the Settings scene entirely. We host
// SettingsView in our own NSWindow + NSHostingController, manage
// it with a single shared instance, and let AppDelegate.openSettings
// just call `showWindow(_:)`. Reliable on every macOS version.

import AppKit
import SwiftUI

final class SettingsWindowController: NSWindowController {
    private let viewModel: NotchViewModel

    init(viewModel: NotchViewModel) {
        self.viewModel = viewModel
        let host = NSHostingController(rootView: SettingsView(viewModel: viewModel))

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 540, height: 600),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "NotchPop Settings"
        window.contentViewController = host
        window.center()
        window.isReleasedWhenClosed = false
        window.titlebarAppearsTransparent = false
        // Restore on every launch so the user can reopen at the same
        // size if they resized.
        window.setFrameAutosaveName("NotchPopSettings")

        super.init(window: window)
    }

    required init?(coder: NSCoder) { fatalError("not implemented") }

    /// Bring the settings window to the foreground. Since we're an
    /// LSUIElement (accessory) app, we have to flip the activation
    /// policy temporarily so the window can become key. We restore
    /// .accessory when the window closes (handled in AppDelegate).
    func present() {
        guard let window = window else { return }
        NSApp.setActivationPolicy(.regular)
        if !window.isVisible {
            window.center()
        }
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}
