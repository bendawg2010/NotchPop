// SettingsView.swift
//
// Real settings window. Tabs:
//   • Tabs        — checkbox list with up/down reorder
//   • Behavior    — startup, hover timing, notch fit
//   • Appearance  — accent color, clock format, reduced motion
//   • Pomodoro    — focus / short / long durations, cycle, sound
//   • World Clock — cities visible in the World Clock pane
//   • Updates     — Sparkle controls (auto-check, force-update, last check)
//   • Diagnostics — re-detect screen, copy diagnostic info, log location
//   • About       — version, links, credits, danger zone
//
// EVERY tab body is wrapped in a ScrollView so longer sections never
// get clipped at the bottom of the 600pt window. Pre-v1.5.13 only the
// Behavior + Pomodoro tabs scrolled; the others (Tabs, World Clock,
// About) silently truncated their tail content on smaller windows.
//
// Persists everything via UserDefaults through NotchViewModel.

import SwiftUI

struct SettingsView: View {
    @ObservedObject var viewModel: NotchViewModel
    @State private var draggingTab: NotchTab?
    @State private var showResetConfirm = false
    @State private var selectedSection: SectionID = .tabs

    private var appVersion: String {
        (Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String) ?? "?"
    }

    /// Each row in the sidebar maps to a SectionID. Switched from
    /// SwiftUI's TabView to a NavigationSplitView-style sidebar
    /// because TabView dropped overflow tabs into a >> "Navigation
    /// Tab Bar" submenu — user feedback: "you shouldnt have to go
    /// through the navigate tool bar."
    enum SectionID: String, Identifiable, CaseIterable {
        case tabs, behavior, appearance, pomodoro, shortcuts, connections,
             worldClock, updates, diagnostics, about
        var id: String { rawValue }
        var label: String {
            switch self {
            case .tabs:        return "Tabs"
            case .behavior:    return "Behavior"
            case .appearance:  return "Appearance"
            case .pomodoro:    return "Pomodoro"
            case .shortcuts:   return "Shortcuts"
            case .connections: return "Connections"
            case .worldClock:  return "World Clock"
            case .updates:     return "Updates"
            case .diagnostics: return "Diagnostics"
            case .about:       return "About"
            }
        }
        var icon: String {
            switch self {
            case .tabs:        return "rectangle.stack"
            case .behavior:    return "slider.horizontal.3"
            case .appearance:  return "paintpalette"
            case .pomodoro:    return "timer"
            case .shortcuts:   return "square.grid.3x3.fill"
            case .connections: return "bolt.horizontal.fill"
            case .worldClock:  return "globe"
            case .updates:     return "arrow.triangle.2.circlepath"
            case .diagnostics: return "stethoscope"
            case .about:       return "info.circle"
            }
        }
    }

    var body: some View {
        NavigationSplitView {
            List(SectionID.allCases, selection: $selectedSection) { id in
                Label(id.label, systemImage: id.icon)
                    .tag(id)
            }
            .listStyle(.sidebar)
            .navigationSplitViewColumnWidth(min: 170, ideal: 180, max: 220)
        } detail: {
            sectionView(for: selectedSection)
                .padding(20)
        }
        .frame(width: 720, height: 620)
    }

    @ViewBuilder
    private func sectionView(for id: SectionID) -> some View {
        switch id {
        case .tabs:        tabsSection
        case .behavior:    behaviorSection
        case .appearance:  appearanceSection
        case .pomodoro:    pomodoroSection
        case .shortcuts:   shortcutsSection
        case .connections: connectionsSection
        case .worldClock:  worldClockSection
        case .updates:     updatesSection
        case .diagnostics: diagnosticsSection
        case .about:       aboutSection
        }
    }

