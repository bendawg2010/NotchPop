// FileShelfView.swift
//
// Horizontal row of file thumbnails inside the expanded notch.
// Supports:
//  • Drop URLs from any app (Finder, Safari downloads, email attachments)
//  • Drag thumbnails OUT to any other app (NSItemProvider with file URL)
//  • Empty state showing "Drag a file here"

import SwiftUI
import UniformTypeIdentifiers

struct FileShelfView: View {
    @ObservedObject var shelf: FileShelf
    @State private var isDropTargeted: Bool = false
    @State private var pulse: Bool = false

    var body: some View {
        ZStack {
            if shelf.items.isEmpty {
                emptyState
            } else {
                thumbRow
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 88)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.white.opacity(0.04))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(isDropTargeted ? Color.accentColor : Color.white.opacity(0.08),
                                lineWidth: isDropTargeted ? 2 : 1)
                )
                .animation(.easeOut(duration: 0.15), value: isDropTargeted)
        )
        .onDrop(of: [.fileURL], isTargeted: $isDropTargeted) { providers in
            handleDrop(providers: providers)
            return true
        }
    }

    private var emptyState: some View {
        VStack(spacing: 6) {
            Image(systemName: "tray.and.arrow.down")
                .font(.system(size: 22, weight: .semibold))
                .foregroundColor(.white.opacity(isDropTargeted ? 0.9 : 0.5))
                .scaleEffect(pulse ? 1.08 : 1.0)
                .opacity(pulse ? 1.0 : 0.78)
            Text(isDropTargeted ? "Drop to add" : "Drag a file here")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.white.opacity(isDropTargeted ? 0.95 : 0.55))
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 1.4).repeatForever(autoreverses: true)) {
                pulse = true
            }
        }
    }

    private var thumbRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(shelf.items) { item in
                    FileShelfThumb(item: item, onRemove: { shelf.remove(item) })
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
        }
    }

    private func handleDrop(providers: [NSItemProvider]) {
        let group = DispatchGroup()
        var urls: [URL] = []
        for p in providers {
            group.enter()
            _ = p.loadObject(ofClass: URL.self) { url, _ in
                if let u = url { urls.append(u) }
                group.leave()
            }
        }
        group.notify(queue: .main) {
            self.shelf.add(urls: urls)
        }
    }
}

private struct FileShelfThumb: View {
    let item: ShelfItem
    let onRemove: () -> Void
    @State private var hovered = false

    var body: some View {
        VStack(spacing: 4) {
            Image(nsImage: item.icon)
                .resizable()
                .interpolation(.high)
                .scaledToFit()
                .frame(width: 44, height: 44)
                .padding(6)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(Color.white.opacity(hovered ? 0.10 : 0.05))
                )
                .overlay(alignment: .topTrailing) {
                    if hovered {
                        Button(action: onRemove) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.white.opacity(0.85))
                                .background(Color.black.clipShape(Circle()))
                                .font(.system(size: 14))
                        }
                        .buttonStyle(.plain)
                        .offset(x: 4, y: -4)
                    }
                }

            Text(item.name)
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(.white.opacity(0.75))
                .lineLimit(1)
                .truncationMode(.middle)
                .frame(maxWidth: 64)
        }
        .frame(width: 64)
        .onHover { hovered = $0 }
        .onDrag {
            // Provide the file URL so any app can receive it.
            NSItemProvider(object: item.url as NSURL)
        }
        .help(item.url.path)
    }
}
