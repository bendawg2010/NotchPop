// NotchWindow.swift
//
// Borderless, transparent, always-on-top NSWindow that hugs the
// MacBook notch. Resizes when the SwiftUI content asks to expand.
// Stays out of mission-control / spaces switching — it's a single
// pinned UI element across the system.

import AppKit
import SwiftUI

/// Borderless overlay panel that lives at the very top-center of the
/// active screen. We use NSPanel (not NSWindow) with `.nonactivatingPanel`
/// so the notch can become key — letting users actually TYPE into the
/// Quick Notes pane — WITHOUT NotchPop stealing app focus from the
/// Mac's frontmost app. Plain NSWindow with canBecomeKey=true would
/// activate NotchPop and steal focus on every click.
final class NotchWindow: NSPanel {
    init() {
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 220, height: 36),
            styleMask: [.borderless, .fullSizeContentView, .nonactivatingPanel],
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
        // Allow becoming key so TextEditor receives keystrokes
        self.hidesOnDeactivate = false
        self.becomesKeyOnlyIfNeeded = true
    }

    /// True so SwiftUI text fields receive keystrokes. The
    /// .nonactivatingPanel style keeps NotchPop from becoming the
    /// active app — the previously-frontmost app stays frontmost.
    override var canBecomeKey: Bool { true }
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
        if let screen = ScreenHelper.notchedScreen() {
            let frame = window.frame
            let x = screen.frame.midX - frame.width / 2
            let y = screen.frame.maxY - frame.height
            window.setFrameOrigin(NSPoint(x: x, y: y))
        }
    }

    private func applyContentSize() {
        guard let window = window else { return }
        // 4pt hover gutter (was 18pt — too aggressive, opened on
        // every brush past the top of the screen). Now you have to
        // actually be on the notch shape itself.
        let hoverGutter: CGFloat = 4
        let target = viewModel.targetSize
        let frameWidth  = target.width
        let frameHeight = target.height + hoverGutter

        // Always center on the SCREEN's midX, never the window's
        // current midX. The previous code used window.frame.midX which
        // drifts when the window resizes asymmetrically (e.g. expanding
        // wider with a live activity), causing the expanded notch to
        // land off-center from the hardware notch.
        let screenMidX: CGFloat
        let topY: CGFloat
        if let screen = ScreenHelper.notchedScreen() {
            screenMidX = screen.frame.midX
            topY = screen.frame.maxY
        } else {
            screenMidX = window.frame.midX
            topY = window.frame.maxY
        }
        let newOriginX = screenMidX - frameWidth / 2
        let newOriginY = topY - frameHeight
        let newFrame = NSRect(x: newOriginX, y: newOriginY,
                              width: frameWidth, height: frameHeight)
        window.setFrame(newFrame, display: true, animate: false)
    }
}
