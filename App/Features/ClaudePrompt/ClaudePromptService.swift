// ClaudePromptService.swift
//
// Spawns a `claude -p "<prompt>"` subprocess and streams stdout
// back into the SwiftUI view. The user's local Claude Code CLI
// (`/Users/<me>/.local/bin/claude` typically) handles auth +
// model selection — we just shovel prompts in and read replies out.
//
// One subprocess per send. Output streams chunk-by-chunk so the
// SwiftUI ScrollView can show progress mid-flight instead of
// waiting for the whole reply.

import Foundation

// NOTE: We deliberately don't annotate this class @MainActor — that
// would force NotchViewModel (which owns this service) to also become
// @MainActor or initialize asynchronously, which breaks the existing
// `let claudePrompt = ClaudePromptService()` pattern. Instead, every
// @Published mutation below is wrapped in `Task { @MainActor in … }`
// so we still respect SwiftUI's main-thread requirement.
final class ClaudePromptService: ObservableObject {
    // Persist these on every change so they survive notch-close
    // (when ClaudePromptView leaves the SwiftUI hierarchy) AND
    // app relaunches.
    // Draft lives on the service (not @AppStorage on the view) so it
    // survives view teardown even if the TextEditor binding hasn't
    // committed the latest keystroke before the notch collapses.
    @Published var draft: String = UserDefaults.standard.string(forKey: "np.claude.draft") ?? "" {
        didSet { UserDefaults.standard.set(draft, forKey: "np.claude.draft") }
    }
    @Published var output: String = UserDefaults.standard.string(forKey: "np.claude.output") ?? "" {
        didSet { UserDefaults.standard.set(output, forKey: "np.claude.output") }
    }
    @Published var isRunning: Bool = false
    @Published var lastError: String? = nil
    @Published var recent: [String] = (UserDefaults.standard.array(forKey: "np.claude.recent") as? [String]) ?? [] {
        didSet { UserDefaults.standard.set(recent, forKey: "np.claude.recent") }
    }

    private var process: Process?
    private var stdoutHandle: FileHandle?

    /// Search the user's PATH for the `claude` binary. We hard-code a
    /// short candidate list because the SwiftUI app's PATH inherits
    /// from launchd, not the user's shell — `which claude` would
    /// fail here even when the binary IS installed.
    private var claudePath: String {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        let candidates = [
            "\(home)/.local/bin/claude",
            "\(home)/.claude/local/claude",
            "/opt/homebrew/bin/claude",
            "/usr/local/bin/claude",
        ]
        return candidates.first {
            FileManager.default.isExecutableFile(atPath: $0)
        } ?? "/usr/local/bin/claude"
    }

    func send(_ prompt: String) {
        guard !isRunning else { return }
        guard !prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        else { return }

        // Reset state for this run
        output = ""
        lastError = nil
        isRunning = true

        // Track in recent (dedup + cap at 10)
        var newRecent = recent.filter { $0 != prompt }
        newRecent.insert(prompt, at: 0)
        if newRecent.count > 10 { newRecent = Array(newRecent.prefix(10)) }
        recent = newRecent

        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: claudePath)
        proc.arguments = ["-p", prompt]
        // Inherit a reasonable PATH so claude can find its node etc.
        var env = ProcessInfo.processInfo.environment
        env["PATH"] = (env["PATH"] ?? "")
            + ":/opt/homebrew/bin:/usr/local/bin:\(FileManager.default.homeDirectoryForCurrentUser.path)/.local/bin"
        proc.environment = env

        let outPipe = Pipe()
        let errPipe = Pipe()
        proc.standardOutput = outPipe
        proc.standardError = errPipe

        // Stream stdout chunks → @Published output (so the view updates live)
        outPipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            if data.isEmpty {
                // EOF
                handle.readabilityHandler = nil
                return
            }
            if let chunk = String(data: data, encoding: .utf8) {
                Task { @MainActor in
                    self?.output += chunk
                }
            }
        }
        // Collect stderr for diagnostics
        errPipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            if data.isEmpty {
                handle.readabilityHandler = nil
                return
            }
            if let chunk = String(data: data, encoding: .utf8),
               !chunk.isEmpty {
                Task { @MainActor in
                    // Don't surface stderr unless the process actually
                    // fails — Claude writes status to stderr sometimes.
                    self?.lastError = (self?.lastError ?? "") + chunk
                }
            }
        }

        // When the process exits, flip state on main thread.
        proc.terminationHandler = { [weak self] _ in
            Task { @MainActor in
                self?.isRunning = false
                self?.process = nil
                if self?.lastError?.isEmpty == false &&
                   self?.output.isEmpty == true {
                    // Only show stderr if there was no stdout
                    self?.output = self?.lastError ?? ""
                }
            }
        }

        do {
            try proc.run()
            self.process = proc
        } catch {
            isRunning = false
            lastError = "Couldn't start claude — is it installed at \(claudePath)? Error: \(error.localizedDescription)"
        }
    }

    func cancel() {
        process?.terminate()
        process = nil
        isRunning = false
    }
}
