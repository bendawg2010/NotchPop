// ClaudePromptView.swift — chat-style Claude prompter in the notch,
// with a "⛶ Big" toggle that grows the whole notch into a giant
// workspace (closest we can get to "drag the terminal into the
// notch" without reparenting another app's window — see README).

import AppKit
import SwiftUI

struct ClaudePromptView: View {
    // Service is owned by the viewModel so its state (output,
    // recent prompts, running) survives notch collapse — SwiftUI
    // tears down view-scoped @StateObjects when their host view
    // leaves the hierarchy, which was wiping the user's draft +
    // reply every time the mouse left the notch.
    @ObservedObject var viewModel: NotchViewModel
    @ObservedObject var svc: ClaudePromptService
    // Draft lives on the service (which is owned by the viewModel) so
    // it survives notch-collapse view teardown AND app relaunches.
    // Earlier @AppStorage on the view didn't survive teardown because
    // the TextEditor binding committed asynchronously and could lose
    // the latest keystroke when the view was destroyed mid-edit.
    @State private var showRecent: Bool = false

    private var isBig: Bool { viewModel.bigNotchMode }

    var body: some View {
        VStack(alignment: .leading, spacing: isBig ? 12 : 6) {
            statusRow
            if showRecent && !svc.recent.isEmpty { recentList }
            // Manual Binding (vs the $svc.draft shorthand) was the
            // last missing piece for cross-collapse persistence —
            // with @ObservedObject + $svc.draft, SwiftUI's TextEditor
            // would sometimes display empty on re-mount even though
            // svc.draft held the last-typed text. A get/set Binding
            // forces a fresh read of the @Published property on every
            // re-render.
            TextEditor(text: Binding(
                get: { svc.draft },
                set: { svc.draft = $0 }
            ))
                .font(.system(size: isBig ? 14 : 11, design: .monospaced))
                .padding(isBig ? 10 : 4)
                .frame(height: isBig ? 140 : 50)
                .background(RoundedRectangle(cornerRadius: 10)
                    .fill(Color.white.opacity(0.06)))
                .overlay(RoundedRectangle(cornerRadius: 10)
                    .stroke(Color.purple.opacity(0.3), lineWidth: 1))

            ScrollView {
                Text(svc.output.isEmpty
                     ? (isBig
                        ? "Ask Claude anything. Code, refactors, debugging, doc lookups, whole architectures.\n\n⌘↩ to send · ⎋ to collapse"
                        : "Ask Claude anything — code, refactors, debugging.")
                     : svc.output)
                    .font(.system(size: isBig ? 13 : 10, design: .monospaced))
                    .foregroundColor(svc.output.isEmpty ? .secondary : .white)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(isBig ? 14 : 8)
                    .textSelection(.enabled)
            }
            .frame(height: isBig ? 480 : 75)
            .background(RoundedRectangle(cornerRadius: 10)
                .fill(Color.black.opacity(0.35)))

            actionRow
        }
        .padding(.horizontal, isBig ? 24 : 14)
        .padding(.vertical, isBig ? 18 : 10)
        // Esc collapses big mode.
        .background(
            KeyCatcher { key in
                if key == .escape && isBig {
                    viewModel.bigNotchMode = false
                }
            }
        )
    }

    // MARK: – Subcomponents

