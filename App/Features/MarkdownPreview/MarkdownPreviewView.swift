// MarkdownPreviewView.swift — paste markdown, see it rendered.
// Uses Apple's built-in AttributedString markdown parser.

import SwiftUI

struct MarkdownPreviewView: View {
    @AppStorage("np.md.text") private var raw: String =
        "# Hello\n\nClick the **edit** icon, paste *markdown*, see it _rendered_.\n\n- Item one\n- Item two\n- [link](https://example.com)"
    @State private var editing: Bool = false

    private var attributed: AttributedString {
        (try? AttributedString(markdown: raw, options: .init(
            interpretedSyntax: .inlineOnlyPreservingWhitespace)))
            ?? AttributedString(raw)
    }

    var body: some View {
        VStack(spacing: 6) {
            HStack {
                Text(editing ? "Editing" : "Rendered")
                    .font(.system(size: 10, weight: .heavy))
                    .tracking(1.2).foregroundColor(.secondary).textCase(.uppercase)
                Spacer()
                Button {
                    editing.toggle()
                } label: {
                    Image(systemName: editing ? "eye" : "square.and.pencil")
                }.buttonStyle(.bordered)
                Button {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(raw, forType: .string)
                } label: { Image(systemName: "doc.on.doc") }
                .buttonStyle(.bordered)
            }
            ScrollView {
                if editing {
                    TextEditor(text: $raw)
                        .font(.system(size: 11, design: .monospaced))
                        .frame(minHeight: 90)
                        .padding(4)
                } else {
                    Text(attributed)
                        .font(.system(size: 12))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(8)
                }
            }
            .frame(height: 100)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color.white.opacity(0.05)))
        }
        .padding(.horizontal, 14).padding(.vertical, 10)
    }
}
