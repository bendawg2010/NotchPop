import Foundation
import AppKit
import Combine

/// Reads cross-app stats from FocusDex's UserDefaults.
/// FocusDex (com.dryeetsolutions.FocusDex) is not sandboxed, so its prefs
/// live in ~/Library/Preferences/com.dryeetsolutions.FocusDex.plist and
/// can be accessed by any other unsandboxed app via UserDefaults(suiteName:).
@MainActor
final class FocusDexBridge: ObservableObject {
    static let focusDexBundleID = "com.dryeetsolutions.FocusDex"
    static let focusDexAppPath = "/Applications/FocusDex.app"
    static let websiteURL = URL(string: "https://focusdex.pages.dev")!

    @Published private(set) var pokeballs: Int = 0
    @Published private(set) var greatBalls: Int = 0
    @Published private(set) var ultraBalls: Int = 0
    @Published private(set) var masterBalls: Int = 0
    @Published private(set) var totalSessions: Int = 0
    @Published private(set) var totalFocusMin: Double = 0
    @Published private(set) var currentStreak: Int = 0
    @Published private(set) var bestStreak: Int = 0
    @Published private(set) var caughtCount: Int = 0
    @Published private(set) var hasChosenStarter: Bool = false
    @Published private(set) var starterId: Int = 0
    @Published private(set) var focusDexInstalled: Bool = false

    private var timer: Timer?

    init() {
        refresh()
        timer = Timer.scheduledTimer(withTimeInterval: 4.0, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.refresh() }
        }
    }

    deinit {
        timer?.invalidate()
    }

    func refresh() {
        focusDexInstalled = FileManager.default.fileExists(atPath: Self.focusDexAppPath)
        guard let fd = UserDefaults(suiteName: Self.focusDexBundleID) else { return }

        pokeballs       = fd.integer(forKey: "fd.pokeballs")
        greatBalls      = fd.integer(forKey: "fd.greatBalls")
        ultraBalls      = fd.integer(forKey: "fd.ultraBalls")
        masterBalls     = fd.integer(forKey: "fd.masterBalls")
        totalSessions   = fd.integer(forKey: "fd.totalSessions")
        totalFocusMin   = fd.double(forKey: "fd.totalFocusMin")
        currentStreak   = fd.integer(forKey: "fd.currentStreak")
        bestStreak      = fd.integer(forKey: "fd.bestStreak")
        hasChosenStarter = fd.bool(forKey: "fd.hasChosenStarter")
        starterId       = fd.integer(forKey: "fd.starterId")

        // Caught creatures are stored as JSON-encoded [Creature] under `fd.caughtCreatures`.
        // Parse just the top-level array length without needing the struct definition.
        if let data = fd.data(forKey: "fd.caughtCreatures"),
           let array = try? JSONSerialization.jsonObject(with: data) as? [Any] {
            caughtCount = array.count
        } else {
            caughtCount = 0
        }
    }

    var totalBalls: Int { pokeballs + greatBalls + ultraBalls + masterBalls }
    var dexProgress: Double { Double(caughtCount) / 147.0 }
    var formattedFocusTime: String {
        let total = Int(totalFocusMin)
        let h = total / 60
        let m = total % 60
        if h > 0 { return "\(h)h \(m)m" }
        return "\(m)m"
    }

    var starterName: String? {
        switch starterId {
        case 1: return "Codesprite"
        case 4: return "Inkling"
        case 7: return "Pixibrush"
        default: return nil
        }
    }

    var starterPrimaryType: String? {
        switch starterId {
        case 1: return "Code"
        case 4: return "Doc"
        case 7: return "Art"
        default: return nil
        }
    }

    // MARK: - Actions

    func openFocusDex() {
        if focusDexInstalled {
            let url = URL(fileURLWithPath: Self.focusDexAppPath)
            NSWorkspace.shared.openApplication(at: url, configuration: .init())
        } else {
            NSWorkspace.shared.open(Self.websiteURL)
        }
    }

    func openWebsite() {
        NSWorkspace.shared.open(Self.websiteURL)
    }

    func openDemo() {
        NSWorkspace.shared.open(URL(string: "https://focusdex.pages.dev/demo")!)
    }
}
