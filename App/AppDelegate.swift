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
    let viewModel = NotchViewModel()

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Hide Dock icon — we want to live in the notch + menubar only.
        NSApp.setActivationPolicy(.accessory)

        installStatusItem()
        installNotchWindow()
        observeScreenChanges()
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
        menu.addItem(withTitle: "About NotchPop", action: #selector(openAbout), keyEquivalent: "")
            .target = self
        menu.addItem(.separator())
        menu.addItem(withTitle: "Toggle Now-Playing widget",
                     action: #selector(toggleNowPlaying), keyEquivalent: "n").target = self
        menu.addItem(withTitle: "Toggle Charging effect",
                     action: #selector(toggleCharging), keyEquivalent: "c").target = self
        menu.addItem(withTitle: "Clear file shelf",
                     action: #selector(clearShelf), keyEquivalent: "")
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

    @objc private func toggleNowPlaying() {
        viewModel.nowPlayingEnabled.toggle()
    }

    @objc private func toggleCharging() {
        viewModel.chargingEnabled.toggle()
    }

    @objc private func clearShelf() {
        viewModel.shelf.clear()
    }
}
