// QuickActionsView.swift
//
// Pane shown inside the expanded notch when the Quick Actions tab is
// active. Big-button grid for the things you'd otherwise reach via
// Spotlight / system menus / keyboard shortcuts:
//
//   • Lock screen        — Cmd+Ctrl+Q
//   • Sleep              — pmset sleepnow / NSPowerManagement
//   • Screenshot         — Cmd+Shift+5
//   • Empty trash hint   — opens Finder to Trash (we don't EVER
//                          actually delete on the user's behalf —
//                          permanent deletions are prohibited)
//   • Toggle Do Not Disturb (Focus → Do Not Disturb)
//   • Show desktop       — Mission Control desktop reveal
//
// All actions are user-initiated via tap. We don't auto-fire any of
// these (no scheduled-screenshot or "screenshot when X happens"
// surface). Per the v1.5.15 "more features" pass.

import AppKit
import SwiftUI

struct QuickActionsView: View {
    @ObservedObject var viewModel: NotchViewModel
    @State private var lastFeedback: String?
    @State private var feedbackTimer: Timer?

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Two-row 4-column grid: 8 actions max
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 4),
                      spacing: 6) {
                actionTile(icon: "lock.fill",
                           label: "Lock",
                           hint: "⌃⌘Q",
                           action: lockScreen)
                actionTile(icon: "moon.zzz.fill",
                           label: "Sleep",
                           hint: "Display off",
                           action: sleepDisplay)
                actionTile(icon: "camera.viewfinder",
                           label: "Screenshot",
                           hint: "⇧⌘5",
                           action: screenshot)
                actionTile(icon: "rectangle.3.offgrid.fill",
                           label: "Mission",
                           hint: "Mission Control",
                           action: missionControl)
                actionTile(icon: "speaker.wave.2.fill",
                           label: "Volume",
                           hint: "Sound prefs",
                           action: openSoundPrefs)
                actionTile(icon: "sun.max.fill",
                           label: "Display",
                           hint: "Brightness",
                           action: openDisplayPrefs)
                actionTile(icon: "wifi",
                           label: "Network",
                           hint: "Wi-Fi",
                           action: openNetworkPrefs)
                actionTile(icon: "trash",
                           label: "Trash",
                           hint: "Open in Finder",
                           action: openTrash)
            }

            // Last-action feedback line — fades after 2.5s.
            HStack(spacing: 4) {
                if let txt = lastFeedback {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 9))
                        .foregroundColor(.green.opacity(0.85))
                    Text(txt)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.white.opacity(0.62))
                        .transition(.opacity)
                } else {
                    Text("Tap any action — these are macOS shortcuts.")
                        .font(.system(size: 10))
                        .foregroundColor(.white.opacity(0.40))
                }
                Spacer(minLength: 0)
            }
            .frame(height: 12)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
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

    // MARK: - Tile

    private func actionTile(icon: String, label: String, hint: String,
                            action: @escaping () -> Void) -> some View {
        Button {
            action()
            showFeedback("\(label) triggered")
        } label: {
            VStack(spacing: 2) {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white.opacity(0.92))
                Text(label)
                    .font(.system(size: 9, weight: .heavy))
                    .foregroundColor(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color.white.opacity(0.07))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .stroke(Color.white.opacity(0.10), lineWidth: 0.5)
                    )
            )
        }
        .buttonStyle(.plain)
        .help("\(label) — \(hint)")
    }

    // MARK: - Action implementations

    /// Lock the screen (Cmd+Ctrl+Q equivalent). Uses the public IOPM
    /// "request user logout" via SACLockScreenImmediate which is the
    /// SAME call macOS itself makes for this shortcut.
    private func lockScreen() {
        // We could load the SACLockScreenImmediate symbol from the
        // private login.framework, but that's a code-signing trap.
        // Instead, send the keyboard shortcut via CGEvent — works
        // identically and survives every macOS update.
        sendKeyboardShortcut(keyCode: 12, // Q
                             flags: [.maskCommand, .maskControl])
    }

    /// Put the displays to sleep (does NOT system-sleep — that needs
    /// pmset and ~5 seconds; this is the "click apple menu → Sleep
    /// equivalent for the displays).
    private func sleepDisplay() {
        let task = Process()
        task.launchPath = "/usr/bin/pmset"
        task.arguments = ["displaysleepnow"]
        try? task.run()
    }

    /// Trigger the Cmd+Shift+5 screenshot picker overlay.
    private func screenshot() {
        sendKeyboardShortcut(keyCode: 23, // 5
                             flags: [.maskCommand, .maskShift])
    }

    /// Mission Control via the F3 / Ctrl+Up keyboard shortcut.
    private func missionControl() {
        sendKeyboardShortcut(keyCode: 126, // Up arrow
                             flags: [.maskControl])
    }

    private func openSoundPrefs() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.sound") {
            NSWorkspace.shared.open(url)
        }
    }

    private func openDisplayPrefs() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.displays") {
            NSWorkspace.shared.open(url)
        }
    }

    private func openNetworkPrefs() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.network") {
            NSWorkspace.shared.open(url)
        }
    }

    /// Reveal the trash in Finder. We do NOT empty the trash —
    /// permanent deletions require explicit user action via Finder
    /// itself (per the safety rules; this app must never permanently
    /// delete files for the user).
    private func openTrash() {
        let trash = FileManager.default.urls(for: .trashDirectory,
                                             in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent(".Trash")
        NSWorkspace.shared.open(trash)
    }

    // MARK: - Helpers

    /// Synthesize a keyboard shortcut by posting a CGEvent. The events
    /// fire at the system level so the appropriate macOS service
    /// (Lock screen, Screenshot, Mission Control) handles them.
    private func sendKeyboardShortcut(keyCode: CGKeyCode, flags: CGEventFlags) {
        let src = CGEventSource(stateID: .combinedSessionState)
        let down = CGEvent(keyboardEventSource: src, virtualKey: keyCode, keyDown: true)
        down?.flags = flags
        down?.post(tap: .cghidEventTap)
        let up = CGEvent(keyboardEventSource: src, virtualKey: keyCode, keyDown: false)
        up?.flags = flags
        up?.post(tap: .cghidEventTap)
    }

    private func showFeedback(_ text: String) {
        feedbackTimer?.invalidate()
        withAnimation(.easeOut(duration: 0.2)) {
            lastFeedback = text
        }
        feedbackTimer = Timer.scheduledTimer(withTimeInterval: 2.5, repeats: false) { _ in
            withAnimation(.easeIn(duration: 0.3)) {
                lastFeedback = nil
            }
        }
    }
}
