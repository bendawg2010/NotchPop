// JWTDecodeView.swift — paste a JWT, see header + payload decoded.
// Doesn't verify the signature (that requires the key) — purely a
// debug-decode tool for "what's in this token I just got back."

import SwiftUI

struct JWTDecodeView: View {
    @AppStorage("np.jwt.input") private var input: String =
        "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiIxMjM0NSIsIm5hbWUiOiJOb3RjaHkiLCJpYXQiOjE2MDB9.placeholder"

    private struct Decoded {
        let header: String
        let payload: String
        let signaturePresent: Bool
        let error: String?
    }
    private var decoded: Decoded {
        let parts = input.split(separator: ".", omittingEmptySubsequences: false).map(String.init)
        guard parts.count >= 2 else {
            return Decoded(header: "", payload: "", signaturePresent: false,
                            error: "JWTs have 3 dot-separated parts (header.payload.signature)")
        }
        func decode(_ s: String) -> String? {
            // Base64URL → Base64 (replace -_/= padding)
            var b = s.replacingOccurrences(of: "-", with: "+")
                     .replacingOccurrences(of: "_", with: "/")
            while b.count % 4 != 0 { b += "=" }
            guard let data = Data(base64Encoded: b),
                  let txt = String(data: data, encoding: .utf8) else { return nil }
            // Pretty-print JSON if it parses
            if let obj = try? JSONSerialization.jsonObject(with: data),
               let pretty = try? JSONSerialization.data(
                withJSONObject: obj,
                options: [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]),
               let pTxt = String(data: pretty, encoding: .utf8) {
                return pTxt
            }
            return txt
        }
        let h = decode(parts[0]) ?? "(can't decode header)"
        let p = decode(parts[1]) ?? "(can't decode payload)"
        return Decoded(header: h, payload: p,
                        signaturePresent: parts.count >= 3 && !parts[2].isEmpty,
                        error: nil)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image(systemName: decoded.error == nil
                                  ? "checkmark.seal.fill"
                                  : "exclamationmark.triangle.fill")
                    .foregroundColor(decoded.error == nil ? .green : .orange)
                Text(decoded.error ?? (decoded.signaturePresent
                     ? "Decoded · signature present (not verified)"
                     : "Decoded · no signature"))
                    .font(.system(size: 10, weight: .heavy))
                Spacer()
                Button {
                    if let s = NSPasteboard.general.string(forType: .string) {
                        input = s
                    }
                } label: { Image(systemName: "arrow.down.doc") }
                .buttonStyle(.bordered)
            }
            TextEditor(text: $input)
                .font(.system(size: 9, design: .monospaced))
                .padding(4)
                .frame(height: 36)
                .background(RoundedRectangle(cornerRadius: 6).fill(Color.white.opacity(0.05)))
            if decoded.error == nil {
                section(label: "HEADER", text: decoded.header, tint: .pink)
                section(label: "PAYLOAD", text: decoded.payload, tint: .blue)
            }
        }
        .padding(.horizontal, 14).padding(.vertical, 10)
    }

    private func section(label: String, text: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(label).font(.system(size: 9, weight: .heavy))
                .tracking(1.2).foregroundColor(tint)
            ScrollView {
                Text(text)
                    .font(.system(size: 10, design: .monospaced))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(7)
                    .textSelection(.enabled)
            }
            .frame(height: 50)
            .background(RoundedRectangle(cornerRadius: 7).fill(Color.white.opacity(0.05)))
        }
    }
}
