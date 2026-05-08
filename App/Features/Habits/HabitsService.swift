// HabitsService.swift
//
// Daily-checkbox habit tracker with streaks. Each habit has:
//   • title
//   • emoji  (optional, default 🟦)
//   • lastCompletedDay (yyyy-MM-dd of last tick)
//   • streak (consecutive completed days)
//
// Streak math: when the user ticks today and lastCompletedDay was
// yesterday, streak += 1. If lastCompletedDay was today already,
// no-op. If lastCompletedDay was older than yesterday OR nil,
// streak resets to 1. Untick today → streak -= 1 if it was today,
// else no-op.
//
// Persists to UserDefaults under "np.habits" as JSON.

import Foundation
import SwiftUI

struct Habit: Identifiable, Codable, Equatable {
    let id: UUID
    var title: String
    var emoji: String
    var lastCompletedDay: String?  // yyyy-MM-dd
    var streak: Int

    init(id: UUID = UUID(),
         title: String,
         emoji: String = "🟦",
         lastCompletedDay: String? = nil,
         streak: Int = 0) {
        self.id = id
        self.title = title
        self.emoji = emoji
        self.lastCompletedDay = lastCompletedDay
        self.streak = streak
    }

    var doneToday: Bool {
        lastCompletedDay == HabitsService.todayKey()
    }
}

final class HabitsService: ObservableObject {
    @Published var habits: [Habit] = [] {
        didSet { persist() }
    }
    private static let key = "np.habits"

    init() {
        if let data = UserDefaults.standard.data(forKey: Self.key),
           let decoded = try? JSONDecoder().decode([Habit].self, from: data) {
            self.habits = decoded
        }
    }

    static func todayKey() -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.timeZone = .current
        return f.string(from: Date())
    }

    static func yesterdayKey() -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.timeZone = .current
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: Date()) ?? Date()
        return f.string(from: yesterday)
    }

    func add(title: String, emoji: String = "🟦") {
        let trimmed = title.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        habits.append(Habit(title: trimmed, emoji: emoji))
    }

    func remove(_ habit: Habit) {
        habits.removeAll { $0.id == habit.id }
    }

    /// Toggle today's completion. Adjusts streak appropriately:
    /// • If currently done-today and we untick → streak -= 1, set
    ///   lastCompletedDay back to yesterday's value (or nil).
    /// • If not done-today and we tick → streak follows the
    ///   yesterday-was-completed check.
    func toggleToday(_ habit: Habit) {
        guard let i = habits.firstIndex(where: { $0.id == habit.id }) else { return }
        let today = Self.todayKey()
        let yesterday = Self.yesterdayKey()
        if habits[i].lastCompletedDay == today {
            // Untick today
            habits[i].streak = max(0, habits[i].streak - 1)
            habits[i].lastCompletedDay = habits[i].streak == 0 ? nil : yesterday
        } else {
            // Tick today
            if habits[i].lastCompletedDay == yesterday {
                habits[i].streak += 1
            } else {
                habits[i].streak = 1
            }
            habits[i].lastCompletedDay = today
        }
    }

    private func persist() {
        guard let data = try? JSONEncoder().encode(habits) else { return }
        UserDefaults.standard.set(data, forKey: Self.key)
    }
}
