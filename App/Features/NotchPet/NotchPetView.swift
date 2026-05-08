// NotchPetView.swift
//
// Pane shown inside the expanded notch when the Notch Pet tab is
// active. Three columns:
//   • LEFT  — animated sprite (NotchPetSprite). Mood-driven.
//   • MIDDLE — three stat bars (happiness/energy/hunger), age,
//              name, current stage label, XP-to-next-stage progress.
//   • RIGHT — care buttons (Feed / Play / Nap).
//
// The sprite is rendered ENTIRELY in SwiftUI shapes — no external
// art assets — so it's tiny on disk and infinitely re-skinnable
// later if the user replaces the design.

import SwiftUI

struct NotchPetView: View {
    @ObservedObject var service: NotchPetService

    var body: some View {
        HStack(spacing: 12) {
            // LEFT — sprite
            NotchPetSprite(
                stage: service.state.stage,
                mood: service.state.mood
            )
            .frame(width: 70, height: 70)

            // MIDDLE — info + stats
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 5) {
                    Text(service.state.name)
                        .font(.system(size: 13, weight: .heavy))
                        .foregroundColor(.white)
                    Text(service.state.stage.label)
                        .font(.system(size: 9, weight: .heavy))
                        .tracking(0.8)
                        .foregroundColor(.white.opacity(0.55))
                        .padding(.horizontal, 5)
                        .padding(.vertical, 1)
                        .background(
                            Capsule().fill(Color.white.opacity(0.10))
                        )
                    Spacer(minLength: 0)
                }
                Text("\(service.state.ageDays)d old · \(moodLabel) · \(xpToNextLabel)")
                    .font(.system(size: 9, weight: .medium))
                    .foregroundColor(.white.opacity(0.55))
                    .lineLimit(1)
                statBar(label: "♥",
                        value: service.state.happiness,
                        color: Color(red: 0.95, green: 0.30, blue: 0.55))
                statBar(label: "⚡",
                        value: service.state.energy,
                        color: Color(red: 1.00, green: 0.71, blue: 0.33))
                statBar(label: "🍎",
                        value: service.state.hunger,
                        color: Color(red: 0.32, green: 0.84, blue: 0.55))
            }

            // RIGHT — care actions
            VStack(spacing: 4) {
                careButton(label: "Feed", icon: "🍎",
                           gradient: [Color(red: 0.32, green: 0.84, blue: 0.55),
                                      Color(red: 0.18, green: 0.62, blue: 0.85)]) {
                    service.feed()
                }
                careButton(label: "Play", icon: "🎾",
                           gradient: [Color(red: 1.00, green: 0.42, blue: 0.42),
                                      Color(red: 0.95, green: 0.30, blue: 0.85)]) {
                    service.play()
                }
                careButton(label: "Nap",  icon: "💤",
                           gradient: [Color(red: 0.62, green: 0.30, blue: 0.96),
                                      Color(red: 0.30, green: 0.50, blue: 0.95)]) {
                    service.nap()
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .frame(maxWidth: .infinity)
        .frame(height: 88)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.white.opacity(0.04))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(Color.white.opacity(0.08), lineWidth: 1)
                )
        )
    }

    private var moodLabel: String {
        switch service.state.mood {
        case .asleep:   return "sleeping 💤"
        case .hungry:   return "hungry 🍽"
        case .sad:      return "sad 😔"
        case .neutral:  return "chillin"
        case .happy:    return "happy 🥰"
        case .excited:  return "excited! ✨"
        }
    }

    private var xpToNextLabel: String {
        let stages = PetStage.allCases
        guard let idx = stages.firstIndex(of: service.state.stage),
              idx + 1 < stages.count else {
            return "Sage 🏆"
        }
        let next = stages[idx + 1]
        let needed = next.xpThreshold - service.state.xp
        return "\(needed) XP → \(next.label)"
    }

    private func statBar(label: String, value: Double, color: Color) -> some View {
        HStack(spacing: 4) {
            Text(label).font(.system(size: 9))
                .frame(width: 12, alignment: .leading)
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.white.opacity(0.08))
                    Capsule()
                        .fill(LinearGradient(colors: [color.opacity(0.85), color],
                                              startPoint: .leading, endPoint: .trailing))
                        .frame(width: geo.size.width * CGFloat(max(0, min(100, value)) / 100))
                        .animation(.easeOut(duration: 0.5), value: value)
                }
            }
            .frame(height: 5)
            Text("\(Int(value))")
                .font(.system(size: 8, weight: .heavy, design: .monospaced))
                .foregroundColor(.white.opacity(0.55))
                .frame(width: 18, alignment: .trailing)
        }
    }

    private func careButton(label: String, icon: String,
                             gradient: [Color],
                             action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 3) {
                Text(icon).font(.system(size: 9))
                Text(label).font(.system(size: 9, weight: .heavy))
                    .foregroundColor(.white)
            }
            .frame(width: 56, height: 19)
            .background(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(LinearGradient(colors: gradient,
                                         startPoint: .leading, endPoint: .trailing))
            )
        }
        .buttonStyle(.plain)
        .help("\(label) your pet")
    }
}

