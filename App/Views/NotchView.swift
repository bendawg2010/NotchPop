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

    var body: some View {
        ZStack(alignment: .top) {
            // The actual visible notch (black, rounded bottom corners)
            NotchShape(bottomCornerRadius: viewModel.expanded ? 18 : 8)
                .fill(Color.black)
                .overlay(
                    NotchShape(bottomCornerRadius: viewModel.expanded ? 18 : 8)
                        .stroke(Color.white.opacity(0.06), lineWidth: 0.5)
                )
                .frame(height: viewModel.targetSize.height)

            // Expanded content sits inside the bottom of the shape
            if viewModel.expanded {
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
            viewModel.expanded = true
        } else {
            // Don't collapse during the welcome peek — the timer in
            // NotchViewModel handles that timing.
            if viewModel.showingWelcome { return }
            // Grace period so the user can dart in/out without losing it.
            let work = DispatchWorkItem { [weak vm = viewModel] in
                guard let vm = vm else { return }
                if !vm.hovering {
                    withAnimation(.spring(response: 0.42, dampingFraction: 0.85)) {
                        vm.expanded = false
                    }
                }
            }
            collapseWorkItem = work
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.18, execute: work)
        }
    }

    @ViewBuilder
    private var expandedContent: some View {
        if viewModel.showingWelcome {
            WelcomeCard()
                .transition(.opacity)
        } else {
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
    }

    private var tabBar: some View {
        HStack(spacing: 4) {
            ForEach(viewModel.visibleTabs) { tab in
                tabButton(tab)
            }
            Spacer()
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
        case .battery:
            ChargingView(monitor: viewModel.charging)
        }
    }
}
