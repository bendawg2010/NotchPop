// AirPodsView.swift
//
// Renders the AirPods battery pane inside the expanded notch. Pulls
// state from `AirPodsService`, which polls system_profiler — see that
// file for why we shell out instead of touching IOBluetooth (private
// API surface + permission gates make IOBluetooth far pricier than
// just parsing the public profile output every 60s).

import SwiftUI

struct AirPodsView: View {
    @ObservedObject var service: AirPodsService

    /// Drives the gentle pulse on the empty-state icon. Same easing
    /// pattern as `InlineBatteryIndicator`'s pulse.
    @State private var pulse: Bool = false

    var body: some View {
        Group {
            if service.state.connected {
                connectedContent
            } else {
                emptyState
            }
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
            withAnimation(.easeInOut(duration: 1.2)
                .repeatForever(autoreverses: true)) {
                pulse = true
            }
        }
    }

    // MARK: - Empty state

    private var emptyState: some View {
        HStack(spacing: 10) {
            Spacer(minLength: 0)
            Image(systemName: "airpods.gen2")
                .font(.system(size: 22, weight: .regular))
                .foregroundColor(.white.opacity(0.55))
                .scaleEffect(pulse ? 1.06 : 1.0)
                .opacity(pulse ? 1.0 : 0.75)
            Text("No AirPods nearby")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.white.opacity(0.55))
                .lineLimit(1)
            Spacer(minLength: 0)
        }
    }

    // MARK: - Connected state

    private var connectedContent: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(service.state.model)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.white)
                    .lineLimit(1)
                    .truncationMode(.tail)
                Text(subtitle)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.white.opacity(0.55))
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            // Mini battery readouts. Only render the pills that we
            // actually have a reading for — single-piece devices
            // (AirPods Max, generic over-ears) only have a "main"
            // battery, which the service surfaces as `leftPercent`,
            // so the L pill is the lone reading in that case.
            HStack(spacing: 6) {
                if let left = service.state.leftPercent {
                    BatteryPill(label: pillLabel(for: .left),
                                percent: left)
                }
                if let right = service.state.rightPercent {
                    BatteryPill(label: "R", percent: right)
                }
                if let caseLvl = service.state.casePercent {
                    BatteryPill(label: "Case", percent: caseLvl)
                }
            }
        }
    }

    /// Sub-label under the model name. If the user has a stereo pair
    /// we say "Connected"; otherwise we mention it's a single-side
    /// (over-ear) reading so they don't think a pod is missing.
    private var subtitle: String {
        let s = service.state
        let isSinglePiece = s.rightPercent == nil && s.casePercent == nil
        return isSinglePiece ? "Connected" : "Connected"
    }

    /// Single-piece devices (AirPods Max, etc.) report `main` only,
    /// which the service maps onto `leftPercent`. In that case label
    /// the pill more honestly than "L".
    private enum PillSide { case left }
    private func pillLabel(for side: PillSide) -> String {
        let isSinglePiece = service.state.rightPercent == nil
            && service.state.casePercent == nil
        switch side {
        case .left:
            return isSinglePiece ? "Bat" : "L"
        }
    }
}

// MARK: - Battery pill
//
// Visual style mirrors `InlineBatteryIndicator` from ChargingView.swift:
// a thin-stroke rounded silhouette + colored fill. We add a small text
// label inside the pill ("L 89%") because users want to tell L from R
// at a glance without hovering for a tooltip.
private struct BatteryPill: View {
    let label: String
    let percent: Int

    var body: some View {
        HStack(spacing: 4) {
            // Battery silhouette
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 3, style: .continuous)
                    .stroke(Color.white.opacity(0.55), lineWidth: 1.2)
                    .frame(width: 22, height: 11)
                RoundedRectangle(cornerRadius: 1.5, style: .continuous)
                    .fill(fillColor)
                    .frame(width: max(2, 19 * CGFloat(clamped) / 100),
                           height: 7)
                    .padding(.leading, 1.5)
            }
            .overlay(alignment: .trailing) {
                // Battery nub
                Capsule()
                    .fill(Color.white.opacity(0.55))
                    .frame(width: 1.5, height: 5)
                    .offset(x: 2)
            }

            Text("\(label) \(clamped)%")
                .font(.system(size: 10, weight: .heavy, design: .rounded))
                .foregroundColor(.white.opacity(0.85))
                .monospacedDigit()
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
        .background(
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .fill(Color.white.opacity(0.06))
        )
        .help("\(label): \(clamped)%")
    }

    /// Clamp to 0…100 so the bar can't overflow on garbage data.
    private var clamped: Int { max(0, min(100, percent)) }

    /// Color-coded thresholds:
    ///   • green when ≥ 50%
    ///   • amber 20…49%
    ///   • red < 20%
    private var fillColor: Color {
        if clamped < 20 {
            return Color(red: 1.00, green: 0.42, blue: 0.42)   // red
        }
        if clamped < 50 {
            return Color(red: 1.00, green: 0.71, blue: 0.33)   // amber
        }
        return Color(red: 0.32, green: 0.84, blue: 0.55)       // green
    }
}
