// WeatherView.swift
//
// Pane shown inside the expanded notch when the Weather tab is
// active. Big SF Symbol on the left, temperature + label + location
// in the middle, °F/°C toggle + refresh button on the right. Updates
// every 15 minutes via the service's timer; user can hit the
// refresh button at any time.

import SwiftUI

struct WeatherView: View {
    @ObservedObject var service: WeatherService

    var body: some View {
        Group {
            if let snap = service.snapshot {
                content(snap: snap)
            } else if service.isLoading {
                loadingState
            } else if service.lastError != nil {
                errorState
            } else {
                bootstrapState
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
    }

    // MARK: - Content

    private func content(snap: WeatherSnapshot) -> some View {
        HStack(spacing: 12) {
            // Big symbol on the left, gradient-tinted to match condition
            Image(systemName: snap.symbolName)
                .font(.system(size: 32, weight: .regular))
                .foregroundStyle(.white)
                .symbolRenderingMode(.hierarchical)
                .frame(width: 48, height: 48)
                .background(
                    LinearGradient(
                        colors: gradientColors(for: snap.weatherCode),
                        startPoint: .topLeading, endPoint: .bottomTrailing)
                )
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

            VStack(alignment: .leading, spacing: 2) {
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text("\(Int(snap.temperature.rounded()))")
                        .font(.system(size: 28, weight: .heavy, design: .rounded))
                        .foregroundColor(.white)
                        .monospacedDigit()
                    Text("°\(snap.fahrenheit ? "F" : "C")")
                        .font(.system(size: 14, weight: .heavy, design: .rounded))
                        .foregroundColor(.white.opacity(0.62))
                }
                Text(snap.label)
                    .font(.system(size: 11, weight: .heavy))
                    .foregroundColor(.white.opacity(0.78))
                    .lineLimit(1)
                Text(snap.locationLabel)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.white.opacity(0.55))
                    .lineLimit(1)
                Text("Wind \(Int(snap.windKph.rounded())) km/h · updated \(relativeTime(snap.fetchedAt))")
                    .font(.system(size: 9, weight: .medium))
                    .foregroundColor(.white.opacity(0.40))
                    .lineLimit(1)
            }

            Spacer(minLength: 4)

            VStack(spacing: 4) {
                // Unit toggle
                Button {
                    service.fahrenheit.toggle()
                } label: {
                    Text(snap.fahrenheit ? "°C" : "°F")
                        .font(.system(size: 10, weight: .heavy, design: .rounded))
                        .foregroundColor(.white)
                        .frame(width: 28, height: 22)
                        .background(
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .fill(Color.white.opacity(0.10))
                        )
                }
                .buttonStyle(.plain)
                .help("Switch unit")

                // Refresh
                Button {
                    service.refresh()
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 10, weight: .heavy))
                        .foregroundColor(.white.opacity(0.85))
                        .frame(width: 28, height: 22)
                        .background(
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .fill(Color.white.opacity(0.10))
                        )
                }
                .buttonStyle(.plain)
                .help("Refresh now")
            }
        }
    }

    private var loadingState: some View {
        HStack(spacing: 10) {
            Spacer(minLength: 0)
            ProgressView()
                .controlSize(.small)
            Text("Loading weather…")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.white.opacity(0.60))
            Spacer(minLength: 0)
        }
    }

    private var bootstrapState: some View {
        HStack(spacing: 10) {
            Spacer(minLength: 0)
            Image(systemName: "cloud.sun.fill")
                .font(.system(size: 18))
                .foregroundColor(.white.opacity(0.55))
            VStack(alignment: .leading, spacing: 2) {
                Text("Weather")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.white.opacity(0.78))
                Text("Tap refresh to fetch your local forecast")
                    .font(.system(size: 10))
                    .foregroundColor(.white.opacity(0.55))
            }
            Button {
                service.refresh()
            } label: {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 12, weight: .heavy))
                    .foregroundColor(.white)
                    .frame(width: 36, height: 28)
                    .background(
                        RoundedRectangle(cornerRadius: 7, style: .continuous)
                            .fill(LinearGradient(
                                colors: [Color(red: 0.17, green: 0.52, blue: 0.97),
                                         Color(red: 0.62, green: 0.30, blue: 0.96)],
                                startPoint: .leading, endPoint: .trailing)))
            }
            .buttonStyle(.plain)
            Spacer(minLength: 0)
        }
    }

    private var errorState: some View {
        HStack(spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(Color(red: 1.00, green: 0.71, blue: 0.33))
            VStack(alignment: .leading, spacing: 1) {
                Text("Couldn't fetch weather")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.white)
                Text(service.lastError ?? "Unknown error")
                    .font(.system(size: 10))
                    .foregroundColor(.white.opacity(0.55))
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
            Button {
                service.refresh()
            } label: {
                Text("Retry")
                    .font(.system(size: 11, weight: .heavy))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(RoundedRectangle(cornerRadius: 6).fill(Color.white.opacity(0.10)))
                    .foregroundColor(.white)
            }
            .buttonStyle(.plain)
        }
    }

    /// Color tint for the icon background — warm sun, cool clouds,
    /// blue rain, purple thunder. Matches the brand gradient feel.
    private func gradientColors(for code: Int) -> [Color] {
        switch code {
        case 0:
            return [Color(red: 1.00, green: 0.71, blue: 0.33),
                    Color(red: 1.00, green: 0.42, blue: 0.42)]
        case 1, 2:
            return [Color(red: 0.85, green: 0.62, blue: 0.95),
                    Color(red: 0.40, green: 0.65, blue: 0.95)]
        case 3, 45, 48:
            return [Color(red: 0.55, green: 0.58, blue: 0.65),
                    Color(red: 0.38, green: 0.41, blue: 0.48)]
        case 51...67, 80...82:
            return [Color(red: 0.17, green: 0.52, blue: 0.97),
                    Color(red: 0.40, green: 0.45, blue: 0.85)]
        case 71...77, 85, 86:
            return [Color(red: 0.78, green: 0.88, blue: 1.00),
                    Color(red: 0.50, green: 0.65, blue: 0.95)]
        case 95...99:
            return [Color(red: 0.62, green: 0.30, blue: 0.96),
                    Color(red: 0.95, green: 0.30, blue: 0.55)]
        default:
            return [Color(red: 0.40, green: 0.65, blue: 0.95),
                    Color(red: 0.55, green: 0.58, blue: 0.65)]
        }
    }

    private func relativeTime(_ d: Date) -> String {
        let elapsed = Date().timeIntervalSince(d)
        if elapsed < 60 { return "just now" }
        if elapsed < 3600 { return "\(Int(elapsed / 60)) min ago" }
        return "\(Int(elapsed / 3600))h ago"
    }
}
