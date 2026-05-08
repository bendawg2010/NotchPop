// WorldClockView.swift
//
// Horizontal row of city cards. Each shows the friendly label,
// current time (HH:mm), and offset from local in compact form
// ("+5h" / "-3h" / "same"). Updates every second via TimelineView.

import SwiftUI

struct WorldClockView: View {
    @ObservedObject var service: WorldClockService
    /// Pulled in from the NotchViewModel so the user's 12/24-hour and
    /// "show seconds" preferences propagate into each city card.
    /// Defaults match the historical hardcoded "HH:mm" format if the
    /// caller doesn't pass these.
    var uses24Hour: Bool = true
    var showsSeconds: Bool = false

    var body: some View {
        TimelineView(.periodic(from: .now, by: showsSeconds ? 1 : 1)) { context in
            HStack(spacing: 8) {
                if service.clocks.isEmpty {
                    emptyState
                } else {
                    ForEach(service.clocks.prefix(4)) { entry in
                        clockCard(entry: entry, now: context.date)
                    }
                    Spacer(minLength: 0)
                }
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
    }

    private var emptyState: some View {
        Text("Add cities in Settings → Tabs → World Clock")
            .font(.system(size: 12, weight: .medium))
            .foregroundColor(.white.opacity(0.55))
            .frame(maxWidth: .infinity, alignment: .center)
    }

    private func clockCard(entry: ClockEntry, now: Date) -> some View {
        let tz = TimeZone(identifier: entry.timezoneIdentifier) ?? .current
        let formatter = DateFormatter()
        formatter.timeZone = tz
        // Build the format string from user prefs:
        //   24h: HH:mm or HH:mm:ss
        //   12h: h:mm a or h:mm:ss a (a = AM/PM)
        let baseFmt = uses24Hour ? "HH:mm" : "h:mm"
        let withSec = showsSeconds ? baseFmt.replacingOccurrences(of: "mm", with: "mm:ss") : baseFmt
        formatter.dateFormat = uses24Hour ? withSec : (withSec + " a")
        let timeStr = formatter.string(from: now)

        formatter.dateFormat = "EEE"
        let dayStr = formatter.string(from: now).uppercased()

        return VStack(spacing: 2) {
            Text(entry.label)
                .font(.system(size: 10, weight: .heavy))
                .foregroundColor(.white.opacity(0.62))
                .lineLimit(1)
                .truncationMode(.tail)
            Text(timeStr)
                .font(.system(size: 18, weight: .heavy, design: .rounded))
                .foregroundColor(.white)
                .monospacedDigit()
            Text(offsetLabel(tz: tz, now: now) + " · " + dayStr)
                .font(.system(size: 9, weight: .semibold))
                .foregroundColor(.white.opacity(0.45))
        }
        .frame(width: 72)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.white.opacity(0.04))
        )
    }

    /// Offset in hours from current local TZ, e.g. "+5h", "-3h", or "same"
    /// when the city is in the same timezone as the user's Mac.
    private func offsetLabel(tz: TimeZone, now: Date) -> String {
        let local = TimeZone.current.secondsFromGMT(for: now)
        let other = tz.secondsFromGMT(for: now)
        let diff = other - local
        if diff == 0 { return "same" }
        let hours = Double(diff) / 3600
        let sign = diff > 0 ? "+" : ""
        if hours == floor(hours) {
            return "\(sign)\(Int(hours))h"
        }
        return String(format: "%@%.1fh", sign, hours)
    }
}
