// EyedropperView.swift — pick any pixel from the screen via NSColorSampler,
// show its hex+RGB and copy on click. Recent picks listed.

import AppKit
import SwiftUI

struct EyedropperView: View {
    @AppStorage("np.eyedrop.recent") private var recentJSON: String = "[]"
    @State private var current: NSColor? = nil

    private var recents: [String] {
        (try? JSONDecoder().decode([String].self,
                                     from: Data(recentJSON.utf8))) ?? []
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 12) {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color(nsColor: current ?? .gray))
                    .frame(width: 70, height: 60)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .stroke(Color.white.opacity(0.15), lineWidth: 1))
                VStack(alignment: .leading, spacing: 4) {
                    if let c = current {
                        Text(c.hex).font(.system(size: 16, weight: .heavy, design: .monospaced))
                            .foregroundColor(.white)
                        Text(c.rgbString).font(.system(size: 10, design: .monospaced))
                            .foregroundColor(.secondary)
                    } else {
                        Text("Pick a color").font(.system(size: 14, weight: .heavy))
                        Text("Click anywhere on screen with the picker.")
                            .font(.system(size: 10)).foregroundColor(.secondary)
                    }
                }
                Spacer()
                Button { sample() } label: {
                    Label("Pick", systemImage: "eyedropper.halffull")
                        .font(.system(size: 12, weight: .heavy))
                }.buttonStyle(.borderedProminent)
            }
            if !recents.isEmpty {
                Text("Recent")
                    .font(.system(size: 10, weight: .heavy)).tracking(1)
                    .foregroundColor(.secondary).textCase(.uppercase)
                HStack(spacing: 4) {
                    ForEach(recents.prefix(8), id: \.self) { hex in
                        Button {
                            NSPasteboard.general.clearContents()
                            NSPasteboard.general.setString(hex, forType: .string)
                        } label: {
                            RoundedRectangle(cornerRadius: 5)
                                .fill(Color(nsColor: NSColor.fromHex(hex) ?? .gray))
                                .frame(width: 24, height: 24)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 5)
                                        .stroke(Color.white.opacity(0.2), lineWidth: 0.5))
                        }.buttonStyle(.plain).help(hex)
                    }
                }
            }
        }
        .padding(.horizontal, 14).padding(.vertical, 10)
    }

    private func sample() {
        NSColorSampler().show { picked in
            guard let c = picked else { return }
            current = c
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(c.hex, forType: .string)
            var arr = recents
            arr.removeAll { $0 == c.hex }
            arr.insert(c.hex, at: 0)
            arr = Array(arr.prefix(16))
            if let data = try? JSONEncoder().encode(arr),
               let str = String(data: data, encoding: .utf8) {
                recentJSON = str
            }
        }
    }
}

private extension NSColor {
    var hex: String {
        let c = usingColorSpace(.sRGB) ?? self
        let r = Int(round(c.redComponent * 255))
        let g = Int(round(c.greenComponent * 255))
        let b = Int(round(c.blueComponent * 255))
        return String(format: "#%02X%02X%02X", r, g, b)
    }
    var rgbString: String {
        let c = usingColorSpace(.sRGB) ?? self
        let r = Int(round(c.redComponent * 255))
        let g = Int(round(c.greenComponent * 255))
        let b = Int(round(c.blueComponent * 255))
        return "rgb(\(r), \(g), \(b))"
    }
    static func fromHex(_ hex: String) -> NSColor? {
        var s = hex.uppercased()
        if s.hasPrefix("#") { s.removeFirst() }
        guard s.count == 6, let v = UInt32(s, radix: 16) else { return nil }
        return NSColor(srgbRed: CGFloat((v >> 16) & 0xFF) / 255,
                       green: CGFloat((v >> 8) & 0xFF) / 255,
                       blue: CGFloat(v & 0xFF) / 255, alpha: 1)
    }
}
