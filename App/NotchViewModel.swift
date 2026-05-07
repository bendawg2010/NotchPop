// NotchViewModel.swift
//
// Centralized state for the notch UI. Owned by AppDelegate, observed
// by every view. Tracks: collapsed/expanded animation state, which
// "tabs" of content to show, file shelf data, screen info.

import AppKit
import Combine
import SwiftUI

/// Tabs / panes shown when the notch is expanded. The user can hide
/// any of these from Settings — `visibleTabs` in NotchViewModel filters
/// the list at render time.
enum NotchTab: String, CaseIterable, Identifiable, Codable {
    case shelf = "Shelf"
    case nowPlaying = "Music"
    case pomodoro = "Pomodoro"
    case battery = "Battery"

    var id: String { rawValue }
    var icon: String {
        switch self {
        case .shelf:      return "tray.full.fill"
        case .nowPlaying: return "music.note"
        case .pomodoro:   return "timer"
        case .battery:    return "battery.100"
        }
    }
    /// Friendly description shown in Settings checkbox rows.
    var blurb: String {
        switch self {
        case .shelf:      return "Drag any file onto the notch — drag it back out anywhere."
        case .nowPlaying: return "Now-playing controls for Apple Music, Spotify, YouTube, and more."
        case .pomodoro:   return "Built-in 25/5 focus timer with running progress on the notch."
        case .battery:    return "Plug-in peek + battery readout."
        }
    }
}

final class NotchViewModel: ObservableObject {
    // MARK: - State
    @Published var expanded: Bool = false
    @Published var hovering: Bool = false
    @Published var activeTab: NotchTab = .shelf
    @Published var screenInfo: ScreenInfo = ScreenHelper.current()

    /// True only during the first-launch welcome peek. When true, the
    /// expanded view shows the welcome card instead of normal tabs.
    @Published var showingWelcome: Bool = false

    // Settings — persisted across launches via UserDefaults.
    @Published var nowPlayingEnabled: Bool = true {
        didSet { UserDefaults.standard.set(nowPlayingEnabled, forKey: "np.nowPlayingEnabled") }
    }
    @Published var chargingEnabled: Bool = true {
        didSet { UserDefaults.standard.set(chargingEnabled, forKey: "np.chargingEnabled") }
    }
    @Published var persistShelfBetweenLaunches: Bool = false {
        didSet { UserDefaults.standard.set(persistShelfBetweenLaunches, forKey: "np.persistShelf") }
    }

    // MARK: - Children
    let shelf = FileShelf()
    let nowPlaying = NowPlayingService()
    let charging = ChargingMonitor()
    let pomodoro = PomodoroService()

    /// User-configurable order + visibility of tabs. Persisted via
    /// UserDefaults so reordering / hiding sticks across launches.
    @Published var visibleTabs: [NotchTab] = NotchTab.allCases {
        didSet {
            let raw = visibleTabs.map { $0.rawValue }
            UserDefaults.standard.set(raw, forKey: "np.visibleTabs")
            // Snap activeTab back into the visible set if needed
            if !visibleTabs.contains(activeTab), let first = visibleTabs.first {
                activeTab = first
            }
        }
    }

    // MARK: - Notify window controller of size changes
    var onSizeChange: (() -> Void)?

    private var bag = Set<AnyCancellable>()

    init() {
        // Restore persisted settings (defaults: true for everything)
        let d = UserDefaults.standard
        if d.object(forKey: "np.nowPlayingEnabled") != nil {
            self.nowPlayingEnabled = d.bool(forKey: "np.nowPlayingEnabled")
        }
        if d.object(forKey: "np.chargingEnabled") != nil {
            self.chargingEnabled = d.bool(forKey: "np.chargingEnabled")
        }
        if d.object(forKey: "np.persistShelf") != nil {
            self.persistShelfBetweenLaunches = d.bool(forKey: "np.persistShelf")
        }
        // Restore tab order/visibility, falling back to defaults if any
        // raw value is unrecognized (e.g. someone downgrading).
        if let saved = d.array(forKey: "np.visibleTabs") as? [String] {
            let restored = saved.compactMap { NotchTab(rawValue: $0) }
            if !restored.isEmpty {
                self.visibleTabs = restored
            }
        }

        // Re-broadcast: any expanded toggle must notify the window
        $expanded
            .removeDuplicates()
            .sink { [weak self] _ in self?.onSizeChange?() }
            .store(in: &bag)

        // Charging events temporarily expand the notch (peek)
        charging.$peeking
            .removeDuplicates()
            .sink { [weak self] peeking in
                guard let self = self else { return }
                if peeking { withAnimation(.spring()) { self.expanded = true } }
            }
            .store(in: &bag)

        // Restore shelf if user opted in
        if persistShelfBetweenLaunches { shelf.restore() }

        // Start services
        nowPlaying.start()
        charging.start()

        // First-launch onboarding: peek the notch open with a welcome
        // card for 5 seconds so the user actually discovers it exists.
        if !UserDefaults.standard.bool(forKey: "np.didFirstLaunch") {
            UserDefaults.standard.set(true, forKey: "np.didFirstLaunch")
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { [weak self] in
                self?.runWelcomePeek()
            }
        }
    }

    private func runWelcomePeek() {
        showingWelcome = true
        withAnimation(.spring(response: 0.45, dampingFraction: 0.78)) {
            expanded = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) { [weak self] in
            guard let self = self else { return }
            self.showingWelcome = false
            if !self.hovering {
                withAnimation(.spring(response: 0.45, dampingFraction: 0.85)) {
                    self.expanded = false
                }
            }
        }
    }

    /// Compact size — just covers the physical notch when collapsed.
    var compactSize: CGSize {
        let info = screenInfo
        let h = max(info.notchHeight, 32)
        let w = max(info.notchWidth, 200)
        return CGSize(width: w, height: h)
    }

    /// Expanded size — wide enough for the file shelf row + tabs.
    /// Height covers: notch top inset (~32) + tabs (26) + spacing (8) +
    /// pane content (88) + bottom padding (16) = ~170pt with breathing.
    var expandedSize: CGSize {
        CGSize(width: 520, height: 178)
    }

    /// What size the host window should currently be.
    var targetSize: CGSize {
        expanded ? expandedSize : compactSize
    }

    func persistShelfIfEnabled() {
        if persistShelfBetweenLaunches { shelf.persist() }
    }
}
