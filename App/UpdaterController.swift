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
//   SUAutomaticallyUpdate      → false (explicit prompts; silent install
//                                 trapped users on stale versions when
//                                 the relaunch swap failed)
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

    /// "Force update now" — nukes everything Sparkle and the URL
    /// session might have cached, then asks the updater to start a
    /// fresh cycle. Use this when a user reports being trapped on an
    /// old version (Sparkle saying "you're up to date" while the
    /// dialog mentions a NEWER version a line below).
    ///
    /// What we wipe (and why each one matters):
    ///   • SUSkippedVersion / SUSkippedMinorVersion — set when the
    ///     user clicked "Skip This Version" on a previous appcast
    ///     entry. Keeps the dialog showing "up to date" forever.
    ///   • SULastCheckTime / SUUpdaterLastCheckTime — Sparkle's
    ///     scheduling key. Clearing it forces a real check rather
    ///     than the cached "no update" answer.
    ///   • SUFeedLastModifiedString / SUFeedLastETagString — HTTP
    ///     If-Modified-Since / If-None-Match values. Without these
    ///     cleared, Cloudflare returns 304 Not Modified and Sparkle
    ///     re-uses its cached parse of the appcast.
    ///   • URLCache.shared — global NSURLCache that URLSession
    ///     consults. Sparkle uses URLSession internally; if our
    ///     prior response is in here, Sparkle never even hits the
    ///     network.
    /// And then we call controller.updater.resetUpdateCycle() — this
    /// is the official Sparkle API for "throw away whatever you've
    /// got and start a brand-new update cycle." Followed by a
    /// user-initiated checkForUpdates so the user sees the result.
    @objc func forceUpdateNow(_ sender: Any?) {
        NSLog("NotchPop: forceUpdateNow — nuking Sparkle + URL caches")
        let defaults = UserDefaults.standard
        for key in [
            "SUSkippedVersion",
            "SUSkippedMinorVersion",
            "SULastCheckTime",
            "SUFeedLastModifiedString",
            "SUFeedLastETagString",
            "SUUpdaterLastCheckTime",
            "SULastProfileSubmissionDate",
        ] {
            defaults.removeObject(forKey: key)
        }
        defaults.synchronize()

        // Clear NSURLCache — without this, URLSession serves us our
        // own previous response of the appcast, never going to the
        // network, never seeing the latest entries.
        URLCache.shared.removeAllCachedResponses()

        // Sparkle's official "start over" call — discards in-memory
        // appcast state, re-schedules the cycle from scratch.
        controller.updater.resetUpdateCycle()

        // Then a user-visible check so the user gets a sheet either
        // way (sees "you're up to date" with the LATEST version OR
        // "v1.5.X is available, install now").
        controller.checkForUpdates(sender)
    }

    /// Side-channel update check that bypasses Sparkle entirely —
    /// just fetches the appcast, parses the top entry, compares to
    /// the current bundle version. If a newer one exists, posts a
    /// system notification with a deep link to the DMG. Runs once at
    /// launch as a safety net for users where Sparkle's internal
    /// state has gone sideways.
    func runIndependentVersionCheck() {
        guard let url = URL(string: "https://notchpop.pages.dev/appcast.xml") else { return }
        var req = URLRequest(url: url, timeoutInterval: 10)
        req.cachePolicy = .reloadIgnoringLocalAndRemoteCacheData
        URLSession.shared.dataTask(with: req) { [weak self] data, _, error in
            guard let self = self,
                  let data = data,
                  error == nil,
                  let xml = String(data: data, encoding: .utf8) else { return }
            // Quick-and-dirty: pull the FIRST `<sparkle:version>...</sparkle:version>`
            // out of the document. The appcast prepends new entries,
            // so this is the latest version.
            guard let range = xml.range(of: #"<sparkle:version>([^<]+)</sparkle:version>"#,
                                         options: .regularExpression),
                  let inner = xml[range].range(of: #">[^<]+<"#, options: .regularExpression)
            else { return }
            let raw = xml[range][inner].dropFirst().dropLast()
            let latest = String(raw).trimmingCharacters(in: .whitespacesAndNewlines)
            let current = (Bundle.main.infoDictionary?["CFBundleShortVersionString"]
                           as? String) ?? "0.0"
            // Semantic-version-ish compare via NumericSearch — handles
            // 1.5.10 > 1.5.9 correctly without writing a real parser.
            if latest.compare(current, options: .numeric) == .orderedDescending {
                NSLog("NotchPop: independent check found newer version \(latest) > \(current)")
                DispatchQueue.main.async {
                    self.notify(
                        title: "NotchPop \(latest) available",
                        body: "Open Settings → Updates → Force Update Now, or click here to grab the DMG manually."
                    )
                }
            }
        }.resume()
    }

    /// Live binding for the menu item — disabled while Sparkle is busy.
    var canCheckForUpdates: Bool {
        controller.updater.canCheckForUpdates
    }

    /// Called once at launch — wipes Sparkle's "skipped version" key
    /// so a user who accidentally clicked "Skip This Version" on an
    /// old release isn't trapped forever. We deliberately do NOT
    /// touch SULastCheckTime here (Sparkle uses it to throttle) —
    /// just the skip lists.
    func clearSkippedVersionsOnLaunch() {
        let defaults = UserDefaults.standard
        if defaults.object(forKey: "SUSkippedVersion") != nil
            || defaults.object(forKey: "SUSkippedMinorVersion") != nil {
            NSLog("NotchPop: clearing stale SUSkippedVersion/SUSkippedMinorVersion at launch")
            defaults.removeObject(forKey: "SUSkippedVersion")
            defaults.removeObject(forKey: "SUSkippedMinorVersion")
            defaults.synchronize()
        }
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
    /// Override the feed URL with a cache-busting query string. The
    /// vanilla SUFeedURL from Info.plist would be sent as-is, and
    /// CDN/HTTP caching layers (Cloudflare's edge, NSURLCache,
    /// Sparkle's internal If-None-Match) could return a stale parse.
    /// By appending a per-launch random token we guarantee a fresh
    /// fetch on every check. Costs us nothing — the appcast is
    /// 5kb and the request happens at most a few times an hour.
    func feedURLString(for updater: SPUUpdater) -> String? {
        let base = "https://notchpop.pages.dev/appcast.xml"
        let bust = "t=\(Int(Date().timeIntervalSince1970))"
        return "\(base)?\(bust)"
    }

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
