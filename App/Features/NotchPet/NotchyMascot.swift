// NotchyMascot.swift
//
// SwiftUI port of "Notchy" — the official NotchPop mascot designed
// in Claude Design (claude.ai/design). The body IS the notch shape:
// a horizontal pill capsule with stubby arms + legs and a face
// inside, with a soft radial halo behind that shifts color per
// state. Replaces the earlier blob-style NotchPetSprite.
//
// The design space is 200×130 (matches the SVG viewBox from the
// design handoff). Body box is x 30..170, y 36..84 — width 140,
// height 48, corner radius 24. We render in absolute coordinates
// inside a ZStack(.frame(200x130)) and scale to whatever container
// size the caller hands us.
//
// 12 states mapped from the design's state names:
//   idle / alert / focused / celebrate / sleep / love / thinking /
//   listening / charging / dnd / sad / wink

import SwiftUI

enum NotchyState: String, CaseIterable {
    case idle, alert, focused, celebrate, sleep
    case love, thinking, listening, charging, dnd, sad, wink

    /// Per-state glow halo color (matches the design's GLOW table).
    var glowColor: Color {
        switch self {
        case .idle, .alert:    return Color(red: 0.47, green: 0.29, blue: 0.63) // PURPLE
        case .focused:         return Color(red: 0.17, green: 0.52, blue: 0.77) // BLUE
        case .celebrate, .love, .wink:
                               return Color(red: 1.00, green: 0.24, blue: 0.67) // PINK
        case .sleep:           return Color(red: 0.23, green: 0.16, blue: 0.33) // dim indigo
        case .thinking:        return Color(red: 0.42, green: 0.56, blue: 0.83)
        case .listening:       return Color(red: 0.62, green: 0.37, blue: 0.75)
        case .charging:        return Color(red: 0.24, green: 0.84, blue: 0.55)
        case .dnd:             return Color(red: 0.90, green: 0.32, blue: 0.32)
        case .sad:             return Color(red: 0.33, green: 0.46, blue: 0.66)
        }
    }
}

/// Geometry of the notch-capsule body. Same numbers as the SVG.
/// Named "BodyGeo" because plain "Body" collides with SwiftUI's
/// `View.Body` associated type — Swift resolves bare "Body" inside
/// a View's body to `Self.Body` (which is `some View`), not our
/// private enum, so accessing .x/.y on it errors.
private enum BodyGeo {
    static let x: CGFloat = 30
    static let y: CGFloat = 36
    static let w: CGFloat = 140
    static let h: CGFloat = 48
    static let r: CGFloat = 24
}

/// Pose data per state — limb endpoints, body offset, hand/foot
/// positions. Translated from the design's POSES table.
private struct Pose {
    let bodyDx: CGFloat
    let bodyDy: CGFloat
    /// Each line: x1, y1, x2, y2
    let armL: (CGFloat, CGFloat, CGFloat, CGFloat)
    let armR: (CGFloat, CGFloat, CGFloat, CGFloat)
    let legL: (CGFloat, CGFloat, CGFloat, CGFloat)
    let legR: (CGFloat, CGFloat, CGFloat, CGFloat)
    let handL: (CGFloat, CGFloat)
    let handR: (CGFloat, CGFloat)
    let footL: (CGFloat, CGFloat)
    let footR: (CGFloat, CGFloat)

