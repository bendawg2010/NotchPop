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

/// NSPanel subclass that allows becoming key + main even though it's
/// a panel. Default NSPanel behavior is non-key for utility windows;
/// for our settings dialog we DO want it focusable.
private final class SettingsPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}

final class SettingsWindowController: NSWindowController {
    private let viewModel: NotchViewModel

    init(viewModel: NotchViewModel) {
        self.viewModel = viewModel
        let host = NSHostingController(rootView: SettingsView(viewModel: viewModel))

        // NSPanel surfaces reliably in LSUIElement (accessory) apps
        // without requiring an activation-policy flip. The previous
        // NSWindow approach needed setActivationPolicy(.regular) to
        // become key — that race-conditioned with makeKeyAndOrderFront
        // on some macOS versions and the window silently failed to
        // appear.
        let panel = SettingsPanel(
            contentRect: NSRect(x: 0, y: 0, width: 540, height: 600),
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.title = "NotchPop Settings"
        panel.contentViewController = host
        panel.center()
        panel.isReleasedWhenClosed = false
        panel.titlebarAppearsTransparent = false
        // Move to whichever Space the user is currently on
        panel.collectionBehavior = [.moveToActiveSpace, .fullScreenAuxiliary]
        panel.hidesOnDeactivate = false
        panel.becomesKeyOnlyIfNeeded = false
        panel.isFloatingPanel = false
        panel.worksWhenModal = true
        panel.setFrameAutosaveName("NotchPopSettings")

        super.init(window: panel)
    }

    required init?(coder: NSCoder) { fatalError("not implemented") }

    /// Show the settings panel. NSPanel surfaces in accessory apps
    /// without requiring activation-policy flips, so this is much
    /// simpler than the v1.5.10 NSWindow path.
    func present() {
        NSLog("NotchPop: SettingsWindowController.present() called")
        guard let window = window else {
            NSLog("NotchPop: ERROR — settings panel is nil")
            return
        }
        if !window.isVisible {
            window.center()
        }
        // Boost level briefly so the panel comes ABOVE the notch panel
        // (which is at .statusBar+1). Dropping back to .normal after a
        // beat means the settings window doesn't permanently float
        // above other apps.
        window.level = .floating
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            window.level = .normal
        }
        NSLog("NotchPop: Settings panel ordered front, isVisible=\(window.isVisible), frame=\(window.frame)")
    }
}
