// NotchWindow.swift
//
// Borderless, transparent, always-on-top NSWindow that hugs the
// MacBook notch. Resizes when the SwiftUI content asks to expand.
// Stays out of mission-control / spaces switching — it's a single
// pinned UI element across the system.

import AppKit
import SwiftUI

/// Borderless overlay window that lives at the very top-center of the
/// active screen. Mouse events pass through transparent areas.
final class NotchWindow: NSWindow {
    init() {
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 220, height: 36),
            styleMask: [.borderless, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        // Above everything, including full-screen app menubar
        self.level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.statusWindow)) + 1)
        self.collectionBehavior = [
            .canJoinAllSpaces,
            .stationary,
            .ignoresCycle,
            .fullScreenAuxiliary,
        ]
        self.isOpaque = false
        self.backgroundColor = .clear
        self.hasShadow = false
        self.isMovableByWindowBackground = false
        self.isReleasedWhenClosed = false
        self.acceptsMouseMovedEvents = true
        self.titlebarAppearsTransparent = true
        self.titleVisibility = .hidden
        self.ignoresMouseEvents = false
    }

    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}

/// Owns the NotchWindow and binds it to a SwiftUI hosting view that
/// renders the actual notch UI. Repositions when the screen changes
/// or when the SwiftUI content reports a new desired size.
final class NotchWindowController: NSWindowController {
    private let viewModel: NotchViewModel
    private var sizeCancellable: NSObjectProtocol?

    init(viewModel: NotchViewModel) {
        self.viewModel = viewModel
        let window = NotchWindow()
        super.init(window: window)

        let host = NSHostingView(rootView: NotchView(viewModel: viewModel))
        host.translatesAutoresizingMaskIntoConstraints = false
        window.contentView = host

        viewModel.onSizeChange = { [weak self] in
            self?.applyContentSize()
        }

        repositionForCurrentScreen()
    }

    required init?(coder: NSCoder) { fatalError() }

    func repositionForCurrentScreen() {
        guard let window = window else { return }
        let info = ScreenHelper.current()
        viewModel.screenInfo = info
        applyContentSize()

        // Pin window so the visible notch sits centered on the screen's
        // top edge. Even on non-notched MBPs we still pin top-center to
        // mimic the same UI.
        if let screen = NSScreen.main {
            let frame = window.frame
            let x = screen.frame.midX - frame.width / 2
            let y = screen.frame.maxY - frame.height
            window.setFrameOrigin(NSPoint(x: x, y: y))
        }
    }

    private func applyContentSize() {
        guard let window = window else { return }
        let target = viewModel.targetSize
        let current = window.frame.size
        if abs(current.width - target.width) < 0.5 && abs(current.height - target.height) < 0.5 {
            return
        }
        // Keep top edge pinned to screen top
        let topY = window.frame.maxY
        let newOriginX = (window.frame.midX - target.width / 2)
        let newOriginY = topY - target.height
        let newFrame = NSRect(x: newOriginX, y: newOriginY,
                              width: target.width, height: target.height)
        window.setFrame(newFrame, display: true, animate: false)
    }
}
