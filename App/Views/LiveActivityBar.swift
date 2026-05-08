// LiveActivityBar.swift
//
// iPhone-Dynamic-Island-style "live activities" that flank the
// collapsed notch. Two slots:
//
//   ┌──── timer pill ────┐  ┌── notch ──┐  ┌──── music pill ────┐
//   │  🍅  14:32         │  │  (black)  │  │  ◓  Midnight Drive │
//   └────────────────────┘  └───────────┘  └────────────────────┘
//
// • Timer slot (left) shows whichever timer is running, with Pomodoro
//   taking precedence over the standalone Countdown. Tap → expands the
//   notch and switches to the relevant tab.
// • Music slot (right) shows the current track when something is
//   playing in Apple Music or Spotify. Tap → expands + Music tab.
//
// Slots only appear when collapsed AND the user has live activities
// enabled in Settings → Behavior. They smoothly slide in when an
// activity becomes active and slide back out when it ends.

import SwiftUI

struct LiveActivityBar: View {
    @ObservedObject var viewModel: NotchViewModel

    var body: some View {
        HStack(spacing: 0) {
            // Left: timer pill (or empty space if no timer)
            if viewModel.leftActivityWidth > 0 {
                timerPill
                    .frame(width: viewModel.leftActivityWidth, alignment: .center)
                    .transition(.move(edge: .leading).combined(with: .opacity))
            } else {
                Color.clear.frame(width: 0)
            }

            // Center: invisible spacer matching the notch width — the
            // physical notch sits here.
            Color.clear.frame(width: viewModel.compactSize.width)

            // Right: music pill (or empty space if no music)
            if viewModel.rightActivityWidth > 0 {
                musicPill
                    .frame(width: viewModel.rightActivityWidth, alignment: .center)
                    .transition(.move(edge: .trailing).combined(with: .opacity))
            } else {
                Color.clear.frame(width: 0)
            }
        }
        .frame(height: viewModel.compactSize.height)
        .animation(.spring(response: 0.45, dampingFraction: 0.85),
                   value: viewModel.leftActivityWidth)
        .animation(.spring(response: 0.45, dampingFraction: 0.85),
                   value: viewModel.rightActivityWidth)
    }

    // MARK: - Timer pill (left of notch)

    private var timerPill: some View {
        // Pomodoro takes precedence; fall back to Countdown.
        let isPom = viewModel.pomodoro.running
        let label: String
        let accent: Color
        if isPom {
            label = viewModel.pomodoro.formattedTime
            accent = pomodoroAccent
        } else {
            label = viewModel.countdown.formatted
            accent = Color(red: 1.00, green: 0.71, blue: 0.33)
        }

        return Button {
            viewModel.expanded = true
            // Both Pomodoro AND Countdown live in Pomodoro/Timers tabs;
            // pick whichever is visible + relevant.
            if isPom, viewModel.visibleTabs.contains(.pomodoro) {
                viewModel.activeTab = .pomodoro
            } else if viewModel.visibleTabs.contains(.timers) {
                viewModel.activeTab = .timers
            }
        } label: {
            HStack(spacing: 5) {
                Text(isPom ? viewModel.pomodoro.phase.emoji : "⏱")
                    .font(.system(size: 11))
                Text(label)
                    .font(.system(size: 11, weight: .heavy, design: .rounded))
                    .foregroundColor(.white)
                    .monospacedDigit()
                // Tiny progress arc for Pomodoro (visual cue)
                if isPom {
                    Circle()
                        .trim(from: 0, to: viewModel.pomodoro.progress)
                        .stroke(accent, style: StrokeStyle(lineWidth: 1.6, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                        .frame(width: 8, height: 8)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                Capsule().fill(Color.black)
            )
            .overlay(
                Capsule().stroke(accent.opacity(0.55), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .help(isPom ? "Pomodoro · \(viewModel.pomodoro.phase.label)" : "Timer running")
    }

    private var pomodoroAccent: Color {
        switch viewModel.pomodoro.phase {
        case .focus, .idle:  return Color(red: 1.00, green: 0.42, blue: 0.42)
        case .shortBreak:    return Color(red: 0.32, green: 0.84, blue: 0.55)
        case .longBreak:     return Color(red: 0.17, green: 0.52, blue: 0.77)
        }
    }

    // MARK: - Music pill (right of notch)

    private var musicPill: some View {
        let track = viewModel.nowPlaying.track
        return Button {
            viewModel.expanded = true
            if viewModel.visibleTabs.contains(.nowPlaying) {
                viewModel.activeTab = .nowPlaying
            }
        } label: {
            HStack(spacing: 6) {
                // Album art mini (or fallback note icon)
                Group {
                    if let art = track.artwork {
                        Image(nsImage: art).resizable().scaledToFill()
                    } else {
                        Image(systemName: "music.note")
                            .font(.system(size: 9, weight: .heavy))
                            .foregroundColor(.white.opacity(0.7))
                    }
                }
                .frame(width: 16, height: 16)
                .clipShape(RoundedRectangle(cornerRadius: 3, style: .continuous))
                .background(
                    RoundedRectangle(cornerRadius: 3, style: .continuous)
                        .fill(Color.white.opacity(0.06))
                )

                MarqueeText(text: track.title.isEmpty ? "—" : track.title)
                    .font(.system(size: 10.5, weight: .heavy))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(
                Capsule().fill(Color.black)
            )
            .overlay(
                Capsule().stroke(Color(red: 1.00, green: 0.42, blue: 0.42).opacity(0.55), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .help("\(track.title) · \(track.artist)")
    }
}

/// One-line text that scrolls horizontally if it doesn't fit. Apple
/// Music's Now-Playing widget on iOS uses the same effect for long
/// titles. SwiftUI doesn't ship one, so we roll a simple version that
/// uses TimelineView for the per-frame redraw and clips with the
/// container's width.
private struct MarqueeText: View {
    let text: String

    var body: some View {
        GeometryReader { geo in
            let containerW = geo.size.width
            // Estimate text width — overestimate so we err toward
            // showing the marquee. Real width is checked inside.
            let textW = max(CGFloat(text.count) * 6, containerW)
            let needsScroll = textW > containerW

            if !needsScroll {
                Text(text)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .frame(width: containerW, alignment: .leading)
            } else {
                TimelineView(.animation(minimumInterval: 0.04)) { ctx in
                    let t = ctx.date.timeIntervalSinceReferenceDate
                    // 30 px/sec scroll. Loop after textW + spacer.
                    let pxPerSec: CGFloat = 30
                    let cycle = textW + 40
                    let phase = CGFloat(t.truncatingRemainder(dividingBy: Double(cycle / pxPerSec)))
                    let offset = -phase * pxPerSec
                    HStack(spacing: 40) {
                        Text(text).lineLimit(1)
                        Text(text).lineLimit(1)
                    }
                    .offset(x: offset)
                }
                .frame(width: containerW, alignment: .leading)
                .clipped()
            }
        }
        .frame(height: 12)
    }
}
