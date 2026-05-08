// NotchBackgroundView.swift
//
// Renders one of the preset NotchBackground choices as a SwiftUI view
// suitable for use as the expanded-notch fill. Each preset uses a
// LinearGradient / RadialGradient / AngularGradient stack +
// optionally some lightweight decorative dots / particles.
// Collapsed mode is always solid black via a different code path —
// the choices here only kick in when expanded so the hardware notch
// blend is preserved.

import SwiftUI

struct NotchBackgroundView: View {
    let background: NotchBackground
    /// Whether to animate decorative elements (twinkling stars,
    /// drifting hue). Honors the user's Reduce Motion preference
    /// from the parent.
    var animated: Bool = true

    var body: some View {
        Group {
            switch background {
            case .classicBlack: classicBlackBG
            case .galaxy:       galaxyBG
            case .sunset:       sunsetBG
            case .ocean:        oceanBG
            case .aurora:       auroraBG
            case .midnight:     midnightBG
            case .carbon:       carbonBG
            case .rosegold:     rosegoldBG
            }
        }
    }

    // MARK: - Classic black (default)
    private var classicBlackBG: some View {
        Color.black
    }

    // MARK: - Galaxy — deep blue/purple/pink with twinkling stars
    private var galaxyBG: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.04, green: 0.02, blue: 0.10),
                    Color(red: 0.10, green: 0.04, blue: 0.22),
                    Color(red: 0.20, green: 0.06, blue: 0.32),
                    Color(red: 0.06, green: 0.02, blue: 0.18),
                ],
                startPoint: .topLeading, endPoint: .bottomTrailing)
            // A nebula glow — soft bright spot top-right
            RadialGradient(
                colors: [
                    Color(red: 1.00, green: 0.40, blue: 0.78).opacity(0.55),
                    Color(red: 0.62, green: 0.30, blue: 0.96).opacity(0.20),
                    Color.clear
                ],
                center: UnitPoint(x: 0.78, y: 0.18),
                startRadius: 0, endRadius: 220)
            // A second cooler nebula bottom-left
            RadialGradient(
                colors: [
                    Color(red: 0.30, green: 0.55, blue: 1.00).opacity(0.45),
                    Color(red: 0.20, green: 0.35, blue: 0.85).opacity(0.18),
                    Color.clear
                ],
                center: UnitPoint(x: 0.20, y: 0.85),
                startRadius: 0, endRadius: 180)
            stars
        }
    }

    /// 25 small stars at fixed but visually-random positions, twinkling
    /// at slightly different rates. Cheap and pretty; doesn't need a
    /// real RNG since the positions are baked.
    private var stars: some View {
        TimelineView(.animation(minimumInterval: animated ? 0.08 : 60)) { ctx in
            let t = ctx.date.timeIntervalSinceReferenceDate
            ZStack {
                ForEach(0..<starPoints.count, id: \.self) { i in
                    let p = starPoints[i]
                    let phase = animated
                        ? (sin(t * Double(p.speed) + Double(p.phase)) * 0.5 + 0.5)
                        : 0.7
                    Circle()
                        .fill(Color.white)
                        .frame(width: CGFloat(p.size), height: CGFloat(p.size))
                        .position(x: p.x, y: p.y)
                        .opacity(0.25 + 0.55 * phase)
                }
            }
        }
    }

    private struct StarPos {
        let x: CGFloat; let y: CGFloat; let size: Double
        let speed: Double; let phase: Double
    }
    private var starPoints: [StarPos] {
        // Hand-placed positions in a 520x178 reference frame; the
        // overlay clips/positions to whatever frame it's rendered in.
        [
            StarPos(x: 24,  y: 16,  size: 1.5, speed: 1.2, phase: 0),
            StarPos(x: 88,  y: 140, size: 2.0, speed: 0.9, phase: 1.1),
            StarPos(x: 145, y: 32,  size: 1.5, speed: 1.4, phase: 2.3),
            StarPos(x: 200, y: 90,  size: 2.5, speed: 0.7, phase: 3.0),
            StarPos(x: 280, y: 25,  size: 1.5, speed: 1.6, phase: 0.6),
            StarPos(x: 320, y: 110, size: 2.0, speed: 1.0, phase: 4.2),
            StarPos(x: 380, y: 60,  size: 1.5, speed: 1.3, phase: 1.8),
            StarPos(x: 425, y: 145, size: 2.5, speed: 0.8, phase: 2.7),
            StarPos(x: 488, y: 30,  size: 1.5, speed: 1.5, phase: 5.0),
            StarPos(x: 60,  y: 75,  size: 1.0, speed: 1.7, phase: 3.5),
            StarPos(x: 175, y: 160, size: 1.5, speed: 1.1, phase: 0.9),
            StarPos(x: 250, y: 50,  size: 1.0, speed: 1.9, phase: 4.7),
            StarPos(x: 350, y: 165, size: 2.0, speed: 0.85, phase: 2.0),
            StarPos(x: 450, y: 90,  size: 1.5, speed: 1.25, phase: 1.4),
            StarPos(x: 110, y: 60,  size: 1.0, speed: 2.0, phase: 0.3),
            StarPos(x: 230, y: 130, size: 1.5, speed: 1.05, phase: 3.8),
            StarPos(x: 410, y: 12,  size: 1.5, speed: 1.6, phase: 5.5),
            StarPos(x: 470, y: 55,  size: 1.0, speed: 1.8, phase: 2.5),
            StarPos(x: 30,  y: 130, size: 1.0, speed: 1.4, phase: 1.7),
            StarPos(x: 360, y: 130, size: 1.0, speed: 1.6, phase: 4.0),
        ]
    }

    // MARK: - Sunset
    private var sunsetBG: some View {
        LinearGradient(
            colors: [
                Color(red: 0.18, green: 0.04, blue: 0.32),
                Color(red: 0.62, green: 0.18, blue: 0.42),
                Color(red: 1.00, green: 0.42, blue: 0.32),
                Color(red: 1.00, green: 0.71, blue: 0.33),
            ],
            startPoint: .top, endPoint: .bottom)
    }

    // MARK: - Ocean
    private var oceanBG: some View {
        LinearGradient(
            colors: [
                Color(red: 0.04, green: 0.10, blue: 0.18),
                Color(red: 0.06, green: 0.22, blue: 0.38),
                Color(red: 0.10, green: 0.42, blue: 0.55),
                Color(red: 0.16, green: 0.62, blue: 0.72),
            ],
            startPoint: .top, endPoint: .bottom)
    }

    // MARK: - Aurora — animated green/blue/purple drift
    private var auroraBG: some View {
        TimelineView(.animation(minimumInterval: animated ? 0.05 : 60)) { ctx in
            let t = ctx.date.timeIntervalSinceReferenceDate
            let hue = animated
                ? (t.truncatingRemainder(dividingBy: 14) / 14) * 360
                : 0
            ZStack {
                Color(red: 0.02, green: 0.04, blue: 0.10)
                LinearGradient(
                    colors: [
                        Color(red: 0.18, green: 0.82, blue: 0.62).opacity(0.55),
                        Color(red: 0.30, green: 0.50, blue: 0.95).opacity(0.55),
                        Color(red: 0.62, green: 0.30, blue: 0.96).opacity(0.55),
                    ],
                    startPoint: .topLeading, endPoint: .bottomTrailing)
                    .hueRotation(.degrees(hue))
                    .blur(radius: 22)
            }
        }
    }

    // MARK: - Midnight
    private var midnightBG: some View {
        LinearGradient(
            colors: [
                Color(red: 0.02, green: 0.04, blue: 0.10),
                Color(red: 0.06, green: 0.10, blue: 0.20),
                Color(red: 0.10, green: 0.14, blue: 0.28),
            ],
            startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    // MARK: - Carbon (subtle dark gradient)
    private var carbonBG: some View {
        LinearGradient(
            colors: [
                Color(red: 0.10, green: 0.10, blue: 0.10),
                Color(red: 0.04, green: 0.04, blue: 0.04),
                Color(red: 0.12, green: 0.12, blue: 0.13),
            ],
            startPoint: .top, endPoint: .bottom)
    }

    // MARK: - Rose gold
    private var rosegoldBG: some View {
        LinearGradient(
            colors: [
                Color(red: 0.30, green: 0.10, blue: 0.18),
                Color(red: 0.78, green: 0.40, blue: 0.42),
                Color(red: 1.00, green: 0.78, blue: 0.62),
            ],
            startPoint: .topLeading, endPoint: .bottomTrailing)
    }
}
