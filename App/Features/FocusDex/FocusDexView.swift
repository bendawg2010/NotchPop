import SwiftUI

/// FocusDex companion pane. Reads cross-app stats and offers quick actions.
struct FocusDexView: View {
    @StateObject private var bridge = FocusDexBridge()

    // FocusDex brand palette
    private let pink     = Color(red: 1.00, green: 0.42, blue: 0.42)
    private let magenta  = Color(red: 0.76, green: 0.28, blue: 1.00)
    private let blue     = Color(red: 0.28, green: 0.63, blue: 1.00)
    private let mint     = Color(red: 0.18, green: 0.90, blue: 0.63)
    private let yellow   = Color(red: 1.00, green: 0.85, blue: 0.38)

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            // Left side — starter + headline stats
            leftPane
                .frame(width: 200)

            // Right side — ball stockpile + actions
            VStack(alignment: .leading, spacing: 10) {
                if bridge.focusDexInstalled {
                    ballStockpile
                    quickActions
                } else {
                    notInstalledCard
                }
            }
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
        .padding(12)
    }

    // MARK: - Left pane

    private var leftPane: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                FocusDexWordmark()
                Spacer()
            }
            Divider().opacity(0.3)

            if bridge.hasChosenStarter, let name = bridge.starterName, let type = bridge.starterPrimaryType {
                starterCard(name: name, type: type)
            } else {
                noStarterCard
            }

            // Headline stats
            VStack(alignment: .leading, spacing: 6) {
                statRow(icon: "square.grid.3x3.fill",
                        value: "\(bridge.caughtCount) / 147",
                        label: "caught",
                        color: mint)
                statRow(icon: "flame.fill",
                        value: "\(bridge.currentStreak)",
                        label: "streak (best \(bridge.bestStreak))",
                        color: pink)
                statRow(icon: "clock.fill",
                        value: bridge.formattedFocusTime,
                        label: "focused",
                        color: blue)
                statRow(icon: "checkmark.seal.fill",
                        value: "\(bridge.totalSessions)",
                        label: "sessions",
                        color: magenta)
            }
            .padding(.top, 4)
        }
    }

    private func starterCard(name: String, type: String) -> some View {
        HStack(spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(typeColor(type).opacity(0.18))
                Image(systemName: starterSymbol(name))
                    .font(.system(size: 22))
                    .foregroundStyle(typeColor(type))
            }
            .frame(width: 40, height: 40)

            VStack(alignment: .leading, spacing: 2) {
                Text(name)
                    .font(.system(.subheadline, design: .rounded).weight(.heavy))
                Text("#\(String(format: "%03d", bridge.starterId)) · \(type.uppercased())")
                    .font(.system(size: 9, weight: .heavy, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .kerning(0.6)
            }
            Spacer()
        }
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.white.opacity(0.04))
                .overlay(RoundedRectangle(cornerRadius: 10)
                    .strokeBorder(typeColor(type).opacity(0.3), lineWidth: 0.5))
        )
    }

    private var noStarterCard: some View {
        HStack(spacing: 10) {
            Image(systemName: "questionmark.circle.fill")
                .font(.system(size: 28))
                .foregroundStyle(.secondary)
            VStack(alignment: .leading, spacing: 2) {
                Text("No starter yet")
                    .font(.system(.subheadline, design: .rounded).weight(.heavy))
                Text("Open FocusDex to pick one")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(8)
        .background(RoundedRectangle(cornerRadius: 10).fill(Color.white.opacity(0.04)))
    }

    private func statRow(icon: String, value: String, label: String, color: Color) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 11))
                .foregroundStyle(color)
                .frame(width: 14)
            Text(value)
                .font(.system(.subheadline, design: .rounded).weight(.heavy))
                .monospacedDigit()
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
            Spacer()
        }
    }

    // MARK: - Right pane

    private var ballStockpile: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("STOCKPILE")
                .font(.system(size: 9, weight: .heavy, design: .rounded))
                .foregroundStyle(.secondary)
                .kerning(0.8)
            HStack(spacing: 6) {
                ballChip(count: bridge.pokeballs,   label: "Focus",  color: mint)
                ballChip(count: bridge.greatBalls,  label: "Great",  color: blue)
                ballChip(count: bridge.ultraBalls,  label: "Ultra",  color: yellow)
                ballChip(count: bridge.masterBalls, label: "Master", color: magenta)
            }
            Text("Total: \(bridge.totalBalls) · use to catch creatures")
                .font(.caption2)
                .foregroundStyle(.secondary)

            // Dex progress bar
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("DEX PROGRESS")
                        .font(.system(size: 9, weight: .heavy, design: .rounded))
                        .kerning(0.8)
                    Spacer()
                    Text("\(Int(bridge.dexProgress * 100))%")
                        .font(.system(size: 10, weight: .heavy, design: .monospaced))
                }
                .foregroundStyle(.secondary)
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.white.opacity(0.06)).frame(height: 6)
                    GeometryReader { geo in
                        Capsule()
                            .fill(LinearGradient(colors: [mint, blue, magenta], startPoint: .leading, endPoint: .trailing))
                            .frame(width: max(4, geo.size.width * bridge.dexProgress), height: 6)
                            .shadow(color: magenta.opacity(0.4), radius: 4)
                    }
                    .frame(height: 6)
                }
            }
            .padding(.top, 4)
        }
    }

    private func ballChip(count: Int, label: String, color: Color) -> some View {
        VStack(spacing: 2) {
            ZStack {
                Circle().fill(color.gradient).frame(width: 18, height: 18)
                    .overlay(Circle().strokeBorder(.white.opacity(0.4), lineWidth: 0.8))
                    .shadow(color: color.opacity(0.5), radius: 4)
            }
            Text("\(count)")
                .font(.system(.caption, design: .rounded).weight(.heavy))
                .monospacedDigit()
            Text(label)
                .font(.system(size: 8, weight: .heavy, design: .rounded))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 5)
        .background(color.opacity(0.10), in: RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(color.opacity(0.25), lineWidth: 0.5))
    }

    private var quickActions: some View {
        VStack(spacing: 6) {
            Button {
                bridge.openFocusDex()
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "pawprint.fill")
                    Text("Open FocusDex").fontWeight(.heavy)
                }
                .font(.system(.subheadline, design: .rounded))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(LinearGradient(colors: [pink, magenta], startPoint: .topLeading, endPoint: .bottomTrailing),
                           in: RoundedRectangle(cornerRadius: 10))
                .foregroundStyle(.white)
                .shadow(color: magenta.opacity(0.4), radius: 6, y: 3)
            }
            .buttonStyle(.plain)

            HStack(spacing: 6) {
                smallButton(label: "Website", icon: "globe", color: blue) { bridge.openWebsite() }
                smallButton(label: "Live Demo", icon: "play.rectangle.fill", color: mint) { bridge.openDemo() }
            }
        }
    }

    private func smallButton(label: String, icon: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: icon).font(.system(size: 10))
                Text(label).font(.caption.weight(.bold))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 6)
            .background(color.opacity(0.18), in: RoundedRectangle(cornerRadius: 8))
            .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(color.opacity(0.4), lineWidth: 0.5))
            .foregroundStyle(color)
        }
        .buttonStyle(.plain)
    }

    private var notInstalledCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("FocusDex isn't installed yet.", systemImage: "exclamationmark.triangle.fill")
                .font(.subheadline.weight(.bold))
                .foregroundStyle(.orange)
            Text("Install the companion app to start catching creatures while you focus. Free, MIT-licensed, no sign-up.")
                .font(.caption)
                .foregroundStyle(.secondary)

            Button { bridge.openWebsite() } label: {
                HStack(spacing: 6) {
                    Image(systemName: "arrow.down.circle.fill")
                    Text("Get FocusDex").fontWeight(.heavy)
                }
                .font(.system(.subheadline, design: .rounded))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(LinearGradient(colors: [pink, magenta], startPoint: .topLeading, endPoint: .bottomTrailing),
                           in: RoundedRectangle(cornerRadius: 10))
                .foregroundStyle(.white)
            }
            .buttonStyle(.plain)

            Button { bridge.openDemo() } label: {
                HStack(spacing: 6) {
                    Image(systemName: "play.rectangle.fill")
                    Text("Try the browser demo").fontWeight(.bold)
                }
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 6)
            }
            .buttonStyle(.plain)
        }
        .padding(10)
        .background(RoundedRectangle(cornerRadius: 10).fill(Color.white.opacity(0.04)))
    }

    // MARK: - Helpers

    private func typeColor(_ type: String) -> Color {
        switch type {
        case "Code": return mint
        case "Doc": return blue
        case "Art": return pink
        default: return magenta
        }
    }

    private func starterSymbol(_ name: String) -> String {
        switch name {
        case "Codesprite": return "chevron.left.forwardslash.chevron.right"
        case "Inkling": return "drop.fill"
        case "Pixibrush": return "paintbrush.fill"
        default: return "pawprint.fill"
        }
    }
}

/// Gradient FocusDex wordmark with dark stroke (matches the design package).
private struct FocusDexWordmark: View {
    @State private var phase: CGFloat = 0
    var body: some View {
        Text("FocusDex")
            .font(.system(size: 18, weight: .black, design: .rounded))
            .foregroundStyle(
                LinearGradient(
                    colors: [
                        Color(red: 0.18, green: 0.90, blue: 0.63),
                        Color(red: 0.28, green: 0.63, blue: 1.00),
                        Color(red: 0.76, green: 0.28, blue: 1.00),
                        Color(red: 1.00, green: 0.42, blue: 0.42),
                    ],
                    startPoint: UnitPoint(x: phase, y: 0.5),
                    endPoint: UnitPoint(x: phase + 1, y: 0.5)
                )
            )
            .onAppear {
                withAnimation(.linear(duration: 6).repeatForever(autoreverses: false)) {
                    phase = -1
                }
            }
    }
}
