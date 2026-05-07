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

    var body: some View {
        ZStack {
            NotchShape(bottomCornerRadius: viewModel.expanded ? 16 : 8)
                .fill(Color.black)
                .overlay(
                    NotchShape(bottomCornerRadius: viewModel.expanded ? 16 : 8)
                        .stroke(Color.white.opacity(0.04), lineWidth: 0.5)
                )

            if viewModel.expanded {
                expandedContent
                    .padding(.top, max(viewModel.screenInfo.notchHeight, 32))
                    .padding(.horizontal, 16)
                    .padding(.bottom, 16)
                    .transition(.opacity.combined(with: .scale(scale: 0.96)))
            }
        }
        .frame(width: viewModel.targetSize.width, height: viewModel.targetSize.height)
        .animation(.spring(response: 0.42, dampingFraction: 0.78), value: viewModel.expanded)
        .onHover { hovering in
            viewModel.hovering = hovering
            if hovering {
                viewModel.expanded = true
            } else {
                // Slight delay so cursor brushing the edge doesn't
                // collapse instantly.
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                    if !viewModel.hovering {
                        viewModel.expanded = false
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var expandedContent: some View {
        VStack(spacing: 8) {
            tabBar
            paneFor(viewModel.activeTab)
        }
    }

    private var tabBar: some View {
        HStack(spacing: 6) {
            ForEach(NotchTab.allCases) { tab in
                Button {
                    viewModel.activeTab = tab
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
                            .fill(viewModel.activeTab == tab
                                  ? Color.white.opacity(0.12)
                                  : Color.clear)
                    )
                    .foregroundColor(viewModel.activeTab == tab ? .white : .white.opacity(0.55))
                }
                .buttonStyle(.plain)
            }
            Spacer()
        }
    }

    @ViewBuilder
    private func paneFor(_ tab: NotchTab) -> some View {
        switch tab {
        case .shelf:
            FileShelfView(shelf: viewModel.shelf)
        case .nowPlaying:
            NowPlayingView(service: viewModel.nowPlaying)
        case .battery:
            ChargingView(monitor: viewModel.charging)
        }
    }
}
