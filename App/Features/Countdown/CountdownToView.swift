// CountdownToView.swift
//
// Pane shown inside the expanded notch when the Countdown To tab is
// active. Pick a future date — the pane shows days/hours/minutes
// remaining, ticking live. Persists the chosen date + label to
// UserDefaults so it survives relaunch.

import SwiftUI

final class CountdownToService: ObservableObject {
    @Published var targetDate: Date {
        didSet { UserDefaults.standard.set(targetDate, forKey: "np.countdown.date") }
    }
    @Published var label: String {
        didSet { UserDefaults.standard.set(label, forKey: "np.countdown.label") }
    }

    init() {
        self.targetDate = (UserDefaults.standard.object(forKey: "np.countdown.date") as? Date)
            ?? Calendar.current.date(byAdding: .day, value: 30, to: Date())
            ?? Date().addingTimeInterval(30 * 86400)
        self.label = UserDefaults.standard.string(forKey: "np.countdown.label") ?? "Big day"
    }
}

struct CountdownToView: View {
    @ObservedObject var service: CountdownToService
    @State private var editing = false
    @State private var draftLabel = ""

    var body: some View {
        Group {
            if editing {
                editorRow
            } else {
                displayRow
            }
        }
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

    private var displayRow: some View {
        TimelineView(.periodic(from: .now, by: 1)) { ctx in
            let parts = breakdown(now: ctx.date)
            HStack(spacing: 14) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("COUNTDOWN")
                        .font(.system(size: 9, weight: .heavy))
                        .tracking(1.4)
                        .foregroundColor(.white.opacity(0.55))
                    Text(service.label)
                        .font(.system(size: 14, weight: .heavy))
                        .foregroundColor(.white)
                        .lineLimit(1)
                    Text(formatDate(service.targetDate))
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.white.opacity(0.55))
                        .lineLimit(1)
                }
                Spacer(minLength: 4)
                HStack(spacing: 8) {
                    pill(parts.days, "DAYS")
                    pill(parts.hours, "HRS")
                    pill(parts.minutes, "MIN")
                    pill(parts.seconds, "SEC")
                }
                Button {
                    draftLabel = service.label
                    editing = true
                } label: {
                    Image(systemName: "pencil")
                        .font(.system(size: 11, weight: .heavy))
                        .foregroundColor(.white.opacity(0.85))
                        .frame(width: 26, height: 26)
                        .background(
                            RoundedRectangle(cornerRadius: 6).fill(Color.white.opacity(0.10))
                        )
                }
                .buttonStyle(.plain)
                .help("Edit countdown")
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
        }
    }

    private func pill(_ value: Int, _ label: String) -> some View {
        VStack(spacing: 1) {
            Text("\(value)")
                .font(.system(size: 18, weight: .heavy, design: .rounded))
                .foregroundColor(.white)
                .monospacedDigit()
            Text(label)
                .font(.system(size: 8, weight: .heavy))
                .foregroundColor(.white.opacity(0.55))
                .tracking(1.0)
        }
        .frame(width: 38)
        .padding(.vertical, 4)
        .background(
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .fill(Color.white.opacity(0.06))
        )
    }

    private var editorRow: some View {
        HStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 4) {
                TextField("What are you counting down to?", text: $draftLabel)
                    .textFieldStyle(.plain)
                    .foregroundColor(.white)
                    .font(.system(size: 12, weight: .medium))
                    .padding(.horizontal, 10)
                    .frame(height: 28)
                    .background(
                        RoundedRectangle(cornerRadius: 6).fill(Color.white.opacity(0.10))
                    )
                DatePicker("", selection: $service.targetDate,
                           in: Date()..., displayedComponents: [.date, .hourAndMinute])
                    .labelsHidden()
                    .datePickerStyle(.compact)
            }
            Button("Save") {
                service.label = draftLabel.trimmingCharacters(in: .whitespaces).isEmpty
                    ? "Big day"
                    : draftLabel
                editing = false
            }
            .keyboardShortcut(.defaultAction)
            .buttonStyle(.borderedProminent)
            Button {
                editing = false
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 11, weight: .heavy))
                    .foregroundColor(.white.opacity(0.65))
                    .frame(width: 26, height: 26)
                    .background(RoundedRectangle(cornerRadius: 6).fill(Color.white.opacity(0.10)))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
    }

    private func breakdown(now: Date) -> (days: Int, hours: Int, minutes: Int, seconds: Int) {
        let diff = max(0, service.targetDate.timeIntervalSince(now))
        let total = Int(diff)
        return (total / 86400,
                (total % 86400) / 3600,
                (total % 3600) / 60,
                total % 60)
    }

    private func formatDate(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .short
        return f.string(from: date)
    }
}
