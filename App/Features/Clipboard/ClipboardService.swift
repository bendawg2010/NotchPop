// ClipboardService.swift
//
// Backing store for the "Clipboard History" pane. Polls NSPasteboard
// once a second on the main runloop — cheap, and the only reliable
// way on macOS since there's no public change-notification API.
// Capped at 12 entries (oldest dropped) and persisted to UserDefaults
// as JSON under "np.clipboard.entries" so history survives relaunch.

import AppKit
import Combine
import Foundation

struct ClipboardEntry: Identifiable, Equatable, Codable {
    let id: UUID
    let text: String
    let addedAt: Date

    init(id: UUID = UUID(), text: String, addedAt: Date = Date()) {
        self.id = id
        self.text = text
        self.addedAt = addedAt
    }
}

final class ClipboardService: ObservableObject {
    @Published var entries: [ClipboardEntry] = []

    private static let storageKey = "np.clipboard.entries"
    private static let maxEntries = 12
    private static let pollInterval: TimeInterval = 1.0

    private let pasteboard: NSPasteboard = .general
    private var lastChangeCount: Int
    private var timer: Timer?

    /// When `true`, the next pasteboard tick is ignored. Set right
    /// before we programmatically write to the pasteboard via copy()
    /// so we don't loop our own write back into history as a "new"
    /// entry.
    private var suppressNextChange: Bool = false

    init() {
        self.lastChangeCount = NSPasteboard.general.changeCount
        self.entries = Self.loadFromDisk()
    }

    deinit {
        timer?.invalidate()
        timer = nil
    }

    /// Begin polling NSPasteboard. Idempotent — calling twice is a
    /// no-op so the view can call this on .onAppear without worry.
    func start() {
        guard timer == nil else { return }
        let t = Timer(timeInterval: Self.pollInterval, repeats: true) { [weak self] _ in
            self?.tick()
        }
        // .common so it keeps firing while menus / scroll views track.
        RunLoop.main.add(t, forMode: .common)
        timer = t
    }

    private func tick() {
        let cc = pasteboard.changeCount
        guard cc != lastChangeCount else { return }
        lastChangeCount = cc

        if suppressNextChange {
            suppressNextChange = false
            return
        }

        guard let str = pasteboard.string(forType: .string) else { return }
        let trimmed = str.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        // De-dupe against the most recent entry — re-copying the
        // same string repeatedly shouldn't pile up history.
        if let head = entries.first, head.text == str { return }

        let entry = ClipboardEntry(text: str)
        entries.insert(entry, at: 0)
        if entries.count > Self.maxEntries {
            entries = Array(entries.prefix(Self.maxEntries))
        }
        persist()
    }

    /// Push the entry's text back onto the system pasteboard and
    /// promote it to position 0. We mark suppressNextChange so the
    /// resulting changeCount bump doesn't re-add the same string.
    ///
    /// User-reported bug ("it just didnt copy"): the previous version
    /// used `clearContents() + setString(_, forType: .string)` only.
    /// That two-step sequence races with macOS's pasteboard server
    /// under our `.nonactivatingPanel` window — `setString` can
    /// return false silently and the pasteboard ends up holding
    /// nothing (the cleared state from step 1). The `setString`
    /// return value was also being ignored.
    ///
    /// Fix: use `declareTypes` (the older but more reliable API
    /// that explicitly registers our intent to write a string) and
    /// fall back to `writeObjects(_:)` if `setString` returns false.
    /// Then verify the write took by reading back; if it didn't,
    /// retry once after a 50ms beat. Logs to Console for debugging.
    func copy(_ entry: ClipboardEntry) {
        suppressNextChange = true
        let ok = writeStringRobustly(entry.text)
        if !ok {
            NSLog("NotchPop clipboard: copy failed on first attempt — retrying")
            // Brief beat then retry once. Sometimes another process
            // is mid-write to the pasteboard server (e.g. Universal
            // Clipboard sync) and a second try lands cleanly.
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { [weak self] in
                guard let self = self else { return }
                _ = self.writeStringRobustly(entry.text)
                self.lastChangeCount = self.pasteboard.changeCount
            }
        }
        lastChangeCount = pasteboard.changeCount

        if let idx = entries.firstIndex(of: entry), idx != 0 {
            entries.remove(at: idx)
            entries.insert(entry, at: 0)
            persist()
        }
    }

    /// Write a string to the system pasteboard using the most
    /// reliable AppKit path. Returns true on success. We try in
    /// order:
    ///   1. clearContents + declareTypes + setString — the
    ///      pre-NSPasteboardWriting era's standard combo.
    ///   2. clearContents + writeObjects([NSString]) — modern API,
    ///      occasionally better-behaved when (1) returns false.
    @discardableResult
    private func writeStringRobustly(_ text: String) -> Bool {
        pasteboard.clearContents()
        pasteboard.declareTypes([.string], owner: nil)
        let setOK = pasteboard.setString(text, forType: .string)
        if setOK {
            // Verify the read-back round-trips so we KNOW it took.
            if let readback = pasteboard.string(forType: .string),
               readback == text {
                return true
            }
        }
        // Fallback: writeObjects.
        pasteboard.clearContents()
        let woOK = pasteboard.writeObjects([text as NSString])
        if woOK,
           let readback = pasteboard.string(forType: .string),
           readback == text {
            return true
        }
        return false
    }

    func remove(_ entry: ClipboardEntry) {
        entries.removeAll { $0.id == entry.id }
        persist()
    }

    func clear() {
        entries.removeAll()
        persist()
    }

    // MARK: - Persistence

    private func persist() {
        do {
            let data = try JSONEncoder().encode(entries)
            UserDefaults.standard.set(data, forKey: Self.storageKey)
        } catch {
            // Best-effort: a failed encode shouldn't crash the app.
            // Worst case the user loses history on next relaunch.
        }
    }

    private static func loadFromDisk() -> [ClipboardEntry] {
        guard let data = UserDefaults.standard.data(forKey: storageKey) else { return [] }
        return (try? JSONDecoder().decode([ClipboardEntry].self, from: data)) ?? []
    }
}
