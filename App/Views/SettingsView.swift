// SettingsView.swift
//
// Minimal placeholder settings window. Most of the user-visible
// controls live in the menubar item; this is here so SwiftUI's
// App protocol has a Scene to render and Cmd+, has somewhere to go.

import SwiftUI

struct SettingsView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("NotchPop")
                .font(.title2.bold())
            Text("v1.0 · Free · MIT licensed")
                .font(.subheadline)
                .foregroundColor(.secondary)
            Divider()
            Text("Hover the notch on your MacBook to expand it. Drop files in to keep them on your shelf — drag them out to any other app.")
                .font(.callout)
            Divider()
            Text("Settings live in the menubar — click the rectangle icon in the top-right.")
                .font(.callout)
                .foregroundColor(.secondary)
            Spacer()
            Link("github.com/bendawg2010/NotchPop",
                 destination: URL(string: "https://github.com/bendawg2010/NotchPop")!)
                .font(.callout)
        }
        .padding(24)
        .frame(width: 420, height: 320)
    }
}
