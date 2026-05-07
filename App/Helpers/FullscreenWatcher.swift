// FullscreenWatcher.swift
//
// Watches whether ANY app is currently in macOS native fullscreen.
// We use this to auto-hide the notch overlay when the user is in
// fullscreen video / games / coding sessions — the black bar over
// what should be a bezel is jarring during media.
//
// Detection strategy: poll NSWorkspace.shared.frontmostApplication
// every 0.5s and check if its frontmost window is on a fullscreen
// space. We rely on CGWindowListCopyWindowInfo to inspect the
// application's window bounds vs. screen bounds; if they match
// (within 1pt) AND it occupies the screen alone, we treat it as
// fullscreen.

import AppKit
import Combine
import CoreGraphics

final class FullscreenWatcher: ObservableObject {
    @Published var anyAppFullscreen: Bool = false
    private var timer: Timer?

    func start() {
        stop()
        check()
        timer = Timer.scheduledTimer(withTimeInterval: 0.6, repeats: true) { [weak self] _ in
            self?.check()
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    private func check() {
        guard let screen = NSScreen.main else { return }
        let screenFrame = screen.frame

        // Window list filter: on-screen, normal layer (0). Excludes
        // dock, menubar, and our own overlay.
        let opts: CGWindowListOption = [.optionOnScreenOnly, .excludeDesktopElements]
        guard let info = CGWindowListCopyWindowInfo(opts, kCGNullWindowID)
                          as? [[String: AnyObject]] else {
            DispatchQueue.main.async { self.anyAppFullscreen = false }
            return
        }

        var isFullscreen = false
        for w in info {
            guard let layer = w[kCGWindowLayer as String] as? Int, layer == 0 else { continue }
            guard let bounds = w[kCGWindowBounds as String] as? [String: CGFloat] else { continue }
            let rect = CGRect(
                x: bounds["X"] ?? 0,
                y: bounds["Y"] ?? 0,
                width: bounds["Width"] ?? 0,
                height: bounds["Height"] ?? 0
            )
            // CGWindow uses top-left origin in display coordinates.
            // Compare against the active screen size, allowing 1pt slop.
            let widthMatches = abs(rect.width - screenFrame.width) < 1.5
            let heightMatches = abs(rect.height - screenFrame.height) < 1.5
            if widthMatches && heightMatches {
                isFullscreen = true
                break
            }
        }

        DispatchQueue.main.async { [weak self] in
            self?.anyAppFullscreen = isFullscreen
        }
    }
}
