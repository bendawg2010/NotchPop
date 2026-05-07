// ChargingView.swift
//
// Pane shown when user just plugged in (peek state) OR when they
// manually flip to the Battery tab. Shows percentage, animated
// charging indicator if charging, and a battery bar.

import SwiftUI

struct ChargingView: View {
    @ObservedObject var monitor: ChargingMonitor
    @State private var pulse: Bool = false

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color.white.opacity(0.06))
                    .frame(width: 60, height: 30)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .stroke(Color.white.opacity(0.18), lineWidth: 1.5)
                    )
                    .overlay(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 5, style: .continuous)
                            .fill(barFill)
                            .frame(width: max(4, 56 * CGFloat(monitor.batteryPercent) / 100), height: 22)
                            .padding(2)
                    }
                if monitor.isCharging {
                    Image(systemName: "bolt.fill")
                        .font(.system(size: 14, weight: .heavy))
                        .foregroundColor(.white)
                        .shadow(color: .black.opacity(0.5), radius: 1, y: 1)
                        .scaleEffect(pulse ? 1.2 : 1.0)
                        .opacity(pulse ? 1.0 : 0.85)
                }
            }
            .frame(width: 70)

            VStack(alignment: .leading, spacing: 2) {
                Text("\(monitor.batteryPercent)%")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundColor(.white)
                Text(monitor.isCharging ? "Charging" : "On battery")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.white.opacity(0.62))
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
        .onAppear {
            withAnimation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true)) {
                pulse = true
            }
        }
    }

    private var barFill: LinearGradient {
        if monitor.isCharging {
            return LinearGradient(
                colors: [Color(red: 0.32, green: 0.84, blue: 0.55),
                         Color(red: 0.20, green: 0.62, blue: 0.42)],
                startPoint: .top, endPoint: .bottom)
        }
        if monitor.batteryPercent < 20 {
            return LinearGradient(
                colors: [Color(red: 1.00, green: 0.42, blue: 0.42),
                         Color(red: 0.85, green: 0.20, blue: 0.20)],
                startPoint: .top, endPoint: .bottom)
        }
        return LinearGradient(
            colors: [Color.white.opacity(0.85), Color.white.opacity(0.55)],
            startPoint: .top, endPoint: .bottom)
    }
}
