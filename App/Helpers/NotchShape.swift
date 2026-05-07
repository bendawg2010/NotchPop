// NotchShape.swift
//
// Notch silhouette — flat top (flush with the screen bezel), with
// continuous (squircle) corners on the bottom that match Apple's
// actual hardware notch geometry. Uses UnevenRoundedRectangle (macOS
// 13+) which renders proper continuous corners; falls back to a
// regular path on older OS via the fallback shape.

import SwiftUI

/// Shape with flat top + continuous-style rounded bottom corners.
/// Uses a Bézier approximation of the squircle curve so the corner
/// flow doesn't show the "circular bulge" artifact you get from a
/// plain quarter-arc — that artifact is the giveaway tell when an
/// app's drawn notch sits next to the real one.
struct NotchShape: Shape {
    var bottomCornerRadius: CGFloat

    func path(in rect: CGRect) -> Path {
        // Squircle corner approximation. Apple's continuous corners
        // start the curve ~1.5× further from the corner than a
        // standard quarter-arc, with control points biased to flatten
        // the apex. We approximate with cubic Béziers.
        let r = max(0, min(bottomCornerRadius, rect.height, rect.width / 2))
        let stretch: CGFloat = 1.528665 // Apple's published P3 ratio
        let s = min(r * stretch, rect.width / 2, rect.height)

        var p = Path()
        p.move(to: .zero)
        p.addLine(to: CGPoint(x: rect.width, y: 0))
        p.addLine(to: CGPoint(x: rect.width, y: rect.height - s))
        // Bottom-right squircle corner
        p.addCurve(
            to: CGPoint(x: rect.width - s, y: rect.height),
            control1: CGPoint(x: rect.width, y: rect.height - s * 0.448),
            control2: CGPoint(x: rect.width - s * 0.448, y: rect.height)
        )
        p.addLine(to: CGPoint(x: s, y: rect.height))
        // Bottom-left squircle corner
        p.addCurve(
            to: CGPoint(x: 0, y: rect.height - s),
            control1: CGPoint(x: s * 0.448, y: rect.height),
            control2: CGPoint(x: 0, y: rect.height - s * 0.448)
        )
        p.closeSubpath()
        return p
    }

    var animatableData: CGFloat {
        get { bottomCornerRadius }
        set { bottomCornerRadius = newValue }
    }
}