    static let table: [NotchyState: Pose] = [
        .idle: Pose(
            bodyDx: 0, bodyDy: 0,
            armL: (30, 60, 14, 68), armR: (170, 60, 186, 68),
            legL: (78, 84, 72, 110), legR: (122, 84, 128, 110),
            handL: (14, 68), handR: (186, 68),
            footL: (72, 112), footR: (128, 112)),
        .alert: Pose(
            bodyDx: 0, bodyDy: -3,
            armL: (30, 56, 6, 30), armR: (170, 56, 194, 30),
            legL: (78, 84, 64, 108), legR: (122, 84, 136, 108),
            handL: (6, 30), handR: (194, 30),
            footL: (64, 110), footR: (136, 110)),
        .focused: Pose(
            bodyDx: 0, bodyDy: 0,
            armL: (30, 60, 18, 78), armR: (170, 60, 182, 78),
            legL: (78, 84, 72, 110), legR: (122, 84, 128, 110),
            handL: (18, 78), handR: (182, 78),
            footL: (72, 112), footR: (128, 112)),
        .celebrate: Pose(
            bodyDx: 0, bodyDy: -2,
            armL: (30, 50, 4, 18), armR: (170, 50, 196, 18),
            legL: (78, 84, 60, 100), legR: (122, 84, 140, 100),
            handL: (4, 18), handR: (196, 18),
            footL: (60, 102), footR: (140, 102)),
        .sleep: Pose(
            bodyDx: 0, bodyDy: 2,
            armL: (38, 70, 60, 84), armR: (162, 70, 140, 84),
            legL: (84, 84, 84, 108), legR: (116, 84, 116, 108),
            handL: (60, 84), handR: (140, 84),
            footL: (84, 110), footR: (116, 110)),
        .love: Pose(
            bodyDx: 0, bodyDy: 0,
            armL: (40, 64, 86, 80), armR: (160, 64, 114, 80),
            legL: (78, 84, 72, 110), legR: (122, 84, 128, 110),
            handL: (90, 82), handR: (110, 82),
            footL: (72, 112), footR: (128, 112)),
        .thinking: Pose(
            bodyDx: 0, bodyDy: 0,
            armL: (30, 60, 14, 70), armR: (170, 64, 130, 78),
            legL: (78, 84, 72, 110), legR: (122, 84, 128, 110),
            handL: (14, 70), handR: (128, 78),
            footL: (72, 112), footR: (128, 112)),
        .listening: Pose(
            bodyDx: 0, bodyDy: -1,
            armL: (30, 56, 8, 40), armR: (170, 64, 194, 80),
            legL: (78, 84, 64, 108), legR: (122, 84, 136, 108),
            handL: (8, 40), handR: (194, 80),
            footL: (64, 110), footR: (136, 110)),
        .charging: Pose(
            bodyDx: 0, bodyDy: 0,
            armL: (30, 60, 14, 36), armR: (170, 60, 186, 36),
            legL: (78, 84, 70, 110), legR: (122, 84, 130, 110),
            handL: (14, 36), handR: (186, 36),
            footL: (70, 112), footR: (130, 112)),
        .dnd: Pose(
            bodyDx: 0, bodyDy: 0,
            armL: (36, 56, 116, 80), armR: (164, 56, 84, 80),
            legL: (78, 84, 78, 110), legR: (122, 84, 122, 110),
            handL: (116, 80), handR: (84, 80),
            footL: (78, 112), footR: (122, 112)),
        .sad: Pose(
            bodyDx: 0, bodyDy: 4,
            armL: (32, 66, 22, 92), armR: (168, 66, 178, 92),
            legL: (80, 84, 76, 110), legR: (120, 84, 124, 110),
            handL: (22, 94), handR: (178, 94),
            footL: (76, 112), footR: (124, 112)),
        .wink: Pose(
            bodyDx: 0, bodyDy: 0,
            armL: (30, 60, 14, 68), armR: (170, 56, 198, 26),
            legL: (78, 84, 72, 110), legR: (122, 84, 128, 110),
            handL: (14, 68), handR: (198, 26),
            footL: (72, 112), footR: (128, 112)),
    ]
}

/// The mascot view. Renders in a 200×130 design space; scales to
/// the parent frame. Pass a state to control pose + face + halo
/// color. Animations between states animate via SwiftUI implicit
/// transitions.
struct NotchyMascot: View {
    var state: NotchyState = .idle
    /// Body fill — defaults to the dark hardware-notch black so the
    /// mascot reads as the notch itself when placed on a dark UI.
    var bodyFill: Color = Color(red: 0.04, green: 0.03, blue: 0.05)
    /// Detail (eyes/mouth/limbs) color — defaults to white.
    var detail: Color = .white
    /// Whether to render the halo glow behind the body.
    var showHalo: Bool = true

    private var pose: Pose {
        Pose.table[state] ?? Pose.table[.idle]!
    }

