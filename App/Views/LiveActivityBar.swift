// LiveActivityBar.swift
//
// NotchNook-style integrated live activity. The notch shape itself
// grows wider when something's active, and content sits INSIDE the
// shape — icon on the left, signal on the right (animated audio
// bars for music, countdown text for timer). Single continuous
// black pill, not two separate flanking pills.
//
//   ┌────────── one wide notch shape ──────────┐
//   │ [icon]   [hardware notch area]   [right] │
//   └──────────────────────────────────────────┘
//
// Priority: a running timer (Pomodoro or Countdown) outranks music.
// Per user feedback we only show ONE activity at a time, not both —
// avoids cramming the pill and matches NotchNook's design.

import SwiftUI

struct LiveActivityBar: View {
    @ObservedObject var viewModel: NotchViewModel

    var body: some View {
        HStack(spacing: 0) {
            // LEFT: small icon (album art or phase emoji)
            leftIcon
                .frame(width: viewModel.activityLeftIconSize,
                       height: viewModel.activityLeftIconSize)
                .padding(.leading, 8)

            // CENTER: invisible spacer matching the hardware notch.
            // The drawn pill extends behind the notch but the notch
            // itself is a hardware cutout — we don't render content
            // there.
            Spacer(minLength: viewModel.compactSize.width - 16)

            // RIGHT: audio bars (music) OR countdown (timer)
            rightContent
                .padding(.trailing, 10)
        }
        .frame(width: viewModel.targetSize.width,
               height: viewModel.targetSize.height)
        .contentShape(Rectangle())
        .onTapGesture { tapped() }
    }

    // MARK: - Left icon
    @ViewBuilder
    private var leftIcon: some View {
        if viewModel.hasActiveTimer {
            timerIcon
        } else if viewModel.hasActiveMusic {
            musicIcon
        }
    }

    private var timerIcon: some View {
        let (sym, tint) = timerIconStyle
        return ZStack {
            // Phase-coded glow halo behind the icon for the
            // pomodoro-style accent
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(tint.opacity(0.18))
            Image(systemName: sym)
                .font(.system(size: 13, weight: .heavy))
                .foregroundStyle(tint)
        }
    }

    private var timerIconStyle: (String, Color) {
        if viewModel.pomodoro.running {
            switch viewModel.pomodoro.phase {
            case .focus, .idle:
                return ("brain.head.profile", Color(red: 0.32, green: 0.84, blue: 0.55))
            case .shortBreak:
                return ("cup.and.saucer.fill", Color(red: 0.32, green: 0.84, blue: 0.55))
            case .longBreak:
                return ("leaf.fill", Color(red: 0.17, green: 0.62, blue: 0.85))
            }
        }
        return ("alarm.fill", Color(red: 1.00, green: 0.71, blue: 0.33))
    }

    private var musicIcon: some View {
        Group {
            if let art = viewModel.nowPlaying.track.artwork {
                Image(nsImage: art)
                    .resizable()
                    .scaledToFill()
            } else {
                LinearGradient(
                    colors: [Color(red: 1.00, green: 0.42, blue: 0.42),
                             Color(red: 0.47, green: 0.29, blue: 0.63)],
                    startPoint: .topLeading, endPoint: .bottomTrailing)
                .overlay(
                    Image(systemName: "music.note")
                        .font(.system(size: 11, weight: .heavy))
                        .foregroundColor(.white.opacity(0.85))
                )
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 5, style: .continuous)
                .stroke(Color.white.opacity(0.10), lineWidth: 0.5)
        )
    }

    // MARK: - Right content
    @ViewBuilder
    private var rightContent: some View {
        if viewModel.hasActiveTimer {
            timerCountdown
        } else if viewModel.hasActiveMusic {
            AudioBars(isPlaying: viewModel.nowPlaying.track.isPlaying)
                .frame(width: 38, height: viewModel.compactSize.height - 6)
        }
    }

    private var timerCountdown: some View {
        let (text, tint) = timerCountdownStyle
        return Text(text)
            .font(.system(size: 13, weight: .heavy, design: .rounded))
            .foregroundColor(tint)
            .monospacedDigit()
    }

    private var timerCountdownStyle: (String, Color) {
        if viewModel.pomodoro.running {
            let tint: Color
            switch viewModel.pomodoro.phase {
            case .focus, .idle: tint = Color(red: 0.32, green: 0.84, blue: 0.55)
            case .shortBreak:   tint = Color(red: 0.32, green: 0.84, blue: 0.55)
            case .longBreak:    tint = Color(red: 0.17, green: 0.62, blue: 0.85)
            }
            return (viewModel.pomodoro.formattedTime, tint)
        }
        return (viewModel.countdown.formatted, Color(red: 1.00, green: 0.71, blue: 0.33))
    }

    // MARK: - Tap → expand + jump to relevant tab
    private func tapped() {
        viewModel.expanded = true
        if viewModel.hasActiveTimer {
            if viewModel.pomodoro.running, viewModel.visibleTabs.contains(.pomodoro) {
                viewModel.activeTab = .pomodoro
            } else if viewModel.visibleTabs.contains(.timers) {
                viewModel.activeTab = .timers
            }
        } else if viewModel.hasActiveMusic, viewModel.visibleTabs.contains(.nowPlaying) {
            viewModel.activeTab = .nowPlaying
        }
    }
}

// MARK: - AudioBars

/// Animated audio-level bars next to the album art. macOS doesn't
/// expose the system audio level via any public API, so these are
/// decorative — driven by sine waves staggered per-bar. When music
/// is paused, the bars freeze low.
private struct AudioBars: View {
    let isPlaying: Bool
    private let count = 4

    var body: some View {
        TimelineView(.animation(minimumInterval: 0.05)) { ctx in
            let t = ctx.date.timeIntervalSinceReferenceDate
            HStack(alignment: .center, spacing: 2.5) {
                ForEach(0..<count, id: \.self) { i in
                    Capsule()
                        .fill(LinearGradient(
                            colors: [
                                Color(red: 0.32, green: 0.84, blue: 0.55),
                                Color(red: 0.78, green: 0.93, blue: 0.30),
                            ],
                            startPoint: .bottom, endPoint: .top))
                        .frame(width: 3, height: barHeight(at: i, time: t))
                }
            }
        }
    }

    private func barHeight(at index: Int, time: Double) -> CGFloat {
        if !isPlaying { return 4 }
        let phase = time * 6 + Double(index) * 0.7
        let envelope = (cos(phase * 0.31) * 0.3 + 0.7)
        let level = (sin(phase) * 0.5 + 0.5) * envelope
        return CGFloat(5 + level * 14)
    }
}
