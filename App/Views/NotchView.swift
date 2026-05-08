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

    /// Extra invisible padding below the visible notch — clicks pass
    /// through but the hover hit-area extends further so users don't
    /// have to land mouse on a 30px-tall strip.
    private let hoverGutter: CGFloat = 18

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

    var body: some View {
        ZStack(alignment: .top) {
            // Pure-black notch silhouette — NO border, NO opacity.
            // When collapsed, dimensions match the hardware notch
            // exactly so the drawn shape is indistinguishable from
            // the physical cutout above it. When expanded, the shape
            // grows downward + outward with a continuous-corner curve.
            NotchShape(bottomCornerRadius: bottomCornerRadius)
                .fill(Color.black)
                .frame(width: viewModel.targetSize.width,
                       height: viewModel.targetSize.height)
                .opacity(shouldRender ? 1 : 0)
                // When the user starts dragging a file from Finder
                // toward the notch, auto-expand + switch to Shelf.
                // Per user feedback: "when you drag a file it should
                // show shelf".
                .onDrop(of: [.fileURL], isTargeted: nil) { providers in
                    if viewModel.visibleTabs.contains(.shelf) {
                        viewModel.activeTab = .shelf
                        viewModel.expanded = true
                    }
                    // Forward the drop to the FileShelf service so
                    // the file lands in the shelf even if the user
                    // released on the collapsed notch.
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
                    }
                    return true
                }

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
        // so the whole frame counts as hoverable.
        .contentShape(Rectangle())
        .animation(.spring(response: 0.42, dampingFraction: 0.78), value: viewModel.expanded)
        .onHover(perform: onHoverChange)
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
    /// we mount a compact battery indicator so it's always visible
    /// without needing a dedicated tab.
    private var tabBar: some View {
        HStack(spacing: 4) {
            ForEach(viewModel.visibleTabs) { tab in
                tabButton(tab)
            }
            Spacer(minLength: 6)
            InlineBatteryIndicator(monitor: viewModel.charging)
        }
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
        }
    }
}