    // MARK: - Reusable section header
    @ViewBuilder
    private func sectionHeader(_ title: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(size: 12, weight: .heavy))
                .foregroundColor(.secondary)
                .textCase(.uppercase)
                .tracking(1.2)
            Divider()
        }
        .padding(.top, 4)
    }

    // MARK: - Footer credit
    @ViewBuilder
    private var footerCredit: some View {
        HStack {
            Spacer()
            Text("v\(appVersion) · MIT licensed · Sparkle 2.x")
                .font(.caption2)
                .foregroundColor(Color.secondary.opacity(0.6))
        }
        .padding(.top, 6)
    }

    // MARK: - Caption helper
    @ViewBuilder
    private func caption(_ text: String) -> some View {
        Text(text)
            .font(.caption2)
            .foregroundColor(.secondary)
    }

    /// Wrap a section's body so it scrolls when content overflows the
    /// 600pt panel height. Padding-bottom matches what existing sections
    /// already used so spacing looks consistent across tabs.
    @ViewBuilder
    private func scrollable<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 14) { content() }
                .padding(.bottom, 10)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    // MARK: - Tabs section
    private var tabsSection: some View {
        scrollable {
            Text("Customize what shows up").font(.headline)
            Text("Toggle tabs on and off. Drag handles to reorder.")
                .font(.caption)
                .foregroundColor(.secondary)

            sectionHeader("Visible tabs")

            VStack(spacing: 0) {
                ForEach(NotchTab.allCases) { tab in
                    tabRow(tab)
                    if tab != NotchTab.allCases.last { Divider() }
                }
            }
            .background(Color(.windowBackgroundColor).opacity(0.5))
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.gray.opacity(0.3)))

            caption("Reorder with the up/down arrows. The topmost visible tab is the default fallback if your selected default is hidden.")

            HStack {
                Button("Show all") {
                    viewModel.visibleTabs = NotchTab.allCases
                }
                .buttonStyle(.bordered)
                Button("Reset to default order") {
                    viewModel.visibleTabs = [.nowPlaying, .pomodoro, .timers, .notes, .shelf]
                }
                .buttonStyle(.bordered)
                Spacer()
                Text("\(viewModel.visibleTabs.count) of \(NotchTab.allCases.count) visible")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            // ── Per-tab options ──────────────────────────────────

            sectionHeader("Music tab")
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("Marquee scroll speed")
                    Spacer()
                    Text(String(format: "%.0f px/s", viewModel.marqueeSpeed))
                        .foregroundColor(.secondary).monospacedDigit()
                }
                Slider(value: $viewModel.marqueeSpeed, in: 10...80, step: 5)
                caption("How fast long track titles scroll across the Music pane. 30 ≈ readable, 80 = aggressive.")
            }
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("Apple Music polling interval")
                    Spacer()
                    Text(String(format: "%.0f s", viewModel.musicPollInterval))
                        .foregroundColor(.secondary).monospacedDigit()
                }
                Slider(value: $viewModel.musicPollInterval, in: 1...10, step: 1)
                caption("Lower = more responsive elapsed-time updates, slightly more battery. Spotify pushes via DistributedNotification so this only affects Apple Music.")
            }

            sectionHeader("Shelf tab")
            HStack {
                Text("Maximum items").frame(width: 150, alignment: .leading)
                Stepper(value: $viewModel.shelfMaxItems, in: 5...200, step: 5) {
                    Text("\(viewModel.shelfMaxItems) files")
                        .frame(minWidth: 100, alignment: .leading)
                }
                Spacer()
            }
            caption("Older drops get evicted FIFO when the count would exceed this.")

            LabeledContent {
                Toggle("", isOn: $viewModel.shelfShowsThumbnails).labelsHidden()
            } label: {
                Text("Show file thumbnails")
            }

            HStack {
                Text("Click action").frame(width: 150, alignment: .leading)
                Picker("", selection: $viewModel.shelfClickAction) {
                    Text("Open in default app").tag(0)
                    Text("Reveal in Finder").tag(1)
                }
                .labelsHidden()
                .pickerStyle(.segmented)
                .frame(maxWidth: 320)
                Spacer()
            }

            sectionHeader("Calendar tab")
            HStack {
                Text("Events to show").frame(width: 150, alignment: .leading)
                Stepper(value: $viewModel.calendarEventCount, in: 1...10) {
                    Text("\(viewModel.calendarEventCount) events")
                        .frame(minWidth: 100, alignment: .leading)
                }
                Spacer()
            }
            HStack {
                Text("Time range").frame(width: 150, alignment: .leading)
                Picker("", selection: $viewModel.calendarTimeRange) {
                    Text("Today").tag(0)
                    Text("Next 24h").tag(1)
                    Text("Next 7 days").tag(2)
                }
                .labelsHidden()
                .pickerStyle(.segmented)
                .frame(maxWidth: 320)
                Spacer()
            }
            LabeledContent {
                Toggle("", isOn: $viewModel.calendarHidesAllDay).labelsHidden()
            } label: {
                Text("Hide all-day events")
            }
            caption("Useful if your calendars are clogged with 'Out of Office' / birthdays.")

            sectionHeader("Weather tab")
            HStack {
                Text("Refresh interval").frame(width: 150, alignment: .leading)
                Stepper(value: $viewModel.weatherRefreshMinutes, in: 5...120, step: 5) {
                    Text("\(viewModel.weatherRefreshMinutes) min")
                        .frame(minWidth: 100, alignment: .leading)
                }
                Spacer()
            }
            LabeledContent {
                Toggle("", isOn: $viewModel.weatherShowsWind).labelsHidden()
            } label: {
                Text("Show wind speed in footer")
            }

            sectionHeader("Notes tab")
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("Body font size")
                    Spacer()
                    Text(String(format: "%.0f pt", viewModel.notesFontSize))
                        .foregroundColor(.secondary).monospacedDigit()
                }
                Slider(value: $viewModel.notesFontSize, in: 10...22, step: 1)
            }
            LabeledContent {
                Toggle("", isOn: $viewModel.notesMonospaced).labelsHidden()
            } label: {
                Text("Use monospaced font")
            }

            sectionHeader("Clipboard tab")
            HStack {
                Text("History size").frame(width: 150, alignment: .leading)
                Stepper(value: $viewModel.clipboardMax, in: 5...50, step: 1) {
                    Text("\(viewModel.clipboardMax) entries")
                        .frame(minWidth: 100, alignment: .leading)
                }
                Spacer()
            }
            caption("Number of recent copies to remember. Older entries get evicted when the count exceeds this.")

            LabeledContent {
                Toggle("", isOn: $viewModel.clipboardAutoPaste).labelsHidden()
            } label: {
                Text("Auto-paste on click")
            }
            caption("On = clicking a chip copies the text AND simulates ⌘V into the previously-frontmost app, so you go from notch to pasted in one click. Off = chip click just copies (you press ⌘V manually).")

            footerCredit
        }
    }

    private func tabRow(_ tab: NotchTab) -> some View {
        let visible = viewModel.visibleTabs.contains(tab)
        let isFirst = viewModel.visibleTabs.first == tab
        let isLast = viewModel.visibleTabs.last == tab
        return HStack(spacing: 12) {
            Image(systemName: tab.icon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(visible ? .accentColor : .secondary)
                .frame(width: 24)
            VStack(alignment: .leading, spacing: 2) {
                Text(tab.rawValue).font(.system(size: 13, weight: .semibold))
                Text(tab.blurb).font(.caption).foregroundColor(.secondary)
            }
            Spacer()
            if visible {
                // Up/down arrows now use .plain with an explicit
                // contentShape(Rectangle) so the entire 28x28 area is
                // clickable, not just the 11pt SF Symbol glyph
                // (which the user reported as 'doesnt work' — too
                // small to hit reliably).
                arrowButton(symbol: "arrow.up",
                            disabled: isFirst,
                            help: "Move up") {
                    moveTab(tab, by: -1)
                }
                arrowButton(symbol: "arrow.down",
                            disabled: isLast,
                            help: "Move down") {
                    moveTab(tab, by: 1)
                }
            }
            Toggle("", isOn: Binding(
                get: { visible },
                set: { newVal in
                    if newVal {
                        if !viewModel.visibleTabs.contains(tab) {
                            viewModel.visibleTabs.append(tab)
                        }
                    } else {
                        if viewModel.visibleTabs.count > 1 {
                            viewModel.visibleTabs.removeAll { $0 == tab }
                        }
                    }
                }
            ))
            .labelsHidden()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
    }

    /// Tab-row arrow with a generous 32×32 click target plus an
    /// onPressGesture flash so the user gets visual confirmation
    /// the click registered (user reported "arrows still dont work"
    /// even after v1.5.21's first fix — turned out the issue was
    /// they couldn't TELL the click was registering on .first/.last
    /// tabs because disabled arrows look the same as enabled).
    /// Now the active arrow has a stronger background + scale-down
    /// on press, the disabled arrow is much more obviously dim.
    private func arrowButton(symbol: String, disabled: Bool, help: String,
                             action: @escaping () -> Void) -> some View {
        ArrowTapButton(symbol: symbol, disabled: disabled, action: action)
            .help(help)
    }

    private func moveTab(_ tab: NotchTab, by delta: Int) {
        guard let i = viewModel.visibleTabs.firstIndex(of: tab) else { return }
        let new = i + delta
        guard new >= 0 && new < viewModel.visibleTabs.count else { return }
        var arr = viewModel.visibleTabs
        arr.swapAt(i, new)
        viewModel.visibleTabs = arr
    }

    // MARK: - Behavior section
    private var behaviorSection: some View {
        scrollable {
            Text("How NotchPop behaves").font(.headline)

            // ── Startup ──────────────────────────────────────────
            sectionHeader("Startup")

            LabeledContent {
                Toggle("", isOn: $viewModel.launchAtLogin).labelsHidden()
            } label: {
                Text("Launch NotchPop at login")
            }
            caption("Adds NotchPop to System Settings → Login Items so it starts when you log in.")

            LabeledContent {
                Toggle("", isOn: $viewModel.persistShelfBetweenLaunches).labelsHidden()
            } label: {
                Text("Remember file shelf between launches")
            }
            caption("On = the dropped files in your shelf survive a relaunch. Off = shelf empties on quit.")

            // ── Default tab ──────────────────────────────────────
            sectionHeader("Default tab")

            LabeledContent {
                Picker("", selection: $viewModel.defaultTab) {
                    ForEach(viewModel.visibleTabs) { tab in
                        Label(tab.rawValue, systemImage: tab.icon).tag(tab)
                    }
                }
                .labelsHidden()
                .frame(maxWidth: 180)
            } label: {
                Text("Default tab on expand")
            }
            caption("When you hover the notch, this tab shows first. Dragging a file in still auto-switches to Shelf.")

            // ── Display ──────────────────────────────────────────
            sectionHeader("Display")

            LabeledContent {
                Toggle("", isOn: $viewModel.hideInFullscreen).labelsHidden()
            } label: {
                Text("Hide notch in fullscreen apps")
            }
            caption("Keeps NotchPop out of the way when you're using a fullscreen video, presentation, or game.")

            LabeledContent {
                Toggle("", isOn: $viewModel.liveActivitiesEnabled).labelsHidden()
            } label: {
                Text("Live activities flanking the notch (master)")
            }
            caption("When music is playing or a timer is running, slim pills appear on either side of the collapsed notch — track info on the right, countdown on the left. Tap either to open it.")

            LabeledContent {
                Toggle("", isOn: $viewModel.timerLiveActivityEnabled).labelsHidden()
            } label: {
                Text("Show timer in live activity")
            }
            caption("Hide the running-timer pill specifically. The timer keeps running — only the flanking surface goes away. User feedback: 'there should be an option to hide the timer.'")

            LabeledContent {
                Toggle("", isOn: $viewModel.musicLiveActivityEnabled).labelsHidden()
            } label: {
                Text("Show music in live activity")
            }
            caption("Hide the now-playing pill. Music keeps playing; the in-notch info just disappears.")

            LabeledContent {
                Toggle("", isOn: $viewModel.liveActivityShowsArtwork).labelsHidden()
            } label: {
                Text("Show album artwork in live activity")
            }
            caption("Off = falls back to a generic music note glyph (privacy mode for shoulder-surfing scenarios).")

            LabeledContent {
                Toggle("", isOn: $viewModel.pomodoroFollowsActive).labelsHidden()
            } label: {
                Text("Auto-switch to Pomodoro tab when timer starts")
            }
            caption("On = expanding the notch during a focus session lands on Pomodoro instead of your default tab.")

            // ── Interaction ──────────────────────────────────────
            sectionHeader("Interaction")

            LabeledContent {
                Toggle("", isOn: $viewModel.expandOnDragHover).labelsHidden()
            } label: {
                Text("Auto-expand when dragging a file near the notch")
            }
            caption("On = drag-to-shelf is much easier; the notch opens as soon as your dragged file approaches it. Off = you must hover first, then drag.")

            LabeledContent {
                Toggle("", isOn: $viewModel.clickOutsideToCollapse).labelsHidden()
            } label: {
                Text("Click outside the notch to collapse it")
            }
            caption("Off = only mouse-out collapses. Useful if you keep accidentally clicking through to apps behind.")

            LabeledContent {
                Toggle("", isOn: $viewModel.autoCollapseAfterTabSelect).labelsHidden()
            } label: {
                Text("Collapse the notch after tapping a tab")
            }
            caption("Glance-and-go workflow — the notch shrinks back ~600ms after you pick a tab.")

            LabeledContent {
                Toggle("", isOn: $viewModel.alwaysShowTabLabels).labelsHidden()
            } label: {
                Text("Always show tab labels")
            }
            caption("Off = labels auto-hide on inactive tabs when more than 4 are visible (avoids 'Pomo… / N… / S…' truncation). On = labels always shown — text may truncate with all 12 tabs enabled.")

            // ── Welcome animation ────────────────────────────────
            sectionHeader("Welcome animation")

            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("Welcome peek duration")
                    Spacer()
                    Text(String(format: "%.1f s", viewModel.welcomePeekDuration))
                        .foregroundColor(.secondary).monospacedDigit()
                }
                Slider(value: $viewModel.welcomePeekDuration, in: 3...15, step: 0.5)
                caption("How long the welcome card stays open on first launch + replay. Default 5.5s matches the 3-scene cycle.")
            }

            HStack {
                Button {
                    viewModel.runWelcomePeek()
                } label: {
                    Label("Replay welcome animation now", systemImage: "play.circle.fill")
                }
                .buttonStyle(.bordered)
                Spacer()
            }

            // ── Top-bar widgets ──────────────────────────────────
            sectionHeader("Expanded notch top bar")

            LabeledContent {
                Toggle("", isOn: $viewModel.showInlineBattery).labelsHidden()
            } label: {
                Text("Show inline battery indicator")
            }
            caption("The compact battery glyph in the top-right of the expanded notch. Off = cleaner top bar.")

            LabeledContent {
                Toggle("", isOn: $viewModel.showVersionLabel).labelsHidden()
            } label: {
                Text("Show version label")
            }
            caption("The tiny 'v1.5.x' stamp next to the battery. Off if you find it cluttered.")

            LabeledContent {
                Toggle("", isOn: $viewModel.chargingPeekEnabled).labelsHidden()
            } label: {
                Text("Peek the notch when charging starts")
            }
            caption("Plug in and the notch briefly expands with a charging cheer animation. Off = no peek.")

            LabeledContent {
                Toggle("", isOn: $viewModel.showMenuBarIcon).labelsHidden()
            } label: {
                Text("Show menubar icon")
            }
            caption("Off = no menubar icon (rely on the notch + auto-launch). Settings reachable via the gear inside the expanded notch.")

            // ── Quiet hours ──────────────────────────────────────
            sectionHeader("Quiet hours")
            caption("Suppress welcome peeks, charging peeks, and live-activity expansions during a chosen time window.")

            LabeledContent {
                Toggle("", isOn: $viewModel.quietHoursEnabled).labelsHidden()
            } label: {
                Text("Enable quiet hours")
            }

            HStack {
                Text("From").frame(width: 80, alignment: .leading)
                Picker("", selection: $viewModel.quietHoursStart) {
                    ForEach(0..<24, id: \.self) { h in
                        Text(String(format: "%02d:00", h)).tag(h)
                    }
                }
                .labelsHidden()
                .frame(maxWidth: 100)
                Text("to").frame(width: 30, alignment: .center)
                Picker("", selection: $viewModel.quietHoursEnd) {
                    ForEach(0..<24, id: \.self) { h in
                        Text(String(format: "%02d:00", h)).tag(h)
                    }
                }
                .labelsHidden()
                .frame(maxWidth: 100)
                Spacer()
            }
            .opacity(viewModel.quietHoursEnabled ? 1 : 0.55)
            caption("Wraparound supported (e.g. 22:00 to 07:00 means 'overnight').")

            // ── Hover timing ─────────────────────────────────────
            sectionHeader("Hover timing")

            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("Hover delay before expanding")
                    Spacer()
                    Text("\(Int(viewModel.hoverDelay * 1000)) ms")
                        .foregroundColor(.secondary)
                        .monospacedDigit()
                }
                Slider(value: $viewModel.hoverDelay, in: 0...0.5, step: 0.05)
                caption("Higher = brushing the notch on the way past won't trigger it.")
            }

            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("Mouse-out collapse delay")
                    Spacer()
                    Text("\(Int(viewModel.collapseDelay * 1000)) ms")
                        .foregroundColor(.secondary)
                        .monospacedDigit()
                }
                Slider(value: $viewModel.collapseDelay, in: 0.05...1.0, step: 0.05)
                caption("Higher = more forgiving if you dart your mouse out for a moment.")
            }

            // ── Notch fit ────────────────────────────────────────
            sectionHeader("Notch fit")
            caption("If the collapsed notch doesn't blend perfectly with your hardware, nudge these. The drawn shape is always pure black.")

            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("Width nudge")
                    Spacer()
                    Text(formatOffset(viewModel.notchWidthOffset))
                        .foregroundColor(.secondary).monospacedDigit()
                }
                Slider(value: $viewModel.notchWidthOffset, in: -10...10, step: 0.5)
                caption("Negative shrinks the drawn notch; positive widens it. Use if the edges of your hardware cutout peek through.")
            }

            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("Height extension")
                    Spacer()
                    Text(formatOffset(viewModel.notchHeightExtension))
                        .foregroundColor(.secondary).monospacedDigit()
                }
                Slider(value: $viewModel.notchHeightExtension, in: 0...10, step: 0.5)
                caption("Extends the notch a few pixels below the hardware cutout. Useful if you want the bottom corners to be visible vs. perfectly hidden.")
            }

            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("Corner radius")
                    Spacer()
                    Text(viewModel.notchCornerRadiusOverride > 0
                         ? String(format: "%.1f pt", viewModel.notchCornerRadiusOverride)
                         : "Auto (\(String(format: "%.1f", viewModel.screenInfo.notchCornerRadius)))")
                        .foregroundColor(.secondary).monospacedDigit()
                }
                Slider(value: $viewModel.notchCornerRadiusOverride, in: 0...14, step: 0.5)
                caption("0 = auto-detect from your screen. Higher = rounder bottom corners.")
            }

            Button("Reset notch fit to auto") {
                viewModel.notchWidthOffset = 0
                viewModel.notchHeightExtension = 0
                viewModel.notchCornerRadiusOverride = 0
            }
            .buttonStyle(.bordered)

            footerCredit
        }
    }

    private func formatOffset(_ v: Double) -> String {
        let rounded = (v * 2).rounded() / 2
        if rounded == 0 { return "0 pt" }
        return String(format: "%@%.1f pt", v > 0 ? "+" : "", rounded)
    }

    // MARK: - Appearance section
    /// New in v1.5.13 — accent color picker, 12/24-hour clock, show
    /// seconds, reduce motion. All preferences are wired through
    /// NotchViewModel and surface in the views that consume them
    /// (WorldClockView, runWelcomePeek, etc.).
    private var appearanceSection: some View {
        scrollable {
            Text("Look & feel").font(.headline)

            // ── Accent color ─────────────────────────────────────
            sectionHeader("Accent color")
            caption("Used for transport buttons, the Pomodoro ring, selected chips, and live-activity highlights. Default 'Pink → Blue' is the brand gradient.")

            // 4 swatches per row in a grid
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 2),
                      spacing: 8) {
                ForEach(AccentChoice.allCases) { choice in
                    accentSwatch(choice)
                }
            }

            // ── Clock format ─────────────────────────────────────
            sectionHeader("Clock format")

            Picker("Hour format", selection: $viewModel.clockUses24Hour) {
                Text("12-hour (1:30 PM)").tag(false)
                Text("24-hour (13:30)").tag(true)
            }
            .pickerStyle(.segmented)
            caption("Affects the World Clock cards. Other clock displays follow the same setting.")

            LabeledContent {
                Toggle("", isOn: $viewModel.clockShowsSeconds).labelsHidden()
            } label: {
                Text("Show seconds")
            }
            caption("Adds :ss to clock displays. Off by default for a cleaner look.")

            // ── Notch background ─────────────────────────────────
            sectionHeader("Expanded notch background")
            caption("The collapsed notch always stays solid black so it blends with the hardware cutout — but when expanded you can pick a custom backdrop. Galaxy includes twinkling stars and nebula glows.")

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 2),
                      spacing: 8) {
                ForEach(NotchBackground.allCases) { bg in
                    backgroundSwatch(bg)
                }
            }

            // ── Motion ───────────────────────────────────────────
            sectionHeader("Motion")

            LabeledContent {
                Toggle("", isOn: $viewModel.reducedMotion).labelsHidden()
            } label: {
                Text("Reduce motion")
            }
            caption("Skips spring animations on the welcome peek and stops the Pomodoro ring's gradient orbit. Useful for vestibular sensitivity or older Macs.")

            LabeledContent {
                Toggle("", isOn: $viewModel.ambientShimmerEnabled).labelsHidden()
            } label: {
                Text("Ambient shimmer when idle")
            }
            caption("Top-edge aurora shimmer on the collapsed notch — from the official 8-animations handoff. Reads as 'alive' without pulling focus.")

            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("Animation speed")
                    Spacer()
                    Text(String(format: "%.2f×", viewModel.animationSpeed))
                        .foregroundColor(.secondary).monospacedDigit()
                }
                Slider(value: $viewModel.animationSpeed, in: 0.5...2.0, step: 0.05)
                caption("0.5× = snappier (animations finish in half the time). 2.0× = slow-mo demo. Default 1.0× matches the original timing.")
            }

            // ── Per-surface animation tuning ─────────────────────
            sectionHeader("Per-surface tuning")
            caption("Fine-grained sliders for each animated surface. Reset each one back to default by double-clicking the slider.")

            animationSlider(
                label: "Pomodoro ring spin",
                value: $viewModel.pomodoroRingRotationSpeed,
                range: 0...20,
                format: "%.1f s",
                hint: "How long one full gradient orbit takes around the ring. 0 = no rotation.")

            animationSlider(
                label: "Welcome hue cycle",
                value: $viewModel.welcomeHueCyclePeriod,
                range: 1...20,
                format: "%.1f s",
                hint: "How long the welcome glow takes to cycle the full pink → purple → blue → mint rainbow.")

            animationSlider(
                label: "Welcome bloom depth",
                value: $viewModel.welcomeBloomDepth,
                range: 0...2,
                format: "%.2f×",
                hint: "How much the welcome glow scales up as it ramps in. 0 = no scale, 1.0 = default 0.85 → 1.0, 2.0 = exaggerated.")

            animationSlider(
                label: "Live-activity audio bars",
                value: $viewModel.audioBarsIntensity,
                range: 0...2,
                format: "%.2f×",
                hint: "How aggressive the dancing bars are when music is playing. 1.0 = base, 0.3 = chill, 1.7 = bouncy.")

            animationSlider(
                label: "Album-art breathing",
                value: $viewModel.artworkPulseDepth,
                range: 0...0.10,
                format: "%.0f%% scale",
                multiplier: 100,
                hint: "How much the now-playing artwork scales up and down each beat. 4% default; 0% off; 10% noticeable.")

            animationSlider(
                label: "Notch Pet bounce",
                value: $viewModel.petBounceIntensity,
                range: 0...3,
                format: "%.2f×",
                hint: "Excited-state bounce amplitude on the Notch Pet sprite. 1.0 = default 6pt jump, 0.5 = chill, 2.5 = wild.")

            animationSlider(
                label: "Background animation speed",
                value: $viewModel.backgroundAnimSpeed,
                range: 0...3,
                format: "%.2f×",
                hint: "Galaxy stars / Aurora drift / etc. 1.0 = default, 0.3 = barely moves, 2.5 = chaotic.")

            animationSlider(
                label: "Progress line thickness",
                value: $viewModel.progressLineThickness,
                range: 1...4,
                format: "%.1f pt",
                hint: "How thick the bottom progress line on the live-activity pill is. 1.5pt default, 4pt = thick.")

            HStack {
                Button("Reset all animation sliders") {
                    viewModel.pomodoroRingRotationSpeed = 8.0
                    viewModel.welcomeHueCyclePeriod = 5.0
                    viewModel.welcomeBloomDepth = 1.0
                    viewModel.audioBarsIntensity = 1.0
                    viewModel.artworkPulseDepth = 0.04
                    viewModel.petBounceIntensity = 1.0
                    viewModel.backgroundAnimSpeed = 1.0
                    viewModel.progressLineThickness = 1.5
                }
                .buttonStyle(.bordered)
                Spacer()
            }

            footerCredit
        }
    }

    /// Re-usable labeled slider for animation tuning. Multiplier
    /// scales the displayed value (used for the artwork pulse where
    /// 0.04 should display as "4%" not "0.04").
    private func animationSlider(
        label: String,
        value: Binding<Double>,
        range: ClosedRange<Double>,
        format: String,
        multiplier: Double = 1,
        hint: String
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(label)
                Spacer()
                Text(String(format: format, value.wrappedValue * multiplier))
                    .foregroundColor(.secondary).monospacedDigit()
            }
            Slider(value: value, in: range)
            caption(hint)
        }
        .padding(.vertical, 2)
    }

    private func backgroundSwatch(_ choice: NotchBackground) -> some View {
        let selected = viewModel.expandedBackground == choice
        return Button {
            viewModel.expandedBackground = choice
        } label: {
            HStack(spacing: 10) {
                ZStack {
                    NotchBackgroundView(background: choice, animated: false)
                    if choice == .classicBlack {
                        Color.black
                    }
                }
                .frame(width: 56, height: 26)
                .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .stroke(selected ? Color.accentColor : Color.gray.opacity(0.3),
                                lineWidth: selected ? 2 : 1)
                )
                Text(choice.label)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.primary)
                Spacer()
                if selected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.accentColor)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(selected
                          ? Color.accentColor.opacity(0.12)
                          : Color.gray.opacity(0.08))
            )
        }
        .buttonStyle(.plain)
    }

    private func accentSwatch(_ choice: AccentChoice) -> some View {
        let selected = viewModel.accentChoice == choice
        return Button {
            viewModel.accentChoice = choice
        } label: {
            HStack(spacing: 10) {
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(LinearGradient(
                        colors: [choice.startColor, choice.endColor],
                        startPoint: .leading, endPoint: .trailing))
                    .frame(width: 38, height: 22)
                    .overlay(
                        RoundedRectangle(cornerRadius: 7, style: .continuous)
                            .stroke(selected
                                    ? Color.accentColor
                                    : Color.gray.opacity(0.3), lineWidth: selected ? 2 : 1)
                    )
                Text(choice.label)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.primary)
                Spacer()
                if selected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.accentColor)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(selected
                          ? Color.accentColor.opacity(0.12)
                          : Color.gray.opacity(0.08))
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Pomodoro section
    private var pomodoroSection: some View {
        scrollable {
            Text("Pomodoro durations").font(.headline)

            sectionHeader("Durations")

            durationStepper("Focus", value: Binding(
                get: { viewModel.pomodoro.focusMinutes },
                set: { viewModel.pomodoro.focusMinutes = $0 }), range: 5...120, suffix: "min")
            caption("Length of one focus block. Classic Pomodoro is 25 minutes.")

            durationStepper("Short break", value: Binding(
                get: { viewModel.pomodoro.shortBreakMinutes },
                set: { viewModel.pomodoro.shortBreakMinutes = $0 }), range: 1...30, suffix: "min")
            caption("Quick rest between focus blocks.")

            durationStepper("Long break", value: Binding(
                get: { viewModel.pomodoro.longBreakMinutes },
                set: { viewModel.pomodoro.longBreakMinutes = $0 }), range: 5...60, suffix: "min")
            caption("Bigger break taken every few cycles.")

            durationStepper("Long break every", value: Binding(
                get: { viewModel.pomodoro.sessionsBeforeLongBreak },
                set: { viewModel.pomodoro.sessionsBeforeLongBreak = $0 }), range: 2...10, suffix: "sessions")
            caption("How many focus blocks happen before a long break kicks in.")

            durationStepper("Daily goal", value: Binding(
                get: { viewModel.pomodoro.dailyGoal },
                set: { viewModel.pomodoro.dailyGoal = $0 }), range: 1...20, suffix: "sessions")
            caption("Target number of completed focus sessions per day. Drives the ring fill in the Pomodoro tab.")

            sectionHeader("Ring style")

            // Toggle the Pomodoro ring between the default orbit
            // gradient stroke and the new "tide" variant from the
            // Anthropic Design 8 Animations handoff (water-rises-as-
            // time-passes). Persisted under np.pomodoroRingStyle.
            HStack {
                Text("Ring style")
                Spacer()
                Picker("", selection: Binding<String>(
                    get: { UserDefaults.standard.string(forKey: "np.pomodoroRingStyle") ?? "orbit" },
                    set: { UserDefaults.standard.set($0, forKey: "np.pomodoroRingStyle") }
                )) {
                    Text("Orbit (default)").tag("orbit")
                    Text("🌊 Tide").tag("tide")
                }.labelsHidden().frame(width: 180)
            }
            caption("Tide fills the ring with sloshing water as time elapses — designed in the official 8-animations handoff.")

            sectionHeader("Flow")

            LabeledContent {
                Toggle("", isOn: Binding(
                    get: { viewModel.pomodoro.autoStartNextPhase },
                    set: { viewModel.pomodoro.autoStartNextPhase = $0 })).labelsHidden()
            } label: {
                Text("Auto-start the next phase")
            }
            caption("On = goes straight from focus → break → focus without clicking.")

            LabeledContent {
                Toggle("", isOn: Binding(
                    get: { viewModel.pomodoro.strictMode },
                    set: { viewModel.pomodoro.strictMode = $0 })).labelsHidden()
            } label: {
                Text("Strict mode (can't pause focus)")
            }
            caption("Pause is disabled mid-focus. Skip and Reset still work.")

            sectionHeader("Sound")

            LabeledContent {
                Toggle("", isOn: $viewModel.soundEffectsEnabled).labelsHidden()
            } label: {
                Text("Play sound when a timer ends")
            }
            caption("Master toggle for end-of-phase chimes. Used by both Pomodoro and the Countdown timer.")

            HStack {
                Text("Sound").frame(width: 100, alignment: .leading)
                Picker("", selection: $viewModel.timerSoundName) {
                    ForEach(TimerSound.choices, id: \.self) { name in
                        Text(name).tag(name)
                    }
                }
                .labelsHidden()
                .frame(maxWidth: 180)
                Spacer()
                Button {
                    TimerSound.playRaw(name: viewModel.timerSoundName)
                } label: {
                    Label("Preview", systemImage: "speaker.wave.2.fill")
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
            .opacity(viewModel.soundEffectsEnabled ? 1 : 0.55)
            caption("Preview always plays, even when the master toggle is off.")

            Button("Reset Pomodoro session") { viewModel.pomodoro.reset() }
                .buttonStyle(.bordered)

            footerCredit
        }
    }

    private func durationStepper(_ label: String, value: Binding<Int>,
                                 range: ClosedRange<Int>, suffix: String) -> some View {
        HStack {
            Text(label).frame(width: 150, alignment: .leading)
            Stepper(value: value, in: range) {
                Text("\(value.wrappedValue) \(suffix)")
                    .font(.system(.body, design: .rounded))
                    .frame(minWidth: 100, alignment: .leading)
            }
            Spacer()
        }
    }

    // MARK: - World Clock section
    @State private var newClockTimezoneIndex: Int = 0
    @State private var newClockLabel: String = ""
    @State private var clockSearchText: String = ""

    // MARK: - App Shortcuts section
    @State private var newURLString = ""
    @State private var newURLTitle = ""

    private var shortcutsSection: some View {
        scrollable {
            Text("App & URL Shortcuts").font(.headline)
            Text("Pin macOS apps and URLs — click to launch from inside the notch's App Shortcuts tab.")
                .font(.caption).foregroundColor(.secondary)

            sectionHeader("Pinned shortcuts")

            VStack(spacing: 0) {
                ForEach(viewModel.appShortcuts.items) { item in
                    shortcutRow(item)
                    if item.id != viewModel.appShortcuts.items.last?.id { Divider() }
                }
                if viewModel.appShortcuts.items.isEmpty {
                    Text("No shortcuts yet — add one below")
                        .font(.caption).foregroundColor(.secondary)
                        .padding(.vertical, 14)
                }
            }
            .background(Color(.windowBackgroundColor).opacity(0.5))
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.gray.opacity(0.3)))

            sectionHeader("Add an app")
            HStack {
                Button {
                    pickAppFromOpenPanel()
                } label: {
                    Label("Choose app from /Applications…", systemImage: "plus.app.fill")
                }
                .buttonStyle(.borderedProminent)
                Spacer()
            }
            caption("An NSOpenPanel opens — pick any .app and it'll appear in the row above.")

            sectionHeader("Add a URL")
            HStack(spacing: 8) {
                TextField("https://github.com or github.com", text: $newURLString)
                    .textFieldStyle(.roundedBorder)
                TextField("Optional label", text: $newURLTitle)
                    .textFieldStyle(.roundedBorder)
                    .frame(maxWidth: 140)
                Button("Add") {
                    let title = newURLTitle.trimmingCharacters(in: .whitespaces)
                    viewModel.appShortcuts.addURL(
                        newURLString,
                        title: title.isEmpty ? nil : title)
                    newURLString = ""
                    newURLTitle = ""
                }
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.borderedProminent)
                .disabled(newURLString.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            caption("Schema-less URLs default to https://. Click the resulting tile to open in your default browser.")

            footerCredit
        }
    }

    private func shortcutRow(_ item: ShortcutItem) -> some View {
        HStack(spacing: 8) {
            // Tiny icon preview using the same NSWorkspace lookup as
            // the in-notch tile.
            Group {
                if let img = viewModel.appShortcuts.icon(for: item) {
                    Image(nsImage: img).resizable().scaledToFit()
                } else if let symbol = item.iconSymbol {
                    Image(systemName: symbol)
                } else {
                    Image(systemName: "questionmark.app.fill")
                }
            }
            .frame(width: 22, height: 22)

            VStack(alignment: .leading, spacing: 1) {
                Text(item.title).font(.system(size: 13, weight: .semibold))
                Text(item.kind == .app ? "App" : item.payload)
                    .font(.caption2).foregroundColor(.secondary)
                    .lineLimit(1).truncationMode(.middle)
            }
            Spacer()
            arrowButton(symbol: "arrow.up",
                        disabled: viewModel.appShortcuts.items.first?.id == item.id,
                        help: "Move up") { viewModel.appShortcuts.move(item, by: -1) }
            arrowButton(symbol: "arrow.down",
                        disabled: viewModel.appShortcuts.items.last?.id == item.id,
                        help: "Move down") { viewModel.appShortcuts.move(item, by: 1) }
            Button {
                viewModel.appShortcuts.remove(item)
            } label: {
                Image(systemName: "minus.circle.fill")
                    .frame(width: 28, height: 28)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .foregroundColor(.red)
            .help("Remove")
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
    }

    private func pickAppFromOpenPanel() {
        let panel = NSOpenPanel()
        panel.title = "Pick an app to pin"
        panel.allowedContentTypes = [.application]
        panel.directoryURL = URL(fileURLWithPath: "/Applications")
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        if panel.runModal() == .OK, let url = panel.url {
            viewModel.appShortcuts.addApp(at: url)
        }
    }

    // MARK: - Connections section
    @State private var newConnectionTrigger: ConnectionTrigger = .pomodoroFocusStart
    @State private var newConnectionAction: ConnectionAction = .launchApp
    @State private var newConnectionArg: String = ""

    private var connectionsSection: some View {
        scrollable {
            Text("Connections — when X happens, do Y").font(.headline)
            Text("Tiny automation engine. Pomodoro phase changes, charging, music, app launch — each can fire an action.")
                .font(.caption).foregroundColor(.secondary)

            sectionHeader("Your connections")

            VStack(spacing: 0) {
                ForEach(viewModel.connections.connections) { c in
                    connectionRow(c)
                    if c.id != viewModel.connections.connections.last?.id { Divider() }
                }
                if viewModel.connections.connections.isEmpty {
                    Text("No connections yet — add one below")
                        .font(.caption).foregroundColor(.secondary)
                        .padding(.vertical, 14)
                }
            }
            .background(Color(.windowBackgroundColor).opacity(0.5))
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.gray.opacity(0.3)))

            sectionHeader("Add a connection")

            HStack(spacing: 8) {
                Text("When").frame(width: 50, alignment: .leading)
                Picker("", selection: $newConnectionTrigger) {
                    ForEach(ConnectionTrigger.allCases) { t in
                        Text(t.label).tag(t)
                    }
                }
                .labelsHidden()
                .frame(maxWidth: 220)
                Spacer()
            }
            HStack(spacing: 8) {
                Text("Then").frame(width: 50, alignment: .leading)
                Picker("", selection: $newConnectionAction) {
                    ForEach(ConnectionAction.allCases) { a in
                        Text(a.label).tag(a)
                    }
                }
                .labelsHidden()
                .frame(maxWidth: 220)
                Spacer()
            }
            HStack(spacing: 8) {
                Text("Arg").frame(width: 50, alignment: .leading)
                TextField(newConnectionAction.argLabel, text: $newConnectionArg)
                    .textFieldStyle(.roundedBorder)
                if newConnectionAction == .launchApp {
                    Button("Pick…") {
                        let panel = NSOpenPanel()
                        panel.allowedContentTypes = [.application]
                        panel.directoryURL = URL(fileURLWithPath: "/Applications")
                        panel.canChooseFiles = true
                        panel.canChooseDirectories = false
                        if panel.runModal() == .OK, let url = panel.url {
                            newConnectionArg = url.path
                        }
                    }
                    .buttonStyle(.bordered)
                }
            }
            caption(connectionArgHint(for: newConnectionAction))

            HStack {
                Button("Add connection") {
                    let conn = Connection(trigger: newConnectionTrigger,
                                          action: newConnectionAction,
                                          arg: newConnectionArg)
                    viewModel.connections.add(conn)
                    newConnectionArg = ""
                }
                .buttonStyle(.borderedProminent)
                .disabled(newConnectionArg.trimmingCharacters(in: .whitespaces).isEmpty)

                Button("Test fire trigger") {
                    viewModel.connections.testFire(newConnectionTrigger)
                }
                .buttonStyle(.bordered)
                Spacer()
            }
            caption("'Test fire trigger' simulates the event so you can verify your connection runs without waiting for a real Pomodoro / charge / etc.")

            footerCredit
        }
    }

    private func connectionRow(_ c: Connection) -> some View {
        HStack(spacing: 8) {
            Toggle("", isOn: Binding(
                get: { c.enabled },
                set: { _ in viewModel.connections.toggle(c) }
            ))
            .labelsHidden()

            VStack(alignment: .leading, spacing: 1) {
                HStack(spacing: 4) {
                    Text("When").font(.caption2).foregroundColor(.secondary)
                    Text(c.trigger.label)
                        .font(.system(size: 12, weight: .heavy))
                }
                HStack(spacing: 4) {
                    Text("then").font(.caption2).foregroundColor(.secondary)
                    Text(c.action.label)
                        .font(.system(size: 12, weight: .semibold))
                    Text("→")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(c.arg)
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                        .foregroundColor(.secondary)
                        .lineLimit(1).truncationMode(.middle)
                }
            }
            Spacer()
            Button {
                viewModel.connections.remove(c)
            } label: {
                Image(systemName: "minus.circle.fill")
                    .frame(width: 28, height: 28)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .foregroundColor(.red)
            .help("Remove")
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .opacity(c.enabled ? 1 : 0.55)
    }

    private func connectionArgHint(for action: ConnectionAction) -> String {
        switch action {
        case .launchApp:   return "Full path like /Applications/Things3.app — or click 'Pick…'."
        case .openURL:     return "Anything macOS can open. https:// added if missing."
        case .runShortcut: return "The exact name of a shortcut from the Shortcuts app."
        case .playSound:   return "Glass · Submarine · Bell · Hero · Funk · Frog · Pop · Sosumi · Tink · Ping · Purr · Beep"
        case .copyText:    return "Whatever you want. Useful for paste-this-snippet workflows."
        }
    }

    private var worldClockSection: some View {
        scrollable {
            Text("World Clock cities").font(.headline)
            Text("Up to 4 cities show in the World Clock tab.")
                .font(.caption).foregroundColor(.secondary)

            sectionHeader("Your cities")

            VStack(spacing: 0) {
                ForEach(Array(viewModel.worldClock.clocks.enumerated()), id: \.element.id) { idx, entry in
                    HStack(spacing: 8) {
                        Image(systemName: "globe")
                            .frame(width: 18)
                            .foregroundColor(.secondary)
                        VStack(alignment: .leading, spacing: 1) {
                            Text(entry.label).font(.system(size: 13, weight: .semibold))
                            Text(entry.timezoneIdentifier).font(.caption2).foregroundColor(.secondary)
                        }
                        Spacer()
                        if idx > 0 {
                            Button { moveClock(idx, by: -1) } label: { Image(systemName: "arrow.up") }
                                .buttonStyle(.borderless)
                        } else {
                            Image(systemName: "arrow.up").opacity(0).accessibilityHidden(true)
                        }
                        if idx < viewModel.worldClock.clocks.count - 1 {
                            Button { moveClock(idx, by: 1) } label: { Image(systemName: "arrow.down") }
                                .buttonStyle(.borderless)
                        } else {
                            Image(systemName: "arrow.down").opacity(0).accessibilityHidden(true)
                        }
                        Button { viewModel.worldClock.remove(entry) } label: {
                            Image(systemName: "minus.circle.fill")
                        }
                        .buttonStyle(.borderless)
                        .foregroundColor(.red)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    if idx < viewModel.worldClock.clocks.count - 1 { Divider() }
                }
                if viewModel.worldClock.clocks.isEmpty {
                    Text("No cities yet — add one below")
                        .font(.caption).foregroundColor(.secondary)
                        .padding(.vertical, 14)
                }
            }
            .background(Color(.windowBackgroundColor).opacity(0.5))
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.gray.opacity(0.3)))

            caption("Reorder with the up/down arrows. Tap the red minus to remove a city.")

            if viewModel.worldClock.clocks.count < 6 {
                addCityBlock
            } else {
                Text("Maximum 6 cities. Remove one before adding.")
                    .font(.caption).foregroundColor(.secondary)
                    .padding(.top, 4)
            }
            resetWorldClockBlock
            footerCredit
        }
    }

    /// Extracted as a property so the parent ViewBuilder doesn't
    /// blow up Swift's type-checker. Searchable timezone picker
    /// (was an unsorted scroll of 400+ IANA identifiers — user
    /// report: "you cant use the bar to change where you are").
    @ViewBuilder
    private var addCityBlock: some View {
        sectionHeader("Add a city")
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                TextField("Search timezones — try \"Tokyo\" or \"Pacific\"",
                          text: $clockSearchText)
                    .textFieldStyle(.plain)
                    .padding(.vertical, 4)
            }
            .padding(.horizontal, 8)
            .frame(height: 28)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.gray.opacity(0.15))
            )
            timezonePickerScroll
            HStack(spacing: 8) {
                TextField("Label (optional, e.g. \"Mom\" or \"Tokyo office\")",
                          text: $newClockLabel)
                    .textFieldStyle(.roundedBorder)
                Button("Add") { addNewClock() }
                    .keyboardShortcut(.defaultAction)
                    .buttonStyle(.borderedProminent)
            }
        }
        caption("Search above, click a row to select, optionally rename, then Add. Selected: \(currentSelectionLabel)")
    }

    @ViewBuilder
    private var timezonePickerScroll: some View {
        let filtered = filteredTimezones(query: clockSearchText)
        let selectedTZ = currentSelectionLabel
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
                ForEach(Array(filtered.enumerated()),
                        id: \.element) { idx, tz in
                    timezonePickerButton(tz: tz, selectedTZ: selectedTZ)
                    if idx < filtered.count - 1 { Divider() }
                }
                if filtered.isEmpty {
                    Text("No timezones match \"\(clockSearchText)\"")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(12)
                }
            }
        }
        .frame(maxHeight: 180)
        .background(Color(.windowBackgroundColor).opacity(0.5))
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(Color.gray.opacity(0.25))
        )
    }

    private func timezonePickerButton(tz: String, selectedTZ: String) -> some View {
        let isSelected = tz == selectedTZ
        return Button {
            if let realIdx = WorldClockService
                .availableTimezones.firstIndex(of: tz) {
                newClockTimezoneIndex = realIdx
            }
        } label: {
            timezoneRow(tz: tz, isSelected: isSelected)
        }
        .buttonStyle(.plain)
    }

    private var currentSelectionLabel: String {
        WorldClockService.availableTimezones[safe: newClockTimezoneIndex] ?? "—"
    }

    @ViewBuilder
    private var resetWorldClockBlock: some View {
        sectionHeader("Reset")
        HStack {
            Button("Reset to defaults (Home + NY + London + Tokyo)") {
                resetWorldClockToDefaults()
            }
            .buttonStyle(.bordered)
            Spacer()
        }
        caption("If your World Clock has duplicate cities (Home + your local city showing the same time), tap this to rebuild from a clean default.")
    }

    private func resetWorldClockToDefaults() {
        UserDefaults.standard.removeObject(forKey: "np.worldClock.clocks")
        let home = TimeZone.current.identifier
        let homeFriendly = TimeZone.current.identifier
            .split(separator: "/").last
            .map { String($0).replacingOccurrences(of: "_", with: " ") }
            ?? "Home"
        let defaults: [(String, String)] = [
            (home,                  "Home (\(homeFriendly))"),
            ("America/New_York",    "New York"),
            ("Europe/London",       "London"),
            ("Asia/Tokyo",          "Tokyo"),
        ]
        var seen = Set<String>()
        viewModel.worldClock.clocks = defaults.compactMap { (id, label) in
            guard seen.insert(id).inserted else { return nil }
            return ClockEntry(timezoneIdentifier: id, label: label)
        }
    }

    /// Filter the IANA timezone list by a free-text query. Match is
    /// case-insensitive and substring-based on the identifier path
    /// AND on the trailing city portion (so "tokyo" finds
    /// "Asia/Tokyo" and "new york" finds "America/New_York" with
    /// the underscore stripped).
    private func filteredTimezones(query: String) -> [String] {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
        let all = WorldClockService.availableTimezones
        guard !q.isEmpty else { return all }
        return all.filter { tz in
            let lower = tz.lowercased()
            if lower.contains(q) { return true }
            // Match on the friendly city portion with underscores
            // converted to spaces — "new york" should find
            // "America/New_York".
            let friendly = lower.replacingOccurrences(of: "_", with: " ")
            return friendly.contains(q)
        }
    }

    private func timezoneRow(tz: String, isSelected: Bool) -> some View {
        let parts = tz.split(separator: "/")
        let region = parts.first.map(String.init) ?? ""
        let city = parts.last.map { String($0).replacingOccurrences(of: "_", with: " ") } ?? tz
        let now = Date()
        let f = DateFormatter()
        f.timeZone = TimeZone(identifier: tz)
        f.dateFormat = "HH:mm"
        let nowStr = f.string(from: now)

        return HStack(spacing: 8) {
            Image(systemName: "globe")
                .frame(width: 18)
                .foregroundColor(isSelected ? .accentColor : .secondary)
            VStack(alignment: .leading, spacing: 1) {
                Text(city)
                    .font(.system(size: 12, weight: .semibold))
                if region != city {
                    Text(region)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            Spacer()
            Text(nowStr)
                .font(.system(size: 12, weight: .heavy, design: .monospaced))
                .foregroundColor(.secondary)
            if isSelected {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.accentColor)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            isSelected ? Color.accentColor.opacity(0.10) : Color.clear
        )
        .contentShape(Rectangle())
    }

    private func moveClock(_ from: Int, by delta: Int) {
        let to = from + delta
        guard to >= 0 && to < viewModel.worldClock.clocks.count else { return }
        var arr = viewModel.worldClock.clocks
        arr.swapAt(from, to)
        viewModel.worldClock.clocks = arr
    }

    private func addNewClock() {
        let identifiers = WorldClockService.availableTimezones
        guard identifiers.indices.contains(newClockTimezoneIndex) else { return }
        let tz = identifiers[newClockTimezoneIndex]
        let label: String
        if !newClockLabel.trimmingCharacters(in: .whitespaces).isEmpty {
            label = newClockLabel
        } else {
            label = String(tz.split(separator: "/").last ?? Substring(tz)).replacingOccurrences(of: "_", with: " ")
        }
        viewModel.worldClock.add(ClockEntry(timezoneIdentifier: tz, label: label))
        newClockLabel = ""
    }

    // MARK: - Updates section
    /// New in v1.5.13. Auto-update was getting users stuck on stale
    /// versions when SUAutomaticallyUpdate=true silently queued an
    /// install that never landed. The Updates tab gives users a panic
    /// button (Force Update Now), surfaces the auto-check toggle in
    /// plain English, and shows when Sparkle last hit the appcast so
    /// you can tell whether it's even trying.
    @AppStorage("SUEnableAutomaticChecks") private var sparkleAutoCheck: Bool = true

    private var updatesSection: some View {
        scrollable {
            Text("Auto-updates").font(.headline)
            Text("Updates are signed with our EdDSA key. Your app verifies every release before installing.")
                .font(.caption).foregroundColor(.secondary)

            sectionHeader("Status")

            HStack(spacing: 10) {
                Image(systemName: "shippingbox.fill")
                    .foregroundColor(.accentColor)
                    .font(.system(size: 18))
                VStack(alignment: .leading, spacing: 2) {
                    Text("Currently running v\(appVersion)").font(.system(size: 13, weight: .semibold))
                    Text("Last checked: \(lastUpdateCheckLabel)")
                        .font(.caption).foregroundColor(.secondary)
                }
                Spacer()
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color.gray.opacity(0.08))
            )

            sectionHeader("Controls")

            HStack(spacing: 10) {
                Button {
                    appDelegate?.updater.checkForUpdates(nil)
                } label: {
                    Label("Check for Updates", systemImage: "arrow.triangle.2.circlepath")
                }
                .buttonStyle(.borderedProminent)

                Button {
                    appDelegate?.updater.forceUpdateNow(nil)
                } label: {
                    Label("Force Update Now", systemImage: "exclamationmark.arrow.triangle.2.circlepath")
                }
                .buttonStyle(.bordered)
                Spacer()
            }
            caption("Force Update Now wipes Sparkle's cached state (skipped versions, last-check time, HTTP cache) and re-checks. Use this if Sparkle insists you're up to date but the Releases page shows a newer version.")

            sectionHeader("Preferences")

            LabeledContent {
                Toggle("", isOn: $sparkleAutoCheck).labelsHidden()
            } label: {
                Text("Check for updates automatically")
            }
            caption("On = NotchPop checks the appcast every few hours. You'll always see a prompt before anything installs — silent install is off by default.")

            sectionHeader("Resources")
            HStack(spacing: 14) {
                Link("All Releases ↗",
                     destination: URL(string: "https://github.com/bendawg2010/NotchPop/releases")!)
                Link("Latest DMG ↗",
                     destination: URL(string: "https://github.com/bendawg2010/NotchPop/releases/latest/download/NotchPop.dmg")!)
                Link("Appcast (XML) ↗",
                     destination: URL(string: "https://notchpop.pages.dev/appcast.xml")!)
            }
            .font(.callout)
            caption("If auto-update keeps failing, downloading the DMG and replacing /Applications/NotchPop.app manually always works.")

            footerCredit
        }
    }

    /// Pretty-print SULastCheckTime from UserDefaults. Sparkle stores
    /// it as a Date; if missing or parseable, we fall back to "Never".
    private var lastUpdateCheckLabel: String {
        let key = "SULastCheckTime"
        guard let date = UserDefaults.standard.object(forKey: key) as? Date else {
            return "Never (auto-check hasn't fired yet)"
        }
        let f = RelativeDateTimeFormatter()
        f.unitsStyle = .full
        return f.localizedString(for: date, relativeTo: Date())
    }

    // MARK: - Diagnostics section
    /// Tools for users to grab info we'd ask them for in a bug report.
    @State private var copiedToClipboard = false

    private var diagnosticsSection: some View {
        scrollable {
            Text("Diagnostics").font(.headline)
            Text("Tools for troubleshooting positioning, screen detection, and update issues.")
                .font(.caption).foregroundColor(.secondary)

            sectionHeader("Screen detection")

            LabeledContent {
                Text(viewModel.screenInfo.hasNotch ? "Yes" : "No (using fallback pill)")
                    .foregroundColor(.secondary)
            } label: { Text("Notch detected") }

            LabeledContent {
                Text(String(format: "%.1f × %.1f pt",
                            viewModel.screenInfo.notchWidth,
                            viewModel.screenInfo.notchHeight))
                    .foregroundColor(.secondary)
                    .monospacedDigit()
            } label: { Text("Hardware notch size") }

            LabeledContent {
                Text(String(format: "%.1f pt", viewModel.screenInfo.notchCornerRadius))
                    .foregroundColor(.secondary)
                    .monospacedDigit()
            } label: { Text("Auto-detected corner radius") }

            HStack(spacing: 10) {
                Button {
                    // Wipe ScreenHelper's cached display ID so the
                    // next lookup re-resolves from scratch, then
                    // refresh viewModel.screenInfo + reposition.
                    ScreenHelper.invalidateCache()
                    viewModel.screenInfo = ScreenHelper.current()
                    repositionNotch()
                } label: {
                    Label("Re-detect screen", systemImage: "arrow.clockwise")
                }
                .buttonStyle(.bordered)

                Button {
                    repositionNotch()
                } label: {
                    Label("Re-center notch", systemImage: "scope")
                }
                .buttonStyle(.bordered)
                Spacer()
            }
            caption("Use these if you've plugged in a display or moved NotchPop to a different Mac and the notch is in the wrong spot.")

            sectionHeader("Diagnostic info")

            HStack(spacing: 10) {
                Button {
                    copyDiagnosticInfo()
                } label: {
                    Label(copiedToClipboard ? "Copied!" : "Copy diagnostic info",
                          systemImage: copiedToClipboard ? "checkmark.circle.fill" : "doc.on.doc")
                }
                .buttonStyle(.bordered)

                Button {
                    openConsoleLogs()
                } label: {
                    Label("Open Console.app", systemImage: "doc.text.magnifyingglass")
                }
                .buttonStyle(.bordered)
                Spacer()
            }
            caption("'Copy diagnostic info' grabs your version, screen list, notch dimensions, and current settings — paste into a GitHub issue. 'Open Console.app' lets you filter for 'NotchPop' to see runtime logs.")

            sectionHeader("Submit a bug report")
            HStack(spacing: 14) {
                Link("New issue ↗",
                     destination: URL(string: "https://github.com/bendawg2010/NotchPop/issues/new")!)
                Link("Existing issues ↗",
                     destination: URL(string: "https://github.com/bendawg2010/NotchPop/issues")!)
            }
            .font(.callout)
            caption("Please include the diagnostic info above so I can reproduce on a similar setup.")

            footerCredit
        }
    }

    /// Tell the window controller to recompute the notch's position.
    /// Useful if a user plugged in/out a display and the notch ended
    /// up on the wrong screen.
    private func repositionNotch() {
        guard let appDelegate = appDelegate else { return }
        appDelegate.notchWindowController?.repositionForCurrentScreen()
    }

    private func copyDiagnosticInfo() {
        let info = buildDiagnosticInfo()
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.setString(info, forType: .string)
        copiedToClipboard = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            copiedToClipboard = false
        }
    }

    private func openConsoleLogs() {
        // Open Console.app — user can filter for "NotchPop" in the search bar
        NSWorkspace.shared.launchApplication("Console")
    }

    private func buildDiagnosticInfo() -> String {
        let info = viewModel.screenInfo
        let screens = NSScreen.screens.enumerated().map { idx, s in
            "  [\(idx)] \(s.localizedName) frame=\(s.frame) safeTop=\(s.safeAreaInsets.top)"
        }.joined(separator: "\n")
        let lastCheck = (UserDefaults.standard.object(forKey: "SULastCheckTime") as? Date)
            .map { ISO8601DateFormatter().string(from: $0) } ?? "never"
        return """
        NotchPop v\(appVersion)
        macOS: \(ProcessInfo.processInfo.operatingSystemVersionString)
        Locale: \(Locale.current.identifier)

        Screen detection:
        - Notch detected: \(info.hasNotch)
        - Notch size: \(info.notchWidth) × \(info.notchHeight) pt
        - Corner radius: \(info.notchCornerRadius) pt

        All screens:
        \(screens)

        Settings:
        - Visible tabs: \(viewModel.visibleTabs.map { $0.rawValue }.joined(separator: ", "))
        - Default tab: \(viewModel.defaultTab.rawValue)
        - Hover delay: \(Int(viewModel.hoverDelay * 1000)) ms
        - Collapse delay: \(Int(viewModel.collapseDelay * 1000)) ms
        - Live activities: \(viewModel.liveActivitiesEnabled)
        - Hide in fullscreen: \(viewModel.hideInFullscreen)
        - Width nudge: \(viewModel.notchWidthOffset) pt
        - Height extension: \(viewModel.notchHeightExtension) pt
        - Corner radius override: \(viewModel.notchCornerRadiusOverride) pt
        - Accent: \(viewModel.accentChoice.rawValue)
        - 24-hour clock: \(viewModel.clockUses24Hour)
        - Reduced motion: \(viewModel.reducedMotion)

        Sparkle:
        - Last check: \(lastCheck)
        - Auto-check: \(UserDefaults.standard.object(forKey: "SUEnableAutomaticChecks") as? Bool ?? true)
        """
    }

    /// Cast NSApp.delegate to AppDelegate so the Updates + Diagnostics
    /// tabs can call into the updater + window controller. Returns nil
    /// in SwiftUI previews (where there's no app delegate).
    private var appDelegate: AppDelegate? {
        NSApp.delegate as? AppDelegate
    }

    // MARK: - About
    private var aboutSection: some View {
        scrollable {
            Text("NotchPop").font(.title2.bold())
            Text("v\(appVersion) · Free · MIT licensed").font(.subheadline).foregroundColor(.secondary)

            sectionHeader("About")
            Text("Hover the notch to expand. Drop files in. Drag them back out anywhere. Music works with Apple Music + Spotify (transport controls included).")
                .font(.callout)

            sectionHeader("Tour")
            HStack(spacing: 12) {
                Button {
                    viewModel.runWelcomePeek()
                } label: {
                    Label("Replay welcome animation", systemImage: "play.circle.fill")
                }
                .buttonStyle(.bordered)
                Spacer()
            }
            caption("Plays the first-launch peek so you can revisit the intro.")

            sectionHeader("Keyboard shortcuts")
            VStack(alignment: .leading, spacing: 4) {
                Text("Cmd+,").bold() + Text(" — Open Settings (when Settings window is focused)")
                Text("Cmd+U").bold() + Text(" — Check for Updates (from menubar menu)")
                Text("Cmd+Q").bold() + Text(" — Quit NotchPop")
            }
            .font(.callout)

            sectionHeader("Links")
            HStack(spacing: 14) {
                Link("GitHub", destination: URL(string: "https://github.com/bendawg2010/NotchPop")!)
                Link("Releases", destination: URL(string: "https://github.com/bendawg2010/NotchPop/releases")!)
                Link("Sponsor", destination: URL(string: "https://github.com/sponsors/bendawg2010")!)
            }
            .font(.callout)

            sectionHeader("Danger zone")
            HStack {
                Button(role: .destructive) {
                    showResetConfirm = true
                } label: {
                    Label("Reset all settings", systemImage: "arrow.counterclockwise")
                }
                .buttonStyle(.bordered)
                Spacer()
            }
            caption("Wipes all NotchPop preferences (np.* keys). Your file shelf and notes are untouched.")

            footerCredit
        }
        .alert("Reset all NotchPop settings?", isPresented: $showResetConfirm) {
            Button("Cancel", role: .cancel) { }
            Button("Reset", role: .destructive) {
                resetAllSettings()
            }
        } message: {
            Text("Reset all NotchPop settings? This won't delete your file shelf or notes — just preferences.")
        }
    }

    /// Sub-view so we can hold @State for press-flash without
    /// needing one State-per-arrow on the parent.
    private struct ArrowTapButton: View {
        let symbol: String
        let disabled: Bool
        let action: () -> Void
        @State private var pressed = false
        @State private var flashed = false

        var body: some View {
            Button {
                guard !disabled else { return }
                withAnimation(.easeOut(duration: 0.06)) { flashed = true }
                action()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
                    withAnimation(.easeIn(duration: 0.18)) { flashed = false }
                }
            } label: {
                Image(systemName: symbol)
                    .font(.system(size: 13, weight: .heavy))
                    .frame(width: 32, height: 32)
                    .background(
                        RoundedRectangle(cornerRadius: 7, style: .continuous)
                            .fill(disabled
                                  ? Color.gray.opacity(0.04)
                                  : Color.accentColor.opacity(flashed ? 0.40
                                                              : (pressed ? 0.28 : 0.14)))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 7, style: .continuous)
                            .stroke(Color.accentColor.opacity(disabled ? 0 : 0.35),
                                    lineWidth: 0.75)
                    )
                    .foregroundColor(disabled ? Color.secondary.opacity(0.45) : .accentColor)
                    .scaleEffect(pressed ? 0.92 : 1.0)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(disabled)
            .opacity(disabled ? 0.45 : 1.0)
            .onLongPressGesture(minimumDuration: .infinity,
                                maximumDistance: 8,
                                perform: { },
                                onPressingChanged: { isPressing in
                withAnimation(.easeOut(duration: 0.06)) {
                    pressed = isPressing
                }
            })
        }
    }

    /// Wipe every `np.*` key from UserDefaults and post a relaunch request.
    private func resetAllSettings() {
        let defaults = UserDefaults.standard
        let dict = defaults.dictionaryRepresentation()
        for key in dict.keys where key.hasPrefix("np.") {
            defaults.removeObject(forKey: key)
        }
        defaults.synchronize()
        NotificationCenter.default.post(name: Notification.Name("np.requestRelaunch"), object: nil)
    }
}
