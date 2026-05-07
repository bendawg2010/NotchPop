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
    case stopwatch = "Stopwatch"
    case countdown = "Timer"
    case worldClock = "World Clock"
    case notes = "Notes"
    case battery = "Battery"

    var id: String { rawValue }
    var icon: String {
        switch self {
        case .shelf:      return "tray.full.fill"
        case .nowPlaying: return "music.note"
        case .pomodoro:   return "timer"
        case .stopwatch:  return "stopwatch.fill"
        case .countdown:  return "alarm.fill"
        case .worldClock: return "globe"
        case .notes:      return "note.text"
        case .battery:    return "battery.100"
        }
    }
    /// Friendly description shown in Settings checkbox rows.
    var blurb: String {
        switch self {
        case .shelf:      return "Drag any file onto the notch — drag it back out anywhere."
        case .nowPlaying: return "Now-playing controls for Apple Music, Spotify, YouTube, and more."
        case .pomodoro:   return "Phased focus timer with strict mode + daily goal."
        case .stopwatch:  return "Count-up timer with lap support."
        case .countdown:  return "Quick countdown for cooking, exercise, anything single-shot."
        case .worldClock: return "Up to 4 cities at a glance. Configurable in Settings."
        case .notes:      return "Quick scratchpad. Auto-saves as you type."
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
    /// When true, the notch is completely hidden while any app is in
    /// fullscreen. Most users want this on for movies / games.
    @Published var hideInFullscreen: Bool = true {
        didSet { UserDefaults.standard.set(hideInFullscreen, forKey: "np.hideInFullscreen") }
    }
    /// Hover-to-expand delay (seconds). 0 = instant, 0.3 = relaxed.
    @Published var hoverDelay: Double = 0.0 {
        didSet { UserDefaults.standard.set(hoverDelay, forKey: "np.hoverDelay") }
    }
    /// Mouse-out collapse delay (seconds). Grace period for darting in/out.
    @Published var collapseDelay: Double = 0.18 {
        didSet { UserDefaults.standard.set(collapseDelay, forKey: "np.collapseDelay") }
    }
    /// Master sound-effects toggle (charging chime, pomodoro alarm, etc.)
    @Published var soundEffectsEnabled: Bool = true {
        didSet { UserDefaults.standard.set(soundEffectsEnabled, forKey: "np.sound") }
    }
    /// Auto-show pomodoro tab when timer starts.
    @Published var pomodoroFollowsActive: Bool = true {
        didSet { UserDefaults.standard.set(pomodoroFollowsActive, forKey: "np.pomFollows") }
    }
    @Published var launchAtLogin: Bool = LaunchAtLogin.isEnabled {
        didSet { LaunchAtLogin.setEnabled(launchAtLogin) }
    }
    /// Notch fit overrides — most users want the auto-detected hardware
    /// match, but if your MBP model has slightly different dimensions
    /// (or you're on a non-notch Mac and want a custom-sized pill),
    /// these sliders let you nudge the rendered shape ±10pt to make
    /// it disappear into the bezel.
    @Published var notchWidthOffset: Double = 0 {
        didSet { UserDefaults.standard.set(notchWidthOffset, forKey: "np.notchWidthOff"); onSizeChange?() }
    }
    @Published var notchHeightExtension: Double = 0 {
        didSet { UserDefaults.standard.set(notchHeightExtension, forKey: "np.notchHeightExt"); onSizeChange?() }
    }
    @Published var notchCornerRadiusOverride: Double = 0 {
        // 0 = use auto-detected hardware value (8.5). Positive = override.
        didSet { UserDefaults.standard.set(notchCornerRadiusOverride, forKey: "np.notchRadius") }
    }

    // MARK: - Children
    let shelf = FileShelf()
    let nowPlaying = NowPlayingService()
    let charging = ChargingMonitor()
    let pomodoro = PomodoroService()
    let stopwatch = StopwatchService()
    let countdown = CountdownTimerService()
    let worldClock = WorldClockService()
    let notes = NotesService()
    let fullscreen = FullscreenWatcher()

    /// User-configurable order + visibility of tabs. Persisted via
    /// UserDefaults so reordering / hiding sticks across launches.
    /// Default = the original five (Shelf / Music / Pomodoro / Notes
    /// / Battery). Stopwatch / Timer / World Clock are opt-in via
    /// Settings → Tabs to keep the tab bar readable for new users.
    @Published var visibleTabs: [NotchTab] = [.shelf, .nowPlaying, .pomodoro, .notes, .battery] {
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
        if d.object(forKey: "np.hideInFullscreen") != nil {
            self.hideInFullscreen = d.bool(forKey: "np.hideInFullscreen")
        }
        if d.object(forKey: "np.hoverDelay") != nil {
            self.hoverDelay = d.double(forKey: "np.hoverDelay")
        }
        if d.object(forKey: "np.collapseDelay") != nil {
            let v = d.double(forKey: "np.collapseDelay")
            self.collapseDelay = v > 0 ? v : 0.18
        }
        if d.object(forKey: "np.sound") != nil {
            self.soundEffectsEnabled = d.bool(forKey: "np.sound")
        }
        if d.object(forKey: "np.pomFollows") != nil {
            self.pomodoroFollowsActive = d.bool(forKey: "np.pomFollows")
        }
        self.notchWidthOffset = d.double(forKey: "np.notchWidthOff")
        self.notchHeightExtension = d.double(forKey: "np.notchHeightExt")
        self.notchCornerRadiusOverride = d.double(forKey: "np.notchRadius")
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
        fullscreen.start()

        // Auto-switch to Pomodoro tab whenever the timer starts running
        // (only if pomodoroFollowsActive is on AND the tab is visible).
        pomodoro.$running
            .removeDuplicates()
            .sink { [weak self] running in
                guard let self = self, self.pomodoroFollowsActive, running else { return }
                if self.visibleTabs.contains(.pomodoro) {
                    self.activeTab = .pomodoro
                }
            }
            .store(in: &bag)

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

    /// Compact size — EXACTLY matches the hardware notch dimensions
    /// so the drawn shape is invisible against the physical cutout.
    /// User can nudge ±10pt via Settings → Behavior → Notch fit if
    /// their specific MBP doesn't quite hit auto-detected values.
    /// On non-notch Macs, fall back to a tasteful 200×32 pill.
    var compactSize: CGSize {
        let info = screenInfo
        if info.hasNotch {
            return CGSize(
                width:  max(40, info.notchWidth + notchWidthOffset),
                height: max(20, info.notchHeight + notchHeightExtension)
            )
        }
        return CGSize(
            width:  max(40, 200 + notchWidthOffset),
            height: max(20, 32 + notchHeightExtension)
        )
    }

    /// Corner radius for the COLLAPSED notch shape. 0 in the override
    /// means "use auto-detected", anything else is an explicit user
    /// pick (typically 6-12pt for fine-tuning blend with the hardware).
    var compactCornerRadius: CGFloat {
        if notchCornerRadiusOverride > 0 {
            return CGFloat(notchCornerRadiusOverride)
        }
        return screenInfo.notchCornerRadius
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
