// DesignAnimations.swift
//
// SwiftUI ports of 5 of the 8 animations from the Anthropic Design
// "8 Animations" handoff (claude.ai/design). Each is a reusable
// View that callers drop in at the right place. Colors come from
// the brand palette: pink #FF6B6B, magenta #C147FF, blue #47A0FF,
// mint #2EE6A0, yellow #FFD960.
//
// Animations included:
//   • PomodoroTideRing  — water-tide-fill ring variant for Pomodoro
//   • ConcentricHaloBackdrop — expanding-rings welcome halo
//   • AmbientNotchShimmer — top-edge aurora shimmer for collapsed notch
//   • ElasticSquishTransition — squish-and-stretch scene transition
//   • AirDropPulseSignal — concentric arcs for live-activity signals
//
// The three not implemented here are already represented elsewhere:
//   • AuroraFlow / DepthRings → WallPop presets
//   • NotchyMusic → NotchyMascot.swift's new `.music` state

import SwiftUI

// MARK: - PomodoroTideRing
//
// A 64×64 ring where the progress is shown as a sloshing water tide
// rising from bottom toward top — instead of the standard arc-stroke
// orbit. Tints follow the phase color the caller passes in.
struct PomodoroTideRing: View {
    /// 0...1 — fraction of the focus phase ELAPSED (we draw the
    /// inverse so "near full" reads as "lots of time left").
    var progress: Double
    /// Phase tint — color of the rising water. Caller passes the
    /// already-themed color (Focus → pink, Short → mint, Long → blue).
    var tint: Color = Color(red: 0.28, green: 0.63, blue: 1.00)
    /// Center text. Usually "MM:SS".
    var label: String

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30)) { ctx in
            let t = ctx.date.timeIntervalSinceReferenceDate
            ZStack {
                Circle()
                    .stroke(Color.white.opacity(0.08), lineWidth: 5)
                Canvas { ctx, size in
                    let cx = size.width / 2, cy = size.height / 2
                    let r = min(size.width, size.height) / 2 - 3
                    // Clip to ring interior
                    var clip = Path()
                    clip.addEllipse(in: CGRect(x: cx - r, y: cy - r,
                                                width: r * 2, height: r * 2))
                    ctx.clip(to: clip)

                    // Water level — when progress=0 we're full; when
                    // progress=1 the tide has receded out the top.
                    let waterY = cy - r + CGFloat(progress) * (r * 2)

                    // Sloshing wave path
                    var wave = Path()
                    let steps = 32
                    for i in 0...steps {
                        let x = CGFloat(i) / CGFloat(steps) * size.width
                        let y = waterY + CGFloat(sin(t * 2 + Double(i) * 0.4) * 1.8)
                        if i == 0 { wave.move(to: CGPoint(x: x, y: y)) }
                        else { wave.addLine(to: CGPoint(x: x, y: y)) }
                    }
                    wave.addLine(to: CGPoint(x: size.width, y: size.height))
                    wave.addLine(to: CGPoint(x: 0, y: size.height))
                    wave.closeSubpath()

                    let grad = Gradient(colors: [tint, tint.opacity(0.55)])
                    ctx.fill(wave, with: .linearGradient(
                        grad,
                        startPoint: CGPoint(x: 0, y: waterY - 6),
                        endPoint: CGPoint(x: 0, y: size.height)))
                }
                Text(label)
                    .font(.system(size: 13, weight: .heavy, design: .rounded))
                    .foregroundColor(.white)
                    .monospacedDigit()
            }
        }
    }
}

// MARK: - ConcentricHaloBackdrop
//
// 4 expanding ellipses pulsing outward from the center, color-cycled
// pink → magenta → blue → mint, on top of a soft radial glow. Used as
// an alternative welcome halo backdrop. Sits behind the notch panel.
struct ConcentricHaloBackdrop: View {
    /// Speed multiplier (1.0 = stock).
    var speed: Double = 0.5
    /// Base halo tint behind the rings.
    var baseTint: Color = Color(red: 0.76, green: 0.28, blue: 1.00)

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 60)) { ctx in
            let t = ctx.date.timeIntervalSinceReferenceDate
            GeometryReader { geo in
                ZStack {
                    // Radial backdrop glow
                    Ellipse()
                        .fill(RadialGradient(
                            colors: [baseTint.opacity(0.50),
                                     baseTint.opacity(0)],
                            center: .center,
                            startRadius: 0,
                            endRadius: max(geo.size.width, geo.size.height) * 0.55))
                        .blendMode(.plusLighter)
                    // 4 concentric expanding rings, staggered phases
                    Canvas { ctx, size in
                        let cx = size.width / 2, cy = size.height / 2
                        let palette: [Color] = [
                            Color(red: 1.00, green: 0.42, blue: 0.42),
                            Color(red: 0.76, green: 0.28, blue: 1.00),
                            Color(red: 0.28, green: 0.63, blue: 1.00),
                            Color(red: 0.18, green: 0.90, blue: 0.63)]
                        for i in 0..<4 {
                            let phase = ((t * speed) + Double(i) * 0.25)
                                .truncatingRemainder(dividingBy: 1)
                            let rx = 60 + phase * (size.width * 0.45)
                            let ry = 40 + phase * (size.height * 0.45)
                            let op = max(0, 1 - phase) * 0.6
                            let rect = CGRect(x: cx - rx, y: cy - ry,
                                               width: rx * 2, height: ry * 2)
                            ctx.stroke(Path(ellipseIn: rect),
                                       with: .color(palette[i].opacity(op)),
                                       lineWidth: 2)
                        }
                    }
                }
            }
        }
    }
}