// MARK: - Sprite

/// Pure-SwiftUI pet sprite — a gradient blob body with two eyes and
/// a mouth that morphs based on the pet's mood. Slight idle bob +
/// breathing, more lively bounce in `excited` / `happy` states. The
/// EGG stage shows a static egg shape with crack accents that grows
/// as XP accumulates; hatching at xp ≥ 5 swaps it out for the blob.
struct NotchPetSprite: View {
    let stage: PetStage
    let mood: PetMood

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30)) { ctx in
            // Wrap the body content in our own View to isolate
            // SwiftUI's type inference — TimelineView's content
            // generic kept failing on the conditional inside the
            // ZStack. Splitting it out into a typed sub-view (with
            // an explicit some View body) sidesteps that.
            spriteContent(time: ctx.date.timeIntervalSinceReferenceDate)
        }
    }

    @ViewBuilder
    private func spriteContent(time t: TimeInterval) -> some View {
        // ViewBuilder can't tolerate `switch` as a non-View statement,
        // so the bob calculation lives in its own function.
        if stage == .egg {
            eggShape(time: t)
        } else {
            blobShape(time: t)
                .offset(y: bobOffset(time: t) * -0.5)
        }
    }

    /// Idle bob offset — pulled out of the @ViewBuilder body so the
    /// switch statement doesn't trip up SwiftUI's view-result chain.
    private func bobOffset(time t: TimeInterval) -> CGFloat {
        switch mood {
        case .asleep:   return 0.0
        case .excited:  return 6 * sin(t * 8)
        case .happy:    return 3 * sin(t * 4)
        default:        return 1.5 * sin(t * 1.5)
        }
    }

    @ViewBuilder
    private func eggShape(time t: TimeInterval) -> some View {
        ZStack {
            // Egg body — vertical ellipse, soft cream gradient.
            Ellipse()
                .fill(LinearGradient(
                    colors: stage.bodyColors,
                    startPoint: .top, endPoint: .bottom))
                .frame(width: stage.bodySize * 0.78,
                       height: stage.bodySize)
                .overlay(
                    Ellipse()
                        .stroke(Color.white.opacity(0.18), lineWidth: 0.75)
                )
            // Two faint cracks that wiggle slightly so the egg feels
            // alive even before hatching.
            Path { p in
                p.move(to: CGPoint(x: 12 + 1.5 * sin(t), y: 8))
                p.addLine(to: CGPoint(x: 18, y: 14))
                p.addLine(to: CGPoint(x: 14, y: 22))
                p.addLine(to: CGPoint(x: 20, y: 28))
            }
            .stroke(Color.white.opacity(0.35),
                    style: StrokeStyle(lineWidth: 0.8, lineCap: .round))
            .frame(width: stage.bodySize * 0.78,
                   height: stage.bodySize)
        }
    }

    @ViewBuilder
    private func blobShape(time t: TimeInterval) -> some View {
        let bodyW = stage.bodySize
        let bodyH = stage.bodySize * 0.92
        ZStack {
            // Soft glow halo behind, brighter when excited
            Ellipse()
                .fill(LinearGradient(colors: stage.bodyColors,
                                      startPoint: .topLeading,
                                      endPoint: .bottomTrailing))
                .frame(width: bodyW * 1.4, height: bodyH * 1.4)
                .blur(radius: 14)
                .opacity(mood == .excited ? 0.65 : 0.35)
            // Body
            Ellipse()
                .fill(LinearGradient(colors: stage.bodyColors,
                                      startPoint: .top, endPoint: .bottom))
                .frame(width: bodyW, height: bodyH)
                .overlay(
                    Ellipse()
                        .stroke(Color.white.opacity(0.30), lineWidth: 0.75)
                )
                .shadow(color: stage.bodyColors.first?.opacity(0.6) ?? .clear,
                        radius: 6)
            // Cheek highlights — small shiny dots top-left of eyes
            Circle()
                .fill(Color.white.opacity(0.55))
                .frame(width: bodyW * 0.10, height: bodyW * 0.10)
                .offset(x: -bodyW * 0.22, y: -bodyW * 0.20)
            // Face
            faceLayer(width: bodyW, height: bodyH, time: t)
            // Sage gets a tiny crown — the loyalty reward.
            if stage == .sage { crown(width: bodyW) }
            // Sleep Z's
            if mood == .asleep { sleepZs(time: t) }
            // Excited sparkles
            if mood == .excited { sparkles(time: t, width: bodyW, height: bodyH) }
        }
    }

    @ViewBuilder
    private func faceLayer(width: CGFloat, height: CGFloat, time t: TimeInterval) -> some View {
        let eyeY: CGFloat = -height * 0.08
        let eyeX: CGFloat = width * 0.16
        ZStack {
            // EYES — change shape per mood
            switch mood {
            case .asleep:
                eyeArc(closed: true, x: -eyeX, y: eyeY)
                eyeArc(closed: true, x: eyeX, y: eyeY)
            case .happy, .excited:
                // Squinty joy eyes
                eyeArc(closed: true, x: -eyeX, y: eyeY)
                eyeArc(closed: true, x: eyeX, y: eyeY)
            case .hungry:
                // Eyes wide open with small pupils — slight
                // anticipation wobble
                eyeOpen(x: -eyeX, y: eyeY, jitter: sin(t * 6) * 0.5)
                eyeOpen(x: eyeX, y: eyeY, jitter: sin(t * 6) * 0.5)
            case .sad:
                // Half-droopy eyes
                eyeDroop(x: -eyeX, y: eyeY)
                eyeDroop(x: eyeX, y: eyeY)
            case .neutral:
                eyeOpen(x: -eyeX, y: eyeY, jitter: 0)
                eyeOpen(x: eyeX, y: eyeY, jitter: 0)
            }
            // MOUTH
            mouth(width: width, height: height, time: t)
        }
        .frame(width: width, height: height)
    }

    private func eyeOpen(x: CGFloat, y: CGFloat, jitter: CGFloat) -> some View {
        Circle()
            .fill(Color.black.opacity(0.85))
            .frame(width: 5, height: 5)
            .offset(x: x + jitter, y: y)
    }
    private func eyeArc(closed: Bool, x: CGFloat, y: CGFloat) -> some View {
        // ⌒ shape — closed/squinted eye
        Path { p in
            p.move(to: CGPoint(x: x - 3, y: y + 1))
            p.addQuadCurve(to: CGPoint(x: x + 3, y: y + 1),
                           control: CGPoint(x: x, y: y - 2))
        }
        .stroke(Color.black.opacity(0.85),
                style: StrokeStyle(lineWidth: 1.2, lineCap: .round))
        .frame(width: 12, height: 8)
    }
    private func eyeDroop(x: CGFloat, y: CGFloat) -> some View {
        // Half-circle droop
        Path { p in
            p.move(to: CGPoint(x: x - 3, y: y))
            p.addQuadCurve(to: CGPoint(x: x + 3, y: y),
                           control: CGPoint(x: x, y: y + 2))
        }
        .stroke(Color.black.opacity(0.7),
                style: StrokeStyle(lineWidth: 1.0, lineCap: .round))
        .frame(width: 12, height: 8)
    }

    @ViewBuilder
    private func mouth(width: CGFloat, height: CGFloat, time t: TimeInterval) -> some View {
        let y: CGFloat = height * 0.16
        switch mood {
        case .happy, .excited:
            // Big smile
            Path { p in
                p.move(to: CGPoint(x: -8, y: y))
                p.addQuadCurve(to: CGPoint(x: 8, y: y),
                               control: CGPoint(x: 0, y: y + 6))
            }
            .stroke(Color.black.opacity(0.8),
                    style: StrokeStyle(lineWidth: 1.4, lineCap: .round))
        case .sad:
            // Frown
            Path { p in
                p.move(to: CGPoint(x: -7, y: y + 2))
                p.addQuadCurve(to: CGPoint(x: 7, y: y + 2),
                               control: CGPoint(x: 0, y: y - 3))
            }
            .stroke(Color.black.opacity(0.8),
                    style: StrokeStyle(lineWidth: 1.2, lineCap: .round))
        case .hungry:
            // Open O — animates slightly
            Circle()
                .stroke(Color.black.opacity(0.8), lineWidth: 1.2)
                .frame(width: 6 + abs(sin(t * 3)) * 2,
                       height: 6 + abs(sin(t * 3)) * 2)
                .offset(y: y + 2)
        case .asleep:
            // Tiny line — closed mouth
            Path { p in
                p.move(to: CGPoint(x: -3, y: y + 2))
                p.addLine(to: CGPoint(x: 3, y: y + 2))
            }
            .stroke(Color.black.opacity(0.6),
                    style: StrokeStyle(lineWidth: 1, lineCap: .round))
        case .neutral:
            // Subtle smile
            Path { p in
                p.move(to: CGPoint(x: -5, y: y))
                p.addQuadCurve(to: CGPoint(x: 5, y: y),
                               control: CGPoint(x: 0, y: y + 2))
            }
            .stroke(Color.black.opacity(0.7),
                    style: StrokeStyle(lineWidth: 1, lineCap: .round))
        }
    }

    @ViewBuilder
    private func sleepZs(time t: TimeInterval) -> some View {
        let phase = (t.truncatingRemainder(dividingBy: 2.0)) / 2.0
        let yOffset = -CGFloat(20 + phase * 12)
        Text("Z")
            .font(.system(size: 10, weight: .heavy, design: .rounded))
            .foregroundColor(.white.opacity(0.7 - phase * 0.5))
            .offset(x: 18, y: yOffset)
    }

    @ViewBuilder
    private func sparkles(time t: TimeInterval, width: CGFloat, height: CGFloat) -> some View {
        ForEach(0..<6, id: \.self) { i in
            let phase = (t * 1.5 + Double(i) * 0.3)
                .truncatingRemainder(dividingBy: 1.0)
            let angle = Double(i) * .pi / 3
            let r = width * 0.8 * (0.5 + phase * 0.5)
            Image(systemName: "sparkle")
                .font(.system(size: 6 + CGFloat(phase) * 3))
                .foregroundColor(Color(red: 1.00, green: 0.85, blue: 0.40))
                .opacity(1 - phase)
                .offset(x: CGFloat(cos(angle) * r),
                        y: CGFloat(sin(angle) * r))
        }
    }

    @ViewBuilder
    private func crown(width: CGFloat) -> some View {
        Image(systemName: "crown.fill")
            .font(.system(size: width * 0.20, weight: .heavy))
            .foregroundStyle(LinearGradient(
                colors: [Color(red: 1.00, green: 0.85, blue: 0.40),
                         Color(red: 1.00, green: 0.55, blue: 0.20)],
                startPoint: .top, endPoint: .bottom))
            .offset(y: -width * 0.55)
    }
}
