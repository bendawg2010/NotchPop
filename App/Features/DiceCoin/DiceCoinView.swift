// DiceCoinView.swift — D6 / D20 rolls + coin flip with rolling history.

import SwiftUI

struct DiceCoinView: View {
    @State private var lastRolls: [String] = []
    @State private var current: String = "🎲"
    @State private var spin: Double = 0

    var body: some View {
        VStack(spacing: 10) {
            Text(current)
                .font(.system(size: 42, weight: .heavy, design: .rounded))
                .frame(maxWidth: .infinity)
                .frame(height: 70)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color.white.opacity(0.06))
                )
                .rotationEffect(.degrees(spin))
                .animation(.spring(response: 0.5, dampingFraction: 0.55), value: spin)

            HStack(spacing: 6) {
                button("🎲 D6")  { roll(6, label: "D6") }
                button("🎯 D20") { roll(20, label: "D20") }
                button("🪙 Coin") { flipCoin() }
                button("🎲×2 D6+D6") { roll(6, label: "2d6", times: 2) }
            }
            if !lastRolls.isEmpty {
                Text("Recent: " + lastRolls.suffix(8).joined(separator: " · "))
                    .font(.system(size: 10, weight: .semibold, design: .monospaced))
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }
        }
        .padding(.horizontal, 14).padding(.vertical, 10)
    }

    private func button(_ title: String, _ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 11, weight: .heavy))
                .padding(.horizontal, 10).padding(.vertical, 6)
                .background(
                    Capsule().fill(LinearGradient(
                        colors: [Color(red: 1.00, green: 0.24, blue: 0.67),
                                 Color(red: 0.17, green: 0.52, blue: 0.77)],
                        startPoint: .leading, endPoint: .trailing).opacity(0.7))
                )
                .foregroundColor(.white)
        }.buttonStyle(.plain)
    }

    private func roll(_ sides: Int, label: String, times: Int = 1) {
        let nums = (0..<times).map { _ in Int.random(in: 1...sides) }
        let total = nums.reduce(0, +)
        let display = times == 1 ? "\(nums[0])" : "\(total) (" + nums.map(String.init).joined(separator: "+") + ")"
        current = display
        lastRolls.append("\(label):\(display)")
        spin += 360
    }
    private func flipCoin() {
        let result = Bool.random() ? "Heads" : "Tails"
        current = result == "Heads" ? "🟡" : "⚪"
        lastRolls.append("Coin:" + result)
        spin += 720
    }
}
