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

    /// Bumped on every applyContentSize() call. The async re-apply
    /// pass aborts if a newer call has happened in the meantime —
    /// otherwise an OLDER applyContentSize's stale newFrame would
    /// race against a newer call's correct frame and revert the
    /// window to the wrong position. ("Starts fine THEN jumps to
    /// the left.")
    private var sizeApplyGeneration: UInt64 = 0

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
        sizeApplyGeneration &+= 1
        let myGen = sizeApplyGeneration
        applyFrame()

        // Force a second pass after the system finishes its async
        // window placement — sometimes macOS overrides the frame for
        // borderless panels with .canJoinAllSpaces collectionBehavior.
        // Critical: bail out if a NEWER applyContentSize has been
        // called since (myGen != current) — otherwise we'd revert the
        // window to OUR stale frame and undo the newer call's correct
        // frame. That race was the root cause of "starts fine THEN
        // jumps to the left" on display reconnect / live-activity
        // toggle / welcome-glow padding kick-in.
        DispatchQueue.main.async { [weak self] in
            guard let self = self,
                  self.sizeApplyGeneration == myGen,
                  let window = self.window else { return }

            // Also recompute the *current* desired frame (from the
            // current viewModel + chosen screen) rather than reusing
            // a captured value. If viewModel.targetSize changed in
            // the same runloop, applyFrame() will land us on the
            // newest desired frame instead of an older one.
            let want = self.computeDesiredFrame()
            let cur = window.frame
            if abs(cur.origin.x - want.origin.x) > 0.5
                || abs(cur.origin.y - want.origin.y) > 0.5
                || abs(cur.size.width  - want.size.width)  > 0.5
                || abs(cur.size.height - want.size.height) > 0.5 {
                NSLog("NotchPop: re-applying frame after macOS override (was %@, want %@)",
                      NSStringFromRect(cur), NSStringFromRect(want))
                window.setFrame(want, display: true, animate: false)
            }
        }
    }

    /// Compute the frame we'd LIKE the notch to have right now, given
    /// the current viewModel + ScreenHelper choice. Returns NSRect.zero
    /// if we don't have a window. Single source of truth used by both
    /// applyFrame() and the async re-apply check.
    private func computeDesiredFrame() -> NSRect {
        guard let window = window else { return .zero }
        let hoverGutter: CGFloat = 4
        let target = viewModel.targetSize
        let frameWidth  = target.width
        let frameHeight = target.height + hoverGutter

        let screenMidX: CGFloat
        let topY: CGFloat
        if let screen = ScreenHelper.notchedScreen() {
            screenMidX = screen.frame.midX
            topY = screen.frame.maxY
        } else {
            // Fall back to current window position rather than
            // recomputing relative to a guess — at least the window
            // doesn't get yeeted to the wrong spot. midX is already
            // the center of the window, so use it directly.
            screenMidX = window.frame.midX
            topY = window.frame.maxY
        }
        return NSRect(x: screenMidX - frameWidth / 2,
                      y: topY - frameHeight,
                      width: frameWidth,
                      height: frameHeight)
    }

    private func applyFrame() {
        guard let window = window else { return }

        // Diagnostic — check Console.app for these to debug centering
        // issues on user reports. Lists every screen so we can see
        // whether ScreenHelper picked the right one.
        let chosen = ScreenHelper.notchedScreen()
        let chosenName = chosen?.localizedName ?? "FALLBACK (notchedScreen returned nil)"
        let chosenFrame = chosen?.frame ?? .zero
        let newFrame = computeDesiredFrame()
        let allScreens = NSScreen.screens.enumerated().map { idx, s in
            "[\(idx)] \(s.localizedName) frame=\(s.frame) safeTop=\(s.safeAreaInsets.top)"
        }.joined(separator: " | ")
        NSLog("NotchPop centering: chose '%@' frame=%@ → newFrame=%@ | all screens: %@",
              chosenName, NSStringFromRect(chosenFrame),
              NSStringFromRect(newFrame), allScreens)
        window.setFrame(newFrame, display: true, animate: false)
    }
}
