// WelcomeCard.swift
//
// First-launch onboarding card. Auto-shown once when NotchPop is
// first opened, then never again (unless ~/Library/Preferences for
// the bundle is wiped). Replaces the normal tab UI for 5 seconds so
// the user discovers what the app actually does — without it the
// notch is just a black bar with no obvious trigger.

import SwiftUI

/// Welcome card shown on first launch (and replayable from Settings).
/// Cycles through three "scenes": gradient + tagline → feature ticks
/// → "hover any time to start". Each scene fades in/out, while the
/// background gradient pans continuously underneath via hueRotation.
struct WelcomeCard: View {
    @State private var sceneIndex: Int = 0

    private let stops: [Color] = [
        Color(red: 1.00, green: 0.24, blue: 0.67).opacity(0.45),
        Color(red: 0.47, green: 0.29, blue: 0.63).opacity(0.45),
        Color(red: 0.17, green: 0.52, blue: 0.77).opacity(0.45),
    ]

    /// Tagline cycle — 1.5s each, total 4.5s. Mirrors the welcome peek
    /// duration in NotchViewModel.runWelcomePeek.
    private let scenes: [WelcomeScene] = [
        .init(emoji: "✨",
              headline: "Your workflow,",
              accent:   "faster.",
              caption:  "Hover the notch to see music, pomodoro, files, and notes."),
        .init(emoji: "📥",
              headline: "Drop files in.",
              accent:   "Drag them out.",
              caption:  "Anywhere on your Mac. The notch is your shelf."),
        .init(emoji: "🍅",
              headline: "Tabs are yours.",
              accent:   "Customize all of it.",
              caption:  "Settings → Tabs to reorder. Click the menu-bar icon."),
    ]

    var body: some View {
        TimelineView(.animation) { context in
            let t = context.date.timeIntervalSinceReferenceDate
            let hue = (t.truncatingRemainder(dividingBy: 12) / 12) * 360

            ZStack {
                // Layer 1: animated gradient backdrop
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(LinearGradient(
                        colors: stops,
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing))
                    .hueRotation(.degrees(hue))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(Color.white.opacity(0.14), lineWidth: 1)
                    )

                // Layer 2: scene content with the NotchPop wordmark
                // hero on top.
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 6) {
                        Image(systemName: "rectangle.bottomthird.inset.filled")
                            .font(.system(size: 11, weight: .heavy))
                            .foregroundColor(.white.opacity(0.85))
                        Text("NOTCHPOP")
                            .font(.system(size: 11, weight: .black, design: .rounded))
                            .tracking(2.4)
                            .foregroundColor(.white.opacity(0.85))
                        Spacer(minLength: 0)
                    }
                    sceneText
                    Spacer()
                    sceneDots
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }
        }
        .onAppear {
            // Advance scene every 1.5s
            for i in 1...(scenes.count - 1) {
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5 * Double(i)) {
                    withAnimation(.spring(response: 0.45, dampingFraction: 0.85)) {
                        sceneIndex = i
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var sceneText: some View {
        let scene = scenes[min(sceneIndex, scenes.count - 1)]
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 8) {
                Text(scene.emoji)
                    .font(.system(size: 26))
                    .transition(.scale.combined(with: .opacity))
                Text(scene.headline)
                    .font(.system(size: 17, weight: .heavy))
                    .foregroundColor(.white)
                    .transition(.opacity)
            }
            // Big accent line — gradient-stroked text so it looks
            // like the gradient halo around the notch leaks into
            // the headline. User feedback: "thats a weak ah intro"
            // — the previous 18pt static-white text was the most
            // milquetoast thing we could've shipped.
            Text(scene.accent)
                .font(.system(size: 30, weight: .black, design: .rounded))
                .foregroundStyle(LinearGradient(
                    colors: [
                        Color(red: 1.00, green: 0.42, blue: 0.42),
                        Color(red: 0.95, green: 0.30, blue: 0.85),
                        Color(red: 0.40, green: 0.65, blue: 0.97),
                    ],
                    startPoint: .leading, endPoint: .trailing))
                .transition(.opacity.combined(with: .scale(scale: 0.92, anchor: .leading)))
                .shadow(color: Color.white.opacity(0.18), radius: 6)
            Text(scene.caption)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.white.opacity(0.85))
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
                .transition(.opacity)
                .padding(.top, 2)
        }
        .id(sceneIndex)  // force fresh transition per scene
    }

    private var sceneDots: some View {
        HStack(spacing: 4) {
            ForEach(0..<scenes.count, id: \.self) { i in
                Capsule()
                    .fill(Color.white.opacity(i == sceneIndex ? 0.95 : 0.30))
                    .frame(width: i == sceneIndex ? 18 : 8, height: 3)
                    .animation(.spring(response: 0.32, dampingFraction: 0.85), value: sceneIndex)
            }
        }
    }
}

private struct WelcomeScene {
    let emoji: String
    let headline: String
    let accent: String
    let caption: String
}
