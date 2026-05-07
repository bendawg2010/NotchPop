// WorldClockService.swift
//
// Owns the user's chosen list of timezones for the World Clock tab.
// Default set: home (current device tz), New York, London, Tokyo —
// the four most-asked-about cities for remote work.
//
// Persists as an array of TimeZone identifiers in UserDefaults so
// reconfigured cities survive across launches.

import Foundation
import Combine

struct ClockEntry: Identifiable, Equatable, Codable {
    var id: String { timezoneIdentifier }
    let timezoneIdentifier: String
    /// Friendly name shown on the clock card. Often the city, but the
    /// user can rename ("Mom" instead of "America/Phoenix").
    var label: String
}

final class WorldClockService: ObservableObject {
    @Published var clocks: [ClockEntry] = [] {
        didSet { persist() }
    }

    init() {
        if let data = UserDefaults.standard.data(forKey: "np.worldClock.clocks"),
           let restored = try? JSONDecoder().decode([ClockEntry].self, from: data),
           !restored.isEmpty {
            self.clocks = restored
        } else {
            // Sensible defaults: local + 3 popular timezones
            self.clocks = [
                ClockEntry(timezoneIdentifier: TimeZone.current.identifier,
                           label: "Home"),
                ClockEntry(timezoneIdentifier: "America/New_York", label: "New York"),
                ClockEntry(timezoneIdentifier: "Europe/London",     label: "London"),
                ClockEntry(timezoneIdentifier: "Asia/Tokyo",        label: "Tokyo"),
            ]
        }
    }

    func add(_ entry: ClockEntry) {
        if !clocks.contains(where: { $0.timezoneIdentifier == entry.timezoneIdentifier }) {
            clocks.append(entry)
        }
    }

    func remove(_ entry: ClockEntry) {
        clocks.removeAll { $0.timezoneIdentifier == entry.timezoneIdentifier }
    }

    func move(from: Int, to: Int) {
        guard from != to, clocks.indices.contains(from), to >= 0, to <= clocks.count else { return }
        let item = clocks.remove(at: from)
        let target = to > from ? to - 1 : to
        clocks.insert(item, at: target)
    }

    private func persist() {
        if let data = try? JSONEncoder().encode(clocks) {
            UserDefaults.standard.set(data, forKey: "np.worldClock.clocks")
        }
    }

    /// Currently-selected list of TimeZone identifiers, sorted into
    /// the categories we need for the city picker (continent → city).
    static var availableTimezones: [String] {
        TimeZone.knownTimeZoneIdentifiers.sorted()
    }
}
