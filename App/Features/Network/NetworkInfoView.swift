// NetworkInfoView.swift
//
// Pane shown inside the expanded notch when the Network tab is
// active. Wi-Fi SSID + signal bars on the left, IP address + a
// refresh button on the right.

import SwiftUI

struct NetworkInfoView: View {
    @ObservedObject var service: NetworkInfoService

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    Image(systemName: wifiSymbol)
                        .font(.system(size: 18, weight: .regular))
                        .foregroundColor(wifiColor)
                    Text(service.ssid ?? "Not connected")
                        .font(.system(size: 14, weight: .heavy))
                        .foregroundColor(.white)
                        .lineLimit(1).truncationMode(.tail)
                }
                if let r = service.rssi {
                    Text("Signal: \(r) dBm · \(service.bars)/4 bars")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.white.opacity(0.55))
                } else {
                    Text("No signal info")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.white.opacity(0.45))
                }
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text("IP")
                    .font(.system(size: 9, weight: .heavy))
                    .foregroundColor(.white.opacity(0.55))
                    .tracking(1.0)
                Text(service.ipAddress ?? "—")
                    .font(.system(size: 14, weight: .heavy, design: .monospaced))
                    .foregroundColor(.white)
                    .lineLimit(1)
                if let ip = service.ipAddress {
                    Button {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(ip, forType: .string)
                    } label: {
                        Text("Copy")
                            .font(.system(size: 9, weight: .heavy))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(
                                RoundedRectangle(cornerRadius: 5)
                                    .fill(Color.white.opacity(0.10))
                            )
                            .foregroundColor(.white.opacity(0.85))
                    }
                    .buttonStyle(.plain)
                }
            }
            VStack {
                Button {
                    service.refresh()
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 11, weight: .heavy))
                        .foregroundColor(.white.opacity(0.85))
                        .frame(width: 26, height: 26)
                        .background(
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .fill(Color.white.opacity(0.10))
                        )
                }
                .buttonStyle(.plain)
                .help("Refresh")
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
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
        .onAppear { service.start() }
        .onDisappear { service.stop() }
    }

    private var wifiSymbol: String {
        switch service.bars {
        case 4: return "wifi"
        case 3: return "wifi"
        case 2: return "wifi"
        case 1: return "wifi.slash"
        default: return service.ssid == nil ? "wifi.slash" : "wifi.exclamationmark"
        }
    }

    private var wifiColor: Color {
        if service.ssid == nil { return Color(red: 1.00, green: 0.42, blue: 0.42) }
        switch service.bars {
        case 4: return Color(red: 0.32, green: 0.84, blue: 0.55)
        case 3: return Color(red: 0.32, green: 0.84, blue: 0.55)
        case 2: return Color(red: 1.00, green: 0.71, blue: 0.33)
        default: return Color(red: 1.00, green: 0.42, blue: 0.42)
        }
    }
}
