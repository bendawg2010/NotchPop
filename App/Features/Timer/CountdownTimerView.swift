// CountdownTimerView.swift
//
// Compact countdown UI: nudge ±30s buttons frame the big time
// readout, with start/pause/reset transport beneath. When the timer
// is running, the readout flashes accent color in its last 5 seconds.

import SwiftUI

struct CountdownTimerView: View {
    @ObservedObject var service: CountdownTimerService

    var body: some View {
        HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 4) {
                    Text("⏱")
                    Text("Countdown")
                        .font(.system(size: 12, weight: .heavy))
                        .foregroundColor(.white)
                }

                HStack(spacing: 8) {
                    nudgeButton("-30", -30)
                    Text(service.formatted)
                        .font(.system(size: 22, weight: .heavy, design: .rounded))
                        .foregroundColor(timeColor)
                        .monospacedDigit()
                        .frame(minWidth: 80, alignment: .center)
                    nudgeButton("+30", 30)
                }
            }
            Spacer()
            VStack(spacing: 6) {
                button(
                    icon: service.running ? "pause.fill" : "play.fill",
                    label: service.running ? "Pause" : "Start",
                    primary: true
                ) { service.toggle() }
                button(icon: "arrow.counterclockwise", label: "Reset") {
                    service.reset()
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

    /// Flash accent during the final 5 seconds so the user knows it's
    /// almost done — keeps focus without needing audio.
    private var timeColor: Color {
        if service.running && service.remaining <= 5 && service.remaining > 0 {
            return Color(red: 1.00, green: 0.42, blue: 0.42)
        }
        return .white
    }

    private func nudgeButton(_ label: String, _ delta: TimeInterval) -> some View {
        Button { service.nudge(by: delta) } label: {
            Text(label)
                .font(.system(size: 10, weight: .heavy, design: .rounded))
                .foregroundColor(.white.opacity(0.78))
                .frame(width: 32, height: 22)
                .background(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(Color.white.opacity(0.08))
                )
        }
        .buttonStyle(.plain)
        .disabled(service.running)
        .opacity(service.running ? 0.4 : 1.0)
        .help("\(delta > 0 ? "+" : "")\(Int(delta))s")
    }

    private func button(icon: String, label: String,
                        primary: Bool = false,
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
        }
        .buttonStyle(.plain)
        .help(label)
    }
}
