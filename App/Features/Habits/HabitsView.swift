// HabitsView.swift
//
// Pane shown inside the expanded notch when the Habits tab is
// active. Horizontal row of habit tiles. Click a tile to toggle
// today's completion. Streak shown in the corner. Add/remove from
// the inline + button.

import SwiftUI

struct HabitsView: View {
    @ObservedObject var service: HabitsService
    @State private var showingAdd: Bool = false
    @State private var newTitle: String = ""
    @State private var newEmoji: String = "🔥"

    var body: some View {
        Group {
            if service.habits.isEmpty {
                emptyState
            } else {
                habitsRow
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
        .popover(isPresented: $showingAdd) { addPopover }
    }

    private var emptyState: some View {
        HStack(spacing: 10) {
            Spacer(minLength: 0)
            Image(systemName: "flame.fill")
                .font(.system(size: 18))
                .foregroundColor(Color(red: 1.00, green: 0.42, blue: 0.42))
            VStack(alignment: .leading, spacing: 1) {
                Text("Habits").font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.white.opacity(0.78))
                Text("Daily checkboxes with streaks")
                    .font(.system(size: 10))
                    .foregroundColor(.white.opacity(0.55))
            }
            Spacer(minLength: 0)
            addButton.padding(.trailing, 14)
        }
        .padding(.horizontal, 14)
    }

    private var habitsRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(service.habits) { habit in
                    HabitTile(habit: habit, service: service)
                }
                addButton
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
        }
    }

    private var addButton: some View {
        Button {
            showingAdd = true
        } label: {
            VStack(spacing: 2) {
                Image(systemName: "plus")
                    .font(.system(size: 14, weight: .heavy))
                Text("Add")
                    .font(.system(size: 9, weight: .heavy))
            }
            .frame(width: 56, height: 56)
            .foregroundColor(.white.opacity(0.65))
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color.white.opacity(0.06))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .stroke(Color.white.opacity(0.18),
                                    style: StrokeStyle(lineWidth: 1, dash: [3, 3]))
                    )
            )
        }
        .buttonStyle(.plain)
        .help("Add a habit")
    }

    private var addPopover: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Add a habit").font(.headline)
            HStack {
                TextField("Emoji", text: $newEmoji)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 70)
                    .multilineTextAlignment(.center)
                TextField("Habit name (e.g. Drink water)", text: $newTitle)
                    .textFieldStyle(.roundedBorder)
            }
            HStack {
                Spacer()
                Button("Cancel") { showingAdd = false }
                Button("Add") {
                    service.add(title: newTitle, emoji: newEmoji)
                    newTitle = ""
                    newEmoji = "🔥"
                    showingAdd = false
                }
                .keyboardShortcut(.defaultAction)
                .disabled(newTitle.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .padding(16)
        .frame(width: 320)
    }
}

private struct HabitTile: View {
    let habit: Habit
    @ObservedObject var service: HabitsService
    @State private var hovered = false

    var body: some View {
        Button {
            service.toggleToday(habit)
        } label: {
            VStack(spacing: 1) {
                ZStack {
                    Text(habit.emoji)
                        .font(.system(size: 22))
                    if habit.doneToday {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 14))
                            .foregroundStyle(Color(red: 0.32, green: 0.84, blue: 0.55))
                            .background(Circle().fill(Color.black.opacity(0.55)))
                            .offset(x: 14, y: 12)
                    }
                }
                .frame(height: 26)
                Text(habit.title)
                    .font(.system(size: 8, weight: .heavy))
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .foregroundColor(.white)
                    .frame(maxWidth: 56)
                if habit.streak > 0 {
                    HStack(spacing: 1) {
                        Image(systemName: "flame.fill")
                            .font(.system(size: 7))
                            .foregroundColor(Color(red: 1.00, green: 0.55, blue: 0.20))
                        Text("\(habit.streak)d")
                            .font(.system(size: 8, weight: .heavy, design: .rounded))
                            .foregroundColor(.white.opacity(0.85))
                    }
                } else {
                    Text("start").font(.system(size: 8))
                        .foregroundColor(.white.opacity(0.45))
                }
            }
            .frame(width: 60, height: 56)
            .padding(.horizontal, 4)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(habit.doneToday
                          ? Color(red: 0.18, green: 0.55, blue: 0.32).opacity(hovered ? 0.45 : 0.32)
                          : Color.white.opacity(hovered ? 0.12 : 0.07))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(habit.doneToday
                            ? Color(red: 0.32, green: 0.84, blue: 0.55).opacity(0.5)
                            : Color.white.opacity(0.10),
                            lineWidth: 0.75)
            )
        }
        .buttonStyle(.plain)
        .onHover { hovered = $0 }
        .help(habit.doneToday
              ? "✓ Done today — click to untick"
              : "Tap to mark today done")
        .contextMenu {
            Button("Toggle today") { service.toggleToday(habit) }
            Divider()
            Button("Remove", role: .destructive) { service.remove(habit) }
        }
    }
}
