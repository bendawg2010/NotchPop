// NotchViewModel.swift
//
// Centralized state for the notch UI. Owned by AppDelegate, observed
// by every view. Tracks: collapsed/expanded animation state, which
// "tabs" of content to show, file shelf data, screen info.

import AppKit
import Combine
import SwiftUI

extension Notification.Name {
    /// Posted when the user toggles the "Show menubar icon" setting.
    /// AppDelegate listens and hides/restores its NSStatusItem.
    static let npMenubarVisibilityChanged = Notification.Name("np.menubarVisibilityChanged")
}

/// User-pickable accent for gradients and primary buttons. We keep
/// the existing pink→blue brand gradient as the default but let users
/// swap to a single solid accent if they prefer something quieter.
/// Each case provides .startColor + .endColor (which collapse to the
/// same color for solid choices), so consumers can use a single
/// LinearGradient(colors:) call regardless of solid-vs-gradient.
enum AccentChoice: String, CaseIterable, Identifiable, Codable {
    case pinkBlue   // brand gradient (default)
    case pink
    case blue
    case purple
    case mint
    case orange
    case graphite

    var id: String { rawValue }

    var label: String {
        switch self {
        case .pinkBlue: return "Pink → Blue (brand)"
        case .pink:     return "Pink"
        case .blue:     return "Blue"
        case .purple:   return "Purple"
        case .mint:     return "Mint"
        case .orange:   return "Orange"
        case .graphite: return "Graphite"
        }
    }

    var startColor: Color {
        switch self {
        case .pinkBlue, .pink: return Color(red: 1.00, green: 0.24, blue: 0.67)
        case .blue:            return Color(red: 0.17, green: 0.52, blue: 0.97)
        case .purple:          return Color(red: 0.62, green: 0.30, blue: 0.96)
        case .mint:            return Color(red: 0.18, green: 0.82, blue: 0.62)
        case .orange:          return Color(red: 1.00, green: 0.52, blue: 0.20)
        case .graphite:        return Color(red: 0.55, green: 0.58, blue: 0.65)
        }
    }
    var endColor: Color {
        switch self {
        case .pinkBlue:        return Color(red: 0.17, green: 0.52, blue: 0.77)
        case .pink:            return Color(red: 1.00, green: 0.24, blue: 0.67)
        case .blue:            return Color(red: 0.17, green: 0.52, blue: 0.97)
        case .purple:          return Color(red: 0.62, green: 0.30, blue: 0.96)
        case .mint:            return Color(red: 0.18, green: 0.82, blue: 0.62)
        case .orange:          return Color(red: 1.00, green: 0.52, blue: 0.20)
        case .graphite:        return Color(red: 0.55, green: 0.58, blue: 0.65)
        }
    }
}

/// Tabs / panes shown when the notch is expanded. The user can hide
/// any of these from Settings — `visibleTabs` in NotchViewModel filters
/// the list at render time.
///
/// Battery used to be its own tab, but per user feedback it's now an
/// inline indicator in the top-right of the expanded notch (always
/// visible). The .battery case is gone; existing users who had it in
/// their saved visibleTabs get it filtered out at restore time.
enum NotchTab: String, CaseIterable, Identifiable, Codable {
    case shelf = "Shelf"
    case nowPlaying = "Music"
    case pomodoro = "Pomodoro"
    case timers = "Timers"      // combined Stopwatch + Countdown
    case worldClock = "World Clock"
    case notes = "Notes"
    case clipboard = "Clipboard"
    case systemStats = "System"
    case calendar = "Calendar"
    case airpods = "AirPods"
    case quickActions = "Quick Actions"
    case weather = "Weather"

