// TipCalcView.swift
// Bill amount + tip percentage + people split → per-person total.
// Lives entirely in @State; no service required.

import SwiftUI

struct TipCalcView: View {
    @AppStorage("np.tip.bill") private var billText: String = "0"
    @AppStorage("np.tip.pct") private var tipPct: Int = 18
    @AppStorage("np.tip.people") private var people: Int = 1

    private var bill: Double { Double(billText) ?? 0 }
    private var tipDollars: Double { bill * Double(tipPct) / 100 }
    private var total: Double { bill + tipDollars }
    private var perPerson: Double { total / Double(max(1, people)) }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("$").foregroundColor(.secondary)
                TextField("Bill amount", text: $billText)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(size: 16, weight: .heavy, design: .rounded))
                    .frame(width: 100)
                Spacer()
                tipChips
            }
            HStack {
                Text("Split").font(.system(size: 11, weight: .heavy)).foregroundColor(.secondary)
                Stepper(value: $people, in: 1...20) {
                    Text("\(people) " + (people == 1 ? "person" : "people"))
                        .font(.system(size: 12, weight: .semibold))
                }
            }
            Divider().padding(.vertical, 2)
            row("Tip",   String(format: "$%.2f", tipDollars), .yellow)
            row("Total", String(format: "$%.2f", total), .blue)
            row("Per person", String(format: "$%.2f", perPerson), .pink, big: true)
        }
        .padding(.horizontal, 14).padding(.vertical, 10)
    }

    private var tipChips: some View {
        HStack(spacing: 4) {
            ForEach([10, 15, 18, 20, 25], id: \.self) { p in
                Button {
                    tipPct = p
                } label: {
                    Text("\(p)%")
                        .font(.system(size: 10, weight: .heavy))
                        .padding(.horizontal, 7).padding(.vertical, 3)
                        .background(
                            Capsule().fill(tipPct == p
                                            ? Color.accentColor.opacity(0.4)
                                            : Color.white.opacity(0.08)))
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func row(_ label: String, _ value: String, _ tint: Color, big: Bool = false) -> some View {
        HStack {
            Text(label).font(.system(size: big ? 13 : 11,
                                      weight: big ? .heavy : .semibold))
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .font(.system(size: big ? 18 : 13, weight: .heavy, design: .rounded))
                .foregroundColor(tint)
                .monospacedDigit()
        }
    }
}