// MARK: - AmbientNotchShimmer
//
// Tiny aurora shimmer along the inner top edge of the collapsed
// notch. Long period (~6s) so it reads as "alive but never pulls
// focus." Drop on top of the collapsed notch background as an
// overlay; sized to match the notch's internal width.
struct AmbientNotchShimmer: View {
    /// Height of the shimmer band in points (default 8).
    var height: CGFloat = 8
    /// Reduce-motion mode → render a flat dim gradient with no animation.
    var reduceMotion: Bool = false

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30)) { ctx in
            let t = reduceMotion ? 0 : ctx.date.timeIntervalSinceReferenceDate
            // Hex strings from animations-8.jsx — alpha bytes get
            // mixed in via opacity multipliers because Color(hex:)
            // isn't built in. Drift the stops slightly along x for
            // aurora-like motion.
            let pinkOp = sin(t * 0.6) * 0.30 + 0.50
            let magentaOp = sin(t * 0.5 + 1) * 0.30 + 0.50
            let blueOp = sin(t * 0.7 + 2) * 0.30 + 0.50
            let pinkX = 0.20 + sin(t * 0.4) * 0.15
            let magentaX = 0.50 + cos(t * 0.5) * 0.10
            let blueX = 0.80 + sin(t * 0.3) * 0.10
            LinearGradient(stops: [
                .init(color: .clear, location: 0),
                .init(color: Color(red: 1.00, green: 0.42, blue: 0.42).opacity(pinkOp),
                      location: pinkX),
                .init(color: Color(red: 0.76, green: 0.28, blue: 1.00).opacity(magentaOp),
                      location: magentaX),
                .init(color: Color(red: 0.28, green: 0.63, blue: 1.00).opacity(blueOp),
                      location: blueX),
                .init(color: .clear, location: 1),
            ], startPoint: .leading, endPoint: .trailing)
                .frame(height: height)
                .blur(radius: 4)
                .opacity(0.55)
                .allowsHitTesting(false)
        }
    }
}

// MARK: - ElasticSquishTransition
//
// AnyTransition that combines a scale-with-elasticity squish (out) +
// stretch (in) with opacity. Adopt with `.transition(.elasticSquish)`.
extension AnyTransition {
    static var elasticSquish: AnyTransition {
        let out = AnyTransition.modifier(
            active: ElasticSquishModifier(progress: 1, exiting: true),
            identity: ElasticSquishModifier(progress: 0, exiting: true))
        let inT = AnyTransition.modifier(
            active: ElasticSquishModifier(progress: 1, exiting: false),
            identity: ElasticSquishModifier(progress: 0, exiting: false))
        return .asymmetric(insertion: inT, removal: out)
    }
}

private struct ElasticSquishModifier: ViewModifier {
    /// 0 = identity, 1 = fully squished/stretched. Animates between.
    var progress: Double
    /// Out (exiting=true) horizontally squashes; In (exiting=false)
    /// vertically stretches. Both fade.
    var exiting: Bool

    var animatableData: Double {
        get { progress }
        set { progress = newValue }
    }

    func body(content: Content) -> some View {
        let p = max(0, min(1, progress))
        let sx: CGFloat
        let sy: CGFloat
        let opacity: Double
        if exiting {
            sx = CGFloat(1 - p * 0.4)
            sy = CGFloat(1 + p * 0.3)
            opacity = 1 - p
        } else {
            sx = CGFloat(0.6 + (1 - p) * 0.4)
            sy = CGFloat(1.3 - (1 - p) * 0.3)
            opacity = 1 - p
        }
        return content
            .scaleEffect(x: sx, y: sy, anchor: .center)
            .opacity(opacity)
    }
}

// MARK: - AirDropPulseSignal
//
// Three concentric arcs expanding from a central dot — designed for
// the right side of the live-activity pill (38pt × 22pt area).
// Caller gives us the size; we render at native pixel positions.
// Tint defaults to mint, the AirDrop semantic green.
struct AirDropPulseSignal: View {
    var tint: Color = Color(red: 0.18, green: 0.90, blue: 0.63)

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30)) { ctx in
            let t = ctx.date.timeIntervalSinceReferenceDate
            Canvas { ctx, size in
                let cx = size.width / 2, cy = size.height / 2
                let maxR = min(size.width, size.height) / 2
                let phases: [Double] = [0, 0.5, 1]
                for p in phases {
                    let phase = (t * 0.8 + p)
                        .truncatingRemainder(dividingBy: 1.5)
                    let r = 4 + CGFloat(phase) * (maxR - 4)
                    let op = max(0, 1 - phase / 1.5)
                    let rect = CGRect(x: cx - r, y: cy - r,
                                       width: r * 2, height: r * 2)
                    ctx.stroke(Path(ellipseIn: rect),
                               with: .color(tint.opacity(op)),
                               lineWidth: 1.5)
                }
                // Solid center dot
                ctx.fill(Path(ellipseIn: CGRect(x: cx - 2.5, y: cy - 2.5,
                                                  width: 5, height: 5)),
                         with: .color(tint))
            }
        }
    }
}
