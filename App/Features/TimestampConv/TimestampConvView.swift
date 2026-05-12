// TimestampConvView.swift — convert between Unix epoch seconds /
// milliseconds and ISO 8601 / human-readable dates. Bidirectional:
// type a number, see the date; type a date, see the number.

import SwiftUI

struct TimestampConvView: View {
    @AppStorage("np.ts.input") private var input: String = ""
    @State private var nowTrigger: Date = Date()

    /// Try to parse the input as either:
    ///  - Unix seconds (10 digits)
    ///  - Unix milliseconds (13 digits)
    ///  - ISO 8601 date string
    ///  - "now" keyword
    private var parsed: Date? {
        let s = input.trimmingCharacters(in: .whitespaces)
        if s.isEmpty || s.lowercased() == "now" { return nowTrigger }
        // Try numeric (seconds or ms)
        if let n = Double(s) {
            return n > 9_999_999_999  // > year 2286 in seconds → assume ms
                ? Date(timeIntervalSince1970: n / 1000)
                : Date(timeIntervalSince1970: n)
        }
        // Try ISO 8601
        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let d = iso.date(from: s) { return d }
        iso.formatOptions = [.withInternetDateTime]
        if let d = iso.date(from: s) { return d }
        // Try a few common formats
        let f = DateFormatter()
        for fmt in ["yyyy-MM-dd HH:mm:ss", "yyyy-MM-dd'T'HH:mm:ss",
                     "yyyy-MM-dd", "MM/dd/yyyy HH:mm:ss"] {
            f.dateFormat = fmt
            if let d = f.date(from: s) { return d }
        }
        return nil
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                TextField("Unix seconds, ms, ISO 8601, or 'now'", text: $input)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(size: 11, design: .monospaced))
                Button("Now") {
                    nowTrigger = Date()
                    input = String(Int(nowTrigger.timeIntervalSince1970))
                }.buttonStyle(.bordered)
            }
            if let d = parsed {
                row("Unix seconds",
                     String(Int(d.timeIntervalSince1970)))
                row("Unix milliseconds",
                     String(Int(d.timeIntervalSince1970 * 1000)))
                row("ISO 8601 (UTC)",
                     {
                        let f = ISO8601DateFormatter()
                        f.formatOptions = [.withInternetDateTime]
                        return f.string(from: d)
                     }())
                row("Local time", {
                    let f = DateFormatter()
                    f.dateStyle = .medium
                    f.timeStyle = .medium
                    return f.string(from: d)
                }())
                row("Relative", relativeString(from: d))
            } else {
                Text("Type a number, ISO date, or 'now'.")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                    .padding(.top, 8)
            }
        }
        .padding(.horizontal, 14).padding(.vertical, 10)
    }

    private func row(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label).font(.system(size: 10, weight: .heavy))
                .foregroundColor(.secondary)
                .frame(width: 130, alignment: .leading)
            Text(value)
                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                .foregroundColor(.white)
                .lineLimit(1)
                .truncationMode(.middle)
                .textSelection(.enabled)
            Spacer()
            Button {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(value, forType: .string)
            } label: {
                Image(systemName: "doc.on.doc")
                    .font(.system(size: 9))
            }.buttonStyle(.plain)
        }
    }

    private func relativeString(from d: Date) -> String {
        let f = RelativeDateTimeFormatter()
        f.unitsStyle = .full
        return f.localizedString(for: d, relativeTo: Date())
    }
}
