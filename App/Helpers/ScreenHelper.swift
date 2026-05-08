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
    /// Cached display ID of the notched screen. We resolve once per
    /// session (or until didChangeScreenParametersNotification fires),
    /// then look it up by ID on every subsequent notchedScreen() call.
    /// Without this cache, notchedScreen() walked NSScreen.screens on
    /// every applyContentSize() — sometimes finding the screen, then
    /// sometimes not (e.g. transient CGDisplayIsBuiltin-returns-false
    /// during display sleep transitions), causing the notch to jump
    /// between screens within one user session.
    private static var cachedDisplayID: CGDirectDisplayID?
    private static var observerInstalled = false

    private static func installObserverIfNeeded() {
        guard !observerInstalled else { return }
        observerInstalled = true
        NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil,
            queue: .main
        ) { _ in
            // Invalidate; the next notchedScreen() call re-resolves.
            cachedDisplayID = nil
        }
    }

    /// Returns the screen we should pin the notch UI to. Multi-tier
    /// fallback because every detection method is unreliable on SOME
    /// hardware combo:
    ///
    /// 1. Cached display ID (if still present in NSScreen.screens) —
    ///    keeps our choice stable across calls in the same session.
    /// 2. CGDisplayIsBuiltin — the most authoritative way to find the
    ///    laptop's internal display. Works even when safeAreaInsets is
    ///    misreported, even when display arrangement puts the laptop
    ///    at non-zero origin, even with multiple notched displays.
    /// 3. safeAreaInsets.top > 0 — works on most Macs but has been
    ///    seen to false-zero on some external-display configs.
    /// 4. Primary screen (origin == .zero) — the menu-bar display.
    /// 5. NSScreen.main — last resort. Returns whichever screen has
    ///    keyboard focus right now, which shifts as the user clicks
    ///    around — so we treat it as a poor tiebreaker only.
    static func notchedScreen() -> NSScreen? {
        installObserverIfNeeded()

        // 1. Use the cached choice if it's still around
        if let id = cachedDisplayID {
            for screen in NSScreen.screens {
                if screenDisplayID(screen) == id { return screen }
            }
            // Display was unplugged — fall through and re-resolve
            cachedDisplayID = nil
        }

        // 2. Built-in display via CGDisplayIsBuiltin
        for screen in NSScreen.screens {
            guard let id = screenDisplayID(screen) else { continue }
            if CGDisplayIsBuiltin(id) != 0 {
                cachedDisplayID = id
                return screen
            }
        }
        // 3. Prefer a screen with a non-zero top safe-area inset
        if let notched = NSScreen.screens.first(where: { $0.safeAreaInsets.top > 0 }) {
            cachedDisplayID = screenDisplayID(notched)
            return notched
        }
        // 4. Primary screen (origin == .zero) — the menu-bar display
        if let primary = NSScreen.screens.first(where: { $0.frame.origin == .zero }) {
            cachedDisplayID = screenDisplayID(primary)
            return primary
        }
        // 5. Last resort — explicitly do NOT cache .main, it shifts.
        return NSScreen.main
    }

    /// Force the next notchedScreen() call to re-resolve from scratch.
    /// Bound to the Diagnostics → Re-detect screen button.
    static func invalidateCache() { cachedDisplayID = nil }

    private static func screenDisplayID(_ screen: NSScreen) -> CGDirectDisplayID? {
        let key = NSDeviceDescriptionKey("NSScreenNumber")
        guard let raw = screen.deviceDescription[key] as? NSNumber else { return nil }
        return raw.uint32Value as CGDirectDisplayID
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
