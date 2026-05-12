// RegexTestView.swift — paste a pattern + a test string, see live
// matches highlighted with capture groups and a count summary.

import SwiftUI

struct RegexTestView: View {
    @AppStorage("np.regex.pattern") private var pattern: String = #"\b(\w+)@(\w+\.\w+)\b"#
    @AppStorage("np.regex.input")   private var testText: String =
        "Drop a line: bob@example.com or alice@notchpop.dev — we'll get back."
    @AppStorage("np.regex.opts")    private var optsRaw: String = "i"

    private struct MatchInfo {
        let range: NSRange
        let groups: [String]
    }

    private var matches: [MatchInfo] {
        guard !pattern.isEmpty else { return [] }
        var opts: NSRegularExpression.Options = []
        if optsRaw.contains("i") { opts.insert(.caseInsensitive) }
        if optsRaw.contains("m") { opts.insert(.anchorsMatchLines) }
        if optsRaw.contains("s") { opts.insert(.dotMatchesLineSeparators) }
        guard let re = try? NSRegularExpression(pattern: pattern, options: opts) else {
            return []
        }
        let ns = testText as NSString
        let result = re.matches(in: testText, range: NSRange(location: 0, length: ns.length))
        return result.map { m in
            let groups = (0..<m.numberOfRanges).compactMap { i -> String? in
                let r = m.range(at: i)
                guard r.location != NSNotFound else { return nil }
                return ns.substring(with: r)
            }
            return MatchInfo(range: m.range, groups: groups)
        }
    }

    private var error: String? {
        guard !pattern.isEmpty else { return nil }
        do { _ = try NSRegularExpression(pattern: pattern); return nil }
        catch { return error.localizedDescription }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("/").foregroundColor(.secondary)
                TextField("regex", text: $pattern)
                    .textFieldStyle(.plain)
                    .font(.system(size: 11, design: .monospaced))
                Text("/").foregroundColor(.secondary)
                TextField("flags", text: $optsRaw)
                    .textFieldStyle(.plain)
                    .font(.system(size: 11, design: .monospaced))
                    .frame(width: 50)
                    .help("i: case-insensitive · m: multiline · s: dotall")
            }
            .padding(.horizontal, 8).padding(.vertical, 6)
            .background(RoundedRectangle(cornerRadius: 8).fill(Color.white.opacity(0.06)))

            HStack(spacing: 6) {
                Image(systemName: error == nil
                                  ? (matches.isEmpty
                                     ? "circle"
                                     : "checkmark.seal.fill")
                                  : "exclamationmark.triangle.fill")
                    .foregroundColor(error == nil
                                       ? (matches.isEmpty ? .secondary : .green)
                                       : .red)
                Text(error ?? "\(matches.count) match\(matches.count == 1 ? "" : "es")")
                    .font(.system(size: 10, weight: .heavy))
                    .foregroundColor(error == nil ? .secondary : .red)
            }

            // Test input
            TextEditor(text: $testText)
                .font(.system(size: 11, design: .monospaced))
                .padding(4)
                .frame(height: 50)
                .background(RoundedRectangle(cornerRadius: 6).fill(Color.white.opacity(0.05)))

            // Match list
            if !matches.isEmpty {
                ScrollView {
                    VStack(alignment: .leading, spacing: 3) {
                        ForEach(Array(matches.enumerated()), id: \.offset) { idx, m in
                            HStack(alignment: .top, spacing: 6) {
                                Text("\(idx + 1)")
                                    .font(.system(size: 9, weight: .heavy, design: .monospaced))
                                    .foregroundColor(.secondary)
                                    .frame(width: 16, alignment: .trailing)
                                VStack(alignment: .leading, spacing: 1) {
                                    Text(m.groups.first ?? "")
                                        .font(.system(size: 10, weight: .heavy, design: .monospaced))
                                        .foregroundColor(.green)
                                    if m.groups.count > 1 {
                                        ForEach(Array(m.groups.dropFirst().enumerated()),
                                                  id: \.offset) { gIdx, g in
                                            Text("$\(gIdx + 1) = \(g)")
                                                .font(.system(size: 9, design: .monospaced))
                                                .foregroundColor(.blue)
                                        }
                                    }
                                }
                                Spacer()
                            }
                        }
                    }
                }
                .frame(maxHeight: 80)
            }
        }
        .padding(.horizontal, 14).padding(.vertical, 10)
    }
}
