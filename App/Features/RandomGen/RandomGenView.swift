// RandomGenView.swift
//
// Quick-fire generators: secure password, UUID, dice roll, random
// number in a range. Each tile copies its result to the clipboard
// on tap and flashes "Copied" briefly.

import AppKit
import SwiftUI

struct RandomGenView: View {
    @State private var lastCopiedID: String?

    var body: some View {
        VStack(spacing: 6) {
            HStack(spacing: 6) {
                generatorTile(label: "Password", icon: "key.fill",
                              gradient: [Color(red: 1.00, green: 0.42, blue: 0.42),
                                         Color(red: 0.95, green: 0.30, blue: 0.55)]) {
                    generatePassword()
                }
                generatorTile(label: "UUID", icon: "barcode",
                              gradient: [Color(red: 0.62, green: 0.30, blue: 0.96),
                                         Color(red: 0.32, green: 0.50, blue: 0.95)]) {
                    UUID().uuidString
                }
                generatorTile(label: "Dice", icon: "die.face.5.fill",
                              gradient: [Color(red: 0.18, green: 0.62, blue: 0.85),
                                         Color(red: 0.18, green: 0.82, blue: 0.62)]) {
                    "🎲 \(Int.random(in: 1...6))"
                }
                generatorTile(label: "1-100", icon: "number",
                              gradient: [Color(red: 1.00, green: 0.71, blue: 0.33),
                                         Color(red: 1.00, green: 0.42, blue: 0.42)]) {
                    "\(Int.random(in: 1...100))"
                }
            }
            HStack(spacing: 6) {
                generatorTile(label: "Coin", icon: "circle.lefthalf.filled",
                              gradient: [Color(red: 0.85, green: 0.62, blue: 0.95),
                                         Color(red: 0.40, green: 0.65, blue: 0.95)]) {
                    Bool.random() ? "🪙 Heads" : "🪙 Tails"
                }
                generatorTile(label: "Color", icon: "paintpalette.fill",
                              gradient: [Color(red: 1.00, green: 0.55, blue: 0.20),
                                         Color(red: 1.00, green: 0.24, blue: 0.67)]) {
                    String(format: "#%02X%02X%02X",
                           Int.random(in: 0...255),
                           Int.random(in: 0...255),
                           Int.random(in: 0...255))
                }
                generatorTile(label: "Time", icon: "clock.fill",
                              gradient: [Color(red: 0.32, green: 0.84, blue: 0.55),
                                         Color(red: 0.18, green: 0.62, blue: 0.85)]) {
                    let h = Int.random(in: 0...23)
                    let m = Int.random(in: 0...59)
                    return String(format: "%02d:%02d", h, m)
                }
                generatorTile(label: "Hex 16", icon: "square.grid.2x2.fill",
                              gradient: [Color(red: 0.55, green: 0.58, blue: 0.65),
                                         Color(red: 0.30, green: 0.34, blue: 0.40)]) {
                    let bytes = (0..<8).map { _ in UInt8.random(in: 0...255) }
                    return bytes.map { String(format: "%02x", $0) }.joined()
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
    }

    private func generatorTile(label: String, icon: String,
                               gradient: [Color],
                               result: @escaping () -> String) -> some View {
        // Stable per-label ID — UUID() inside the function body
        // re-rolls every SwiftUI re-render, which made the
        // 'Copied!' flash never appear. Hashing the label gives us
        // a stable id per tile that survives renders.
        let id = label
        return Button {
            let value = result()
            // Same writeStringRobustly pattern as ClipboardService —
            // .nonactivatingPanel windows lose silent-setString
            // races with the pasteboard server. User report: "the
            // random things dont work" — the click was firing but
            // the pasteboard never got the value.
            writeToPasteboard(value)
            withAnimation(.easeOut(duration: 0.15)) {
                lastCopiedID = id
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                if lastCopiedID == id {
                    withAnimation(.easeIn(duration: 0.2)) {
                        lastCopiedID = nil
                    }
                }
            }
        } label: {
            VStack(spacing: 1) {
                if lastCopiedID == id {
                    Image(systemName: "checkmark")
                        .font(.system(size: 12, weight: .heavy))
                        .foregroundColor(.white)
                    Text("Copied")
                        .font(.system(size: 8, weight: .heavy))
                        .foregroundColor(.white)
                } else {
                    Image(systemName: icon)
                        .font(.system(size: 12, weight: .heavy))
                        .foregroundColor(.white)
                    Text(label)
                        .font(.system(size: 9, weight: .heavy))
                        .foregroundColor(.white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 32)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(LinearGradient(colors: gradient,
                                          startPoint: .topLeading,
                                          endPoint: .bottomTrailing))
            )
        }
        .buttonStyle(.plain)
        .help("Generate + copy a \(label.lowercased())")
    }

    /// Cryptographically-strong-ish password (uses .random which is
    /// SystemRandomNumberGenerator under the hood — fine for shared
    /// memorable strings, not for keys).
    private func generatePassword() -> String {
        let chars = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789!@#$%^&*"
        return String((0..<16).map { _ in chars.randomElement()! })
    }

    /// Robust pasteboard write — declareTypes + setString, verify
    /// readback, fall back to writeObjects, retry once after 50ms.
    /// Mirrors ClipboardService.writeStringRobustly so this view's
    /// chips actually copy from a .nonactivatingPanel context.
    private func writeToPasteboard(_ text: String) {
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.declareTypes([.string], owner: nil)
        let ok = pb.setString(text, forType: .string)
        if ok, pb.string(forType: .string) == text { return }
        pb.clearContents()
        let woOK = pb.writeObjects([text as NSString])
        if woOK, pb.string(forType: .string) == text { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            pb.clearContents()
            pb.declareTypes([.string], owner: nil)
            _ = pb.setString(text, forType: .string)
        }
    }
}