    var id: String { rawValue }
    var icon: String {
        switch self {
        case .shelf:        return "tray.full.fill"
        case .nowPlaying:   return "music.note"
        case .pomodoro:     return "timer"
        case .timers:       return "stopwatch.fill"
        case .worldClock:   return "globe"
        case .notes:        return "note.text"
        case .clipboard:    return "doc.on.clipboard.fill"
        case .systemStats:  return "cpu"
        case .calendar:     return "calendar"
        case .airpods:      return "airpods.gen2"
        case .quickActions: return "bolt.fill"
        case .weather:      return "cloud.sun.fill"
        }
    }
    /// Friendly description shown in Settings checkbox rows.
    var blurb: String {
        switch self {
        case .shelf:        return "Drag any file onto the notch — drag it back out anywhere."
        case .nowPlaying:   return "Apple Music / Spotify track info + transport controls."
        case .pomodoro:     return "Phased focus timer with strict mode + daily goal."
        case .timers:       return "Stopwatch and quick countdown timer in one tab."
        case .worldClock:   return "Up to 4 cities at a glance. Configurable in Settings."
        case .notes:        return "Quick scratchpad. Auto-saves as you type."
        case .clipboard:    return "Last 12 things you copied — click any to paste it back."
        case .systemStats:  return "Live CPU + RAM gauges so you can spot a runaway process."
        case .calendar:     return "Today's next events, pulled from macOS Calendar via EventKit."
        case .airpods:      return "Battery levels for connected AirPods — left, right, and case."
        case .quickActions: return "Lock screen, sleep displays, screenshot, Mission Control — fast."
        case .weather:      return "Live conditions from Open-Meteo. Free, no API key. °F / °C."
        }
    }
}

final class NotchViewModel: ObservableObject {
    // MARK: - State
    @Published var expanded: Bool = false
    @Published var hovering: Bool = false
    @Published var activeTab: NotchTab = .nowPlaying
    @Published var screenInfo: ScreenInfo = ScreenHelper.current()

