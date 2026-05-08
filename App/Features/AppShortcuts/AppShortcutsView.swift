// AppShortcutsView.swift
//
// Pane shown inside the expanded notch when the App Shortcuts tab is
// active. Horizontally-scrolling row of icon tiles. Click to launch
// the app or open the URL. Empty state nudges the user to add some
// from Settings → Tabs → App Shortcuts.

import AppKit
import SwiftUI

struct AppShortcutsView: View {
    @ObservedObject var service: AppShortcutsService

    var body: some View {
        Group {
            if service.items.isEmpty {
                emptyState
            } else {
                shortcutRow
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 88)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.white.opacity(0.04))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(Color.white.opacity(0.08), lineWidth: 1)
                )
        )
    }

    private var emptyState: some View {
        HStack(spacing: 10) {
            Spacer(minLength: 0)
            Image(systemName: "square.grid.3x3.fill")
                .font(.system(size: 18))
                .foregroundColor(.white.opacity(0.5))
            VStack(alignment: .leading, spacing: 1) {
                Text("App Shortcuts")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.white.opacity(0.78))
                Text("Pin apps + URLs in Settings → Tabs → App Shortcuts")
                    .font(.system(size: 10))
                    .foregroundColor(.white.opacity(0.55))
            }
            Spacer(minLength: 0)
            Button {
                (NSApp.delegate as? AppDelegate)?.openSettings()
            } label: {
                Text("Add")
                    .font(.system(size: 11, weight: .heavy))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(
                        RoundedRectangle(cornerRadius: 7, style: .continuous)
                            .fill(LinearGradient(
                                colors: [Color(red: 1.00, green: 0.24, blue: 0.67),
                                         Color(red: 0.17, green: 0.52, blue: 0.97)],
                                startPoint: .leading, endPoint: .trailing)))
                    .foregroundColor(.white)
            }
            .buttonStyle(.plain)
            .padding(.trailing, 14)
        }
        .padding(.horizontal, 14)
    }

    private var shortcutRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(service.items) { item in
                    ShortcutTile(item: item, service: service)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
        }
    }
}

private struct ShortcutTile: View {
    let item: ShortcutItem
    @ObservedObject var service: AppShortcutsService
    @State private var hovered = false
    @State private var pressed = false

    var body: some View {
        Button {
            // Tiny press animation so the user gets feedback that the
            // click registered, especially since the app launch can
            // take 1-2s.
            withAnimation(.easeOut(duration: 0.08)) { pressed = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.10) {
                withAnimation(.easeIn(duration: 0.18)) { pressed = false }
            }
            service.launch(item)
        } label: {
            VStack(spacing: 3) {
                iconView
                    .frame(width: 38, height: 38)
                    .background(
                        RoundedRectangle(cornerRadius: 9, style: .continuous)
                            .fill(Color.white.opacity(hovered ? 0.14 : 0.08))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 9, style: .continuous)
                            .stroke(Color.white.opacity(hovered ? 0.22 : 0.10),
                                    lineWidth: 0.5)
                    )
                    .scaleEffect(pressed ? 0.92 : (hovered ? 1.04 : 1.0))
                Text(item.title)
                    .font(.system(size: 9, weight: .heavy))
                    .foregroundColor(.white.opacity(0.85))
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .frame(maxWidth: 56)
            }
        }
        .buttonStyle(.plain)
        .onHover { hovered = $0 }
        .help(item.title)
        .contextMenu {
            Button("Launch") { service.launch(item) }
            Divider()
            Button("Move left") { service.move(item, by: -1) }
            Button("Move right") { service.move(item, by: 1) }
            Divider()
            Button("Remove", role: .destructive) { service.remove(item) }
        }
    }

    @ViewBuilder
    private var iconView: some View {
        if let img = service.icon(for: item) {
            Image(nsImage: img)
                .resizable()
                .interpolation(.high)
                .scaledToFit()
                .padding(2)
        } else if let symbol = item.iconSymbol {
            Image(systemName: symbol)
                .font(.system(size: 18, weight: .regular))
                .foregroundColor(.white.opacity(0.85))
        } else {
            Image(systemName: "questionmark.app.fill")
                .font(.system(size: 18, weight: .regular))
                .foregroundColor(.white.opacity(0.5))
        }
    }
}
