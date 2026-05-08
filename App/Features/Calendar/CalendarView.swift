// CalendarView.swift
//
// "Calendar peek" pane inside the expanded notch. Renders three
// permission-driven states (notDetermined / denied / granted) and a
// horizontal scroll of upcoming event chips when access is granted.
// Wraps the body in a TimelineView so the "Now" cutoff refreshes once
// per minute and just-ended events drop off without manual reload.

import SwiftUI
import EventKit
import AppKit

struct CalendarView: View {
    @ObservedObject var service: CalendarService

    var body: some View {
        TimelineView(.periodic(from: .now, by: 60)) { context in
            content(now: context.date)
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
    }

    @ViewBuilder
    private func content(now: Date) -> some View {
        switch service.permissionState {
        case .notDetermined:
            notDeterminedState
        case .denied:
            deniedState
        case .granted:
            grantedState(now: now)
        }
    }

    // MARK: - States

    private var notDeterminedState: some View {
        HStack(spacing: 12) {
            Button(action: { service.start() }) {
                Text("Click to enable")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(
                        Capsule()
                            .fill(LinearGradient(
                                colors: [
                                    Color(red: 1.00, green: 0.24, blue: 0.67),
                                    Color(red: 0.17, green: 0.52, blue: 0.77)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing))
                    )
            }
            .buttonStyle(.plain)

            Text("NotchPop needs access to your calendar.")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.white.opacity(0.72))
                .lineLimit(2)

            Spacer(minLength: 0)
        }
    }

    private var deniedState: some View {
        HStack(spacing: 10) {
            Image(systemName: "lock.fill")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(.white.opacity(0.72))
            Text("Calendar access denied. Enable in System Settings → Privacy → Calendar.")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.white.opacity(0.72))
                .lineLimit(3)
            Spacer(minLength: 0)
        }
    }

    @ViewBuilder
    private func grantedState(now: Date) -> some View {
        let visible = service.todaysEvents
            .filter { ($0.endDate ?? $0.startDate) > now }
            .prefix(5)

        if visible.isEmpty {
            HStack {
                Spacer()
                VStack(spacing: 4) {
                    Image(systemName: "calendar.badge.checkmark")
                        .font(.system(size: 18, weight: .regular))
                        .foregroundColor(.white.opacity(0.55))
                    Text("Nothing else today")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.white.opacity(0.62))
                }
                Spacer()
            }
        } else {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(Array(visible), id: \.eventIdentifier) { event in
                        eventChip(event)
                    }
                }
                .padding(.vertical, 2)
            }
        }
    }

    // MARK: - Chip

    private func eventChip(_ event: EKEvent) -> some View {
        HStack(spacing: 8) {
            Rectangle()
                .fill(stripeColor(for: event))
                .frame(width: 3)
                .clipShape(RoundedRectangle(cornerRadius: 1.5, style: .continuous))

            VStack(alignment: .leading, spacing: 2) {
                Text(timeLabel(for: event))
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(.white)
                Text(event.title ?? "Untitled")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.white.opacity(0.7))
                    .lineLimit(1)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .frame(minWidth: 92, maxWidth: 140, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color.white.opacity(0.06))
        )
    }

    // MARK: - Formatting

    /// "2:30p" / "11a" — compact lowercase am/pm, drops :00.
    private func timeLabel(for event: EKEvent) -> String {
        guard let start = event.startDate else { return "—" }
        let cal = Calendar.current
        let comps = cal.dateComponents([.hour, .minute], from: start)
        let hour24 = comps.hour ?? 0
        let minute = comps.minute ?? 0
        let suffix = hour24 < 12 ? "a" : "p"
        var hour12 = hour24 % 12
        if hour12 == 0 { hour12 = 12 }
        if minute == 0 {
            return "\(hour12)\(suffix)"
        } else {
            return String(format: "%d:%02d%@", hour12, minute, suffix)
        }
    }

    private func stripeColor(for event: EKEvent) -> Color {
        if let cg = event.calendar?.cgColor {
            return Color(NSColor(cgColor: cg) ?? .systemGray)
        }
        return Color.white.opacity(0.4)
    }
}
