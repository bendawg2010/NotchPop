// RemindersView.swift
//
// Pane shown inside the expanded notch when the Reminders tab is
// active. Compact list with a single-line input on top to add
// new items. Click the circle to toggle done. Click ✕ to delete.

import SwiftUI

struct RemindersView: View {
    @ObservedObject var service: RemindersService
    @State private var newText: String = ""

    var body: some View {
        VStack(spacing: 6) {
            inputRow
            Divider().opacity(0.18)
            if service.items.isEmpty {
                Spacer()
                Text("No reminders. Type one above and press return.")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.white.opacity(0.55))
                Spacer()
            } else {
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 2) {
                        ForEach(service.items) { item in
                            row(item)
                        }
                    }
                }
            }
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

    private var inputRow: some View {
        HStack(spacing: 6) {
            Image(systemName: "plus.circle.fill")
                .foregroundColor(.white.opacity(0.55))
            TextField("Add a reminder…", text: $newText, onCommit: commit)
                .textFieldStyle(.plain)
                .foregroundColor(.white)
                .font(.system(size: 12, weight: .medium))
            if !service.items.allSatisfy({ !$0.done }) {
                Button {
                    service.clearDone()
                } label: {
                    Text("Clear ✓")
                        .font(.system(size: 10, weight: .heavy))
                        .foregroundColor(.white.opacity(0.65))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(
                            RoundedRectangle(cornerRadius: 5)
                                .fill(Color.white.opacity(0.10))
                        )
                }
                .buttonStyle(.plain)
                .help("Remove all completed reminders")
            }
        }
    }

    private func commit() {
        service.add(newText)
        newText = ""
    }

    private func row(_ item: ReminderItem) -> some View {
        HStack(spacing: 6) {
            Button {
                service.toggle(item)
            } label: {
                Image(systemName: item.done ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(item.done
                        ? Color(red: 0.32, green: 0.84, blue: 0.55)
                        : .white.opacity(0.55))
            }
            .buttonStyle(.plain)
            Text(item.text)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.white.opacity(item.done ? 0.45 : 0.92))
                .strikethrough(item.done, color: .white.opacity(0.45))
                .lineLimit(1)
                .truncationMode(.tail)
            Spacer()
            Button {
                service.remove(item)
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 9, weight: .heavy))
                    .foregroundColor(.white.opacity(0.4))
                    .frame(width: 16, height: 16)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help("Delete")
        }
        .padding(.vertical, 2)
    }
}
