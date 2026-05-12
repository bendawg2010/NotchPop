// SpeedTestView.swift — quick download-speed measurement.
// Pulls a known-size 25 MB file from Cloudflare's speed.cloudflare.com
// and computes Mbps. Strictly download-only (no upload).

import SwiftUI

@MainActor
final class SpeedTestService: ObservableObject {
    @Published var mbps: Double? = nil
    @Published var status: String = "Ready."
    @Published var running: Bool = false

    func run() {
        guard !running else { return }
        running = true
        status = "Connecting…"
        mbps = nil
        // 25 MB test endpoint
        let url = URL(string: "https://speed.cloudflare.com/__down?bytes=25000000")!
        var req = URLRequest(url: url, timeoutInterval: 30)
        req.cachePolicy = .reloadIgnoringLocalAndRemoteCacheData
        let started = Date()
        URLSession.shared.dataTask(with: req) { [weak self] data, _, error in
            Task { @MainActor in
                guard let self = self else { return }
                defer { self.running = false }
                if let error = error {
                    self.status = "Error: \(error.localizedDescription)"
                    return
                }
                guard let data = data else {
                    self.status = "No data."
                    return
                }
                let elapsed = Date().timeIntervalSince(started)
                let bits = Double(data.count) * 8
                let mbps = (bits / elapsed) / 1_000_000
                self.mbps = mbps
                self.status = String(format: "Downloaded %.1f MB in %.1fs",
                                      Double(data.count) / 1_000_000, elapsed)
            }
        }.resume()
    }
}

struct SpeedTestView: View {
    @StateObject private var service = SpeedTestService()
    var body: some View {
        VStack(spacing: 10) {
            VStack(spacing: 0) {
                Text(service.mbps.map { String(format: "%.1f", $0) } ?? "—")
                    .font(.system(size: 42, weight: .heavy, design: .rounded))
                    .foregroundStyle(LinearGradient(
                        colors: [Color(red: 0.18, green: 0.90, blue: 0.63),
                                 Color(red: 0.28, green: 0.63, blue: 1.00)],
                        startPoint: .leading, endPoint: .trailing))
                    .monospacedDigit()
                Text("Mbps · download")
                    .font(.system(size: 10, weight: .heavy))
                    .tracking(1.4)
                    .foregroundColor(.secondary)
                    .textCase(.uppercase)
            }
            Text(service.status)
                .font(.system(size: 10))
                .foregroundColor(.secondary)
                .lineLimit(2)
                .multilineTextAlignment(.center)
            Button { service.run() } label: {
                Label(service.running ? "Running…" : "Run speed test",
                       systemImage: service.running ? "hourglass" : "speedometer")
                    .font(.system(size: 12, weight: .heavy))
            }
            .buttonStyle(.borderedProminent)
            .disabled(service.running)
        }
        .padding(.horizontal, 14).padding(.vertical, 10)
        .frame(maxWidth: .infinity)
    }
}