    var body: some View {
        Canvas { context, size in
            // Transform the 200×130 design space onto the actual
            // canvas size, preserving aspect by using the smaller
            // axis ratio (so the mascot doesn't squish).
            let scale = min(size.width / 200, size.height / 130)
            let dx = (size.width - 200 * scale) / 2
            let dy = (size.height - 130 * scale) / 2
            context.translateBy(x: dx, y: dy)
            context.scaleBy(x: scale, y: scale)

            // Halo behind everything
            if showHalo {
                drawHalo(context: context)
            }

            // Body offset per pose
            context.translateBy(x: pose.bodyDx, y: pose.bodyDy)

            // Legs (drawn first so feet sit BEHIND the body's
            // curved lower edge)
            drawLine(context: context, from: pose.legL.0, pose.legL.1,
                     to: pose.legL.2, pose.legL.3, color: bodyFill)
            drawLine(context: context, from: pose.legR.0, pose.legR.1,
                     to: pose.legR.2, pose.legR.3, color: bodyFill)
            drawDot(context: context, x: pose.footL.0, y: pose.footL.1,
                    radius: 6, color: bodyFill)
            drawDot(context: context, x: pose.footR.0, y: pose.footR.1,
                    radius: 6, color: bodyFill)

            // Arms
            drawLine(context: context, from: pose.armL.0, pose.armL.1,
                     to: pose.armL.2, pose.armL.3, color: bodyFill)
            drawLine(context: context, from: pose.armR.0, pose.armR.1,
                     to: pose.armR.2, pose.armR.3, color: bodyFill)
            drawDot(context: context, x: pose.handL.0, y: pose.handL.1,
                    radius: 6, color: bodyFill)
            drawDot(context: context, x: pose.handR.0, y: pose.handR.1,
                    radius: 6, color: bodyFill)

            // Body — the notch capsule
            let bodyRect = CGRect(x: BodyGeo.x, y: BodyGeo.y,
                                   width: BodyGeo.w, height: BodyGeo.h)
            var bodyPath = Path()
            bodyPath.addRoundedRect(in: bodyRect,
                                     cornerSize: CGSize(width: BodyGeo.r,
                                                          height: BodyGeo.r))
            context.fill(bodyPath, with: .color(bodyFill))

            // Inner sheen
            let sheen = CGRect(x: BodyGeo.x + 6, y: BodyGeo.y + 4,
                                width: BodyGeo.w - 12, height: 10)
            var sheenPath = Path()
            sheenPath.addRoundedRect(in: sheen,
                                       cornerSize: CGSize(width: 6, height: 6))
            context.fill(sheenPath, with: .color(.white.opacity(0.05)))

            // Face
            drawFace(context: context)

            // Sleep Z's float to the upper right, OUTSIDE the body.
            // Reset transforms first since Z's are positioned in
            // absolute design space (not relative to body offset).
            if state == .sleep {
                context.translateBy(x: -pose.bodyDx, y: -pose.bodyDy)
                drawSleepZs(context: context)
            }
        }
    }

    // MARK: - Draw helpers

    private func drawHalo(context: GraphicsContext) {
        // Radial gradient ellipse 105×55 centered at (100, 60)
        let rect = CGRect(x: 100 - 105, y: 60 - 55, width: 210, height: 110)
        var path = Path()
        path.addEllipse(in: rect)
        context.fill(path, with: .radialGradient(
            Gradient(stops: [
                .init(color: state.glowColor.opacity(0.65), location: 0.0),
                .init(color: state.glowColor.opacity(0.18), location: 0.6),
                .init(color: state.glowColor.opacity(0.0),  location: 1.0),
            ]),
            center: CGPoint(x: 100, y: 60),
            startRadius: 0, endRadius: 105))
        // Soft blur effect — Canvas doesn't blur natively at draw
        // time but stacking the same gradient at lower opacity
        // produces a similar feel without filter cost.
    }

    private func drawLine(context: GraphicsContext,
                           from x1: CGFloat, _ y1: CGFloat,
                           to x2: CGFloat, _ y2: CGFloat,
                           color: Color) {
        var path = Path()
        path.move(to: CGPoint(x: x1, y: y1))
        path.addLine(to: CGPoint(x: x2, y: y2))
        context.stroke(path, with: .color(color),
                       style: StrokeStyle(lineWidth: 6, lineCap: .round))
    }

