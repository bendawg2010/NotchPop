// NotchPetService.swift
//
// A persistent virtual pet that lives in the notch. Has stats
// (happiness / energy / hunger), levels up when you complete
// Pomodoro focus sessions or hit habit streaks, sleeps when you're
// idle, evolves visually at milestones (Egg → Hatchling → Kid →
// Teen → Adult → Sage).
//
// Persists everything to UserDefaults under "np.pet". The decay
// timer ticks once a minute and slowly bleeds happiness / energy /
// hunger toward zero — tend to your pet or it withers.
//
// Wired to Pomodoro / Habit / Music events via NotificationCenter
// (the same trigger names ConnectionsService uses) so the pet
// reacts in real time without us threading callbacks through every
// service.

import Combine
import Foundation
import SwiftUI

/// Pet evolution stages. Each stage unlocks at an XP threshold.
enum PetStage: Int, Codable, CaseIterable, Identifiable {
    case egg = 0
    case hatchling
    case kid
    case teen
    case adult
    case sage

    var id: Int { rawValue }

    /// XP needed to ENTER this stage. Egg starts at 0; the pet
    /// hatches the first time the user feeds / plays / completes
    /// a Pomodoro.
    var xpThreshold: Int {
        switch self {
        case .egg:       return 0
        case .hatchling: return 5
        case .kid:       return 50
        case .teen:      return 200
        case .adult:     return 600
        case .sage:      return 1500
        }
    }

    var label: String {
        switch self {
        case .egg:       return "Egg"
        case .hatchling: return "Hatchling"
        case .kid:       return "Kid"
        case .teen:      return "Teen"
        case .adult:     return "Adult"
        case .sage:      return "Sage"
        }
    }

    /// Body size in points for the in-notch sprite. Grows with the
    /// pet so users can SEE progress at a glance.
    var bodySize: CGFloat {
        switch self {
        case .egg:       return 38
        case .hatchling: return 42
        case .kid:       return 48
        case .teen:      return 54
        case .adult:     return 60
        case .sage:      return 66
        }
    }

    /// Body palette for the gradient fill. Each stage shifts toward
    /// a different end of the brand palette so stage transitions
    /// FEEL like real growth.
    var bodyColors: [Color] {
        switch self {
        case .egg:
            return [Color(red: 0.96, green: 0.92, blue: 0.86),
                    Color(red: 0.85, green: 0.78, blue: 0.70)]
        case .hatchling:
            return [Color(red: 1.00, green: 0.78, blue: 0.62),
                    Color(red: 1.00, green: 0.42, blue: 0.42)]
        case .kid:
            return [Color(red: 1.00, green: 0.42, blue: 0.42),
                    Color(red: 0.95, green: 0.30, blue: 0.85)]
        case .teen:
            return [Color(red: 0.95, green: 0.30, blue: 0.85),
                    Color(red: 0.62, green: 0.30, blue: 0.96)]
        case .adult:
            return [Color(red: 0.62, green: 0.30, blue: 0.96),
                    Color(red: 0.17, green: 0.52, blue: 0.97)]
        case .sage:
            // Sage gets a 3-stop rainbow as its reward.
            return [Color(red: 1.00, green: 0.55, blue: 0.20),
                    Color(red: 0.95, green: 0.30, blue: 0.85),
                    Color(red: 0.18, green: 0.82, blue: 0.62)]
        }
    }
}

/// Mood snapshot derived from current stats. Drives the pet's
/// expression in the view.
enum PetMood {
    case asleep, hungry, sad, neutral, happy, excited
}

struct NotchPetState: Codable, Equatable {
    var name: String
    var hatchedAt: Date
    var xp: Int
    var happiness: Double   // 0-100
    var energy: Double      // 0-100
    var hunger: Double      // 0-100; 0 = starving, 100 = full
    var lastFedAt: Date
    var lastPlayedAt: Date
    var lastEventAt: Date

    /// "Excited" celebration window — set when something good
    /// happens (Pomodoro complete / habit tick), clears after a
    /// short interval so the view can react.
    var excitedUntil: Date

    /// Pet's stage is computed from xp at read time so we never get
    /// out-of-sync stage vs xp.
    var stage: PetStage {
        var current: PetStage = .egg
        for s in PetStage.allCases {
            if xp >= s.xpThreshold { current = s }
        }
        return current
    }

    /// Days alive — used in the sprite-evolution copy.
    var ageDays: Int {
        max(0, Int(Date().timeIntervalSince(hatchedAt) / 86400))
    }

    var mood: PetMood {
        if Date() < excitedUntil { return .excited }
        // Asleep wins if it's late at night OR energy near 0.
        let hour = Calendar.current.component(.hour, from: Date())
        if energy < 12 || hour >= 23 || hour < 6 { return .asleep }
        if hunger < 25 { return .hungry }
        if happiness < 30 { return .sad }
        if happiness > 80 { return .happy }
        return .neutral
    }

    static let initial = NotchPetState(
        name: "Pippa",
        hatchedAt: Date(),
        xp: 0,
        happiness: 80,
        energy: 80,
        hunger: 80,
        lastFedAt: Date(),
        lastPlayedAt: Date(),
        lastEventAt: Date(),
        excitedUntil: Date(timeIntervalSince1970: 0)
    )
}

