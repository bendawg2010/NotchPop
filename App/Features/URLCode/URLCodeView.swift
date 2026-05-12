// URLCodeView.swift — percent-encode / decode URLs.
// Mirrors Base64Tool's UI pattern (segmented mode picker + I/O).

import SwiftUI

struct URLCodeView: View {
    enum Mode: String, CaseIterable, Identifiable {
        case encode, decode
        var id: String { rawValue }
    }
    @AppStorage("np.url.mode") private var modeRaw: String = "encode"
    @AppStorage("np.url.input") private var input: String = "https://example.com/search?q=hello world&lang=en"

    private var mode: Mode { Mode(rawValue: modeRaw) ?? .encode }
    private var output: String {
        switch mode {
        case .encode:
            return input.addingPercentEncoding(
                withAllowedCharacters: .urlQueryAllowed.subtracting(
                    CharacterSet(charactersIn: "&=+ "))) ?? "(error)"
        case .decode:
            return input.removingPercentEncoding ?? "(can't decode)"
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
                .pickerStyle(.segmented)
                .frame(width: 140)
                Spacer()
                Button {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(output, forType: .string)
                } label: { Label("Copy out", systemImage: "doc.on.doc") }
                .buttonStyle(.borderedProminent)
            }
            HStack(spacing: 6) {
                ioCol(label: "Input",  text: $input, editable: true)
                ioCol(label: "Output", text: .constant(output), editable: false)
            }
        }
        .padding(.horizontal, 14).padding(.vertical, 10)
    }

    private func ioCol(label: String, text: Binding<String>, editable: Bool) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label).font(.system(size: 9, weight: .heavy))
                .tracking(1).foregroundColor(.secondary).textCase(.uppercase)
            if editable {
                TextEditor(text: text)
                    .font(.system(size: 10, design: .monospaced))
                    .padding(4)
                    .frame(height: 80)
                    .background(RoundedRectangle(cornerRadius: 8).fill(Color.white.opacity(0.05)))
            } else {
                ScrollView {
                    Text(text.wrappedValue)
                        .font(.system(size: 10, design: .monospaced))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(8).textSelection(.enabled)
                }
                .frame(height: 80)
                .background(RoundedRectangle(cornerRadius: 8).fill(Color.white.opacity(0.05)))
            }
        }
    }
}
