// FileShelf.swift
//
// "Shelf" / "Drop tray" — the killer feature. User drags any file onto
// the expanded notch, it's added to the shelf. They can then drag it
// out anywhere — Finder window, email composition, Slack, Messages.
// Files persist by URL bookmark only; we don't copy them anywhere.
//
// On disk persistence uses a JSON of security-scoped bookmarks under
// ~/Library/Application Support/NotchPop/shelf.json — only used when
// the user opts in to "remember shelf between launches."

import AppKit
import Combine
import UniformTypeIdentifiers

struct ShelfItem: Identifiable, Equatable {
    let id: UUID
    let url: URL
    let name: String
    let icon: NSImage
    let addedAt: Date

    init(url: URL) {
        self.id = UUID()
        self.url = url
        self.name = url.lastPathComponent
        self.icon = NSWorkspace.shared.icon(forFile: url.path)
        self.addedAt = Date()
    }

    static func == (lhs: ShelfItem, rhs: ShelfItem) -> Bool { lhs.id == rhs.id }
}

final class FileShelf: ObservableObject {
    @Published private(set) var items: [ShelfItem] = []

    /// Default capacity. We just trim the oldest beyond this so the
    /// expanded notch stays a reasonable size.
    let capacity = 12

    func add(urls: [URL]) {
        // De-dupe by path; bring matching items to the top.
        for url in urls {
            if let existing = items.firstIndex(where: { $0.url.path == url.path }) {
                let item = items.remove(at: existing)
                items.insert(item, at: 0)
            } else {
                items.insert(ShelfItem(url: url), at: 0)
            }
        }
        if items.count > capacity {
            items.removeLast(items.count - capacity)
        }
    }

    func remove(_ item: ShelfItem) {
        items.removeAll { $0.id == item.id }
    }

    func clear() {
        items.removeAll()
    }

    // MARK: - Persistence (opt-in only)

    func persist() {
        let urls = items.map { $0.url.path }
        guard let data = try? JSONSerialization.data(withJSONObject: urls) else { return }
        try? data.write(to: persistURL())
    }

    func restore() {
        guard let data = try? Data(contentsOf: persistURL()),
              let arr = try? JSONSerialization.jsonObject(with: data) as? [String]
        else { return }
        let urls = arr.compactMap { path -> URL? in
            let u = URL(fileURLWithPath: path)
            return FileManager.default.fileExists(atPath: u.path) ? u : nil
        }
        items = urls.map { ShelfItem(url: $0) }
    }

    private func persistURL() -> URL {
        let fm = FileManager.default
        let support = (try? fm.url(for: .applicationSupportDirectory, in: .userDomainMask,
                                    appropriateFor: nil, create: true))!
        let dir = support.appendingPathComponent("NotchPop", isDirectory: true)
        try? fm.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("shelf.json")
    }
}
