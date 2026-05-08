// NotchView.swift
//
// Root SwiftUI view rendered into the floating NSWindow. Two states:
//   • collapsed → just the black notch shape, hugging the screen
//   • expanded → wider, taller, shows tabs + active pane
//
// Hover detection lives here. We use SwiftUI's onHover; AppKit hover
// tracking would also work but onHover is sufficient because the
// window frame matches the visible notch.

import SwiftUI

struct NotchView: View {
    @ObservedObject var viewModel: NotchViewModel
    @State private var collapseWorkItem: DispatchWorkItem?
    /// True while the user has a drag (file from Finder, etc.) hovered
    /// over our window. Drives auto-expand-on-hover so the notch grows
    /// into a big drop target before they release the mouse.
    @State private var isDragHovering: Bool = false

    /// Extra invisible padding below the visible notch. Was 18pt
    /// (made the hit zone bigger but triggered accidentally any
    /// time the user moved past the top of the screen). Now 4pt —
    /// just enough to absorb sub-pixel mouse rounding without
    /// extending into "menu bar territory."
    private let hoverGutter: CGFloat = 4

    /// Corner radius for the visible notch. Compact = hardware-matched
    /// (so the drawn shape is indistinguishable from the real notch),
    /// honoring any user override from Settings → Notch fit.
    /// Expanded = larger for a friendlier rounded panel.
    private var bottomCornerRadius: CGFloat {
        viewModel.expanded ? 22 : viewModel.compactCornerRadius
    }

    /// True when the notch should be drawn at all. Hides entirely when
    /// the user enabled "hide in fullscreen" and any app is fullscreen.
    private var shouldRender: Bool {
        if viewModel.hideInFullscreen && viewModel.fullscreen.anyAppFullscreen {
            return viewModel.expanded // still allow it during welcome peek
        }
        return true
    }

    /// The current dimensions of the visible black shape — wider
    /// when expanded OR when a live activity is showing (integrated
    /// pill style), narrowest at hardware-notch dimensions otherwise.
    private var visibleShapeSize: CGSize {
        if viewModel.expanded { return viewModel.targetSize }
        if viewModel.hasAnyLiveActivity { return viewModel.compactSizeWithActivities }
        return viewModel.compactSize
    }

    var body: some View {
        ZStack(alignment: .top) {
            // ONE integrated black notch shape. When something is
            // active (timer / music), the shape grows wider into a
            // pill that contains the activity content (icon + signal).
            // The hardware notch sits in the middle of this pill —
            // since both are pure black, it reads as one continuous
            // shape. NotchNook does the same.
            NotchShape(bottomCornerRadius: bottomCornerRadius)
                .fill(Color.black)
                .frame(width: visibleShapeSize.width,
                       height: visibleShapeSize.height)
                .opacity(shouldRender ? 1 : 0)
                .overlay {
                    // Drop ring while a drag is over us
                    if isDragHovering {
                        NotchShape(bottomCornerRadius: bottomCornerRadius)
                            .stroke(LinearGradient(colors: [
                                Color(red: 1.00, green: 0.24, blue: 0.67),
                                Color(red: 0.17, green: 0.52, blue: 0.77),
                            ], startPoint: .leading, endPoint: .trailing),
                                    lineWidth: 2)
                            .frame(width: visibleShapeSize.width,
                                   height: visibleShapeSize.height)
                            .transition(.opacity)
                    }
                }
                .overlay {
                    // Live activity content (icon + audio bars / time)
                    // sits INSIDE the shape when collapsed.
                    if !viewModel.expanded && viewModel.hasAnyLiveActivity {
                        LiveActivityBar(viewModel: viewModel)
                            .frame(width: visibleShapeSize.width,
                                   height: visibleShapeSize.height)
                            .transition(.opacity)
                    }
                }
                .frame(width: viewModel.targetSize.width,
                       height: viewModel.targetSize.height,
                       alignment: .center)

            // Expanded content sits inside the bottom of the shape
            if viewModel.expanded && !viewModel.showingWelcome {
                expandedContent
                    .padding(.top, max(viewModel.screenInfo.notchHeight, 32))
                    .padding(.horizontal, 16)
                    .padding(.bottom, 16)
                    .frame(width: viewModel.expandedSize.width,
                           height: viewModel.expandedSize.height)
                    .transition(.asymmetric(
                        insertion: .opacity.combined(with: .scale(scale: 0.94, anchor: .top))
                                          .animation(.spring(response: 0.45, dampingFraction: 0.80).delay(0.05)),
                        removal:   .opacity.animation(.easeOut(duration: 0.12))
                    ))
            } else if viewModel.expanded && viewModel.showingWelcome {
                WelcomeCard()
                    .padding(.top, max(viewModel.screenInfo.notchHeight, 32))
                    .padding(.horizontal, 16)
                    .padding(.bottom, 16)
                    .frame(width: viewModel.expandedSize.width,
                           height: viewModel.expandedSize.height)
                    .transition(.opacity)
            }
        }
        .frame(width: viewModel.targetSize.width,
               height: viewModel.targetSize.height + hoverGutter,
               alignment: .top)
        // Invisible gutter beneath the notch so brushing toward it
        // still triggers expansion. We keep .contentShape(Rectangle())
        // so the whole frame counts as hoverable AND drop-targeted —
        // the drop hit area is the entire window, not just the visible
        // notch (which would be a tiny ~178x32 target to aim at).
        .contentShape(Rectangle())
        .animation(.spring(response: 0.42, dampingFraction: 0.78), value: viewModel.expanded)
        .animation(.easeOut(duration: 0.15), value: isDragHovering)
        .onHover(perform: onHoverChange)
        // Drop handler covers the FULL window — drag a file anywhere
        // near the notch and it counts. Auto-expands to Shelf the
        // moment the drag touches us, so users get a generous drop
        // target instead of a 178pt-wide notch sliver.
        .onDrop(of: [.fileURL], isTargeted: dragTargetBinding) { providers in
            handleFileDrop(providers: providers)
        }
    }

