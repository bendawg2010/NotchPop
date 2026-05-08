// NotesView.swift
//
// "Quick Notes" pane inside the expanded notch. Single TextEditor for
// free-form jotting, with a placeholder when empty and a footer row
// showing the live char count and a ghost trash button to clear.
// Visual style matches the other 88pt panes (NowPlaying, etc.).

import SwiftUI

struct NotesView: View {
    @ObservedObject var service: NotesService
    /// Body font size — pulled from NotchViewModel.notesFontSize.
    /// Defaults to the historical 12.5pt if the caller doesn't pass one.
    var fontSize: CGFloat = 12.5
    /// Use a monospaced font (default = system rounded body).
    var monospaced: Bool = false

    var body: some View {
        VStack(spacing: 4) {
            editor
            footer
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

    private var editor: some View {
        TextEditor(text: $service.text)
            .font(noteFont)
            .foregroundColor(.white)
            .scrollContentBackground(.hidden)
            .background(Color.clear)
            .overlay(alignment: .topLeading) {
                if service.text.isEmpty {
                    Text("Jot a quick note…")
                        .font(noteFont)
                        .foregroundColor(Color.white.opacity(0.35))
                        .padding(14)
                        .allowsHitTesting(false)
                }
            }
    }

    private var noteFont: Font {
        if monospaced {
            return .system(size: fontSize, weight: .medium, design: .monospaced)
        }
        return .system(size: fontSize, weight: .medium)
    }

    private var footer: some View {
        HStack {
            Text("\(service.text.count) chars")
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(.white.opacity(0.45))

            Spacer(minLength: 4)

            Button(action: { service.clear() }) {
                Image(systemName: "trash")
                    .font(.system(size: 10, weight: .heavy))
                    .foregroundColor(.white.opacity(0.65))
                    .frame(width: 20, height: 20)
                    .background(
                        Circle().fill(Color.white.opacity(0.08))
                    )
            }
            .buttonStyle(.plain)
            .help("Clear note")
            .disabled(service.text.isEmpty)
            .opacity(service.text.isEmpty ? 0.4 : 1.0)
        }
    }
}
