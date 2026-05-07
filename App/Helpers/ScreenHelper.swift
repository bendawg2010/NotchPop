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
    let notchHeight: CGFloat
    let notchWidth: CGFloat
    let screenSize: CGSize

    static let fallback = ScreenInfo(
        hasNotch: false,
        notchHeight: 32,
        notchWidth: 220,
        screenSize: CGSize(width: 1440, height: 900)
    )
}

enum ScreenHelper {
    static func current() -> ScreenInfo {
        guard let screen = NSScreen.main else { return .fallback }
        let inset = screen.safeAreaInsets.top
        let hasNotch = inset > 0

        var notchWidth: CGFloat = 220
        if hasNotch {
            // The auxiliary top-left and top-right rects sit on either
            // side of the notch. Compute the gap between them.
            if let left = screen.auxiliaryTopLeftArea,
               let right = screen.auxiliaryTopRightArea {
                let gap = right.origin.x - left.maxX
                if gap > 0 { notchWidth = gap }
            }
        }

        return ScreenInfo(
            hasNotch: hasNotch,
            notchHeight: hasNotch ? max(inset, 32) : 36,
            notchWidth: notchWidth,
            screenSize: screen.frame.size
        )
    }
}