    /// Which tab the notch shows when first expanded each session.
    /// User-configurable in Settings → Behavior. Per user feedback,
    /// default is now Music instead of Shelf — most people expand the
    /// notch to glance at music or a timer; the shelf only matters
    /// when actively dragging a file (which auto-switches to it).
    @Published var defaultTab: NotchTab = .nowPlaying {
        didSet {
            UserDefaults.standard.set(defaultTab.rawValue, forKey: "np.defaultTab")
        }
    }

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
    /// Which named system sound the timers play when they end. Set of
    /// choices lives in TimerSound.choices. "Glass" by default — same
    /// chime as macOS's built-in Calendar alerts.
    @Published var timerSoundName: String = "Glass" {
        didSet { UserDefaults.standard.set(timerSoundName, forKey: "np.timerSoundName") }
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
    /// Show iPhone-Dynamic-Island-style live activities flanking the
    /// collapsed notch — track info on the right, running timer on
    /// the left. Tap either to expand the notch + jump to that tab.
    @Published var liveActivitiesEnabled: Bool = true {
        didSet {
            UserDefaults.standard.set(liveActivitiesEnabled, forKey: "np.liveActivities")
            onSizeChange?()
        }
    }

    // MARK: - Appearance

    /// Brand-accent color for buttons, gradients, ring strokes. Default
    /// "pink-to-blue" matches NotchPop's pink/blue gradient. Users can
    /// pick a single solid accent if they prefer a less colorful UI.
    @Published var accentChoice: AccentChoice = .pinkBlue {
        didSet { UserDefaults.standard.set(accentChoice.rawValue, forKey: "np.accent") }
    }
    /// 24-hour vs 12-hour time format. Affects World Clock, system
    /// time displays, and any other "what time is it" rendering.
    /// Default = 24h (matches the prior hardcoded HH:mm format).
    @Published var clockUses24Hour: Bool = true {
        didSet { UserDefaults.standard.set(clockUses24Hour, forKey: "np.clock24h") }
    }
    /// Show seconds in clock displays. Off by default (cleaner).
    @Published var clockShowsSeconds: Bool = false {
        didSet { UserDefaults.standard.set(clockShowsSeconds, forKey: "np.clockSec") }
    }
    /// Reduce motion: kills welcome animation, gradient ring rotation,
    /// and any other purely-decorative animation. Useful for users with
    /// vestibular sensitivity or a low-power Mac.
    @Published var reducedMotion: Bool = false {
        didSet { UserDefaults.standard.set(reducedMotion, forKey: "np.reduceMotion") }
    }
    /// When dragging a file near the notch, auto-expand to the file
    /// shelf even before the user has actually hovered. ON by default
    /// because it makes the drop target much easier to hit.
    @Published var expandOnDragHover: Bool = true {
        didSet { UserDefaults.standard.set(expandOnDragHover, forKey: "np.dragExpand") }
    }
    /// Click outside the expanded notch to collapse it. ON by default;
    /// users who prefer "hover only" behavior can turn this off.
    @Published var clickOutsideToCollapse: Bool = true {
        didSet { UserDefaults.standard.set(clickOutsideToCollapse, forKey: "np.clickOutside") }
    }
    /// Force every tab to always show its label, even when there are
    /// many tabs visible (which would normally truncate). Off = the
    /// adaptive icon-only-with-active-label behavior introduced in
    /// v1.5.17. On = labels always shown — text MAY truncate on
    /// 14" MBPs with all 12 tabs enabled.
    @Published var alwaysShowTabLabels: Bool = false {
        didSet { UserDefaults.standard.set(alwaysShowTabLabels, forKey: "np.alwaysLabels") }
    }
    /// When true, picking a tab from the tab bar collapses the notch
    /// after a short beat. Useful for the "glance and go" workflow.
    @Published var autoCollapseAfterTabSelect: Bool = false {
        didSet { UserDefaults.standard.set(autoCollapseAfterTabSelect, forKey: "np.autoCollapseAfterTab") }
    }
    /// How many seconds the welcome peek stays open. Default 5.5 to
    /// match the 3 × 1.5s scene cycle plus breathing room. Bound 3–12.
    @Published var welcomePeekDuration: Double = 5.5 {
        didSet { UserDefaults.standard.set(welcomePeekDuration, forKey: "np.welcomeDur") }
    }
    /// Show the menubar icon. Off = no icon (relies on auto-launch +
    /// the notch itself for app interaction). Settings can be
    /// reached by replaying the welcome → gear from the expanded
    /// notch, or by relaunching the app.
    @Published var showMenuBarIcon: Bool = true {
        didSet {
            UserDefaults.standard.set(showMenuBarIcon, forKey: "np.menubar")
            NotificationCenter.default.post(name: .npMenubarVisibilityChanged, object: nil)
        }
    }
    /// Show the inline battery indicator in the top-right of the
    /// expanded notch. Off = hidden (some users find it cluttered).
    @Published var showInlineBattery: Bool = true {
        didSet { UserDefaults.standard.set(showInlineBattery, forKey: "np.inlineBattery") }
    }
    /// Show the inline version stamp in the top-right of the expanded
    /// notch. Off = cleaner look.
    @Published var showVersionLabel: Bool = true {
        didSet { UserDefaults.standard.set(showVersionLabel, forKey: "np.versionLabel") }
    }
    /// Auto-show the notch peek when charging starts. Some users find
    /// the charging cheer animation distracting; this lets them
    /// disable it without losing the charging-state telemetry
    /// elsewhere.
    @Published var chargingPeekEnabled: Bool = true {
        didSet { UserDefaults.standard.set(chargingPeekEnabled, forKey: "np.chargingPeek") }
    }
    /// Show the timer live-activity pill at all (separate from music).
    /// Off = even if a Pomodoro/Countdown is running, no flanking pill
    /// appears. Useful if you find the running timer distracting but
    /// still want music live activity.
    @Published var timerLiveActivityEnabled: Bool = true {
        didSet {
            UserDefaults.standard.set(timerLiveActivityEnabled, forKey: "np.timerLiveAct")
            onSizeChange?()
        }
    }
    /// Show the music live-activity pill at all (separate from timer).
    @Published var musicLiveActivityEnabled: Bool = true {
        didSet {
            UserDefaults.standard.set(musicLiveActivityEnabled, forKey: "np.musicLiveAct")
            onSizeChange?()
        }
    }
    // Note: end-of-timer sound is gated by `soundEffectsEnabled`
    // (key "np.sound") which TimerSound.play() reads directly. We
    // expose that toggle from both Behavior and Pomodoro sections so
    // users can find it from either place.

    // MARK: - Music

    /// Show album artwork on the LEFT of the live activity pill.
    /// Off = falls back to a generic music.note glyph (privacy mode).
    @Published var liveActivityShowsArtwork: Bool = true {
        didSet { UserDefaults.standard.set(liveActivityShowsArtwork, forKey: "np.liveArt") }
    }
    /// Marquee scroll speed for long track titles in the Music pane.
    /// Range 10–80 px/s. Default 30 ≈ 2.5 chars/sec at body size.
    @Published var marqueeSpeed: Double = 30 {
        didSet { UserDefaults.standard.set(marqueeSpeed, forKey: "np.marqueeSpeed") }
    }
    /// How often to poll the music app for state changes (mostly used
    /// for Apple Music since Spotify pushes via DistributedNotification).
    /// Range 1–10s.
    @Published var musicPollInterval: Double = 5 {
        didSet { UserDefaults.standard.set(musicPollInterval, forKey: "np.musicPoll") }
    }

    // MARK: - File shelf

    /// Maximum number of files allowed in the shelf at once. Older
    /// drops are evicted FIFO when the count would exceed this.
    @Published var shelfMaxItems: Int = 25 {
        didSet { UserDefaults.standard.set(shelfMaxItems, forKey: "np.shelfMax") }
    }
    /// Show file-icon thumbnails in the shelf cards.
    @Published var shelfShowsThumbnails: Bool = true {
        didSet { UserDefaults.standard.set(shelfShowsThumbnails, forKey: "np.shelfThumbs") }
    }
    /// Single-click action: 0 = open in default app, 1 = reveal in Finder.
    @Published var shelfClickAction: Int = 0 {
        didSet { UserDefaults.standard.set(shelfClickAction, forKey: "np.shelfClick") }
    }

    // MARK: - Calendar

    /// How many upcoming events to render in the Calendar tab. 1–10.
    @Published var calendarEventCount: Int = 4 {
        didSet { UserDefaults.standard.set(calendarEventCount, forKey: "np.calCount") }
    }
    /// Time-range filter for the Calendar tab.
    /// 0 = today, 1 = next 24h (rolling), 2 = next 7 days.
    @Published var calendarTimeRange: Int = 1 {
        didSet { UserDefaults.standard.set(calendarTimeRange, forKey: "np.calRange") }
    }
    /// Skip all-day events (for users whose calendars are clogged with
    /// "Out of Office" / birthdays / etc).
    @Published var calendarHidesAllDay: Bool = false {
        didSet { UserDefaults.standard.set(calendarHidesAllDay, forKey: "np.calNoAllDay") }
    }

    // MARK: - Weather

    /// Refresh interval in minutes. Range 5–120.
    @Published var weatherRefreshMinutes: Int = 15 {
        didSet { UserDefaults.standard.set(weatherRefreshMinutes, forKey: "np.weatherRefresh") }
    }
    /// Show wind-speed line in the Weather pane footer.
    @Published var weatherShowsWind: Bool = true {
        didSet { UserDefaults.standard.set(weatherShowsWind, forKey: "np.weatherWind") }
    }

    // MARK: - Notes

    /// Body font size for the Notes scratchpad. 10–22pt.
    @Published var notesFontSize: Double = 14 {
        didSet { UserDefaults.standard.set(notesFontSize, forKey: "np.notesFont") }
    }
    /// Use a monospaced font in Notes. Off = system default.
    @Published var notesMonospaced: Bool = false {
        didSet { UserDefaults.standard.set(notesMonospaced, forKey: "np.notesMono") }
    }

    // MARK: - Clipboard

    /// Number of clipboard entries to remember. 5–50.
    @Published var clipboardMax: Int = 12 {
        didSet { UserDefaults.standard.set(clipboardMax, forKey: "np.clipMax") }
    }

    // MARK: - Animation speed

    /// Global animation speed multiplier. 0.5 = half-speed (snappier),
    /// 1.0 = default, 2.0 = slow-mo demo. Applied as a divisor on
    /// spring response durations throughout the app.
    @Published var animationSpeed: Double = 1.0 {
        didSet { UserDefaults.standard.set(animationSpeed, forKey: "np.animSpeed") }
    }

    // MARK: - Quiet hours

    /// When true, NotchPop suppresses welcome peeks, charging peeks,
    /// and live-activity expansions during quietHoursStart…quietHoursEnd.
    /// Hours are LOCAL HOURS (0–23) — wraparound supported (e.g. 22 to 7
    /// = "10pm to 7am").
    @Published var quietHoursEnabled: Bool = false {
        didSet { UserDefaults.standard.set(quietHoursEnabled, forKey: "np.quiet") }
    }
    @Published var quietHoursStart: Int = 22 {
        didSet { UserDefaults.standard.set(quietHoursStart, forKey: "np.quietStart") }
    }
    @Published var quietHoursEnd: Int = 7 {
        didSet { UserDefaults.standard.set(quietHoursEnd, forKey: "np.quietEnd") }
    }

    /// True when the local clock is currently inside the user's quiet
    /// hours window. Wraparound (start > end) is treated as crossing
    /// midnight.
    var inQuietHours: Bool {
        guard quietHoursEnabled else { return false }
        let h = Calendar.current.component(.hour, from: Date())
        if quietHoursStart == quietHoursEnd { return false }
        if quietHoursStart < quietHoursEnd {
            return h >= quietHoursStart && h < quietHoursEnd
        }
        // Wraps midnight (e.g. 22..7 = 22,23,0..6)
        return h >= quietHoursStart || h < quietHoursEnd
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
    let clipboard = ClipboardService()
    let systemStats = SystemStatsService()
    let calendar = CalendarService()
    let airpods = AirPodsService()
    let weather = WeatherService()
    let fullscreen = FullscreenWatcher()

    /// User-configurable order + visibility of tabs. Persisted via
    /// UserDefaults so reordering / hiding sticks across launches.
    /// Default = Music / Pomodoro / Timers / Notes / Shelf — the order
    /// puts the most-used widgets first and Shelf last (it auto-shows
    /// when the user drags a file in anyway).
    @Published var visibleTabs: [NotchTab] = [.nowPlaying, .pomodoro, .timers, .notes, .shelf] {
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
        if let saved = d.string(forKey: "np.timerSoundName"),
           TimerSound.choices.contains(saved) {
            self.timerSoundName = saved
        }
        if d.object(forKey: "np.pomFollows") != nil {
            self.pomodoroFollowsActive = d.bool(forKey: "np.pomFollows")
        }
        self.notchWidthOffset = d.double(forKey: "np.notchWidthOff")
        self.notchHeightExtension = d.double(forKey: "np.notchHeightExt")
        self.notchCornerRadiusOverride = d.double(forKey: "np.notchRadius")
        if d.object(forKey: "np.liveActivities") != nil {
            self.liveActivitiesEnabled = d.bool(forKey: "np.liveActivities")
        }
        // Appearance settings
        if let raw = d.string(forKey: "np.accent"),
           let parsed = AccentChoice(rawValue: raw) {
            self.accentChoice = parsed
        }
        if d.object(forKey: "np.clock24h") != nil {
            self.clockUses24Hour = d.bool(forKey: "np.clock24h")
        }
        if d.object(forKey: "np.clockSec") != nil {
            self.clockShowsSeconds = d.bool(forKey: "np.clockSec")
        }
        if d.object(forKey: "np.reduceMotion") != nil {
            self.reducedMotion = d.bool(forKey: "np.reduceMotion")
        }
        if d.object(forKey: "np.dragExpand") != nil {
            self.expandOnDragHover = d.bool(forKey: "np.dragExpand")
        }
        if d.object(forKey: "np.clickOutside") != nil {
            self.clickOutsideToCollapse = d.bool(forKey: "np.clickOutside")
        }
        if d.object(forKey: "np.alwaysLabels") != nil {
            self.alwaysShowTabLabels = d.bool(forKey: "np.alwaysLabels")
        }
        if d.object(forKey: "np.autoCollapseAfterTab") != nil {
            self.autoCollapseAfterTabSelect = d.bool(forKey: "np.autoCollapseAfterTab")
        }
        if d.object(forKey: "np.welcomeDur") != nil {
            let v = d.double(forKey: "np.welcomeDur")
            self.welcomePeekDuration = v >= 3 && v <= 12 ? v : 5.5
        }
        if d.object(forKey: "np.menubar") != nil {
            self.showMenuBarIcon = d.bool(forKey: "np.menubar")
        }
        if d.object(forKey: "np.inlineBattery") != nil {
            self.showInlineBattery = d.bool(forKey: "np.inlineBattery")
        }
        if d.object(forKey: "np.versionLabel") != nil {
            self.showVersionLabel = d.bool(forKey: "np.versionLabel")
        }
        if d.object(forKey: "np.chargingPeek") != nil {
            self.chargingPeekEnabled = d.bool(forKey: "np.chargingPeek")
        }
        if d.object(forKey: "np.timerLiveAct") != nil {
            self.timerLiveActivityEnabled = d.bool(forKey: "np.timerLiveAct")
        }
        if d.object(forKey: "np.musicLiveAct") != nil {
            self.musicLiveActivityEnabled = d.bool(forKey: "np.musicLiveAct")
        }
        // Music
        if d.object(forKey: "np.liveArt") != nil {
            self.liveActivityShowsArtwork = d.bool(forKey: "np.liveArt")
        }
        if d.object(forKey: "np.marqueeSpeed") != nil {
            let v = d.double(forKey: "np.marqueeSpeed")
            self.marqueeSpeed = v >= 10 && v <= 80 ? v : 30
        }
        if d.object(forKey: "np.musicPoll") != nil {
            let v = d.double(forKey: "np.musicPoll")
            self.musicPollInterval = v >= 1 && v <= 10 ? v : 5
        }
        // Shelf
        if d.object(forKey: "np.shelfMax") != nil {
            self.shelfMaxItems = max(5, min(200, d.integer(forKey: "np.shelfMax")))
        }
        if d.object(forKey: "np.shelfThumbs") != nil {
            self.shelfShowsThumbnails = d.bool(forKey: "np.shelfThumbs")
        }
        if d.object(forKey: "np.shelfClick") != nil {
            self.shelfClickAction = d.integer(forKey: "np.shelfClick")
        }
        // Calendar
        if d.object(forKey: "np.calCount") != nil {
            self.calendarEventCount = max(1, min(10, d.integer(forKey: "np.calCount")))
        }
        if d.object(forKey: "np.calRange") != nil {
            self.calendarTimeRange = d.integer(forKey: "np.calRange")
        }
        if d.object(forKey: "np.calNoAllDay") != nil {
            self.calendarHidesAllDay = d.bool(forKey: "np.calNoAllDay")
        }
        // Weather
        if d.object(forKey: "np.weatherRefresh") != nil {
            self.weatherRefreshMinutes = max(5, min(120, d.integer(forKey: "np.weatherRefresh")))
        }
        if d.object(forKey: "np.weatherWind") != nil {
            self.weatherShowsWind = d.bool(forKey: "np.weatherWind")
        }
        // Notes
        if d.object(forKey: "np.notesFont") != nil {
            let v = d.double(forKey: "np.notesFont")
            self.notesFontSize = v >= 10 && v <= 22 ? v : 14
        }
        if d.object(forKey: "np.notesMono") != nil {
            self.notesMonospaced = d.bool(forKey: "np.notesMono")
        }
        // Clipboard
        if d.object(forKey: "np.clipMax") != nil {
            self.clipboardMax = max(5, min(50, d.integer(forKey: "np.clipMax")))
        }
        // Animation speed
        if d.object(forKey: "np.animSpeed") != nil {
            let v = d.double(forKey: "np.animSpeed")
            self.animationSpeed = v >= 0.5 && v <= 2.0 ? v : 1.0
        }
        // Quiet hours
        if d.object(forKey: "np.quiet") != nil {
            self.quietHoursEnabled = d.bool(forKey: "np.quiet")
        }
        if d.object(forKey: "np.quietStart") != nil {
            self.quietHoursStart = max(0, min(23, d.integer(forKey: "np.quietStart")))
        }
        if d.object(forKey: "np.quietEnd") != nil {
            self.quietHoursEnd = max(0, min(23, d.integer(forKey: "np.quietEnd")))
        }
        // Restore tab order/visibility, falling back to defaults if any
        // raw value is unrecognized. Legacy raw values from old NotchTab
        // cases ("Battery", "Stopwatch", "Timer") get silently dropped;
        // if the resulting list would be empty, we keep the defaults.
        if let saved = d.array(forKey: "np.visibleTabs") as? [String] {
            let restored = saved.compactMap { NotchTab(rawValue: $0) }
            if !restored.isEmpty {
                self.visibleTabs = restored
            }
        }
        // Restore default-tab choice
        if let raw = d.string(forKey: "np.defaultTab"),
           let parsed = NotchTab(rawValue: raw) {
            self.defaultTab = parsed
            self.activeTab = parsed
        }

        // Re-broadcast: any expanded toggle must notify the window
        $expanded
            .removeDuplicates()
            .sink { [weak self] _ in self?.onSizeChange?() }
            .store(in: &bag)

        // Welcome peek toggles the glow padding around the notch, so
        // the window has to grow/shrink at those moments too. Without
        // this sink, the welcome card would render but the gradient
        // halo would stay clipped to the un-padded notch frame.
        $showingWelcome
            .removeDuplicates()
            .sink { [weak self] _ in self?.onSizeChange?() }
            .store(in: &bag)

        // Charging events temporarily expand the notch (peek). Honors
        // Settings → Behavior → "Charging peek" toggle and Quiet Hours
        // (no peek during the user's no-disturb window).
        charging.$peeking
            .removeDuplicates()
            .sink { [weak self] peeking in
                guard let self = self,
                      self.chargingPeekEnabled,
                      !self.inQuietHours else { return }
                if peeking { withAnimation(.spring()) { self.expanded = true } }
            }
            .store(in: &bag)

        // Restore shelf if user opted in
        if persistShelfBetweenLaunches { shelf.restore() }

        // Start services
        nowPlaying.start()
        charging.start()
        fullscreen.start()
        clipboard.start()
        systemStats.start()
        calendar.start()
        airpods.start()

        // Auto-switch to Pomodoro tab whenever the timer starts running
        // (only if pomodoroFollowsActive is on AND the tab is visible).
        // ALSO: send objectWillChange so SwiftUI re-renders the live
        // activity bar — hasActiveTimer is a computed property on this
        // model and SwiftUI doesn't observe computed props automatically.
        pomodoro.$running
            .removeDuplicates()
            .sink { [weak self] running in
                guard let self = self else { return }
                self.objectWillChange.send()
                self.onSizeChange?()
                if self.pomodoroFollowsActive, running, self.visibleTabs.contains(.pomodoro) {
                    self.activeTab = .pomodoro
                }
            }
            .store(in: &bag)

        // Same dance for Countdown timer
        countdown.$running
            .removeDuplicates()
            .sink { [weak self] _ in
                self?.objectWillChange.send()
                self?.onSizeChange?()
            }
            .store(in: &bag)

        // Re-publish whenever the entire track changes — both for the
        // live activity pill and the now-playing pane (artwork,
        // elapsed, etc.).
        nowPlaying.$track
            .removeDuplicates()
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
            .store(in: &bag)

        // Music pill specifically reacts to isPlaying flips — force
        // a window resize so the pill grows/shrinks the notch.
        nowPlaying.$track
            .map { $0.isPlaying && !$0.title.isEmpty }
            .removeDuplicates()
            .sink { [weak self] _ in self?.onSizeChange?() }
            .store(in: &bag)

        // Pomodoro phase / remaining time updates so the live activity
        // countdown text and progress arc refresh every second.
        pomodoro.$remaining
            .removeDuplicates()
            .sink { [weak self] _ in self?.objectWillChange.send() }
            .store(in: &bag)
        countdown.$remaining
            .removeDuplicates()
            .sink { [weak self] _ in self?.objectWillChange.send() }
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

    /// Triggers the multi-scene welcome animation. Used on first launch
    /// and replayable from Settings → About → "Replay welcome animation".
    /// When `reducedMotion` is on we skip the animation entirely — peek
    /// open without the spring, hold for the same duration, then close.
    func runWelcomePeek() {
        // CRITICAL: when the user clicks Replay from Settings the notch
        // is already collapsed, but `expanded` may have been left in a
        // half-state from a previous peek mid-animation. Snap to a
        // clean baseline before flipping the welcome flags so the
        // window-size math doesn't fold in stale "compactSize +
        // welcome glow" values.
        expanded = false
        showingWelcome = false
        // Give the SwiftUI run-loop a single tick so the prior frame
        // is committed before we kick off the new animation. Without
        // this the targetSize change races with the welcome glow's
        // padding kick-in and the notch can land off-center.
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.showingWelcome = true
            // Tiny delay between the showingWelcome flip and the
            // expanded flip so the window has time to grow with the
            // welcome glow padding before the SwiftUI content swaps
            // to the welcome card. Two state changes in the same
            // run-loop tick used to land the notch off-center on
            // Replay because the FIRST applyContentSize ran with
            // expanded=false (compactSize) but showingWelcome=true.
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                if self.reducedMotion {
                    self.expanded = true
                } else {
                    withAnimation(.spring(response: 0.45, dampingFraction: 0.78)) {
                        self.expanded = true
                    }
                }
            }
        }
        // 3 scenes × 1.5s + breathing room (default). Configurable
        // in Settings → Behavior → "Welcome peek duration".
        DispatchQueue.main.asyncAfter(deadline: .now() + welcomePeekDuration) { [weak self] in
            guard let self = self else { return }
            // Animate BOTH state changes together so the welcome glow
            // padding shrinks at the same time the notch shape does
            // — the previous code flipped showingWelcome synchronously
            // (no animation), making the window jump abruptly.
            if self.reducedMotion {
                self.showingWelcome = false
                if !self.hovering { self.expanded = false }
            } else {
                withAnimation(.spring(response: 0.5, dampingFraction: 0.82)) {
                    self.showingWelcome = false
                    if !self.hovering { self.expanded = false }
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

    // MARK: - Live activities (NotchNook-style integrated wide pill)

    /// True if a timer (Pomodoro or Countdown) is currently running
    /// AND the user has the timer live activity enabled. The timer
    /// keeps RUNNING regardless of this toggle — only the live-
    /// activity surface depends on it. Pomodoro takes precedence —
    /// it's the higher-stakes timer.
    var hasActiveTimer: Bool {
        timerLiveActivityEnabled && (pomodoro.running || countdown.running)
    }

    /// True if any audio app is currently playing a track AND the
    /// user has the music live activity enabled.
    var hasActiveMusic: Bool {
        musicLiveActivityEnabled
            && nowPlaying.track.isPlaying
            && !nowPlaying.track.title.isEmpty
    }

    /// True if any live-activity content should be shown on the notch.
    /// Timer outranks music — we only show one at a time, matching the
    /// NotchNook reference design.
    var hasAnyLiveActivity: Bool {
        liveActivitiesEnabled && !expanded && (hasActiveTimer || hasActiveMusic)
    }

    /// Pixel size of the small icon on the left side of the activity
    /// pill. ~24pt fits inside our 32pt-tall notch with breathing room.
    var activityLeftIconSize: CGFloat { 22 }

    /// How much wider the notch pill grows when an activity is active.
    /// Designed so the icon (~22pt) and the right-side content (~38pt
    /// for audio bars or "00:00" text) both fit, plus padding.
    var activityExtraWidth: CGFloat { 110 }

    /// Compact-mode width when an activity is showing — the integrated
    /// wide pill that replaces the bare notch shape.
    var compactSizeWithActivities: CGSize {
        let base = compactSize
        guard hasAnyLiveActivity else { return base }
        return CGSize(
            width: base.width + activityExtraWidth,
            height: base.height
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

    /// Extra padding around the notch panel during the welcome peek
    /// so we can render a glowing gradient halo OUTSIDE the actual
    /// notch shape. User feedback: "the cool first demo glowing
    /// gradient outside the notch thing still isnt there." Returning
    /// non-zero here grows the host window beyond the visible notch
    /// shape; NotchView then renders the glow into that extra space.
    /// Side padding only; we can't extend ABOVE the screen's top
    /// edge (the OS clips us there), and asymmetric vertical padding
    /// would push the notch off the top. Bumped to 110pt in v1.5.17
    /// so the halo is actually visible — the previous 70pt strip was
    /// almost entirely consumed by blur fall-off.
    var welcomeGlowSidePadding: CGFloat { showingWelcome ? 110 : 0 }
    var welcomeGlowBottomPadding: CGFloat { showingWelcome ? 100 : 0 }

    /// What size the host window should currently be. Includes the
    /// flanking live-activity pills when collapsed if anything's
    /// active (timer running, music playing). During the welcome
    /// peek, also reserves room for the gradient glow halo that
    /// bleeds OUTSIDE the notch shape on first launch / replay.
    var targetSize: CGSize {
        let base = expanded ? expandedSize : compactSizeWithActivities
        let sidePad = welcomeGlowSidePadding
        let bottomPad = welcomeGlowBottomPadding
        return CGSize(
            width:  base.width + sidePad * 2,
            height: base.height + bottomPad
        )
    }

    func persistShelfIfEnabled() {
        if persistShelfBetweenLaunches { shelf.persist() }
    }
}