    /// Binding that toggles isDragHovering AND auto-expands the notch
    /// to Shelf the moment a drag enters our window. SwiftUI calls
    /// this with `true` on enter, `false` on leave.
    private var dragTargetBinding: Binding<Bool> {
        Binding(
            get: { isDragHovering },
            set: { newValue in
                isDragHovering = newValue
                if newValue {
                    // Force the Shelf tab to be visible even if the
                    // user has hidden it — we want a real drop target,
                    // not just a "the file went somewhere invisible"
                    // outcome. We only ADD shelf to visibleTabs if
                    // it's already missing; otherwise we just switch
                    // to it.
                    if !viewModel.visibleTabs.contains(.shelf) {
                        viewModel.visibleTabs.insert(.shelf, at: 0)
                    }
                    viewModel.activeTab = .shelf
                    viewModel.expanded = true
                    // Cancel any pending hover-collapse timer
                    collapseWorkItem?.cancel()
                } else {
                    // Drag left without dropping — collapse after the
                    // standard grace period, unless a real mouse-hover
                    // is keeping us open.
                    if !viewModel.hovering && !viewModel.showingWelcome {
                        let work = DispatchWorkItem { [weak vm = viewModel] in
                            guard let vm = vm else { return }
                            if !vm.hovering {
                                withAnimation(.spring(response: 0.42, dampingFraction: 0.85)) {
                                    vm.expanded = false
                                }
                            }
                        }
                        collapseWorkItem = work
                        DispatchQueue.main.asyncAfter(
                            deadline: .now() + max(0.15, viewModel.collapseDelay),
                            execute: work)
                    }
                }
            }
        )
    }

    private func handleFileDrop(providers: [NSItemProvider]) -> Bool {
        // Make sure we land on the Shelf tab (in case it wasn't visible
        // and the drag-hover branch above didn't switch us).
        if viewModel.visibleTabs.contains(.shelf) {
            viewModel.activeTab = .shelf
        }
        viewModel.expanded = true

        var urls: [URL] = []
        let group = DispatchGroup()
        for p in providers {
            group.enter()
            _ = p.loadObject(ofClass: URL.self) { url, _ in
                if let u = url { urls.append(u) }
                group.leave()
            }
        }
        group.notify(queue: .main) {
            viewModel.shelf.add(urls: urls)
            isDragHovering = false
        }
        return true
    }

