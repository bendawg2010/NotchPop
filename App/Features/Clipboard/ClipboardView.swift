// ClipboardView.swift
//
// "Clipboard History" pane inside the expanded notch. Renders recent
// pasteboard strings as a horizontal scrollable strip of chips. Click
// to re-copy (with a brief "Copied" flash), right-click or hover-X to
// remove. Empty state nudges the user to copy something. Matches the
// 88pt card chrome used by the other panes.

import SwiftUI

struct ClipboardView: View {
    @ObservedObject var service: ClipboardService
    /// When true, clicking a chip simulates Cmd+V into the previously-
    /// frontmost app right after the copy. The notch's
    /// .nonactivatingPanel style means we never stole focus, so the
    /// app the user came from is still active and ready to receive
    /// the paste. Setting lives on NotchViewModel.clipboardAutoPaste.
    var autoPaste: Bool = true
    @State private var pulse: Bool = false
    @State private var copiedID: UUID?

    var body: some View {
        ZStack {
            if service.entries.isEmpty {
                emptyState
            } else {
                chipRow
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
        .onAppear { service.start() }
    }

    // MARK: - Empty

    private var emptyState: some View {
        VStack(spacing: 6) {
            Image(systemName: "doc.on.clipboard")
                .font(.system(size: 22, weight: .semibold))
                .foregroundColor(.white.opacity(0.5))
                .scaleEffect(pulse ? 1.08 : 1.0)
                .opacity(pulse ? 1.0 : 0.78)
            Text("Copy something to get started")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.white.opacity(0.55))
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 1.4).repeatForever(autoreverses: true)) {
                pulse = true
            }
        }
    }

    // MARK: - Chips

    private var chipRow: some View {
        HStack(spacing: 0) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(service.entries) { entry in
                        ClipboardChip(
                            entry: entry,
                            isCopied: copiedID == entry.id,
                            onCopy: { handleCopy(entry) },
                            onRemove: { service.remove(entry) }
                        )
                    }
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
            }

            // Tiny clear-all on the right edge.
            Button(action: { service.clear() }) {
                Image(systemName: "trash")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.white.opacity(0.7))
                    .frame(width: 26, height: 26)
                    .background(Circle().fill(Color.white.opacity(0.10)))
            }
            .buttonStyle(.plain)
            .help("Clear all")
            .padding(.trailing, 10)
        }
    }

    private func handleCopy(_ entry: ClipboardEntry) {
        service.copy(entry)
        withAnimation(.easeOut(duration: 0.15)) {
            copiedID = entry.id
        }
        // Auto-paste: synthesize Cmd+V into the foreground app (the
        // app the user was on BEFORE expanding the notch — our panel
        // never stole focus). Tiny delay so the pasteboard write
        // settles before the keystroke arrives.
        if autoPaste {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
                synthesizePaste()
            }
        }
        // Reset the badge after a short beat so future clicks show
        // the flash again.
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            if copiedID == entry.id {
                withAnimation(.easeIn(duration: 0.2)) {
                    copiedID = nil
                }
            }
        }
    }

    /// Post Cmd+V via CGEvent so the foreground app pastes the new
    /// pasteboard contents. We use .combinedSessionState so the
    /// keystroke goes wherever the system would route a real
    /// keyboard event right now.
    private func synthesizePaste() {
        let src = CGEventSource(stateID: .combinedSessionState)
        let cmdV: CGKeyCode = 9 // V
        let down = CGEvent(keyboardEventSource: src, virtualKey: cmdV, keyDown: true)
        down?.flags = .maskCommand
        down?.post(tap: .cghidEventTap)
        let up = CGEvent(keyboardEventSource: src, virtualKey: cmdV, keyDown: false)
        up?.flags = .maskCommand
        up?.post(tap: .cghidEventTap)
    }
}

// MARK: - Chip

private struct ClipboardChip: View {
    let entry: ClipboardEntry
    let isCopied: Bool
    let onCopy: () -> Void
    let onRemove: () -> Void

    @State private var hovered: Bool = false

    private static let previewLength = 28

    private var preview: String {
        // Collapse newlines so multi-line clips stay on one row, then
        // truncate to ~28 chars and append an ellipsis when needed.
        let flat = entry.text
            .replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: "\r", with: " ")
            .replacingOccurrences(of: "\t", with: " ")
            .trimmingCharacters(in: .whitespaces)
        if flat.count <= Self.previewLength { return flat }
        let idx = flat.index(flat.startIndex, offsetBy: Self.previewLength)
        return String(flat[..<idx]) + "…"
    }

    var body: some View {
        Button(action: onCopy) {
            HStack(spacing: 6) {
                if isCopied {
                    Image(systemName: "checkmark")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.green)
                    Text("Copied")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.white)
                } else {
                    Text(preview.isEmpty ? " " : preview)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.white.opacity(0.88))
                        .lineLimit(1)
                        .truncationMode(.tail)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .frame(height: 26)
            .background(
                Capsule(style: .continuous)
                    .fill(Color.white.opacity(hovered ? 0.14 : 0.08))
            )
            .overlay(
                Capsule(style: .continuous)
                    .stroke(isCopied ? Color.green.opacity(0.55)
                                     : Color.white.opacity(0.10),
                            lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .overlay(alignment: .topTrailing) {
            if hovered && !isCopied {
                Button(action: onRemove) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.white.opacity(0.85))
                        .background(Color.black.clipShape(Circle()))
                        .font(.system(size: 12))
                }
                .buttonStyle(.plain)
                .offset(x: 5, y: -5)
            }
        }
        .onHover { hovered = $0 }
        .help(entry.text)
        .contextMenu {
            Button("Copy") { onCopy() }
            Button("Remove", role: .destructive) { onRemove() }
        }
    }
}
