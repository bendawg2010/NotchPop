// SettingsView.swift
//
// Real settings window. Two sections:
//   • Customize tabs — checkbox list with drag-to-reorder
//   • Pomodoro — focus / short / long durations, cycle length
//   • About — version, links, credits
//
// Persists everything via UserDefaults through NotchViewModel.

import SwiftUI

struct SettingsView: View {
    @ObservedObject var viewModel: NotchViewModel
    @State private var draggingTab: NotchTab?
    @State private var showResetConfirm = false

    private var appVersion: String {
        (Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String) ?? "?"
    }

    var body: some View {
        TabView {
            tabsSection
                .tabItem { Label("Tabs", systemImage: "rectangle.stack") }
            behaviorSection
                .tabItem { Label("Behavior", systemImage: "slider.horizontal.3") }
            pomodoroSection
                .tabItem { Label("Pomodoro", systemImage: "timer") }
            worldClockSection
                .tabItem { Label("World Clock", systemImage: "globe") }
            aboutSection
                .tabItem { Label("About", systemImage: "info.circle") }
        }
        .frame(width: 540, height: 600)
        .padding(20)
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

    // MARK: - Tabs section
    private var tabsSection: some View {
        VStack(alignment: .leading, spacing: 14) {
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

            Spacer()

            HStack {
                Button("Reset to default order") {
                    viewModel.visibleTabs = NotchTab.allCases
                }
                .buttonStyle(.bordered)
                Spacer()
                Text("\(viewModel.visibleTabs.count) of \(NotchTab.allCases.count) visible")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

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
                // Hide arrows entirely at the boundaries instead of showing them disabled.
                if !isFirst {
                    Button {
                        moveTab(tab, by: -1)
                    } label: { Image(systemName: "arrow.up") }
                        .buttonStyle(.borderless)
                } else {
                    // Reserve the same width so the toggle column doesn't jump.
                    Image(systemName: "arrow.up").opacity(0).accessibilityHidden(true)
                }
                if !isLast {
                    Button {
                        moveTab(tab, by: 1)
                    } label: { Image(systemName: "arrow.down") }
                        .buttonStyle(.borderless)
                } else {
                    Image(systemName: "arrow.down").opacity(0).accessibilityHidden(true)
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
                        // Always keep at least one tab visible
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
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 14) {
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
                    Text("Live activities flanking the notch (music + timer)")
                }
                caption("When music is playing or a timer is running, slim pills appear on either side of the collapsed notch — track info on the right, countdown on the left. Tap either to open it.")

                LabeledContent {
                    Toggle("", isOn: $viewModel.pomodoroFollowsActive).labelsHidden()
                } label: {
                    Text("Auto-switch to Pomodoro tab when timer starts")
                }
                caption("On = expanding the notch during a focus session lands on Pomodoro instead of your default tab.")

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
                // Notch-fit overrides — for users whose collapsed notch
                // doesn't quite blend with their hardware. Auto-detection
                // is right for most M-series MBPs but a few have slightly
                // different bezel radii / cutout widths.
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

                Spacer(minLength: 8)
                footerCredit
            }
            .padding(.bottom, 10)
        }
    }

    private func formatOffset(_ v: Double) -> String {
        let rounded = (v * 2).rounded() / 2
        if rounded == 0 { return "0 pt" }
        return String(format: "%@%.1f pt", v > 0 ? "+" : "", rounded)
    }

    // MARK: - Pomodoro section
    private var pomodoroSection: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 14) {
                Text("Pomodoro durations").font(.headline)

                // ── Durations ────────────────────────────────────────
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

                // ── Flow ─────────────────────────────────────────────
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

                // ── Sound ────────────────────────────────────────────
                // Sound options — apply to BOTH Pomodoro and the Countdown
                // timer (the standalone "set 7 minutes for the oven" one).
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
                        // Preview ALWAYS plays, regardless of master toggle —
                        // the user is actively asking to hear it.
                        TimerSound.playRaw(name: viewModel.timerSoundName)
                    } label: {
                        Label("Preview", systemImage: "speaker.wave.2.fill")
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
                .opacity(viewModel.soundEffectsEnabled ? 1 : 0.55)
                caption("Preview always plays, even when the master toggle is off.")

                Spacer(minLength: 8)
                Button("Reset Pomodoro session") { viewModel.pomodoro.reset() }
                    .buttonStyle(.bordered)

                footerCredit
            }
            .padding(.bottom, 10)
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

    private var worldClockSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("World Clock cities").font(.headline)
            Text("Up to 4 cities show in the World Clock tab.")
                .font(.caption).foregroundColor(.secondary)

            sectionHeader("Your cities")

            // Existing cities — list with delete/move buttons
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
                        // Boundary-aware arrows: hide instead of disabling.
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

            // Add-new row
            if viewModel.worldClock.clocks.count < 6 {
                sectionHeader("Add a city")
                HStack(spacing: 8) {
                    Picker("", selection: $newClockTimezoneIndex) {
                        ForEach(Array(WorldClockService.availableTimezones.enumerated()),
                                id: \.offset) { i, tz in
                            Text(tz).tag(i)
                        }
                    }
                    .labelsHidden()
                    .frame(maxWidth: 220)
                    TextField("Label (optional)", text: $newClockLabel)
                        .textFieldStyle(.roundedBorder)
                    Button("Add") { addNewClock() }
                        .keyboardShortcut(.defaultAction)
                        .buttonStyle(.borderedProminent)
                }
                caption("Pick an IANA timezone, optionally rename it, then click Add.")
            } else {
                Text("Maximum 6 cities. Remove one before adding.")
                    .font(.caption).foregroundColor(.secondary)
                    .padding(.top, 4)
            }
            Spacer()
            footerCredit
        }
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

    // MARK: - About
    private var aboutSection: some View {
        VStack(alignment: .leading, spacing: 12) {
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

            sectionHeader("Links")
            HStack(spacing: 14) {
                Link("GitHub", destination: URL(string: "https://github.com/bendawg2010/NotchPop")!)
                Link("Releases", destination: URL(string: "https://github.com/bendawg2010/NotchPop/releases")!)
                Link("Sponsor", destination: URL(string: "https://github.com/sponsors/bendawg2010")!)
            }
            .font(.callout)

            Spacer()

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

    /// Wipe every `np.*` key from UserDefaults and post a relaunch request.
    private func resetAllSettings() {
        let defaults = UserDefaults.standard
        let dict = defaults.dictionaryRepresentation()
        for key in dict.keys where key.hasPrefix("np.") {
            defaults.removeObject(forKey: key)
        }
        defaults.synchronize()
        // Notify the rest of the app that a relaunch is desired. The app
        // delegate (or anyone listening) can respond — fall back is just
        // to leave the user with a fresh defaults state on next launch.
        NotificationCenter.default.post(name: Notification.Name("np.requestRelaunch"), object: nil)
    }
}