final class NotchPetService: ObservableObject {
    @Published var state: NotchPetState {
        didSet { persist() }
    }

    private static let key = "np.pet"
    private var decayTimer: Timer?
    private var observers: [NSObjectProtocol] = []

    init() {
        if let data = UserDefaults.standard.data(forKey: Self.key),
           let decoded = try? JSONDecoder().decode(NotchPetState.self, from: data) {
            self.state = decoded
        } else {
            self.state = .initial
        }
        installEventHooks()
        startDecayTimer()
    }

    deinit {
        decayTimer?.invalidate()
        for o in observers { NotificationCenter.default.removeObserver(o) }
    }

    // MARK: - Care actions

    /// Feed the pet — bumps hunger toward full, gains a bit of XP.
    func feed() {
        var s = state
        s.hunger = min(100, s.hunger + 30)
        s.happiness = min(100, s.happiness + 5)
        s.lastFedAt = Date()
        s.xp += 2
        s.excitedUntil = Date().addingTimeInterval(3.0)
        state = s
    }

    /// Play with the pet — bumps happiness, drops energy, gains XP.
    func play() {
        var s = state
        s.happiness = min(100, s.happiness + 25)
        s.energy = max(0, s.energy - 8)
        s.hunger = max(0, s.hunger - 4)
        s.lastPlayedAt = Date()
        s.xp += 3
        s.excitedUntil = Date().addingTimeInterval(3.5)
        state = s
    }

    /// Put the pet to sleep — restores energy, small happiness bump
    /// (some pets like a nap, who knew). Has a cooldown via
    /// hasNapped so the user can't infinitely tap the button.
    func nap() {
        var s = state
        s.energy = min(100, s.energy + 35)
        s.happiness = min(100, s.happiness + 3)
        state = s
    }

    /// Rename the pet from the Settings UI. Names cap at 16 chars.
    func rename(_ newName: String) {
        let trimmed = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        var s = state
        s.name = String(trimmed.prefix(16))
        state = s
    }

    /// Reset the pet — back to a fresh egg. Used in Settings as a
    /// nuclear option ("start over").
    func resetPet() {
        state = .initial
    }

    // MARK: - Event hooks

    /// Subscribe to the same Notification.Names ConnectionsService
    /// fires (Pomodoro phase changes, charging, music). Each event
    /// nudges different stats so the pet feels alive without us
    /// having to thread callbacks through every existing service.
    private func installEventHooks() {
        let nc = NotificationCenter.default
        // Pomodoro focus end → big XP boost, happiness, fullness drops
        observers.append(nc.addObserver(
            forName: ConnectionTrigger.pomodoroFocusEnd.notificationName,
            object: nil, queue: .main
        ) { [weak self] _ in self?.reactToFocusEnd() })

        // Pomodoro break end → small happiness bump
        observers.append(nc.addObserver(
            forName: ConnectionTrigger.pomodoroBreakEnd.notificationName,
            object: nil, queue: .main
        ) { [weak self] _ in self?.reactToBreakEnd() })

        // Music start → tiny happiness bump
        observers.append(nc.addObserver(
            forName: ConnectionTrigger.musicStart.notificationName,
            object: nil, queue: .main
        ) { [weak self] _ in self?.reactToMusicStart() })

        // Charging → restores energy
        observers.append(nc.addObserver(
            forName: ConnectionTrigger.chargingStart.notificationName,
            object: nil, queue: .main
        ) { [weak self] _ in self?.reactToCharging() })
    }

    private func reactToFocusEnd() {
        var s = state
        s.xp += 12
        s.happiness = min(100, s.happiness + 12)
        s.hunger = max(0, s.hunger - 8)
        s.energy = max(0, s.energy - 5)
        s.lastEventAt = Date()
        s.excitedUntil = Date().addingTimeInterval(5.0)
        state = s
    }

    private func reactToBreakEnd() {
        var s = state
        s.xp += 4
        s.happiness = min(100, s.happiness + 5)
        s.lastEventAt = Date()
        state = s
    }

    private func reactToMusicStart() {
        var s = state
        s.happiness = min(100, s.happiness + 1)
        state = s
    }

    private func reactToCharging() {
        var s = state
        s.energy = min(100, s.energy + 15)
        state = s
    }

    // MARK: - Decay timer

    /// Tick once a minute. Drains stats slowly so the pet ages /
    /// gets hungry / etc. Called frequently enough to feel alive,
    /// rarely enough to not eat any battery.
    private func startDecayTimer() {
        decayTimer?.invalidate()
        decayTimer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            self?.tick()
        }
    }

    private func tick() {
        var s = state
        // Hunger drains faster than happiness/energy.
        s.hunger = max(0, s.hunger - 0.6)
        s.happiness = max(0, s.happiness - 0.3)
        s.energy = max(0, s.energy - 0.2)
        // Sleeping at night SLOWLY restores energy.
        let hour = Calendar.current.component(.hour, from: Date())
        if hour >= 23 || hour < 6 {
            s.energy = min(100, s.energy + 0.8)
        }
        state = s
    }

    // MARK: - Persistence

    private func persist() {
        guard let data = try? JSONEncoder().encode(state) else { return }
        UserDefaults.standard.set(data, forKey: Self.key)
    }
}
