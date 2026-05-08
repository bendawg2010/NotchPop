// AppShortcutsService.swift
//
// User-pinned launcher: a list of macOS apps and URLs the user can
// launch with one click from the App Shortcuts tab. Persists to
// UserDefaults under "np.appShortcuts" as JSON.
//
// Each shortcut has:
//   • id            — UUID for stable identity across reorders
//   • kind          — .app or .url
//   • payload       — file path for .app, URL string for .url
//   • title         — user-overridable display name
//   • iconName      — optional SF Symbol fallback when icon load fails
//
// We render the actual app icon by asking NSWorkspace for the app's
// .icns; for URLs we fall back to a globe SF Symbol unless the user
// pinned a custom one.

import AppKit
import Foundation

struct ShortcutItem: Identifiable, Codable, Equatable {
    enum Kind: String, Codable { case app, url }

    let id: UUID
    var kind: Kind
    var payload: String   // file path (app) or URL string (url)
    var title: String
    var iconSymbol: String?  // optional SF Symbol fallback

    init(id: UUID = UUID(),
         kind: Kind,
         payload: String,
         title: String,
         iconSymbol: String? = nil) {
        self.id = id
        self.kind = kind
        self.payload = payload
        self.title = title
        self.iconSymbol = iconSymbol
    }
}

final class AppShortcutsService: ObservableObject {
    private static let key = "np.appShortcuts"

    @Published var items: [ShortcutItem] = [] {
        didSet { persist() }
    }

    init() {
        restore()
    }

    /// Launch a shortcut. Apps go through NSWorkspace; URLs open in
    /// the default handler (browser, mail, etc.).
    func launch(_ item: ShortcutItem) {
        switch item.kind {
        case .app:
            let url = URL(fileURLWithPath: item.payload)
            NSWorkspace.shared.openApplication(at: url,
                                                configuration: NSWorkspace.OpenConfiguration(),
                                                completionHandler: nil)
        case .url:
            if let u = URL(string: item.payload) {
                NSWorkspace.shared.open(u)
            }
        }
    }

    /// Fetch the icon for a given shortcut. Apps use NSWorkspace to
    /// pull the bundled .icns at native resolution. URLs fall back
    /// to a generic globe icon (or the user-set SF Symbol).
    func icon(for item: ShortcutItem) -> NSImage? {
        switch item.kind {
        case .app:
            let url = URL(fileURLWithPath: item.payload)
            return NSWorkspace.shared.icon(forFile: url.path)
        case .url:
            return nil
        }
    }

    /// Add a macOS app by its file URL (typically from an NSOpenPanel
    /// pointing at /Applications/SomeApp.app). The display title is
    /// derived from the bundle's CFBundleDisplayName / CFBundleName,
    /// falling back to the file name.
    func addApp(at url: URL) {
        let bundle = Bundle(url: url)
        let title = (bundle?.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String)
            ?? (bundle?.object(forInfoDictionaryKey: "CFBundleName") as? String)
            ?? url.deletingPathExtension().lastPathComponent
        items.append(ShortcutItem(kind: .app, payload: url.path, title: title))
    }

    func addURL(_ raw: String, title: String? = nil) {
        var trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        // If the user typed "github.com" without a scheme, default to
        // https — much friendlier than handing them an error.
        if !trimmed.contains("://") { trimmed = "https://" + trimmed }
        guard let url = URL(string: trimmed), url.scheme != nil else { return }
        let host = url.host ?? trimmed
        items.append(ShortcutItem(
            kind: .url,
            payload: trimmed,
            title: title?.trimmingCharacters(in: .whitespaces).isEmpty == false
                ? title!
                : host,
            iconSymbol: "globe"
        ))
    }

    func remove(_ item: ShortcutItem) {
        items.removeAll { $0.id == item.id }
    }

    func move(_ item: ShortcutItem, by delta: Int) {
        guard let i = items.firstIndex(where: { $0.id == item.id }) else { return }
        let new = i + delta
        guard new >= 0, new < items.count else { return }
        items.swapAt(i, new)
    }

    // MARK: - Persistence

    private func persist() {
        guard let data = try? JSONEncoder().encode(items) else { return }
        UserDefaults.standard.set(data, forKey: Self.key)
    }

    private func restore() {
        guard let data = UserDefaults.standard.data(forKey: Self.key),
              let decoded = try? JSONDecoder().decode([ShortcutItem].self, from: data)
        else { return }
        self.items = decoded
    }
}
