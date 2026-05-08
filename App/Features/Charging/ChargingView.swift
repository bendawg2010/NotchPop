// ChargingView.swift
//
// Two views in this file:
//   • InlineBatteryIndicator — compact always-on battery + charge
//     percentage shown in the top-right of the expanded notch.
//     Replaces the old standalone Battery tab (per user feedback:
//     "battery doesnt need to be a tab it could just be top right").
//   • ChargingView — full pane only used during the auto-peek when
//     the user plugs in their MacBook. Not bound to any tab anymore.

import SwiftUI

// MARK: - Shared color palette

private enum BatteryPalette {
    static let charging  = Color(red: 0.32, green: 0.84, blue: 0.55)
    static let chargingDark = Color(red: 0.18, green: 0.58, blue: 0.38)
    static let low       = Color(red: 1.00, green: 0.42, blue: 0.42)
    static let lowDark   = Color(red: 0.78, green: 0.22, blue: 0.22)
    static let normal    = Color.white.opacity(0.85)
}

/// Compact battery indicator pinned to the top-right of the expanded
/// notch. Shows a small horizontal battery silhouette + percentage,
/// turns green/animated when charging, red when low.
struct InlineBatteryIndicator: View {
    @ObservedObject var monitor: ChargingMonitor
    @State private var pulse: Bool = false

    // Compact pill geometry — body 20×10, nub 1.5×4, gap 4, ~50pt total
    private let bodyW: CGFloat = 20
    private let bodyH: CGFloat = 10

    var body: some View {
        HStack(spacing: 4) {
            ZStack {
                RoundedRectangle(cornerRadius: 2.5, style: .continuous)
                    .stroke(borderColor, lineWidth: 1)
                    .frame(width: bodyW, height: bodyH)
                    .overlay(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 1.5, style: .continuous)
                            .fill(fillColor)
                            .frame(
                                width: max(2, (bodyW - 3) * CGFloat(monitor.batteryPercent) / 100),
                                height: bodyH - 4
                            )
                            .padding(.leading, 1.5)
                    }
                glyph
            }
            .overlay(alignment: .trailing) {
                Capsule()
                    .fill(borderColor)
                    .frame(width: 1.5, height: 4)
                    .offset(x: 2)
            }

            Text("\(monitor.batteryPercent)%")
                .font(.system(size: 10, weight: .heavy, design: .rounded))
                .foregroundColor(.white.opacity(0.85))
                .monospacedDigit()
        }
        .frame(width: 50, alignment: .leading)
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
        .background(
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .fill(Color.white.opacity(0.06))
        )
        .help(monitor.isCharging
              ? "Charging — \(monitor.batteryPercent)%"
              : "On battery — \(monitor.batteryPercent)%")
        .onAppear {
            withAnimation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true)) {
                pulse = true
            }
        }
    }

    @ViewBuilder
    private var glyph: some View {
        if monitor.isCharging && monitor.batteryPercent >= 100 {
            // Topped up — tiny green checkmark
            Image(systemName: "checkmark")
                .font(.system(size: 6, weight: .black))
                .foregroundColor(BatteryPalette.charging)
        } else if monitor.isCharging {
            Image(systemName: "bolt.fill")
                .font(.system(size: 6.5, weight: .heavy))
                .foregroundColor(.white)
                .scaleEffect(pulse ? 1.18 : 1.0)
        }
    }

    private var fillColor: Color {
        if monitor.isCharging { return BatteryPalette.charging }
        if monitor.batteryPercent < 20 { return BatteryPalette.low }
        return BatteryPalette.normal
    }
    private var borderColor: Color {
        Color.white.opacity(0.55)
    }
}

// MARK: - ChargingView (auto-peek)

/// A short-lived spark particle emitted when the battery percent ticks up.
private struct Spark: Identifiable, Equatable {
    let id = UUID()
    let angle: Double      // radians
    let distance: CGFloat  // travel distance
    let size: CGFloat
    let delay: Double
}

struct ChargingView: View {
    @ObservedObject var monitor: ChargingMonitor