    private func drawDot(context: GraphicsContext,
                          x: CGFloat, y: CGFloat,
                          radius: CGFloat, color: Color) {
        var path = Path()
        path.addEllipse(in: CGRect(x: x - radius, y: y - radius,
                                     width: radius * 2,
                                     height: radius * 2))
        context.fill(path, with: .color(color))
    }

    private func drawCircle(context: GraphicsContext,
                             x: CGFloat, y: CGFloat,
                             radius: CGFloat, color: Color) {
        drawDot(context: context, x: x, y: y, radius: radius, color: color)
    }

    private func drawEllipse(context: GraphicsContext,
                              cx: CGFloat, cy: CGFloat,
                              rx: CGFloat, ry: CGFloat, color: Color) {
        var path = Path()
        path.addEllipse(in: CGRect(x: cx - rx, y: cy - ry,
                                     width: rx * 2, height: ry * 2))
        context.fill(path, with: .color(color))
    }

    // MARK: - Face per state (matches the SVG NotchyFace cases)

    private func drawFace(context: GraphicsContext) {
        let cy: CGFloat = 56
        let lx: CGFloat = 76
        let rx: CGFloat = 124

        switch state {
        case .idle:
            drawCircle(context: context, x: lx, y: cy, radius: 5.5, color: detail)
            drawCircle(context: context, x: rx, y: cy, radius: 5.5, color: detail)
            drawCircle(context: context, x: lx + 1.6, y: cy - 1.8, radius: 1.6, color: .white)
            drawCircle(context: context, x: rx + 1.6, y: cy - 1.8, radius: 1.6, color: .white)
            drawSmile(context: context, fromX: 94, midX: 100, toX: 106, midY: 74, baseY: 70)
        case .alert:
            drawCircle(context: context, x: lx, y: cy - 1, radius: 7, color: detail)
            drawCircle(context: context, x: rx, y: cy - 1, radius: 7, color: detail)
            drawCircle(context: context, x: lx + 2, y: cy - 3, radius: 2, color: .white)
            drawCircle(context: context, x: rx + 2, y: cy - 3, radius: 2, color: .white)
            drawEllipse(context: context, cx: 100, cy: 71, rx: 3.4, ry: 4, color: detail)
        case .focused:
            // Brows
            drawStrokeLine(context: context, from: lx - 6, cy - 9, to: lx + 5, cy - 6, color: detail, w: 2.4)
            drawStrokeLine(context: context, from: rx - 5, cy - 6, to: rx + 6, cy - 9, color: detail, w: 2.4)
            // Squinted eyes
            drawEllipse(context: context, cx: lx, cy: cy + 1, rx: 4.5, ry: 2, color: detail)
            drawEllipse(context: context, cx: rx, cy: cy + 1, rx: 4.5, ry: 2, color: detail)
            // Mouth + tongue
            var rect = Path()
            rect.addRoundedRect(in: CGRect(x: 92, y: 68, width: 11, height: 2.4),
                                 cornerSize: CGSize(width: 1.2, height: 1.2))
            context.fill(rect, with: .color(detail))
            drawEllipse(context: context, cx: 106, cy: 72, rx: 3, ry: 3.6,
                         color: Color(red: 1.00, green: 0.42, blue: 0.66))
        case .celebrate:
            // ^_^ eyes
            drawArc(context: context, fromX: lx - 6, baseY: cy + 2, toX: lx + 6,
                    midY: cy - 6, color: detail, w: 2.6)
            drawArc(context: context, fromX: rx - 6, baseY: cy + 2, toX: rx + 6,
                    midY: cy - 6, color: detail, w: 2.6)
            // Big smile
            drawArc(context: context, fromX: 90, baseY: 66, toX: 110,
                    midY: 78, color: detail, w: 2.6)
        case .sleep:
            drawArc(context: context, fromX: lx - 6, baseY: cy, toX: lx + 6,
                    midY: cy + 5, color: detail, w: 2.4)
            drawArc(context: context, fromX: rx - 6, baseY: cy, toX: rx + 6,
                    midY: cy + 5, color: detail, w: 2.4)
            drawArc(context: context, fromX: 96, baseY: 70, toX: 104,
                    midY: 73, color: detail, w: 2.4)
        case .love:
            drawHeart(context: context, x: lx, y: cy)
            drawHeart(context: context, x: rx, y: cy)
            drawArc(context: context, fromX: 92, baseY: 68, toX: 108,
                    midY: 75, color: detail, w: 2.4)
        case .thinking:
            drawCircle(context: context, x: lx, y: cy, radius: 5, color: detail)
            drawCircle(context: context, x: rx, y: cy, radius: 5, color: detail)
            drawCircle(context: context, x: lx - 1.6, y: cy - 1.6, radius: 1.6, color: .white)
            drawCircle(context: context, x: rx - 1.6, y: cy - 1.6, radius: 1.6, color: .white)
            // asymmetric mouth
            drawArc(context: context, fromX: 92, baseY: 70, toX: 108, midY: 70,
                    color: detail, w: 2.2, controlOffset: -2, controlEndY: 72)
        case .listening:
            // Eyes-closed groove + open smile
            drawArc(context: context, fromX: lx - 6, baseY: cy + 1, toX: lx + 6,
                    midY: cy - 6, color: detail, w: 2.4)
            drawArc(context: context, fromX: rx - 6, baseY: cy + 1, toX: rx + 6,
                    midY: cy - 6, color: detail, w: 2.4)
            drawArc(context: context, fromX: 92, baseY: 68, toX: 108,
                    midY: 76, color: detail, w: 2.4)
        case .charging:
            drawEllipse(context: context, cx: lx, cy: cy, rx: 4.5, ry: 3.5, color: detail)
            drawEllipse(context: context, cx: rx, cy: cy, rx: 4.5, ry: 3.5, color: detail)
            drawArc(context: context, fromX: 92, baseY: 70, toX: 108,
                    midY: 74, color: detail, w: 2.2)
        case .dnd:
            drawStrokeLine(context: context, from: lx - 7, cy - 7, to: lx + 6, cy - 4,
                            color: detail, w: 2.6)
            drawStrokeLine(context: context, from: rx - 6, cy - 4, to: rx + 7, cy - 7,
                            color: detail, w: 2.6)
            drawEllipse(context: context, cx: lx, cy: cy + 1, rx: 4, ry: 2.4, color: detail)
            drawEllipse(context: context, cx: rx, cy: cy + 1, rx: 4, ry: 2.4, color: detail)
            drawStrokeLine(context: context, from: 92, 71, to: 108, 71,
                            color: detail, w: 2.4)
        case .sad:
            drawCircle(context: context, x: lx, y: cy + 1, radius: 4.5, color: detail)
            drawCircle(context: context, x: rx, y: cy + 1, radius: 4.5, color: detail)
            // Tear
            var tear = Path()
            tear.move(to: CGPoint(x: 71, y: 60))
            tear.addQuadCurve(to: CGPoint(x: 73, y: 66),
                               control: CGPoint(x: 69, y: 66))
            tear.addQuadCurve(to: CGPoint(x: 71, y: 60),
                               control: CGPoint(x: 75, y: 64))
            tear.closeSubpath()
            context.fill(tear, with: .color(Color(red: 0.48, green: 0.72, blue: 0.91)))
            // Frown
            drawArc(context: context, fromX: 92, baseY: 73, toX: 108,
                    midY: 68, color: detail, w: 2.4)
        case .wink:
            // Open eye on the left
            drawCircle(context: context, x: lx, y: cy, radius: 5, color: detail)
            drawCircle(context: context, x: lx - 1.6, y: cy - 1.8, radius: 1.6, color: .white)
            // Closed (wink) eye on the right
            drawArc(context: context, fromX: rx - 6, baseY: cy + 1, toX: rx + 6,
                    midY: cy - 4, color: detail, w: 2.6)
            // Slight smirk
            drawArc(context: context, fromX: 92, baseY: 68, toX: 108,
                    midY: 75, color: detail, w: 2.4)
        }
    }