    private func onHoverChange(_ hovering: Bool) {
        viewModel.hovering = hovering
        collapseWorkItem?.cancel()

        if hovering {
            // Optional hover delay so brushing-the-notch doesn't always trigger.
            let delay = max(0, viewModel.hoverDelay)
            if delay <= 0.001 {
                viewModel.expanded = true
            } else {
                let work = DispatchWorkItem { [weak vm = viewModel] in
                    guard let vm = vm, vm.hovering else { return }
                    withAnimation(.spring(response: 0.42, dampingFraction: 0.78)) {
                        vm.expanded = true
                    }
                }
                collapseWorkItem = work
                DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: work)
            }
        } else {
            // Don't collapse during the welcome peek — the timer in
            // NotchViewModel handles that timing.
            if viewModel.showingWelcome { return }
            // Grace period so the user can dart in/out without losing it.
            let delay = max(0.05, viewModel.collapseDelay)
            let work = DispatchWorkItem { [weak vm = viewModel] in
                guard let vm = vm else { return }
                if !vm.hovering {
                    withAnimation(.spring(response: 0.42, dampingFraction: 0.85)) {
                        vm.expanded = false
                    }
                }
            }
            collapseWorkItem = work
            DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: work)
        }
    }

    @ViewBuilder
    private var expandedContent: some View {
        VStack(spacing: 8) {
            tabBar
            paneFor(viewModel.activeTab)
                .id(viewModel.activeTab) // force a transition between tabs
                .transition(.asymmetric(
                    insertion: .opacity.combined(with: .move(edge: .trailing)),
                    removal:   .opacity.combined(with: .move(edge: .leading))
                ))
        }
        .animation(.spring(response: 0.32, dampingFraction: 0.85), value: viewModel.activeTab)
    }

    /// Tab bar runs along the top of the expanded notch; on the right
    /// we mount a Settings gear, a compact battery indicator, and a
    /// version label so they're always visible without needing tabs.
    private var tabBar: some View {
        HStack(spacing: 4) {
            ForEach(viewModel.visibleTabs) { tab in
                tabButton(tab)
            }
            Spacer(minLength: 6)
            settingsGearButton
            InlineBatteryIndicator(monitor: viewModel.charging)
            versionLabel
        }
    }

    /// Tiny gear icon — clicking opens the Settings window. Lives in
    /// the expanded notch top-right next to the battery so users can
    /// reach Settings without going to the menu bar.
    private var settingsGearButton: some View {
        Button {
            (NSApp.delegate as? AppDelegate)?.openSettings()
        } label: {
            Image(systemName: "gearshape.fill")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.white.opacity(0.65))
                .frame(width: 22, height: 22)
                .background(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(Color.white.opacity(0.05))
                )
        }
        .buttonStyle(.plain)
        .help("Settings")
    }

    /// Small version label showing the current build (CFBundleShortVersionString).
    /// Tooltip shows the full version + a hint to check for updates.
    private var versionLabel: some View {
        let v = (Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String) ?? "?"
        return Text("v\(v)")
            .font(.system(size: 9, weight: .heavy, design: .rounded))
            .foregroundColor(.white.opacity(0.45))
            .help("NotchPop v\(v) — Check for Updates from the menubar (⌘U)")
    }

    private func tabButton(_ tab: NotchTab) -> some View {
        let on = viewModel.activeTab == tab
        return Button {
            withAnimation(.spring(response: 0.32, dampingFraction: 0.85)) {
                viewModel.activeTab = tab
            }
        } label: {
            HStack(spacing: 4) {
                Image(systemName: tab.icon)
                    .font(.system(size: 11, weight: .semibold))
                Text(tab.rawValue)
                    .font(.system(size: 11, weight: .semibold))
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(on ? Color.white.opacity(0.12) : Color.clear)
            )
            .foregroundColor(on ? .white : .white.opacity(0.55))
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func paneFor(_ tab: NotchTab) -> some View {
        switch tab {
        case .shelf:
            FileShelfView(shelf: viewModel.shelf)
        case .nowPlaying:
            NowPlayingView(service: viewModel.nowPlaying)
        case .pomodoro:
            PomodoroView(service: viewModel.pomodoro)
        case .timers:
            TimersTabView(stopwatch: viewModel.stopwatch, countdown: viewModel.countdown)
        case .worldClock:
            WorldClockView(service: viewModel.worldClock)
        case .notes:
            NotesView(service: viewModel.notes)
        case .clipboard:
            ClipboardView(service: viewModel.clipboard)
        case .systemStats:
            SystemStatsView(service: viewModel.systemStats)
        case .calendar:
            CalendarView(service: viewModel.calendar)
        case .airpods:
            AirPodsView(service: viewModel.airpods)
        }
    }
}
