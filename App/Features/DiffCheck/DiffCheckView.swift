// DiffCheckView.swift — paste two texts, see line-by-line diff.
// Simple LCS-based diff (good enough for short snippets).

import SwiftUI

struct DiffCheckView: View {
    @AppStorage("np.diff.a") private var textA: String = "alpha\nbeta\ngamma\ndelta"
    @AppStorage("np.diff.b") private var textB: String = "alpha\nBETA\ngamma\nepsilon"

    private enum Op { case keep, add, remove }
    private struct DLine: Identifiable {
        let id = UUID()
        let op: Op
        let text: String
    }

    /// LCS-based diff. Returns lines with their op.
    private var diff: [DLine] {
        let a = textA.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        let b = textB.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        // Build LCS length matrix
        let m = a.count, n = b.count
        var lcs = Array(repeating: Array(repeating: 0, count: n + 1), count: m + 1)
        for i in 0..<m {
            for j in 0..<n {
                lcs[i+1][j+1] = a[i] == b[j]
                    ? lcs[i][j] + 1
                    : max(lcs[i+1][j], lcs[i][j+1])
            }
        }
        // Walk back to produce edit script
        var out: [DLine] = []
        var i = m, j = n
        while i > 0 && j > 0 {
            if a[i-1] == b[j-1] {
                out.insert(DLine(op: .keep, text: a[i-1]), at: 0)
                i -= 1; j -= 1
            } else if lcs[i][j-1] >= lcs[i-1][j] {
                out.insert(DLine(op: .add, text: b[j-1]), at: 0)
                j -= 1
            } else {
                out.insert(DLine(op: .remove, text: a[i-1]), at: 0)
                i -= 1
            }
        }
        while i > 0 { out.insert(DLine(op: .remove, text: a[i-1]), at: 0); i -= 1 }
        while j > 0 { out.insert(DLine(op: .add, text: b[j-1]), at: 0); j -= 1 }
        return out
    }

    private var summary: (adds: Int, removes: Int) {
        let lines = diff
        return (lines.filter { $0.op == .add }.count,
                lines.filter { $0.op == .remove }.count)
    }

    var body: some View {
        VStack(spacing: 6) {
            HStack(spacing: 6) {
                pane("A", text: $textA)
                pane("B", text: $textB)
            }
            HStack {
                Text("+\(summary.adds)")
                    .font(.system(size: 11, weight: .heavy, design: .monospaced))
                    .foregroundColor(.green)
                Text("-\(summary.removes)")
                    .font(.system(size: 11, weight: .heavy, design: .monospaced))
                    .foregroundColor(.red)
                Spacer()
            }
            ScrollView {
                VStack(alignment: .leading, spacing: 1) {
                    ForEach(diff) { line in
                        HStack(alignment: .top, spacing: 4) {
                            Text(prefix(for: line.op))
                                .font(.system(size: 10, weight: .heavy, design: .monospaced))
                                .foregroundColor(color(for: line.op))
                                .frame(width: 12, alignment: .center)
                            Text(line.text)
                                .font(.system(size: 10, design: .monospaced))
                                .foregroundColor(color(for: line.op))
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .textSelection(.enabled)
                        }
                        .padding(.horizontal, 6).padding(.vertical, 1)
                        .background(rowBackground(for: line.op))
                    }
                }
            }
            .frame(height: 80)
            .background(RoundedRectangle(cornerRadius: 8).fill(Color.white.opacity(0.05)))
        }
        .padding(.horizontal, 14).padding(.vertical, 10)
    }

    private func pane(_ label: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(label).font(.system(size: 9, weight: .heavy))
                .tracking(1).foregroundColor(.secondary).textCase(.uppercase)
            TextEditor(text: text)
                .font(.system(size: 10, design: .monospaced))
                .padding(4)
                .frame(height: 70)
                .background(RoundedRectangle(cornerRadius: 6).fill(Color.white.opacity(0.05)))
        }
    }
    private func prefix(for op: Op) -> String {
        switch op { case .keep: " "; case .add: "+"; case .remove: "-" }
    }
    private func color(for op: Op) -> Color {
        switch op {
        case .keep:   return .white.opacity(0.65)
        case .add:    return .green
        case .remove: return .red
        }
    }
    private func rowBackground(for op: Op) -> Color {
        switch op {
        case .keep:   return .clear
        case .add:    return Color.green.opacity(0.10)
        case .remove: return Color.red.opacity(0.10)
        }
    }
}