    /// Smile (concave-down) using a quadratic curve.
    private func drawSmile(context: GraphicsContext,
                            fromX: CGFloat, midX: CGFloat, toX: CGFloat,
                            midY: CGFloat, baseY: CGFloat) {
        var path = Path()
        path.move(to: CGPoint(x: fromX, y: baseY))
        path.addQuadCurve(to: CGPoint(x: toX, y: baseY),
                           control: CGPoint(x: midX, y: midY))
        context.stroke(path, with: .color(detail),
                       style: StrokeStyle(lineWidth: 2.4, lineCap: .round))
    }

    /// Generic SVG-quad arc drawn as a stroked Path.
    /// Used for many of the face mouth/eye shapes.
    private func drawArc(context: GraphicsContext,
                          fromX: CGFloat, baseY: CGFloat,
                          toX: CGFloat, midY: CGFloat,
                          color: Color, w: CGFloat,
                          controlOffset: CGFloat = 0,
                          controlEndY: CGFloat? = nil) {
        var path = Path()
        path.move(to: CGPoint(x: fromX, y: baseY))
        let controlX = (fromX + toX) / 2 + controlOffset
        let controlY = controlEndY ?? midY
        path.addQuadCurve(to: CGPoint(x: toX, y: controlEndY ?? baseY),
                           control: CGPoint(x: controlX, y: controlY))
        context.stroke(path, with: .color(color),
                       style: StrokeStyle(lineWidth: w, lineCap: .round))
    }

