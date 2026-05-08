// QRCodeView.swift
//
// Pane shown inside the expanded notch when the QR Code tab is
// active. Type a URL or text — we render a QR code via Core Image's
// CIQRCodeGenerator and display it. The QR auto-updates as the user
// types. Click the QR to copy the source text. Save to Desktop is
// optional via a button.

import AppKit
import SwiftUI

struct QRCodeView: View {
    @State private var input: String = "https://notchpop.pages.dev"
    @FocusState private var focused: Bool

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                Text("QR Code")
                    .font(.system(size: 10, weight: .heavy))
                    .foregroundColor(.white.opacity(0.55))
                    .tracking(1.0)
                TextField("URL or text…", text: $input)
                    .textFieldStyle(.plain)
                    .focused($focused)
                    .foregroundColor(.white)
                    .font(.system(size: 12, weight: .medium))
                    .padding(.horizontal, 10)
                    .frame(height: 28)
                    .background(
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(Color.white.opacity(focused ? 0.14 : 0.08))
                    )
                HStack(spacing: 6) {
                    Button {
                        saveToDesktop()
                    } label: {
                        Label("Save", systemImage: "square.and.arrow.down")
                            .font(.system(size: 10, weight: .heavy))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(
                                RoundedRectangle(cornerRadius: 5)
                                    .fill(Color.white.opacity(0.12))
                            )
                            .foregroundColor(.white.opacity(0.85))
                    }
                    .buttonStyle(.plain)
                    .help("Save QR as PNG to Desktop")
                    Spacer()
                }
            }
            qrPreview
                .frame(width: 64, height: 64)
        }
        .padding(.horizontal, 12)
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

    @ViewBuilder
    private var qrPreview: some View {
        if let img = generateQR(input) {
            Image(nsImage: img)
                .resizable()
                .interpolation(.none)  // crisp 1px-block QR rendering
                .scaledToFit()
                .padding(2)
                .background(Color.white)
                .cornerRadius(6)
        } else {
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(Color.white.opacity(0.10))
                .overlay(
                    Text("?")
                        .font(.system(size: 28, weight: .heavy))
                        .foregroundColor(.white.opacity(0.45))
                )
        }
    }

    /// Build a QR code as an NSImage from a string. The generated CIImage
    /// is upscaled with a non-interpolating scale transform so the
    /// blocks stay crisp (default would smear them).
    private func generateQR(_ text: String) -> NSImage? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty,
              let data = trimmed.data(using: .utf8),
              let filter = CIFilter(name: "CIQRCodeGenerator")
        else { return nil }
        filter.setValue(data, forKey: "inputMessage")
        filter.setValue("M", forKey: "inputCorrectionLevel")
        guard let output = filter.outputImage else { return nil }
        let scale: CGFloat = 8.0
        let scaled = output.transformed(by: CGAffineTransform(scaleX: scale, y: scale))
        let rep = NSCIImageRep(ciImage: scaled)
        let img = NSImage(size: rep.size)
        img.addRepresentation(rep)
        return img
    }

    /// Save the current QR as a PNG to ~/Desktop. Uses a timestamped
    /// filename so subsequent saves don't overwrite each other.
    private func saveToDesktop() {
        guard let img = generateQR(input),
              let tiff = img.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiff),
              let png = bitmap.representation(using: .png, properties: [:])
        else { return }
        let fm = FileManager.default
        guard let desktop = fm.urls(for: .desktopDirectory,
                                     in: .userDomainMask).first
        else { return }
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd-HHmmss"
        let url = desktop.appendingPathComponent("qr-\(formatter.string(from: Date())).png")
        do {
            try png.write(to: url)
            NSWorkspace.shared.activateFileViewerSelecting([url])
        } catch {
            NSLog("NotchPop QR save failed: \(error)")
        }
    }
}
