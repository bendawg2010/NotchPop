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

    /// Global click monitor used to collapse the expanded notch when
    /// the user clicks outside our window. Only installed when
    /// viewModel.clickOutsideToCollapse is true; we toggle the
    /// monitor in/out as the setting changes via Combine.
    private var globalClickMonitor: Any?

    init(viewModel: NotchViewModel) {
        self.viewModel = viewModel
        let window = NotchWindow()
        super.init(window: window)

        let host = NSHostingView(rootView: NotchView(viewModel: viewModel))
        // Pin host to all 4 window edges via autoresizing mask. With
        // translatesAutoresizingMaskIntoConstraints=false (the old
        // setting) AND no explicit constraints, the host's frame
        // could end up at any size — SwiftUI layout was rendering at
        // an arbitrary container size, causing the "off to the right"
        // artifact during close (the SwiftUI shape's center wasn't
        // actually the window's center). Switching to autoresize so
        // the host always exactly fills the window contentLayoutRect
        // → SwiftUI layout matches window center on every resize.
        host.translatesAutoresizingMaskIntoConstraints = true
        host.autoresizingMask = [.width, .height]
        window.contentView = host

        viewModel.onSizeChange = { [weak self] in
            self?.applyContentSize()
        }

        repositionForCurrentScreen()
        installGlobalClickMonitor()
    }

    required init?(coder: NSCoder) { fatalError() }

    deinit {
        if let m = globalClickMonitor {
            NSEvent.removeMonitor(m)
        }
    }

    /// Install a global mouse-down monitor that collapses the expanded
    /// notch when the user clicks anywhere outside our window. Honors
    /// Settings → Behavior → "Click outside the notch to collapse it."
    /// Global monitors are passive — they observe events without
    /// consuming them, so user clicks pass through to whatever app
    /// they were targeting.
    private func installGlobalClickMonitor() {
        // No-op if already installed
        if globalClickMonitor != nil { return }
        globalClickMonitor = NSEvent.addGlobalMonitorForEvents(
            matching: [.leftMouseDown, .rightMouseDown, .otherMouseDown]
        ) { [weak self] _ in
            guard let self = self,
                  self.viewModel.clickOutsideToCollapse,
                  self.viewModel.expanded,
                  !self.viewModel.showingWelcome,
                  let window = self.window else { return }
            // NSEvent.mouseLocation is in screen coords (y-up). The
            // window frame is also in screen coords. If the click is
            // outside our window, collapse.
            let screenPoint = NSEvent.mouseLocation
            if !window.frame.contains(screenPoint) {
                DispatchQueue.main.async {
                    withAnimation(.spring(response: 0.42, dampingFraction: 0.85)) {
                        self.viewModel.expanded = false
                    }
                }
            }
        }
    }

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

    /// Re-apply check is suppressed until this Date passes — set when
    /// we kick off an animated window resize so the next-runloop
    /// re-apply doesn't race with the in-progress animation and
    /// snap the window to a half-interpolated frame.
    private var suppressReapplyUntil: Date?

    private func applyContentSize() {
        sizeApplyGeneration &+= 1
        let myGen = sizeApplyGeneration

        // Window SHRINKING → defer the resize ~0.4s so the SwiftUI
        // spring in NotchView's hover handler can fully spring shut
        // INSIDE the still-expanded window before we shrink the
        // window itself. With the host now properly pinned to the
        // window via autoresizing (see init), the SwiftUI shape
        // stays centered during this deferred period — fixes both
        // "no visible animation" (window was snapping shut, clipping
        // the spring invisibly) AND "slid right then jumped back"
        // (host wasn't filling the window, so the shape wasn't truly
        // center-anchored).
        // Window GROWING → apply immediately so the expanded shape
        // has room to render at full size as soon as the spring
        // starts running.
        let newFrame = computeDesiredFrame()
        let cur = window?.frame ?? .zero
        let shrinking = newFrame.width < cur.width - 8 || newFrame.height < cur.height - 8
        if shrinking {
            suppressReapplyUntil = Date().addingTimeInterval(0.45)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.40) { [weak self] in
                guard let self = self,
                      self.sizeApplyGeneration == myGen else { return }
                self.applyFrame()
            }
        } else {
            applyFrame()
        }

        // Force a second pass after the system finishes its async
        // window placement — sometimes macOS overrides the frame for
        // borderless panels with .canJoinAllSpaces collectionBehavior.
        // Critical: bail out if a NEWER applyContentSize has been
        // called since (myGen != current) — otherwise we'd revert
        // the window to OUR stale frame.
        // Also bail if we're inside an animated-shrink suppression
        // window — the in-progress animation will land at the
        // correct frame on its own.
        DispatchQueue.main.async { [weak self] in
            guard let self = self,
                  self.sizeApplyGeneration == myGen,
                  let window = self.window else { return }
            if let until = self.suppressReapplyUntil, Date() < until { return }
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

        // Sync setFrame on purpose. v1.5.20 tried to use
        // window.animator().setFrame inside an NSAnimationContext to
        // smooth the close-animation chop, but that re-introduced
        // the off-center bug: the async re-apply check (next runloop
        // tick) reads window.frame which is STILL animating —
        // interpolated halfway between old and new — sees that
        // current != want, and forces a sync setFrame to whatever
        // the in-progress frame happened to be. Net effect was
        // "off to the left again" because the snapshot landed
        // somewhere mid-animation. Going back to sync setFrame so
        // the frame is always exactly the desired one immediately.
        window.setFrame(newFrame, display: true, animate: false)
    }
}