    private func drawStrokeLine(context: GraphicsContext,
                                 from x1: CGFloat, _ y1: CGFloat,
                                 to x2: CGFloat, _ y2: CGFloat,
                                 color: Color, w: CGFloat) {
        var path = Path()
        path.move(to: CGPoint(x: x1, y: y1))
        path.addLine(to: CGPoint(x: x2, y: y2))
        context.stroke(path, with: .color(color),
                       style: StrokeStyle(lineWidth: w, lineCap: .round))
    }

    /// Heart shape used for love-state eyes. Cubic curves matching
    /// the design's `heart()` function.
    private func drawHeart(context: GraphicsContext, x cx: CGFloat, y cy: CGFloat) {
        var p = Path()
        p.move(to: CGPoint(x: cx, y: cy + 4))
        p.addCurve(to: CGPoint(x: cx - 3, y: cy - 6),
                    control1: CGPoint(x: cx - 7, y: cy - 1),
                    control2: CGPoint(x: cx - 7, y: cy - 8))
        p.addCurve(to: CGPoint(x: cx, y: cy - 2),
                    control1: CGPoint(x: cx - 1, y: cy - 5),
                    control2: CGPoint(x: cx, y: cy - 3))
        p.addCurve(to: CGPoint(x: cx + 3, y: cy - 6),
                    control1: CGPoint(x: cx, y: cy - 3),
                    control2: CGPoint(x: cx + 1, y: cy - 5))
        p.addCurve(to: CGPoint(x: cx, y: cy + 4),
                    control1: CGPoint(x: cx + 7, y: cy - 8),
                    control2: CGPoint(x: cx + 7, y: cy - 1))
        p.closeSubpath()
        context.fill(p, with: .color(Color(red: 1.00, green: 0.24, blue: 0.67)))
    }

    /// "ZZ" glyphs floating to the upper-right when sleeping.
    private func drawSleepZs(context: GraphicsContext) {
        var p = Path()
        p.move(to: CGPoint(x: 142, y: 22))
        p.addLine(to: CGPoint(x: 152, y: 22))
        p.addLine(to: CGPoint(x: 142, y: 32))
        p.addLine(to: CGPoint(x: 152, y: 32))
        context.stroke(p, with: .color(detail.opacity(0.85)),
                       style: StrokeStyle(lineWidth: 2,
                                            lineCap: .round,
                                            lineJoin: .round))
        var p2 = Path()
        p2.move(to: CGPoint(x: 154, y: 6))
        p2.addLine(to: CGPoint(x: 162, y: 6))
        p2.addLine(to: CGPoint(x: 154, y: 14))
        p2.addLine(to: CGPoint(x: 162, y: 14))
        context.stroke(p2, with: .color(detail.opacity(0.85)),
                       style: StrokeStyle(lineWidth: 2.2,
                                            lineCap: .round,
                                            lineJoin: .round))
    }
}

/// Map our existing PetMood enum to Notchy's richer state set.
extension NotchyState {
    /// Translate a PetMood to the closest Notchy state.
    static func from(petMood mood: PetMood) -> NotchyState {
        switch mood {
        case .asleep:   return .sleep
        case .hungry:   return .thinking
        case .sad:      return .sad
        case .neutral:  return .idle
        case .happy:    return .wink
        case .excited:  return .celebrate
        }
    }
}