    // Pulsing bolt
    @State private var pulse: Bool = false
    // Spark burst state
    @State private var sparks: [Spark] = []
    @State private var lastPercent: Int = -1

    // Bar geometry — referenced by both fill and spark origin
    private let barOuterW: CGFloat = 60
    private let barOuterH: CGFloat = 30
    private let barInsetW: CGFloat = 56
    private let barInsetH: CGFloat = 22

    var body: some View {
        HStack(spacing: 14) {
            batteryGlyph
                .frame(width: 70)

            VStack(alignment: .leading, spacing: 2) {
                percentageText
                Text(monitor.isCharging ? "Charging" : "On battery")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.white.opacity(0.62))
            }
            Spacer()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
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
        .onAppear {
            withAnimation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true)) {
                pulse = true
            }
            lastPercent = monitor.batteryPercent
        }
        .onChange(of: monitor.batteryPercent) { newValue in
            if newValue > lastPercent && lastPercent >= 0 {
                emitSparkBurst()
            }
            lastPercent = newValue
        }
    }

    // MARK: Subviews

    private var batteryGlyph: some View {
        ZStack {
            // Battery shell
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color.white.opacity(0.06))
                .frame(width: barOuterW, height: barOuterH)
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(Color.white.opacity(0.18), lineWidth: 1.5)
                )

            // Animated fill (with electric current when charging)
            barFillView
                .frame(width: barOuterW, height: barOuterH)

            // Bolt overlay
            if monitor.isCharging {
                Image(systemName: "bolt.fill")
                    .font(.system(size: 14, weight: .heavy))
                    .foregroundColor(.white)
                    .shadow(color: .black.opacity(0.5), radius: 1, y: 1)
                    .scaleEffect(pulse ? 1.2 : 1.0)
                    .opacity(pulse ? 1.0 : 0.85)
            }

            // Spark particles burst from the right edge of the fill
            sparkLayer
        }
    }

    private var percentageText: some View {
        Text("\(monitor.batteryPercent)%")
            .font(.system(size: 28, weight: .heavy, design: .rounded))
            .monospacedDigit()
            .foregroundStyle(percentageGradient)
            .shadow(color: percentageGlow, radius: 6, y: 0)
            .contentTransition(.numericText(value: Double(monitor.batteryPercent)))
            .animation(.spring(response: 0.35, dampingFraction: 0.7),
                       value: monitor.batteryPercent)
    }

    /// Gradient-filled percent text: charging→green, low→red, otherwise white.
    private var percentageGradient: LinearGradient {
        if monitor.isCharging {
            return LinearGradient(
                colors: [Color.white, BatteryPalette.charging],
                startPoint: .top, endPoint: .bottom)
        }
        if monitor.batteryPercent < 20 {
            return LinearGradient(
                colors: [Color.white, BatteryPalette.low],
                startPoint: .top, endPoint: .bottom)
        }
        return LinearGradient(
            colors: [Color.white, Color.white.opacity(0.78)],
            startPoint: .top, endPoint: .bottom)
    }

    private var percentageGlow: Color {
        if monitor.isCharging { return BatteryPalette.charging.opacity(0.35) }
        if monitor.batteryPercent < 20 { return BatteryPalette.low.opacity(0.35) }
        return .clear
    }

    /// Bar fill — when charging, a TimelineView pans a diagonal stripe gradient
    /// across the green base to evoke flowing electric current.
    @ViewBuilder
    private var barFillView: some View {
        // The actual fill rectangle, sized to percent
        let fillWidth = max(4, barInsetW * CGFloat(monitor.batteryPercent) / 100)

        ZStack(alignment: .leading) {
            if monitor.isCharging {
                TimelineView(.animation) { context in
                    let t = context.date.timeIntervalSinceReferenceDate
                    // Period ~1.6s — gentle, not flashy
                    let phase = (t.truncatingRemainder(dividingBy: 1.6)) / 1.6

                    RoundedRectangle(cornerRadius: 5, style: .continuous)
                        .fill(barBaseFill)
                        .overlay(
                            RoundedRectangle(cornerRadius: 5, style: .continuous)
                                .fill(currentStripe(phase: phase))
                                .blendMode(.plusLighter)
                                .opacity(0.55)
                        )
                        .frame(width: fillWidth, height: barInsetH)
                        .padding(2)
                }
            } else {
                RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .fill(barBaseFill)
                    .frame(width: fillWidth, height: barInsetH)
                    .padding(2)
            }
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.75),
                   value: monitor.batteryPercent)
    }

    /// Static base color/gradient for the fill (under any current animation).
    private var barBaseFill: LinearGradient {
        if monitor.isCharging {
            return LinearGradient(
                colors: [BatteryPalette.charging, BatteryPalette.chargingDark],
                startPoint: .top, endPoint: .bottom)
        }
        if monitor.batteryPercent < 20 {
            return LinearGradient(
                colors: [BatteryPalette.low, BatteryPalette.lowDark],
                startPoint: .top, endPoint: .bottom)
        }
        return LinearGradient(
            colors: [Color.white.opacity(0.85), Color.white.opacity(0.55)],
            startPoint: .top, endPoint: .bottom)
    }

    /// The flowing diagonal stripe — start/end points orbit so it pans
    /// continuously left-to-right across the bar.
    private func currentStripe(phase: Double) -> LinearGradient {
        // Pan across an extended range so the stripe enters from the left
        // and exits to the right, while keeping the diagonal angle.
        let x = phase * 2.0 - 0.5     // -0.5 .. 1.5
        let stops: [Gradient.Stop] = [
            .init(color: .white.opacity(0.0), location: 0.0),
            .init(color: .white.opacity(0.0), location: 0.35),
            .init(color: .white.opacity(0.85), location: 0.5),
            .init(color: .white.opacity(0.0), location: 0.65),
            .init(color: .white.opacity(0.0), location: 1.0),
        ]
        return LinearGradient(
            gradient: Gradient(stops: stops),
            startPoint: UnitPoint(x: x - 0.2, y: 0.0),
            endPoint:   UnitPoint(x: x + 0.2, y: 1.0)
        )
    }

    // MARK: - Spark particles

    private var sparkLayer: some View {
        // Anchor the particle origin near the leading edge of the battery
        // (where the fill ends, roughly).
        let originX: CGFloat = -barOuterW / 2 + max(4, barInsetW * CGFloat(monitor.batteryPercent) / 100) - 2
        return ZStack {
            ForEach(sparks) { spark in
                SparkDot(spark: spark)
            }
        }
        .offset(x: originX, y: 0)
        .allowsHitTesting(false)
    }

    private func emitSparkBurst() {
        let count = Int.random(in: 4...6)
        let burst: [Spark] = (0..<count).map { i in
            // Fan outward slightly upward-biased
            let baseAngle = -Double.pi / 2  // up
            let spread = Double.pi * 0.9    // ~160°
            let frac = Double(i) / Double(max(1, count - 1)) - 0.5
            let angle = baseAngle + frac * spread + Double.random(in: -0.2...0.2)
            return Spark(
                angle: angle,
                distance: CGFloat.random(in: 14...26),
                size: CGFloat.random(in: 2.5...4.0),
                delay: Double.random(in: 0...0.08)
            )
        }
        // Append, then drop after the burst animation completes
        sparks.append(contentsOf: burst)
        let toRemove = burst.map(\.id)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.75) {
            sparks.removeAll { toRemove.contains($0.id) }
        }
    }
}

/// Single spark particle that flies outward and fades over ~600ms.
private struct SparkDot: View {
    let spark: Spark
    @State private var traveled: Bool = false

    var body: some View {
        Circle()
            .fill(BatteryPalette.charging)
            .frame(width: spark.size, height: spark.size)
            .shadow(color: BatteryPalette.charging.opacity(0.9), radius: 2)
            .offset(
                x: traveled ? cos(spark.angle) * spark.distance : 0,
                y: traveled ? sin(spark.angle) * spark.distance : 0
            )
            .opacity(traveled ? 0.0 : 1.0)
            .scaleEffect(traveled ? 0.4 : 1.0)
            .onAppear {
                withAnimation(.easeOut(duration: 0.6).delay(spark.delay)) {
                    traveled = true
                }
            }
    }
}
