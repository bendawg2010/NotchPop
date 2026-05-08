// HashView.swift
//
// Pane shown inside the expanded notch when the Hash tab is active.
// Type any text and immediately see its MD5, SHA-1, SHA-256 hashes,
// plus Base64 encoded forms. Click any result to copy it.

import AppKit
import CryptoKit
import SwiftUI

struct HashView: View {
    @State private var input: String = ""
    @FocusState private var inputFocused: Bool
    @State private var copiedKind: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Image(systemName: "number")
                    .font(.system(size: 12, weight: .heavy))
                    .foregroundColor(.white.opacity(0.62))
                TextField("Text to hash…", text: $input)
                    .textFieldStyle(.plain)
                    .focused($inputFocused)
                    .foregroundColor(.white)
                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                    .padding(.horizontal, 8)
                    .frame(height: 26)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color.white.opacity(inputFocused ? 0.14 : 0.08))
                    )
                if !input.isEmpty {
                    Button {
                        input = ""
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 9, weight: .heavy))
                            .foregroundColor(.white.opacity(0.65))
                            .frame(width: 22, height: 22)
                            .background(
                                RoundedRectangle(cornerRadius: 5)
                                    .fill(Color.white.opacity(0.10))
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 2) {
                    row("MD5", md5(input))
                    row("SHA-1", sha1(input))
                    row("SHA-256", sha256(input))
                    row("Base64", base64(input))
                }
            }
        }
        .padding(.horizontal, 10)
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
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
                inputFocused = true
            }
        }
    }

    private func row(_ kind: String, _ value: String) -> some View {
        Button {
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(value, forType: .string)
            withAnimation { copiedKind = kind }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                if copiedKind == kind {
                    withAnimation { copiedKind = nil }
                }
            }
        } label: {
            HStack(spacing: 6) {
                Text(kind)
                    .font(.system(size: 9, weight: .heavy))
                    .foregroundColor(.white.opacity(0.55))
                    .frame(width: 60, alignment: .leading)
                Text(copiedKind == kind ? "✓ Copied" : (value.isEmpty ? "—" : value))
                    .font(.system(size: 10, weight: .semibold, design: .monospaced))
                    .foregroundColor(copiedKind == kind
                        ? Color(red: 0.32, green: 0.84, blue: 0.55)
                        : .white.opacity(value.isEmpty ? 0.30 : 0.85))
                    .lineLimit(1)
                    .truncationMode(.middle)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(
                RoundedRectangle(cornerRadius: 5)
                    .fill(Color.white.opacity(0.06))
            )
        }
        .buttonStyle(.plain)
        .help("Click to copy")
    }

    // MARK: - Hashing

    private func md5(_ s: String) -> String {
        guard let data = s.data(using: .utf8) else { return "" }
        return Insecure.MD5.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }
    private func sha1(_ s: String) -> String {
        guard let data = s.data(using: .utf8) else { return "" }
        return Insecure.SHA1.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }
    private func sha256(_ s: String) -> String {
        guard let data = s.data(using: .utf8) else { return "" }
        return SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }
    private func base64(_ s: String) -> String {
        s.data(using: .utf8)?.base64EncodedString() ?? ""
    }
}
