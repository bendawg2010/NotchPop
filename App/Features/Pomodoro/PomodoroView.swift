// PomodoroView.swift
//
// Pane shown inside the expanded notch when the Pomodoro tab is
// active. Big progress ring with time remaining in the center, plus
// transport buttons (start/pause, skip, reset). Streak readout on
// the right.

import SwiftUI

struct PomodoroView: View {
    @ObservedObject var service: PomodoroService
    @State private var showDurationEditor = false

    var body: some View {
        HStack(spacing: 12) {
            ringView
                .frame(width: 64, height: 64)

            VStack(alignment: .leading, spacing: 3) {
                phasePicker
                HStack(spacing: 4) {
                    Button {
                        showDurationEditor = true
                    } label: {
                        Text(durationLabel)
                            .font(.system(size: 10, weight: .heavy, design: .rounded))
                            .foregroundColor(.white.opacity(0.85))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(
                                RoundedRectangle(cornerRadius: 5, style: .continuous)
                                    .fill(Color.white.opacity(0.10))
                            )
                    }
                    .buttonStyle(.plain)
                    .help("Click to edit duration")
                    .popover(isPresented: $showDurationEditor) {
                        durationEditor
                    }
                    Text("· \(service.sessionsToday)/\(service.dailyGoal) today")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(.white.opacity(0.62))
                }
                HStack(spacing: 5) {
                    transportButton(
                        icon: service.running ? "pause.fill" : "play.fill",
                        label: service.running ? "Pause" : "Start",
                        primary: true,
                        disabled: service.running && !service.canPause
                    ) { service.toggle() }
                    transportButton(icon: "forward.end.fill", label: "Skip") { service.skip() }
                    transportButton(icon: "arrow.counterclockwise", label: "Reset") { service.reset() }
                }
                .padding(.top, 2)
            }
            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
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

    /// Phase picker — three pills the user clicks to jump into Focus
    /// / Short break / Long break. Per user feedback: "you should be
    /// able to choose what your currently on not foced into work".
    private var phasePicker: some View {
        HStack(spacing: 4) {
            phaseButton(.focus,      "🍅", "Focus")
            phaseButton(.shortBreak, "☕", "Short")
            phaseButton(.longBreak,  "🌴", "Long")
            if service.strictMode && service.phase == .focus {
                Text("STRICT")
                    .font(.system(size: 8, weight: .heavy))
                    .foregroundColor(Color(red: 1.00, green: 0.42, blue: 0.42))
                    .padding(.horizontal, 4)
                    .padding(.vertical, 1)
                    .background(
                        RoundedRectangle(cornerRadius: 3)
                            .fill(Color(red: 1.00, green: 0.42, blue: 0.42).opacity(0.15))
                    )
            }
        }
    }

    private func phaseButton(_ p: PomodoroPhase, _ emoji: String, _ label: String) -> some View {
        let on = service.phase == p
        return Button {
            service.selectPhase(p)
        } label: {
            HStack(spacing: 3) {
                Text(emoji).font(.system(size: 9))
                Text(label).font(.system(size: 9, weight: .heavy))
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(
                RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .fill(on ? Color.white.opacity(0.18) : Color.clear)
            )
            .foregroundColor(on ? .white : .white.opacity(0.55))
        }
        .buttonStyle(.plain)
        .help("Switch to \(label)")
    }

    /// "25m" / "5m" / "15m" — current phase's duration in compact form.
    private var durationLabel: String {
        let mins: Int
        switch service.phase {
        case .focus, .idle: mins = service.focusMinutes
        case .shortBreak:   mins = service.shortBreakMinutes
        case .longBreak:    mins = service.longBreakMinutes
        }
        return "\(mins)m"
    }

    /// Quick-pick presets per phase. Tapping a chip sets the duration
    /// AND closes the popover so a single click starts you on a 50min
    /// focus session. Per user feedback "you should be able to edit
    /// the timers faster with more options."
    private var focusPresets:    [Int] { [15, 20, 25, 30, 45, 50, 60, 90] }
    private var shortPresets:    [Int] { [1, 3, 5, 7, 10, 15] }
    private var longPresets:     [Int] { [10, 15, 20, 25, 30, 45] }

    private var currentDuration: Int {
        switch service.phase {
        case .focus, .idle: return service.focusMinutes
        case .shortBreak:   return service.shortBreakMinutes
        case .longBreak:    return service.longBreakMinutes
        }
    }

    private var currentPresets: [Int] {
        switch service.phase {
        case .focus, .idle: return focusPresets
        case .shortBreak:   return shortPresets
        case .longBreak:    return longPresets
        }
    }

    private func setDuration(_ minutes: Int) {
        switch service.phase {
        case .focus, .idle: service.focusMinutes = minutes
        case .shortBreak:   service.shortBreakMinutes = minutes
        case .longBreak:    service.longBreakMinutes = minutes
        }
    }

    /// Inline duration editor — quick-pick chips on top, ±/+ stepper
    /// below for fine-grained control. Closes on chip tap.
    private var durationEditor: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Set \(service.phase.label.lowercased()) duration")
                    .font(.headline)
                Spacer()
            }

            // Quick-pick chips, 4 per row
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 4),
                      spacing: 6) {
                ForEach(currentPresets, id: \.self) { mins in
                    Button {
                        setDuration(mins)
                        showDurationEditor = false
                    } label: {
                        Text("\(mins)m")
                            .font(.system(size: 12, weight: .heavy, design: .rounded))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 7)
                            .background(
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .fill(currentDuration == mins
                                          ? AnyShapeStyle(LinearGradient(colors: [
                                              Color(red: 1.00, green: 0.24, blue: 0.67),
                                              Color(red: 0.17, green: 0.52, blue: 0.77),
                                          ], startPoint: .leading, endPoint: .trailing))
                                          : AnyShapeStyle(Color.secondary.opacity(0.12))
                                    )
                            )
                            .foregroundColor(currentDuration == mins ? .white : .primary)
                    }
                    .buttonStyle(.plain)
                }
            }

            Divider()

            // Fine-grained stepper for any duration the chips don't cover
            switch service.phase {
            case .focus, .idle:
                Stepper("Custom: \(service.focusMinutes) min",
                        value: Binding(get: { service.focusMinutes },
                                       set: { service.focusMinutes = $0 }),
                        in: 1...180)
            case .shortBreak:
                Stepper("Custom: \(service.shortBreakMinutes) min",
                        value: Binding(get: { service.shortBreakMinutes },
                                       set: { service.shortBreakMinutes = $0 }),
                        in: 1...30)
            case .longBreak:
                Stepper("Custom: \(service.longBreakMinutes) min",
                        value: Binding(get: { service.longBreakMinutes },
                                       set: { service.longBreakMinutes = $0 }),
                        in: 1...90)
            }

            Text("All four durations + the long-break cycle live in Settings → Pomodoro.")
                .font(.caption2).foregroundColor(.secondary)
        }
        .padding(16)
        .frame(width: 280)
    }

    private var ringView: some View {
        // Two-layer technique:
        //   1. A full-circle stroke filled with the AngularGradient,
        //      ROTATED slowly (so the colors orbit smoothly).
        //   2. A trim-stroked Circle as a MASK so only the progressed
        //      portion is visible.
        // This way the visible arc is always at the correct angle for
        // progress, but the colors WITHIN the arc keep flowing.
        TimelineView(.animation) { context in
            let t = context.date.timeIntervalSinceReferenceDate
            let rot = service.running
                ? (t.truncatingRemainder(dividingBy: 14) / 14) * 360
                : 0

            ZStack {
                Circle()
                    .stroke(Color.white.opacity(0.08), lineWidth: 5)

                // Decorative gradient ring (full circle, slowly spinning)
                Circle()
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
                    .rotationEffect(.degrees(rot))
                    // Mask = the visible-progress arc, in its correct
                    // (non-rotated) position relative to the timer
                    .mask(
                        Circle()
                            .trim(from: 0, to: service.progress)
                            .stroke(Color.white,
                                    style: StrokeStyle(lineWidth: 5, lineCap: .round))
                            .rotationEffect(.degrees(-90))
                    )
                    .animation(.linear(duration: 0.5), value: service.progress)

                Text(service.formattedTime)
                    .font(.system(size: 15, weight: .heavy, design: .rounded))
                    .foregroundColor(.white)
                    .monospacedDigit()
            }
        }
    }

    private func transportButton(icon: String, label: String,
                                 primary: Bool = false,
                                 disabled: Bool = false,
                                 action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .heavy))
                .foregroundColor(primary ? .white : .white.opacity(0.8))
                .frame(width: 28, height: 24)
                .background(
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .fill(primary
                              ? AnyShapeStyle(LinearGradient(colors: [
                                  Color(red: 1.00, green: 0.24, blue: 0.67),
                                  Color(red: 0.17, green: 0.52, blue: 0.77),
                              ], startPoint: .leading, endPoint: .trailing))
                              : AnyShapeStyle(Color.white.opacity(0.10))
                        )
                )
                .opacity(disabled ? 0.35 : 1.0)
        }
        .buttonStyle(.plain)
        .disabled(disabled)
        .help(disabled ? "\(label) — disabled by strict mode" : label)
    }
}
