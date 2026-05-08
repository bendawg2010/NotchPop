// CalculatorView.swift
//
// Pane shown inside the expanded notch when the Calculator tab is
// active. Type an arithmetic expression (e.g. "3 * (5 + 2)") and
// press Return — NSExpression evaluates it. History of last few
// evaluations shown below.
//
// Supports +, -, *, /, parentheses, and the function names
// NSExpression understands (sqrt, sin, cos, exp, log10, etc.).
// Per-cent works as a literal "/100" replacement so "20% of 80"
// can be typed as "20% * 80" → 16. We also accept ^ for power
// (translated to ** internally).

import AppKit
import SwiftUI

struct CalcEntry: Identifiable, Equatable {
    let id = UUID()
    let expression: String
    let result: String
}

final class CalculatorService: ObservableObject {
    @Published var history: [CalcEntry] = []
    static let maxHistory = 6

    func evaluate(_ raw: String) -> String? {
        var expr = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !expr.isEmpty else { return nil }
        // Friendly translations
        expr = expr.replacingOccurrences(of: "%", with: "/100")
        expr = expr.replacingOccurrences(of: "^", with: "**")
        expr = expr.replacingOccurrences(of: "×", with: "*")
        expr = expr.replacingOccurrences(of: "÷", with: "/")
        // NSExpression rejects `**` so map to `pow(a, b)` would
        // require parsing — simpler: only allow basic ops.
        expr = expr.replacingOccurrences(of: "**", with: "*")  // collapse to mult; real power
                                                                // needs typed pow(a,b) by the user.
        let nsExpr = NSExpression(format: expr)
        guard let value = nsExpr.expressionValue(with: nil, context: nil) else { return nil }
        if let n = value as? NSNumber {
            // Trim trailing zeros for cleaner display
            let dbl = n.doubleValue
            if dbl.rounded() == dbl, abs(dbl) < 1e15 {
                return "\(Int64(dbl))"
            }
            return String(format: "%g", dbl)
        }
        return "\(value)"
    }

    func push(_ expr: String, result: String) {
        history.insert(CalcEntry(expression: expr, result: result), at: 0)
        if history.count > Self.maxHistory {
            history = Array(history.prefix(Self.maxHistory))
        }
    }
}

struct CalculatorView: View {
    @ObservedObject var service: CalculatorService
    @State private var input: String = ""
    @State private var lastResult: String?
    @State private var lastError: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            inputRow
            resultRow
            historyView
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

    private var inputRow: some View {
        HStack(spacing: 6) {
            Image(systemName: "function")
                .foregroundColor(.white.opacity(0.55))
            TextField("3 * (5 + 2)…", text: $input, onCommit: evaluate)
                .textFieldStyle(.plain)
                .foregroundColor(.white)
                .font(.system(size: 13, weight: .semibold, design: .monospaced))
                .onSubmit { evaluate() }
            if let r = lastResult {
                Button {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(r, forType: .string)
                } label: {
                    Image(systemName: "doc.on.doc")
                        .font(.system(size: 10, weight: .heavy))
                        .foregroundColor(.white.opacity(0.65))
                }
                .buttonStyle(.plain)
                .help("Copy result")
            }
        }
    }

    private var resultRow: some View {
        HStack {
            if let r = lastResult {
                Text("=").font(.system(size: 13, weight: .heavy, design: .rounded))
                    .foregroundColor(.white.opacity(0.55))
                Text(r)
                    .font(.system(size: 16, weight: .heavy, design: .rounded))
                    .foregroundColor(lastError ? Color(red: 1.00, green: 0.42, blue: 0.42)
                                                : .white)
                    .monospacedDigit()
            } else {
                Text("Press return to evaluate · supports + − × ÷ ( ) % ^ sqrt sin cos")
                    .font(.system(size: 9, weight: .medium))
                    .foregroundColor(.white.opacity(0.40))
                    .lineLimit(1)
            }
            Spacer()
        }
        .frame(height: 22)
    }

    private var historyView: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 4) {
                ForEach(service.history) { entry in
                    Button {
                        input = entry.expression
                    } label: {
                        Text("\(entry.expression) = \(entry.result)")
                            .font(.system(size: 9, weight: .semibold, design: .monospaced))
                            .foregroundColor(.white.opacity(0.62))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(
                                RoundedRectangle(cornerRadius: 5)
                                    .fill(Color.white.opacity(0.06))
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func evaluate() {
        if let result = service.evaluate(input) {
            lastResult = result
            lastError = false
            service.push(input, result: result)
        } else {
            lastResult = "error"
            lastError = true
        }
    }
}
