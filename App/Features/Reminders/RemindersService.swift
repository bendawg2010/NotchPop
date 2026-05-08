// RemindersService.swift
//
// Tiny local-only TODO list. Distinct from the system Reminders.app —
// this is a quick scratch checklist for things you want to bang out
// today. Persists to UserDefaults under "np.reminders" as JSON. No
// EventKit, no calendar integration, no notifications: just a list
// of strings + completion state.

import Foundation
import SwiftUI

struct ReminderItem: Identifiable, Codable, Equatable {
    let id: UUID
    var text: String
    var done: Bool
    let createdAt: Date

    init(id: UUID = UUID(), text: String, done: Bool = false, createdAt: Date = Date()) {
        self.id = id
        self.text = text
        self.done = done
        self.createdAt = createdAt
    }
}

final class RemindersService: ObservableObject {
    @Published var items: [ReminderItem] = [] {
        didSet { persist() }
    }
    private static let key = "np.reminders"

    init() {
        if let data = UserDefaults.standard.data(forKey: Self.key),
           let decoded = try? JSONDecoder().decode([ReminderItem].self, from: data) {
            self.items = decoded
        }
    }

    func add(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        items.insert(ReminderItem(text: trimmed), at: 0)
    }

    func toggle(_ item: ReminderItem) {
        guard let i = items.firstIndex(where: { $0.id == item.id }) else { return }
        items[i].done.toggle()
    }

    func remove(_ item: ReminderItem) {
        items.removeAll { $0.id == item.id }
    }

    func clearDone() {
        items.removeAll { $0.done }
    }

    private func persist() {
        guard let data = try? JSONEncoder().encode(items) else { return }
        UserDefaults.standard.set(data, forKey: Self.key)
    }
}
