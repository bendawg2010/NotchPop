// JSONFormatView.swift — paste JSON, see it pretty-printed.
// Uses JSONSerialization for parse + .prettyPrinted output.

import SwiftUI

struct JSONFormatView: View {
    @AppStorage("np.json.in") private var input: String =
        "{\"name\":\"Notchy\",\"states\":12,\"colors\":[\"pink\",\"blue\"]}"
    @State private var error: String? = nil

    private var formatted: String {
        guard let data = input.data(using: .utf8),
              let obj = try? JSONSerialization.jsonObject(with: data, options: [.allowFragments]),
              let pretty = try? JSONSerialization.data(
                withJSONObject: obj,
                options: [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes])
        else { return "" }
        return String(data: pretty, encoding: .utf8) ?? ""
    }
    private var isValid: Bool { !formatted.isEmpty }

    var body: some View {
        VStack(spacing: 6) {
            HStack {
                Image(systemName: isValid ? "checkmark.seal.fill" : "exclamationmark.triangle.fill")
                    .foregroundColor(isValid ? .green : .orange)
                Text(isValid ? "Valid JSON" : "Invalid JSON")
                    .font(.system(size: 11, weight: .heavy))
                Spacer()
                Button {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(formatted, forType: .string)
                } label: { Label("Copy", systemImage: "doc.on.doc") }
                .buttonStyle(.bordered).disabled(!isValid)
                Button {
                    if let s = NSPasteboard.general.string(forType: .string) {
                        input = s
                    }
                } label: { Label("Paste", systemImage: "arrow.down.doc") }
                .buttonStyle(.borderedProminent)
            }
            HStack(spacing: 6) {
                ScrollView {
                    TextEditor(text: $input)
                        .font(.system(size: 10, design: .monospaced))
                        .padding(4)
                }
                .frame(maxWidth: .infinity)
                .background(RoundedRectangle(cornerRadius: 8).fill(Color.white.opacity(0.05)))
                ScrollView {
                    Text(isValid ? formatted : "—")
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundColor(isValid ? .primary : .secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(8)
                }
                .frame(maxWidth: .infinity)
                .background(RoundedRectangle(cornerRadius: 8).fill(Color.white.opacity(0.05)))
            }.frame(height: 100)
        }
        .padding(.horizontal, 14).padding(.vertical, 10)
    }
}
