// SettingsView.swift
//
// Real settings window. Two sections:
//   • Customize tabs — checkbox list with drag-to-reorder
//   • Pomodoro — focus / short / long durations, cycle length
//   • About — version, links, credits
//
// Persists everything via UserDefaults through NotchViewModel.

import SwiftUI

struct SettingsView: View {
    @ObservedObject var viewModel: NotchViewModel
    @State private var draggingTab: NotchTab?

    var body: some View {
        TabView {
            tabsSection
                .tabItem { Label("Tabs", systemImage: "rectangle.stack") }
            pomodoroSection
                .tabItem { Label("Pomodoro", systemImage: "timer") }
            aboutSection
                .tabItem { Label("About", systemImage: "info.circle") }
        }
        .frame(width: 460, height: 460)
        .padding(20)
    }

    // MARK: - Tabs section
    private var tabsSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Customize what shows up").font(.headline)
            Text("Toggle tabs on and off. Drag handles to reorder.")
                .font(.caption)
                .foregroundColor(.secondary)

            VStack(spacing: 0) {
                ForEach(NotchTab.allCases) { tab in
                    tabRow(tab)
                    if tab != NotchTab.allCases.last { Divider() }
                }
            }
            .background(Color(.windowBackgroundColor).opacity(0.5))
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.gray.opacity(0.3)))

            Spacer()

            HStack {
                Button("Reset to default order") {
                    viewModel.visibleTabs = NotchTab.allCases
                }
                .buttonStyle(.bordered)
                Spacer()
                Text("\(viewModel.visibleTabs.count) of \(NotchTab.allCases.count) visible")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }

    private func tabRow(_ tab: NotchTab) -> some View {
        let visible = viewModel.visibleTabs.contains(tab)
        return HStack(spacing: 12) {
            Image(systemName: tab.icon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(visible ? .accentColor : .secondary)
                .frame(width: 24)
            VStack(alignment: .leading, spacing: 2) {
                Text(tab.rawValue).font(.system(size: 13, weight: .semibold))
                Text(tab.blurb).font(.caption).foregroundColor(.secondary)
            }
            Spacer()
            if visible {
                Button {
                    moveTab(tab, by: -1)
                } label: { Image(systemName: "arrow.up") }
                    .buttonStyle(.borderless)
                    .disabled(viewModel.visibleTabs.first == tab)
                Button {
                    moveTab(tab, by: 1)
                } label: { Image(systemName: "arrow.down") }
                    .buttonStyle(.borderless)
                    .disabled(viewModel.visibleTabs.last == tab)
            }
            Toggle("", isOn: Binding(
                get: { visible },
                set: { newVal in
                    if newVal {
                        if !viewModel.visibleTabs.contains(tab) {
                            viewModel.visibleTabs.append(tab)
                        }
                    } else {
                        // Always keep at least one tab visible
                        if viewModel.visibleTabs.count > 1 {
                            viewModel.visibleTabs.removeAll { $0 == tab }
                        }
                    }
                }
            ))
            .labelsHidden()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
    }

    private func moveTab(_ tab: NotchTab, by delta: Int) {
        guard let i = viewModel.visibleTabs.firstIndex(of: tab) else { return }
        let new = i + delta
        guard new >= 0 && new < viewModel.visibleTabs.count else { return }
        var arr = viewModel.visibleTabs
        arr.swapAt(i, new)
        viewModel.visibleTabs = arr
    }

    // MARK: - Pomodoro section
    private var pomodoroSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Pomodoro durations").font(.headline)
            durationStepper("Focus", value: Binding(
                get: { viewModel.pomodoro.focusMinutes },
                set: { viewModel.pomodoro.focusMinutes = $0 }), range: 5...120, suffix: "min")
            durationStepper("Short break", value: Binding(
                get: { viewModel.pomodoro.shortBreakMinutes },
                set: { viewModel.pomodoro.shortBreakMinutes = $0 }), range: 1...30, suffix: "min")
            durationStepper("Long break", value: Binding(
                get: { viewModel.pomodoro.longBreakMinutes },
                set: { viewModel.pomodoro.longBreakMinutes = $0 }), range: 5...60, suffix: "min")
            durationStepper("Long break every", value: Binding(
                get: { viewModel.pomodoro.sessionsBeforeLongBreak },
                set: { viewModel.pomodoro.sessionsBeforeLongBreak = $0 }), range: 2...10, suffix: "sessions")
            Spacer()
            Button("Reset Pomodoro") { viewModel.pomodoro.reset() }
                .buttonStyle(.bordered)
        }
    }

    private func durationStepper(_ label: String, value: Binding<Int>,
                                 range: ClosedRange<Int>, suffix: String) -> some View {
        HStack {
            Text(label).frame(width: 150, alignment: .leading)
            Stepper(value: value, in: range) {
                Text("\(value.wrappedValue) \(suffix)")
                    .font(.system(.body, design: .rounded))
                    .frame(minWidth: 100, alignment: .leading)
            }
        }
    }

    // MARK: - About
    private var aboutSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("NotchPop").font(.title2.bold())
            Text("v1.1 · Free · MIT licensed").font(.subheadline).foregroundColor(.secondary)
            Divider()
            Text("Hover the notch to expand. Drop files into the shelf, drag them back out anywhere. Music controls work with Apple Music, Spotify, YouTube, podcasts, anything that registers with the system Now-Playing center.")
                .font(.callout)
            Spacer()
            HStack(spacing: 14) {
                Link("GitHub", destination: URL(string: "https://github.com/bendawg2010/NotchPop")!)
                Link("Releases", destination: URL(string: "https://github.com/bendawg2010/NotchPop/releases")!)
                Link("Sponsor", destination: URL(string: "https://github.com/sponsors/bendawg2010")!)
            }
            .font(.callout)
        }
    }
}
