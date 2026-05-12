// SlugifyView.swift — text → URL slug. Useful for blog post URLs,
// filenames, anchors, etc. Live update as you type.

import SwiftUI

struct SlugifyView: View {
    @AppStorage("np.slug.input") private var input: String = "Hello World — This Is My Post!"
    @AppStorage("np.slug.sep")   private var sep: String   = "-"
    @AppStorage("np.slug.lower") private var lower: Bool   = true

    private var slug: String {
        var s = input
        // Strip diacritics (café → cafe) via folding
        s = s.folding(options: .diacriticInsensitive, locale: .current)
        if lower { s = s.lowercased() }
        // Replace anything that's NOT alphanumeric with the separator
        var out = ""
        var prevWasSep = false
        for c in s {
            if c.isLetter || c.isNumber {
                out.append(c)
                prevWasSep = false
            } else if !prevWasSep {
                out += sep
                prevWasSep = true
            }
        }
        // Trim leading/trailing separators
        while out.hasPrefix(sep) { out.removeFirst(sep.count) }
        while out.hasSuffix(sep) { out.removeLast(sep.count) }
        return out
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Input
            VStack(alignment: .leading, spacing: 4) {
                Text("Input").font(.system(size: 9, weight: .heavy))
                    .tracking(1).foregroundColor(.secondary).textCase(.uppercase)
                TextEditor(text: $input)
                    .font(.system(size: 11))
                    .padding(4)
                    .frame(height: 50)
                    .background(RoundedRectangle(cornerRadius: 8).fill(Color.white.opacity(0.05)))
            }
            // Options
            HStack(spacing: 14) {
                Picker("Separator", selection: $sep) {
                    Text("- (hyphen)").tag("-")
                    Text("_ (underscore)").tag("_")
                    Text(". (dot)").tag(".")
                }
                .pickerStyle(.menu).frame(width: 150)
                Toggle("lowercase", isOn: $lower)
                    .font(.system(size: 11))
                Spacer()
            }
            // Output
            HStack {
                Text(slug.isEmpty ? "(empty)" : slug)
                    .font(.system(size: 14, weight: .heavy, design: .monospaced))
                    .foregroundColor(.green)
                    .padding(.horizontal, 12).padding(.vertical, 10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(Color.white.opacity(0.05)))
                    .textSelection(.enabled)
                Button {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(slug, forType: .string)
                } label: { Image(systemName: "doc.on.doc") }
                .buttonStyle(.borderedProminent)
                .disabled(slug.isEmpty)
            }
        }
        .padding(.horizontal, 14).padding(.vertical, 10)
    }
}
