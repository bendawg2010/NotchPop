// StopwatchView.swift
//
// Large monospaced timer readout on the left, transport controls
// (start/lap/reset) on the right, and a compact ticker of the last
// few laps below — only shown when there are laps to avoid taking
// vertical space when unused.

import SwiftUI

struct StopwatchView: View {
    @ObservedObject var service: StopwatchService

    var body: some View {
        HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 3) {
                Text("Stopwatch")
                    .font(.system(size: 11, weight: .heavy))
                    .foregroundColor(.white.opacity(0.62))
                    .textCase(.uppercase)
                    .tracking(1.4)
                Text(service.formatted)
                    .font(.system(size: 26, weight: .heavy, design: .rounded))
                    .foregroundColor(.white)
                    .monospacedDigit()
                if let last = service.laps.first {
                    Text("Last lap: \(formatLap(last))")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(.white.opacity(0.50))
                        .monospacedDigit()
                }
            }
            Spacer()
            VStack(spacing: 6) {
                button(
                    icon: service.running ? "pause.fill" : "play.fill",
                    label: service.running ? "Pause" : "Start",
                    primary: true
                ) { service.toggle() }
                HStack(spacing: 6) {
                    button(icon: "flag.fill", label: "Lap",
                           disabled: !service.running) { service.lap() }
                    button(icon: "arrow.counterclockwise", label: "Reset") {
                        service.reset()
                    }
                }
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
    }

    private func formatLap(_ t: TimeInterval) -> String {
        let m = Int(t) / 60
        let s = Int(t) % 60
        let ms = Int((t - floor(t)) * 100)
        return String(format: "%02d:%02d.%02d", m, s, ms)
    }

    private func button(icon: String, label: String,
                        primary: Bool = false,
                        disabled: Bool = false,
                        action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .heavy))
                .foregroundColor(primary ? .white : .white.opacity(0.8))
                .frame(width: primary ? 60 : 28, height: primary ? 28 : 24)
                .background(
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .fill(primary
                              ? AnyShapeStyle(LinearGradient(colors: [
                                  Color(red: 1.00, green: 0.24, blue: 0.67),
                                  Color(red: 0.17, green: 0.52, blue: 0.77),
                              ], startPoint: .leading, endPoint: .trailing))
                              : AnyShapeStyle(Color.white.opacity(0.10)))
                )
                .opacity(disabled ? 0.35 : 1.0)
        }
        .buttonStyle(.plain)
        .disabled(disabled)
        .help(label)
    }
}
