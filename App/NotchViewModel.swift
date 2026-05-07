// NotchViewModel.swift
//
// Centralized state for the notch UI. Owned by AppDelegate, observed
// by every view. Tracks: collapsed/expanded animation state, which
// "tabs" of content to show, file shelf data, screen info.

import AppKit
import Combine
import SwiftUI

/// Tabs / panes shown when the notch is expanded.
enum NotchTab: String, CaseIterable, Identifiable {
    case shelf = "Shelf"
    case nowPlaying = "Now Playing"
    case battery = "Battery"

    var id: String { rawValue }
    var icon: String {
        switch self {
        case .shelf:      return "tray.full.fill"
        case .nowPlaying: return "music.note"
        case .battery:    return "battery.100"
        }
    }
}

final class NotchViewModel: ObservableObject {
    // MARK: - State
    @Published var expanded: Bool = false
    @Published var hovering: Bool = false
    @Published var activeTab: NotchTab = .shelf
    @Published var screenInfo: ScreenInfo = ScreenHelper.current()

    @Published var nowPlayingEnabled: Bool = true
    @Published var chargingEnabled: Bool = true
    @Published var persistShelfBetweenLaunches: Bool = false

    // MARK: - Children
    let shelf = FileShelf()
    let nowPlaying = NowPlayingService()
    let charging = ChargingMonitor()

    // MARK: - Notify window controller of size changes
    var onSizeChange: (() -> Void)?

    private var bag = Set<AnyCancellable>()

    init() {
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

        // Start services
        nowPlaying.start()
        charging.start()
    }

    /// Compact size — just covers the physical notch when collapsed.
    var compactSize: CGSize {
        let info = screenInfo
        let h = max(info.notchHeight, 32)
        let w = max(info.notchWidth, 200)
        return CGSize(width: w, height: h)
    }

    /// Expanded size — wide enough for the file shelf row + tabs.
    var expandedSize: CGSize {
        CGSize(width: 520, height: 165)
    }

    /// What size the host window should currently be.
    var targetSize: CGSize {
        expanded ? expandedSize : compactSize
    }

    func persistShelfIfEnabled() {
        if persistShelfBetweenLaunches { shelf.persist() }
    }
}
