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
        // Pin the settings panel ABOVE the notch panel.
        //
        // Bug we just fixed: the panel was being raised to .floating
        // (level value 3), but the notch panel sits at .statusBar+1
        // (level value 26). Result — settings was ALWAYS rendered
        // BEHIND the notch the moment the level dropped. From the
        // gear-icon path, this manifested as 'the settings button in
        // the notch doesn't work' because the user expected to see
        // the panel and instead nothing visible appeared (the
        // settings window WAS opened, just hidden behind the notch
        // pill in the corner of the screen, easy to miss).
        //
        // Fix: boost to .statusBar + 2 so it's strictly above the
        // notch, and KEEP it there. Setting it back to .normal after
        // 0.4s was actively bad — the moment the timer fired, the
        // settings window dropped below the notch again.
        window.level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.statusWindow)) + 2)
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        NSLog("NotchPop: Settings panel ordered front, level=\(window.level.rawValue), isVisible=\(window.isVisible), frame=\(window.frame)")
    }
}
