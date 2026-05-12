// Base64ToolView.swift — encode/decode Base64 with mode toggle.

import SwiftUI

struct Base64ToolView: View {
    enum Mode: String, CaseIterable, Identifiable {
        case encode, decode
        var id: String { rawValue }
    }
    @AppStorage("np.b64.mode") private var modeRaw: String = "encode"
    @AppStorage("np.b64.input") private var input: String = "Hello, Notchy!"

    private var mode: Mode { Mode(rawValue: modeRaw) ?? .encode }
    private var output: String {
        switch mode {
        case .encode:
            return Data(input.utf8).base64EncodedString()
        case .decode:
            guard let data = Data(base64Encoded: input,
                                    options: .ignoreUnknownCharacters),
                  let s = String(data: data, encoding: .utf8) else {
                return "(can't decode — invalid Base64)"
            }
            return s
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
                            .padding(8)
                            .textSelection(.enabled)
                    }
                    .frame(height: 80)
                    .background(RoundedRectangle(cornerRadius: 8).fill(Color.white.opacity(0.05)))
                }
            }
        }
        .padding(.horizontal, 14).padding(.vertical, 10)
    }
}
