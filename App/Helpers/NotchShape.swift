// NotchShape.swift
//
// The rounded-bottom shape that mimics the MacBook notch. Flat top
// edge (sits flush with the screen bezel), rounded bottom-left and
// bottom-right corners. Reuses for both the collapsed pill and the
// expanded panel.

import SwiftUI

struct NotchShape: Shape {
    var bottomCornerRadius: CGFloat

    func path(in rect: CGRect) -> Path {
        let r = min(bottomCornerRadius, rect.height / 2, rect.width / 2)
        var p = Path()
        p.move(to: CGPoint(x: 0, y: 0))
        p.addLine(to: CGPoint(x: rect.width, y: 0))
        p.addLine(to: CGPoint(x: rect.width, y: rect.height - r))
        p.addArc(
            center: CGPoint(x: rect.width - r, y: rect.height - r),
            radius: r,
            startAngle: .degrees(0),
            endAngle: .degrees(90),
            clockwise: false
        )
        p.addLine(to: CGPoint(x: r, y: rect.height))
        p.addArc(
            center: CGPoint(x: r, y: rect.height - r),
            radius: r,
            startAngle: .degrees(90),
            endAngle: .degrees(180),
            clockwise: false
        )
        p.closeSubpath()
        return p
    }

    var animatableData: CGFloat {
        get { bottomCornerRadius }
        set { bottomCornerRadius = newValue }
    }
}
