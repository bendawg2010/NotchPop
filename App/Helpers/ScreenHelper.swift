// ScreenHelper.swift
//
// Detect the MacBook notch dimensions on the active screen. macOS 12+
// exposes `safeAreaInsets.top` per NSScreen — that's the notch height.
// Width comes from `auxiliaryTopLeftArea` / `auxiliaryTopRightArea`
// (macOS 12+) which describe the ledge segments either side of the
// notch; the gap between them = notch width.

import AppKit
import CoreGraphics

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
    /// Returns the screen we should pin the notch UI to. Three-tier
    /// fallback because every detection method is unreliable on SOME
    /// hardware combo:
    ///
    /// 1. CGDisplayIsBuiltin — the most authoritative way to find the
    ///    laptop's internal display. Works even when safeAreaInsets is
    ///    misreported, even when display arrangement puts the laptop
    ///    at non-zero origin, even with multiple notched displays.
    /// 2. safeAreaInsets.top > 0 — works on most Macs but has been
    ///    seen to false-zero on some external-display configs.
    /// 3. NSScreen.main — last resort. Returns whichever screen has
    ///    keyboard focus right now, which shifts as the user clicks
    ///    around — so we treat it as a poor tiebreaker only.
    static func notchedScreen() -> NSScreen? {
        // 1. Built-in display via CGDisplayIsBuiltin
        for screen in NSScreen.screens {
            let key = NSDeviceDescriptionKey("NSScreenNumber")
            guard let raw = screen.deviceDescription[key] as? NSNumber else { continue }
            let displayID = raw.uint32Value as CGDirectDisplayID
            if CGDisplayIsBuiltin(displayID) != 0 {
                return screen
            }
        }
        // 2. Prefer a screen with a non-zero top safe-area inset
        if let notched = NSScreen.screens.first(where: { $0.safeAreaInsets.top > 0 }) {
            return notched
        }
        // 3. Primary screen (origin == .zero) — the menu-bar display
        if let primary = NSScreen.screens.first(where: { $0.frame.origin == .zero }) {
            return primary
        }
        // 4. Last resort
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
