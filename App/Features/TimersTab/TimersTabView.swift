// TimersTabView.swift
//
// Combined Stopwatch + Countdown pane, picked from a small toggle at
// the top of the pane. Per user feedback: "things don't HAVE to be in
// their own tab — some could be combined." Both are timing widgets;
// putting them under one tab cuts the tab bar from 8 → 6 widgets and
// keeps related functionality together.
//
// State is preserved when switching between modes — neither widget
// pauses when the user flips the toggle.

import SwiftUI

enum TimersMode: String, CaseIterable, Identifiable {
    case stopwatch = "Stopwatch"
    case countdown = "Countdown"
    var id: String { rawValue }
    var icon: String {
        switch self {
        case .stopwatch: return "stopwatch.fill"
        case .countdown: return "alarm.fill"
        }
    }
}

struct TimersTabView: View {
    @ObservedObject var stopwatch: StopwatchService
    @ObservedObject var countdown: CountdownTimerService
    @State private var mode: TimersMode = .stopwatch

    var body: some View {
        VStack(spacing: 6) {
            modePicker
            paneFor(mode)
        }
    }

    private var modePicker: some View {
        HStack(spacing: 4) {
            ForEach(TimersMode.allCases) { m in
                let on = mode == m
                let running = (m == .stopwatch && stopwatch.running)
                              || (m == .countdown && countdown.running)
                Button {
                    withAnimation(.spring(response: 0.32, dampingFraction: 0.85)) { mode = m }
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: m.icon)
                            .font(.system(size: 10, weight: .heavy))
                        Text(m.rawValue)
                            .font(.system(size: 10, weight: .heavy))
                        if running {
                            Circle()
                                .fill(Color(red: 0.32, green: 0.84, blue: 0.55))
                                .frame(width: 5, height: 5)
                        }
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(on ? Color.white.opacity(0.10) : Color.clear)
                    )
                    .foregroundColor(on ? .white : .white.opacity(0.55))
                }
                .buttonStyle(.plain)
            }
            Spacer()
        }
        .padding(.horizontal, 2)
    }

    @ViewBuilder
    private func paneFor(_ mode: TimersMode) -> some View {
        switch mode {
        case .stopwatch: StopwatchView(service: stopwatch)
        case .countdown: CountdownTimerView(service: countdown)
        }
    }
}