    private var statusRow: some View {
        HStack(spacing: 6) {
            Image(systemName: svc.isRunning ? "circle.dotted" : "sparkle")
                .font(.system(size: isBig ? 16 : 11, weight: .heavy))
                .foregroundColor(svc.isRunning ? .orange : .purple)
                .rotationEffect(.degrees(svc.isRunning ? 360 : 0))
                .animation(svc.isRunning
                            ? .linear(duration: 1.2).repeatForever(autoreverses: false)
                            : .default, value: svc.isRunning)
            Text(svc.isRunning ? "Claude is thinking…" : "Claude")
                .font(.system(size: isBig ? 18 : 11, weight: .heavy))
            Spacer()
            Button {
                viewModel.bigNotchMode.toggle()
            } label: {
                Image(systemName: isBig
                                  ? "arrow.down.right.and.arrow.up.left"
                                  : "arrow.up.left.and.arrow.down.right")
                    .font(.system(size: isBig ? 14 : 10, weight: .heavy))
            }
            .buttonStyle(.bordered)
            .help(isBig ? "Collapse (⎋)" : "Expand to big notch")
            Button { showRecent.toggle() } label: {
                Image(systemName: "clock.arrow.circlepath")
                    .font(.system(size: isBig ? 14 : 10))
            }
            .buttonStyle(.bordered)
            .help("Recent prompts")
            .disabled(svc.recent.isEmpty)
            Button {
                if svc.isRunning { svc.cancel() }
                else { svc.send(svc.draft) }
            } label: {
                Image(systemName: svc.isRunning ? "stop.fill" : "paperplane.fill")
                    .font(.system(size: isBig ? 14 : 10, weight: .heavy))
            }
            .buttonStyle(.borderedProminent)
            .keyboardShortcut(.return, modifiers: .command)
            .help(svc.isRunning ? "Cancel" : "Send (⌘↩)")
        }
    }

    private var recentList: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 2) {
                ForEach(Array(svc.recent.enumerated()), id: \.offset) { _, p in
                    Button {
                        svc.draft = p
                        showRecent = false
                    } label: {
                        Text(p)
                            .font(.system(size: isBig ? 12 : 10))
                            .foregroundColor(.white.opacity(0.85))
                            .lineLimit(1)
                            .truncationMode(.tail)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 8).padding(.vertical, 4)
                            .background(RoundedRectangle(cornerRadius: 5)
                                .fill(Color.white.opacity(0.04)))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .frame(maxHeight: isBig ? 140 : 70)
    }

    private var actionRow: some View {
        HStack(spacing: 8) {
            Button {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(svc.output, forType: .string)
            } label: {
                Label("Copy reply", systemImage: "doc.on.doc")
                    .font(.system(size: isBig ? 12 : 10, weight: .heavy))
            }
            .buttonStyle(.bordered)
            .disabled(svc.output.isEmpty)

            Button {
                openInTerminal(svc.draft)
            } label: {
                Label("Open in Terminal", systemImage: "arrow.up.right.square")
                    .font(.system(size: isBig ? 12 : 10, weight: .heavy))
            }
            .buttonStyle(.bordered)
            .help("Open Terminal with this prompt loaded into claude")

            Spacer()
            if let err = svc.lastError, !err.isEmpty, !svc.isRunning {
                Text("⚠ \(err.prefix(isBig ? 80 : 40))")
                    .font(.system(size: isBig ? 10 : 9))
                    .foregroundColor(.orange)
                    .lineLimit(1)
            }
        }
    }

    private func openInTerminal(_ prompt: String) {
        let safe = prompt.replacingOccurrences(of: "\\", with: "\\\\")
                          .replacingOccurrences(of: "\"", with: "\\\"")
                          .replacingOccurrences(of: "$", with: "\\$")
        let cmd = safe.isEmpty ? "claude" : "claude -p \"\(safe)\""
        let script = """
        tell application "Terminal"
            activate
            do script "\(cmd)"
        end tell
        """
        var error: NSDictionary?
        NSAppleScript(source: script)?.executeAndReturnError(&error)
    }
}

/// Tiny NSViewRepresentable wrapper to catch ⎋ key while big mode is
/// active. Doesn't steal focus from the TextEditor.
private struct KeyCatcher: NSViewRepresentable {
    let handler: (KeyEvent) -> Void
    enum KeyEvent { case escape }
    func makeNSView(context: Context) -> NSView {
        let v = NSView()
        let monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            if event.keyCode == 53 { // escape
                handler(.escape)
                return nil
            }
            return event
        }
        context.coordinator.monitor = monitor
        return v
    }
    func updateNSView(_ nsView: NSView, context: Context) {}
    static func dismantleNSView(_ nsView: NSView, coordinator: Coordinator) {
        if let m = coordinator.monitor { NSEvent.removeMonitor(m) }
    }
    func makeCoordinator() -> Coordinator { Coordinator() }
    class Coordinator { var monitor: Any? }
}
