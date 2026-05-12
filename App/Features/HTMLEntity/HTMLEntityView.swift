// HTMLEntityView.swift — encode/decode HTML entities.
// Mirrors Base64Tool / URLCode pattern.

import SwiftUI

struct HTMLEntityView: View {
    enum Mode: String, CaseIterable, Identifiable {
        case encode, decode
        var id: String { rawValue }
    }
    @AppStorage("np.html.mode") private var modeRaw: String = "encode"
    @AppStorage("np.html.input") private var input: String = "<p>5 < 10 & \"hello\"</p>"

    private var mode: Mode { Mode(rawValue: modeRaw) ?? .encode }
    private var output: String {
        switch mode {
        case .encode:
            // Encode the 5 critical characters + non-ASCII to numeric entities.
            var out = ""
            for c in input {
                switch c {
                case "&":  out += "&amp;"
                case "<":  out += "&lt;"
                case ">":  out += "&gt;"
                case "\"": out += "&quot;"
                case "'":  out += "&#39;"
                default:
                    let scalar = c.unicodeScalars.first!.value
                    out += scalar > 127 ? "&#\(scalar);" : String(c)
                }
            }
            return out
        case .decode:
            // NSAttributedString's html init handles entities natively.
            guard let data = input.data(using: .utf8) else { return "(error)" }
            let opts: [NSAttributedString.DocumentReadingOptionKey: Any] = [
                .documentType: NSAttributedString.DocumentType.html,
                .characterEncoding: String.Encoding.utf8.rawValue,
            ]
            return (try? NSAttributedString(data: data, options: opts,
                                              documentAttributes: nil))?.string
                ?? "(can't decode)"
        }
    }

    var body: some View {
        VStack(spacing: 6) {
            HStack {
                Picker("", selection: Binding(
                    get: { mode },
                    set: { modeRaw = $0.rawValue }
                )) {
                    Text("Encode").tag(Mode.encode)
                    Text("Decode").tag(Mode.decode)
                }
                .pickerStyle(.segmented).frame(width: 140)
                Spacer()
                Button {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(output, forType: .string)
                } label: { Label("Copy out", systemImage: "doc.on.doc") }
                .buttonStyle(.borderedProminent)
            }
            HStack(spacing: 6) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Input").font(.system(size: 9, weight: .heavy))
                        .tracking(1).foregroundColor(.secondary).textCase(.uppercase)
                    TextEditor(text: $input)
                        .font(.system(size: 10, design: .monospaced))
                        .padding(4)
                        .frame(height: 80)
                        .background(RoundedRectangle(cornerRadius: 8).fill(Color.white.opacity(0.05)))
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text("Output").font(.system(size: 9, weight: .heavy))
                        .tracking(1).foregroundColor(.secondary).textCase(.uppercase)
                    ScrollView {
                        Text(output)
                            .font(.system(size: 10, design: .monospaced))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(8).textSelection(.enabled)
                    }
                    .frame(height: 80)
                    .background(RoundedRectangle(cornerRadius: 8).fill(Color.white.opacity(0.05)))
                }
            }
        }
        .padding(.horizontal, 14).padding(.vertical, 10)
    }
}
