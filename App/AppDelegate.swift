// AppDelegate.swift
//
// Owns the menubar item and the floating notch window. Watches for
// screen-config changes (notch dimensions, multi-display setups) and
// re-positions the window over the active screen's notch.

import AppKit
import Combine
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate {
    var notchWindowController: NotchWindowController?
    var statusItem: NSStatusItem?
    var screenChangeCancellable: AnyCancellable?
    var settingsController: SettingsWindowController?
    let viewModel = NotchViewModel()
    let updater = UpdaterController()

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Hide Dock icon — we want to live in the notch + menubar only.
        NSApp.setActivationPolicy(.accessory)

        if viewModel.showMenuBarIcon {
            installStatusItem()
        }
        installNotchWindow()
        observeScreenChanges()
        // Listen for the showMenuBarIcon toggle so we can show/hide
        // the menubar item live without needing a relaunch.
        NotificationCenter.default.addObserver(
            self, selector: #selector(menubarVisibilityChanged),
            name: .npMenubarVisibilityChanged, object: nil)

        // Initialise Sparkle (lazy SPUStandardUpdaterController fires
        // here; see UpdaterController). Wipe any stale "skipped version"
        // marker BEFORE the controller wakes up, so a user who once
        // clicked "Skip This Version" on an old release isn't trapped
        // forever. Then check whether we just got updated since last
        // launch — if so, push a system notification.
        updater.clearSkippedVersionsOnLaunch()
        _ = updater.controller
        updater.notifyIfJustUpdated()
        // Side-channel safety net: 8 seconds after launch, fetch the
        // appcast directly (bypassing Sparkle) and compare to our
        // bundle version. If we're behind, post a system notification
        // with a deep link. Catches the cases where Sparkle's
        // internal state is stuck and "Force Update Now" hasn't
        // been clicked yet.
        DispatchQueue.main.asyncAfter(deadline: .now() + 8) { [weak self] in
            self?.updater.runIndependentVersionCheck()
        }
        // User-configurable Connections trigger — fires once per
        // launch. The user can hook this to "open my IDE on launch"
        // or "play a chime when NotchPop starts."
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            NotificationCenter.default.post(
                name: ConnectionTrigger.appLaunched.notificationName, object: nil)
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        viewModel.persistShelfIfEnabled()
    }

    // MARK: - Status item

    private func installStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        item.button?.image = NSImage(systemSymbolName: "rectangle.bottomthird.inset.filled",
                                     accessibilityDescription: "NotchPop")
        item.button?.toolTip = "NotchPop"

        let menu = NSMenu()
        menu.addItem(withTitle: "Settings…", action: #selector(openSettings), keyEquivalent: ",")
            .target = self
        menu.addItem(.separator())
        // Sparkle handles the entire update flow once the user clicks
        // here: fetches appcast.xml, verifies the EdDSA signature on
        // each entry, downloads the new DMG, prompts the user, swaps
        // the .app bundle on relaunch.
        let updateItem = menu.addItem(
            withTitle: "Check for Updates…",
            action: #selector(UpdaterController.checkForUpdates(_:)),
            keyEquivalent: "u")
        updateItem.target = updater
        // Force-update escape hatch — wipes Sparkle's cached state
        // (skipped versions, last-check time, HTTP cache) and re-checks
        // immediately. Use when Sparkle insists you're "up to date"
        // while the version stamp says otherwise.
        let forceUpdateItem = menu.addItem(
            withTitle: "Force Update Now",
            action: #selector(UpdaterController.forceUpdateNow(_:)),
            keyEquivalent: "")
        forceUpdateItem.target = updater
        menu.addItem(.separator())
        menu.addItem(withTitle: "Clear file shelf",
                     action: #selector(clearShelf), keyEquivalent: "")
            .target = self
        menu.addItem(withTitle: "Reset Pomodoro",
                     action: #selector(resetPomodoro), keyEquivalent: "")
            .target = self
        menu.addItem(withTitle: "Replay welcome animation",
                     action: #selector(replayWelcome), keyEquivalent: "")
            .target = self
        menu.addItem(.separator())
        menu.addItem(withTitle: "About NotchPop",
                     action: #selector(openAbout), keyEquivalent: "")
            .target = self
        menu.addItem(.separator())
        menu.addItem(withTitle: "Quit NotchPop", action: #selector(NSApplication.terminate(_:)),
                     keyEquivalent: "q")

        item.menu = menu
        self.statusItem = item
    }

    // MARK: - Notch window

    private func installNotchWindow() {
        let controller = NotchWindowController(viewModel: viewModel)
        controller.showWindow(self)
        self.notchWindowController = controller
    }

    private func observeScreenChanges() {
        screenChangeCancellable = NotificationCenter.default
            .publisher(for: NSApplication.didChangeScreenParametersNotification)
            .sink { [weak self] _ in
                self?.notchWindowController?.repositionForCurrentScreen()
            }
    }

    // MARK: - Menu actions

    @objc private func openAbout() {
        NSApp.activate(ignoringOtherApps: true)
        NSApp.orderFrontStandardAboutPanel(nil)
    }

    @objc func openSettings() {
        NSLog("NotchPop: AppDelegate.openSettings() invoked")
        // SwiftUI's Settings scene needs an NSMainMenu to wire up the
        // showSettingsWindow: action, which we don't have as an
        // LSUIElement (menu-bar) app. The previous sendAction approach
        // was a no-op because no responder in the chain was registered
        // for that selector. Using a manual NSWindow + NSHostingController
        // bypasses the whole Settings scene mechanism — works every
        // time, no menu-bar dependency.
        if settingsController == nil {
            NSLog("NotchPop: creating SettingsWindowController")
            settingsController = SettingsWindowController(viewModel: viewModel)
        }
        settingsController?.present()
    }

    @objc private func clearShelf() {
        viewModel.shelf.clear()
    }

    @objc private func resetPomodoro() {
        viewModel.pomodoro.reset()
    }

    @objc private func replayWelcome() {
        viewModel.runWelcomePeek()
    }

    @objc private func menubarVisibilityChanged() {
        if viewModel.showMenuBarIcon {
            if statusItem == nil { installStatusItem() }
        } else {
            if let item = statusItem {
                NSStatusBar.system.removeStatusItem(item)
                statusItem = nil
            }
        }
    }
}
