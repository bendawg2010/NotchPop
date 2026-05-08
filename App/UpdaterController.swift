// UpdaterController.swift
//
// Wraps Sparkle's SPUStandardUpdaterController so the rest of the app
// can talk to it without importing Sparkle types directly. AppDelegate
// holds an instance and exposes a "Check for Updates…" menubar item;
// Sparkle handles everything else (background polling of the appcast,
// download with progress UI, user-prompt for permission to install,
// relaunch).
//
// Configuration lives in Info.plist — see project.yml:
//   SUFeedURL                  → https://notchpop.pages.dev/appcast.xml
//   SUPublicEDKey              → ed25519 verifier (private key in Keychain)
//   SUEnableAutomaticChecks    → true
//   SUScheduledCheckInterval   → 14400 (4 hours)
//   SUAutomaticallyUpdate      → true (silent install on relaunch)
//
// On top of Sparkle's built-in modal sheet, we ALSO post system
// notifications via UNUserNotificationCenter at each step of the
// update lifecycle ("Update found", "Update installing", "Updated to
// vX.Y.Z"). The notch app runs LSUIElement so it has no Dock icon —
// the user's only indication that an update happened would otherwise
// be the Sparkle sheet popping up unexpectedly.

import AppKit
import Sparkle
import UserNotifications

final class UpdaterController: NSObject {
    /// The standard Sparkle controller. Initialised lazily so Sparkle
    /// only starts polling once the app finishes launching.
    private(set) lazy var controller: SPUStandardUpdaterController =
        SPUStandardUpdaterController(
            startingUpdater: true,
            updaterDelegate: self,
            userDriverDelegate: nil
        )

    override init() {
        super.init()
        // Request notification permission on first launch. Silently
        // no-ops on subsequent launches if already granted.
        UNUserNotificationCenter.current()
            .requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    /// Trigger a user-initiated check for updates. Sparkle pops a sheet
    /// regardless of result (so the user knows we actually checked).
    @objc func checkForUpdates(_ sender: Any?) {
        controller.checkForUpdates(sender)
    }

    /// Live binding for the menu item — disabled while Sparkle is busy.
    var canCheckForUpdates: Bool {
        controller.updater.canCheckForUpdates
    }

    // MARK: - Notification helper
    private func notify(title: String, body: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        let req = UNNotificationRequest(
            identifier: "notchpop.update." + UUID().uuidString,
            content: content,
            trigger: nil)
        UNUserNotificationCenter.current().add(req)
    }
}

extension UpdaterController: SPUUpdaterDelegate {
    /// Read SUFeedURL from Info.plist (returning nil here means Sparkle
    /// uses the plist value rather than letting us override).
    func feedURLString(for updater: SPUUpdater) -> String? { nil }

    func updater(_ updater: SPUUpdater,
                 didFindValidUpdate item: SUAppcastItem) {
        NSLog("NotchPop Sparkle: found update \(item.versionString)")
        notify(
            title: "NotchPop update available",
            body: "v\(item.versionString) is ready to install."
        )
    }

    func updaterDidNotFindUpdate(_ updater: SPUUpdater) {
        NSLog("NotchPop Sparkle: no update available")
    }

    func updater(_ updater: SPUUpdater,
                 willInstallUpdate item: SUAppcastItem) {
        notify(
            title: "Installing NotchPop v\(item.versionString)",
            body: "NotchPop will relaunch in a moment."
        )
    }

    func updater(_ updater: SPUUpdater,
                 didFinishUpdateCycleFor updateCheck: SPUUpdateCheck,
                 error: Error?) {
        if let error = error {
            NSLog("NotchPop Sparkle: cycle error \(error.localizedDescription)")
        }
    }

    // Notify-on-version-drift: cleanest way to surface "you were just
    // updated" without relying on Sparkle delegate methods that vary
    // between Sparkle versions. We compare the current bundle version
    // against the last one we saw at launch — if they differ, post the
    // notification and update the stored value.
    func notifyIfJustUpdated() {
        let currentVersion = (Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String)
            ?? "unknown"
        let key = "np.updater.lastKnownVersion"
        let lastSeen = UserDefaults.standard.string(forKey: key)
        if let lastSeen = lastSeen, lastSeen != currentVersion {
            notify(
                title: "NotchPop updated",
                body: "You're now on v\(currentVersion). Hover the notch to see what's new."
            )
        }
        UserDefaults.standard.set(currentVersion, forKey: key)
    }
}
