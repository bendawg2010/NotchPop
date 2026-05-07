// WelcomeCard.swift
//
// First-launch onboarding card. Auto-shown once when NotchPop is
// first opened, then never again (unless ~/Library/Preferences for
// the bundle is wiped). Replaces the normal tab UI for 5 seconds so
// the user discovers what the app actually does — without it the
// notch is just a black bar with no obvious trigger.

import SwiftUI

struct WelcomeCard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Text("👋")
                    .font(.system(size: 22))
                Text("Welcome to NotchPop")
                    .font(.system(size: 14, weight: .heavy))
                    .foregroundColor(.white)
            }
            Text("Hover the notch any time to see your file shelf, music, and battery. Drop files in. Drag them out anywhere.")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.white.opacity(0.72))
                .lineLimit(3)
                .fixedSize(horizontal: false, vertical: true)
            HStack(spacing: 4) {
                ForEach(0..<3) { i in
                    Capsule()
                        .fill(Color.white.opacity(0.20))
                        .frame(width: 18, height: 3)
                        .scaleEffect(x: 1, y: 1, anchor: .center)
                }
            }
            .padding(.top, 6)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(LinearGradient(
                    colors: [
                        Color(red: 1.00, green: 0.24, blue: 0.67).opacity(0.18),
                        Color(red: 0.47, green: 0.29, blue: 0.63).opacity(0.18),
                        Color(red: 0.17, green: 0.52, blue: 0.77).opacity(0.18)
                    ],
                    startPoint: .topLeading, endPoint: .bottomTrailing))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(Color.white.opacity(0.10), lineWidth: 1)
                )
        )
    }
}
