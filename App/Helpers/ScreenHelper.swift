// ScreenHelper.swift
//
// Detect the MacBook notch dimensions on the active screen. macOS 12+
// exposes `safeAreaInsets.top` per NSScreen — that's the notch height.
// Width comes from `auxiliaryTopLeftArea` / `auxiliaryTopRightArea`
// (macOS 12+) which describe the ledge segments either side of the
// notch; the gap between them = notch width.

import AppKit

struct ScreenInfo: Equatable {
    let hasNotch: Bool
    /// Hardware notch height in points (= safeAreaInsets.top on notched
    /// MBPs). Typical: 32pt on 14"/16" M-series.
    let notchHeight: CGFloat
    /// Hardware notch width in points. Typical: ~178pt on 14"/16".
    let notchWidth: CGFloat
    /// Bottom-corner radius of the hardware notch. Apple uses ~8.5pt
    /// continuous on current hardware. We measure where possible, fall
    /// back to 8.5 otherwise.
    let notchCornerRadius: CGFloat
    let screenSize: CGSize

    static let fallback = ScreenInfo(
        hasNotch: false,
        notchHeight: 32,
        notchWidth: 200,
        notchCornerRadius: 8.5,
        screenSize: CGSize(width: 1440, height: 900)
    )
}

enum ScreenHelper {
    /// Returns the screen we should pin the notch UI to. Critical bug
    /// fix: NSScreen.main returns whatever screen has KEYBOARD focus,
    /// which shifts as the user switches windows between displays. So
    /// the notch UI was wandering to whichever monitor was last clicked.
    /// We always want the screen that HAS THE NOTCH (built-in MBP
    /// display), regardless of where the active window lives.
    static func notchedScreen() -> NSScreen? {
        // 1. Prefer a screen with an actual hardware notch
        if let notched = NSScreen.screens.first(where: { $0.safeAreaInsets.top > 0 }) {
            return notched
        }
        // 2. Fall back to the primary screen (origin == .zero in macOS
        //    is the screen with the menu bar — the laptop's display
        //    even when an external monitor is connected).
        if let primary = NSScreen.screens.first(where: { $0.frame.origin == .zero }) {
            return primary
        }
        // 3. Last resort
        return NSScreen.main
    }

    static func current() -> ScreenInfo {
        guard let screen = notchedScreen() else { return .fallback }
        let inset = screen.safeAreaInsets.top
        let hasNotch = inset > 0

        // Precise notch width: the gap between auxiliaryTopLeftArea
        // and auxiliaryTopRightArea. macOS publishes these as the
        // "ledge" segments either side of the notch.
        var notchWidth: CGFloat = 200
        if hasNotch {
            if let left = screen.auxiliaryTopLeftArea,
               let right = screen.auxiliaryTopRightArea {
                let gap = right.origin.x - left.maxX
                if gap > 0 { notchWidth = gap }
            }
        }

        return ScreenInfo(
            hasNotch: hasNotch,
            // Real notch is ~31.something on M-series; safeAreaInsets
            // returns the rounded value. Use it as-is so our shape's
            // top edge sits exactly flush with the bezel.
            notchHeight: hasNotch ? inset : 32,
            notchWidth: notchWidth,
            // Hardware corner radius is ~8.5pt continuous. Apple has
            // not published an API to read it.
            notchCornerRadius: hasNotch ? 8.5 : 10,
            screenSize: screen.frame.size
        )
    }
}
