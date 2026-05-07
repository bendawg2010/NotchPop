// PomodoroView.swift
//
// Pane shown inside the expanded notch when the Pomodoro tab is
// active. Big progress ring with time remaining in the center, plus
// transport buttons (start/pause, skip, reset). Streak readout on
// the right.

import SwiftUI

struct PomodoroView: View {
    @ObservedObject var service: PomodoroService

    var body: some View {
        HStack(spacing: 14) {
            ringView
                .frame(width: 70, height: 70)

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(service.phase.emoji)
                        .font(.system(size: 14))
                    Text(service.phase.label)
                        .font(.system(size: 13, weight: .heavy))
                        .foregroundColor(.white)
                }
                Text("\(service.sessionsToday) session\(service.sessionsToday == 1 ? "" : "s") today · \(service.focusMinutes)/\(service.shortBreakMinutes)")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.white.opacity(0.62))
                HStack(spacing: 6) {
                    transportButton(
                        icon: service.running ? "pause.fill" : "play.fill",
                        label: service.running ? "Pause" : "Start",
                        primary: true
                    ) {
                        service.toggle()
                    }
                    transportButton(icon: "forward.end.fill", label: "Skip") {
                        service.skip()
                    }
                    transportButton(icon: "arrow.counterclockwise", label: "Reset") {
                        service.reset()
                    }
                }
                .padding(.top, 2)
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
    }

    private var ringView: some View {
        ZStack {
            Circle()
                .stroke(Color.white.opacity(0.08), lineWidth: 5)

            Circle()
                .trim(from: 0, to: service.progress)
                .stroke(
                    AngularGradient(
                        colors: [
                            Color(red: 1.00, green: 0.24, blue: 0.67),
                            Color(red: 0.47, green: 0.29, blue: 0.63),
                            Color(red: 0.17, green: 0.52, blue: 0.77),
                            Color(red: 1.00, green: 0.24, blue: 0.67),
                        ],
                        center: .center
                    ),
                    style: StrokeStyle(lineWidth: 5, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .animation(.linear(duration: 0.5), value: service.progress)

            Text(service.formattedTime)
                .font(.system(size: 15, weight: .heavy, design: .rounded))
                .foregroundColor(.white)
                .monospacedDigit()
        }
    }

    private func transportButton(icon: String, label: String,
                                 primary: Bool = false,
                                 action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .heavy))
                .foregroundColor(primary ? .white : .white.opacity(0.8))
                .frame(width: 28, height: 24)
                .background(
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .fill(primary
                              ? AnyShapeStyle(
                                  LinearGradient(colors: [
                                      Color(red: 1.00, green: 0.24, blue: 0.67),
                                      Color(red: 0.17, green: 0.52, blue: 0.77)
                                  ], startPoint: .leading, endPoint: .trailing))
                              : AnyShapeStyle(Color.white.opacity(0.10))
                        )
                )
        }
        .buttonStyle(.plain)
        .help(label)
    }
}
