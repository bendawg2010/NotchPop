// ColorConvView.swift — convert between hex / rgb / hsl. Type any
// format, see the rest. Live swatch preview on the right.

import AppKit
import SwiftUI

struct ColorConvView: View {
    @AppStorage("np.color.input") private var input: String = "#C147FF"

    private struct RGB { let r, g, b: Int }
    private struct HSL { let h, s, l: Int }

    /// Parse the input as hex / rgb(...) / hsl(...) → an NSColor.
    private var parsed: NSColor? {
        let s = input.trimmingCharacters(in: .whitespaces).lowercased()
        // hex
        var hex = s
        if hex.hasPrefix("#") { hex.removeFirst() }
        if hex.count == 3 {
            // shorthand: #abc → #aabbcc
            hex = hex.map { "\($0)\($0)" }.joined()
        }
        if hex.count == 6, let v = UInt32(hex, radix: 16) {
            return NSColor(srgbRed: CGFloat((v >> 16) & 0xFF) / 255,
                            green: CGFloat((v >> 8)  & 0xFF) / 255,
                            blue:  CGFloat(v & 0xFF) / 255,
                            alpha: 1)
        }
        // rgb(r, g, b)
        if let m = s.range(of: #"rgba?\(\s*(\d+)[\s,]+(\d+)[\s,]+(\d+)"#,
                            options: .regularExpression) {
            let nums = String(s[m]).components(separatedBy: CharacterSet(charactersIn: "0123456789").inverted)
                .compactMap(Int.init)
            if nums.count >= 3 {
                return NSColor(srgbRed: CGFloat(nums[0]) / 255,
                                green: CGFloat(nums[1]) / 255,
                                blue:  CGFloat(nums[2]) / 255,
                                alpha: 1)
            }
        }
        // hsl(h, s%, l%)
        if let m = s.range(of: #"hsl\(\s*(\d+)[\s,]+(\d+)%?[\s,]+(\d+)%?"#,
                            options: .regularExpression) {
            let nums = String(s[m]).components(separatedBy: CharacterSet(charactersIn: "0123456789").inverted)
                .compactMap(Int.init)
            if nums.count >= 3 {
                return hslToColor(h: Double(nums[0]), s: Double(nums[1]) / 100,
                                    l: Double(nums[2]) / 100)
            }
        }
        return nil
    }

    private func hslToColor(h: Double, s: Double, l: Double) -> NSColor {
        let hh = h / 360
        let q = l < 0.5 ? l * (1 + s) : l + s - l * s
        let p = 2 * l - q
        func hue2rgb(_ t: Double) -> Double {
            var t = t
            if t < 0 { t += 1 }
            if t > 1 { t -= 1 }
            if t < 1.0/6 { return p + (q - p) * 6 * t }
            if t < 0.5   { return q }
            if t < 2.0/3 { return p + (q - p) * (2.0/3 - t) * 6 }
            return p
        }
        return NSColor(srgbRed: hue2rgb(hh + 1.0/3),
                        green: hue2rgb(hh),
                        blue:  hue2rgb(hh - 1.0/3),
                        alpha: 1)
    }

    private func rgb(_ c: NSColor) -> RGB {
        let n = c.usingColorSpace(.sRGB) ?? c
        return RGB(r: Int(round(n.redComponent * 255)),
                   g: Int(round(n.greenComponent * 255)),
                   b: Int(round(n.blueComponent * 255)))
    }
    private func hsl(_ c: NSColor) -> HSL {
        let n = c.usingColorSpace(.sRGB) ?? c
        let r = n.redComponent, g = n.greenComponent, b = n.blueComponent
        let mx = max(r, max(g, b)), mn = min(r, min(g, b))
        let l = (mx + mn) / 2
        var h = 0.0, s = 0.0
        if mx != mn {
            let d = mx - mn
            s = l > 0.5 ? d / (2 - mx - mn) : d / (mx + mn)
            switch mx {
            case r: h = (g - b) / d + (g < b ? 6 : 0)
            case g: h = (b - r) / d + 2
            default: h = (r - g) / d + 4
            }
            h /= 6
        }
        return HSL(h: Int(round(h * 360)),
                   s: Int(round(s * 100)),
                   l: Int(round(l * 100)))
    }

    var body: some View {
        HStack(spacing: 14) {
            // Left: input + outputs
            VStack(alignment: .leading, spacing: 6) {
                TextField("#C147FF, rgb(193 71 255), hsl(283 99 64)", text: $input)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(size: 11, design: .monospaced))
                if let c = parsed {
                    let r = rgb(c), h = hsl(c)
                    let hex = String(format: "#%02X%02X%02X", r.r, r.g, r.b)
                    row("HEX",  hex)
                    row("RGB",  "rgb(\(r.r), \(r.g), \(r.b))")
                    row("HSL",  "hsl(\(h.h), \(h.s)%, \(h.l)%)")
                } else {
                    Text("Type a hex / rgb / hsl color.")
                        .font(.system(size: 10)).foregroundColor(.secondary)
                }
            }
            // Right: swatch
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color(nsColor: parsed ?? .gray))
                .frame(width: 90, height: 90)
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(Color.white.opacity(0.15), lineWidth: 1))
                .shadow(color: .black.opacity(0.3), radius: 8, y: 4)
        }
        .padding(.horizontal, 14).padding(.vertical, 10)
    }

    private func row(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label).font(.system(size: 9, weight: .heavy))
                .tracking(1.2).foregroundColor(.secondary)
                .frame(width: 36, alignment: .leading)
            Text(value)
                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                .foregroundColor(.white)
                .textSelection(.enabled)
            Spacer()
            Button {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(value, forType: .string)
            } label: {
                Image(systemName: "doc.on.doc")
                    .font(.system(size: 9))
            }.buttonStyle(.plain)
        }
    }
}
