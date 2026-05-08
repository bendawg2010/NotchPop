// SystemStatsView.swift
//
// Pane shown inside the expanded notch when the System Stats tab is
// active. Two side-by-side gauge readouts — CPU on the left, RAM on
// the right — each a horizontal pill bar gradient-filled to its current
// percent, with a numeric readout below and a label above. Bars turn red
// when the resource is under pressure (CPU > 85% or RAM > 90%).

import SwiftUI

struct SystemStatsView: View {
    @ObservedObject var service: SystemStatsService

    // Brand gradient (pink → purple → blue) — also used by Pomodoro/transport.
    private let brandColors: [Color] = [
        Color(red: 1.00, green: 0.24, blue: 0.67),  // #FF3CAC
        Color(red: 0.47, green: 0.29, blue: 0.63),  // #784BA0
        Color(red: 0.17, green: 0.52, blue: 0.77),  // #2B86C5
    ]
    private let dangerColor = Color(red: 1.00, green: 0.42, blue: 0.42) // #FF6B6B

    var body: some View {
        HStack(spacing: 14) {
            gauge(
                label: "CPU",
                percent: service.cpuPercent,
                readout: String(format: "%.0f%%", service.cpuPercent),
                danger: service.cpuPercent > 85
            )
            gauge(
                label: "RAM",
                percent: service.memoryPercent,
                readout: String(format: "%.1f / %.0f GB", service.memoryUsedGB, service.memoryTotalGB),
                danger: service.memoryPercent > 90
            )
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
    }

    /// One CPU/RAM column: small uppercase label, a pill gauge, then the
    /// numeric readout. The gauge fill uses the brand gradient unless the
    /// resource is in the danger zone, in which case it flips to red.
    private func gauge(label: String, percent: Double, readout: String, danger: Bool) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(label)
                .font(.system(size: 9, weight: .heavy))
                .tracking(1.0)
                .foregroundColor(.white.opacity(0.55))

            pillBar(percent: percent, danger: danger)
                .frame(height: 8)

            Text(readout)
                .font(.system(size: 14, weight: .heavy, design: .rounded))
                .foregroundColor(danger ? dangerColor : .white)
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// Horizontal pill that fills 0–100% of its width.
    private func pillBar(percent: Double, danger: Bool) -> some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.white.opacity(0.08))

                Capsule()
                    .fill(
                        danger
                        ? AnyShapeStyle(LinearGradient(
                            colors: [dangerColor.opacity(0.85), dangerColor],
                            startPoint: .leading, endPoint: .trailing))
                        : AnyShapeStyle(LinearGradient(
                            colors: brandColors,
                            startPoint: .leading, endPoint: .trailing))
                    )
                    .frame(width: fillWidth(percent: percent, total: geo.size.width))
                    .animation(.easeOut(duration: 0.5), value: percent)
                    .animation(.easeOut(duration: 0.5), value: danger)
            }
        }
    }

    private func fillWidth(percent: Double, total: CGFloat) -> CGFloat {
        let p = max(0, min(100, percent)) / 100.0
        return total * CGFloat(p)
    }
}
