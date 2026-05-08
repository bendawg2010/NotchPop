// NowPlayingService.swift
//
// ----------------------------------------------------------------------------
// Why this file looks the way it does
// ----------------------------------------------------------------------------
// The previous implementation reached into Apple's private MediaRemote
// framework via dlopen + dlsym (MRMediaRemoteGetNowPlayingInfo et al). That
// trick worked for years but Apple has been progressively locking it down,
// and on macOS 26 it now returns an empty info dictionary even when Apple
// Music or Spotify is actively playing. So MediaRemote is no longer a
// reliable source of truth.
//
// Instead we listen for the per-app distributed notifications that Apple
// Music and Spotify post whenever their playback state changes. These have
// been a stable public contract for over a decade — every "scrobbler" and
// menu-bar player on macOS uses them.
//
//   com.apple.Music.playerInfo            (Apple Music)
//   com.apple.iTunes.playerInfo           (legacy iTunes — defensive)
//   com.apple.Spotify.PlayerStateChanged  (Spotify)
//
// Each notification's userInfo dictionary carries the track metadata
// (Name / Artist / Album / Player State / duration / etc.). For Spotify
// we also get an `Artwork URL` we can fetch via URLSession. For Apple
// Music there is no artwork in the notification, so we fall back to
// AppleScript ("tell application \"Music\" to ...") to pull the artwork
// from `current track`. If that fails we just leave artwork empty.
//
// Transport controls (play/pause/skip) are also driven via AppleScript
// against whichever app posted the most recent notification (the "active"
// player). AppleScript is overkill for the data path, but it's a clean
// way to issue commands without needing accessibility permissions.
//
// On start():
//   1. Subscribe to the three distributed notifications.
//   2. Immediately probe both apps via AppleScript so that if music is
//      already playing when NotchPop launches, the notch picks it up
//      without waiting for the next track change.
//
// All @Published mutations are dispatched to .main so SwiftUI can observe
// them safely.
//
// Verification: play a song in Apple Music or Spotify and the Music tab
// in NotchPop should show the title + artist within a second.
// ----------------------------------------------------------------------------

import AppKit
import Combine
import Foundation

/// Snapshot of the currently-playing track.
struct NowPlayingTrack: Equatable {
    var title: String
    var artist: String
    var album: String
    var artwork: NSImage?
    var isPlaying: Bool
    var duration: TimeInterval
    var elapsed: TimeInterval

    static let empty = NowPlayingTrack(
        title: "", artist: "", album: "", artwork: nil,
        isPlaying: false, duration: 0, elapsed: 0
    )

    var isEmpty: Bool { title.isEmpty && artist.isEmpty }
}

final class NowPlayingService: ObservableObject {
    @Published var track: NowPlayingTrack = .empty

    /// Which app's state we're currently mirroring. Whichever app posted
    /// the most recent notification wins — that's almost always the one
    /// the user is actively listening to. Transport commands route here.
    private enum ActivePlayer {
        case none
        case appleMusic
        case spotify
    }
    private var active: ActivePlayer = .none

    /// Track the in-flight artwork fetch so we can ignore stale responses
    /// if the song changes before the previous download completes.
    private var artworkFetchToken: UUID?

    // Distributed notification names. Defined as constants so typos
    // surface at compile time rather than as silently-missing updates.
    private let appleMusicNotification = Notification.Name("com.apple.Music.playerInfo")
    private let iTunesNotification     = Notification.Name("com.apple.iTunes.playerInfo")
    private let spotifyNotification    = Notification.Name("com.apple.Spotify.PlayerStateChanged")

    private var pollTimer: Timer?

    /// Timestamp of the most recent distributed-notification handler run.
    /// The 5s polling timer consults this to skip a probe if a notification
    /// fired within the last second — notification data is fresher than
    /// AppleScript probes and we don't want a stale probe overwriting it.
    private var lastNotificationAt: Date?

    func start() {
        let center = DistributedNotificationCenter.default()

        center.addObserver(
            forName: appleMusicNotification, object: nil, queue: .main
        ) { [weak self] note in
            self?.handleAppleMusicNotification(note)
        }
        center.addObserver(
            forName: iTunesNotification, object: nil, queue: .main
        ) { [weak self] note in
            self?.handleAppleMusicNotification(note)
        }
        center.addObserver(
            forName: spotifyNotification, object: nil, queue: .main
        ) { [weak self] note in
            self?.handleSpotifyNotification(note)
        }

        // Initial probe — distributed notifications don't replay history,
        // so without this the notch stays blank if music was already
        // playing when we launched.
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            self?.probeInitialState()
        }

        // Periodic re-probe — covers cases where:
        //   • Music started AFTER NotchPop launched and the distributed
        //     notification didn't fire (some media-key paths skip it).
        //   • The user switched between Apple Music and Spotify during
        //     a session and we haven't seen a notification since.
        //   • The current track's elapsed time advances — we update it.
        // Cheap: runs every 5s, only does work if a music app is running.
        pollTimer?.invalidate()
        pollTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            // Skip the probe if a notification handler just fired — its
            // payload is fresher than anything AppleScript would return
            // and re-probing risks overwriting good state with stale data.
            if let last = self.lastNotificationAt,
               Date().timeIntervalSince(last) < 1.0 {
                return
            }
            DispatchQueue.global(qos: .utility).async {
                self.probeInitialState()
            }
        }
    }

    // MARK: - Notification handlers

    private func handleAppleMusicNotification(_ note: Notification) {
        guard let info = note.userInfo else { return }
        lastNotificationAt = Date()

        let state = (info["Player State"] as? String) ?? ""
        // When the user quits Music, "Stopped" arrives with empty fields.
        // Treat that as "nothing playing" rather than a half-empty track.
        if state == "Stopped" && (info["Name"] as? String)?.isEmpty != false {
            DispatchQueue.main.async { [weak self] in
                self?.active = .none
                self?.track = .empty
            }
            return
        }

        var t = NowPlayingTrack.empty
        t.title  = (info["Name"]   as? String) ?? ""
        t.artist = (info["Artist"] as? String) ?? ""
        t.album  = (info["Album"]  as? String) ?? ""
        // Parse playback state defensively. Apple Music typically ships
        // "Playing" / "Paused" / "Stopped" but on macOS 26 we've also
        // seen four-char-codes like "kPSP" leak through. If we can't
        // parse it, preserve the previous isPlaying value rather than
        // forcing it to false (which made the play/pause icon stale).
        let lower = state.lowercased()
        if lower.contains("playing") {
            t.isPlaying = true
        } else if lower.contains("paus") || lower.contains("stop") {
            t.isPlaying = false
        } else {
            t.isPlaying = track.isPlaying
        }
        // Apple Music ships duration in milliseconds.
        if let totalMs = info["Total Time"] as? Double {
            t.duration = totalMs / 1000.0
        }
        // Player Position is sometimes there, sometimes not.
        if let pos = info["Player Position"] as? Double {
            t.elapsed = pos
        }

        active = .appleMusic
        // Invalidate any pending Spotify artwork fetch.
        let token = UUID()
        artworkFetchToken = token

        publish(t)

        // Apple Music doesn't put artwork in the notification, so kick
        // off an AppleScript query for it. Result arrives async.
        fetchAppleMusicArtwork(matching: token, title: t.title, artist: t.artist)
    }

    private func handleSpotifyNotification(_ note: Notification) {
        guard let info = note.userInfo else { return }
        lastNotificationAt = Date()

        let state = (info["Player State"] as? String) ?? ""
        if state == "Stopped" {
            DispatchQueue.main.async { [weak self] in
                self?.active = .none
                self?.track = .empty
            }
            return
        }

        var t = NowPlayingTrack.empty
        t.title  = (info["Name"]   as? String) ?? ""
        t.artist = (info["Artist"] as? String) ?? ""
        t.album  = (info["Album"]  as? String) ?? ""
        // Defensive parse: macOS 26 has been observed sending the raw
        // four-char-code "kPSP" instead of "Playing" — preserve the
        // previous isPlaying rather than defaulting to false on garbage.
        let lower = state.lowercased()
        if lower.contains("playing") {
            t.isPlaying = true
        } else if lower.contains("paus") || lower.contains("stop") {
            t.isPlaying = false
        } else {
            t.isPlaying = track.isPlaying
        }
        // Spotify also uses milliseconds for Duration.
        if let durMs = info["Duration"] as? Double {
            t.duration = durMs / 1000.0
        }

        active = .spotify
        let token = UUID()
        artworkFetchToken = token

        publish(t)

        // Spotify hands us an https URL for the cover art — fetch it.
        if let urlString = info["Artwork URL"] as? String,
           let url = URL(string: urlString) {
            fetchSpotifyArtwork(from: url, matching: token)
        }
    }

    // MARK: - Initial probe (AppleScript)

    /// Both Music and Spotify expose AppleScript dictionaries that let us
    /// read the current track without launching the app. The `if it is
    /// `running` guard is critical — referencing `current track` on a
    /// non-running app would launch it, which is exactly what we don't want.
    ///
    /// IMPORTANT: previous version used `\u{1F}` (ASCII 0x1F) as a field
    /// separator inside the AppleScript source. AppleScript's parser
    /// silently treated the embedded control character as whitespace,
    /// which made the probe return empty strings. Switched to a
    /// printable token separator `|||DG|||` that survives AppleScript
    /// concatenation cleanly.
    private static let probeSep = "|||DG|||"

    private func probeInitialState() {
        // Apple Music first.
        let musicSource = """
        tell application "System Events"
            set isRunning to (exists (processes where name is "Music"))
        end tell
        if isRunning then
            tell application "Music"
                if player state is not stopped then
                    try
                        set t to name of current track
                        set a to artist of current track
                        set al to album of current track
                        set d to duration of current track
                        set ps to (player state as text)
                        return t & "\(Self.probeSep)" & a & "\(Self.probeSep)" & al & "\(Self.probeSep)" & d & "\(Self.probeSep)" & ps
                    on error
                        return ""
                    end try
                end if
            end tell
        end if
        return ""
        """
        if let result = runScriptReturningString(musicSource), !result.isEmpty {
            applyProbeResult(result, source: .appleMusic)
        }

        // Then Spotify (only if Music isn't already active).
        let spotifySource = """
        tell application "System Events"
            set isRunning to (exists (processes where name is "Spotify"))
        end tell
        if isRunning then
            tell application "Spotify"
                if player state is not stopped then
                    try
                        set t to name of current track
                        set a to artist of current track
                        set al to album of current track
                        set d to duration of current track
                        set ps to (player state as text)
                        return t & "\(Self.probeSep)" & a & "\(Self.probeSep)" & al & "\(Self.probeSep)" & d & "\(Self.probeSep)" & ps
                    on error
                        return ""
                    end try
                end if
            end tell
        end if
        return ""
        """
        if active != .appleMusic,
           let result = runScriptReturningString(spotifySource), !result.isEmpty {
            applyProbeResult(result, source: .spotify)
        }
    }

    private func applyProbeResult(_ raw: String, source: ActivePlayer) {
        // Log the raw probe result so we can verify the separator survived
        // AppleScript's coercion path on whatever macOS the user is on.
        NSLog("NotchPop: raw probe result for \(source): \(raw)")

        let parts = raw.components(separatedBy: Self.probeSep)
        guard parts.count >= 5 else {
            NSLog("NotchPop: probe returned malformed result: \(raw)")
            return
        }

        var t = NowPlayingTrack.empty
        t.title  = parts[0]
        t.artist = parts[1]
        t.album  = parts[2]
        if let d = Double(parts[3]) {
            t.duration = d
        }
        // Same defensive logic as the notification handlers: if the state
        // string is empty or unrecognizable, preserve the existing
        // isPlaying. Otherwise we'd flip the icon to "play" the moment
        // the probe runs against e.g. macOS 26's "kPSP" code.
        let state = parts[4].lowercased()
        if state.contains("playing") {
            t.isPlaying = true
        } else if state.contains("paus") || state.contains("stop") {
            t.isPlaying = false
        } else if state.isEmpty {
            t.isPlaying = track.isPlaying
        } else {
            t.isPlaying = track.isPlaying
        }

        active = source
        let token = UUID()
        artworkFetchToken = token
        publish(t)

        NSLog("NotchPop: probe found \(source) — \(t.title) — \(t.artist)")

        if source == .appleMusic {
            fetchAppleMusicArtwork(matching: token, title: t.title, artist: t.artist)
        }
    }

    // MARK: - Artwork fetching

    private func fetchSpotifyArtwork(from url: URL, matching token: UUID) {
        let task = URLSession.shared.dataTask(with: url) { [weak self] data, _, _ in
            guard let self = self,
                  let data = data,
                  let img = NSImage(data: data) else { return }
            DispatchQueue.main.async {
                // Only apply artwork if the song hasn't changed mid-flight.
                guard self.artworkFetchToken == token else { return }
                self.track.artwork = img
            }
        }
        task.resume()
    }

    /// Fetch artwork for the currently-playing Apple Music track.
    ///
    /// macOS 26 changed Music.app's AppleScript artwork interface: the
    /// classic `data of artwork 1` path now sometimes returns a
    /// `typeFileURL` descriptor (a URL to a temp file) or a `typeBoolean`
    /// (when artwork is missing) instead of raw image bytes. We try
    /// several paths in sequence and fall back to the public iTunes
    /// Search API as a last resort — that path requires no permissions
    /// and works even when AppleScript is restricted.
    ///
    /// The `title` / `artist` parameters power the iTunes Search fallback.
    /// They're captured at the moment we kick off the fetch so a track
    /// change mid-flight won't cause us to query for the wrong song.
    private func fetchAppleMusicArtwork(matching token: UUID, title: String, artist: String) {
        // AppleScript returns artwork as raw image data we can hand to
        // NSImage. Wrap in `try` because some tracks (cloud library, DRM)
        // simply have no artwork and the script will throw.
        //
        // Path 1: `tell artwork 1 of current track to return raw data`.
        // Path 2: `data of artwork 1 of current track`.
        // Path 3: iTunes Search API (URL-based).
        let primarySource = """
        tell application "Music"
            try
                if player state is not stopped then
                    tell artwork 1 of current track
                        return raw data
                    end tell
                end if
            on error
                return missing value
            end try
        end tell
        return missing value
        """
        let fallbackSource = """
        tell application "Music"
            try
                if player state is not stopped then
                    return data of artwork 1 of current track
                end if
            on error
                return missing value
            end try
        end tell
        return missing value
        """
        DispatchQueue.global(qos: .utility).async { [weak self] in
            guard let self = self else { return }

            if let img = self.runArtworkScript(primarySource) {
                self.applyArtwork(img, token: token)
                return
            }
            if let img = self.runArtworkScript(fallbackSource) {
                self.applyArtwork(img, token: token)
                return
            }
            // Last resort: iTunes Search API. No auth needed, returns JSON.
            self.fetchArtworkFromITunesSearch(title: title, artist: artist, token: token)
        }
    }

    /// Run an AppleScript that should return artwork bytes and decode
    /// the result into an NSImage. Returns nil on any failure path —
    /// missing artwork, wrong descriptor type, undecodable bytes, etc.
    private func runArtworkScript(_ source: String) -> NSImage? {
        var err: NSDictionary?
        guard let script = NSAppleScript(source: source) else { return nil }
        let descriptor = script.executeAndReturnError(&err)
        if err != nil { return nil }
        // Guard against typeNull (no artwork) and typeBoolean (Music
        // sometimes returns `false` when artwork is missing). Empty
        // .data also means there's nothing to decode.
        guard descriptor.descriptorType != typeNull,
              descriptor.descriptorType != typeBoolean,
              !descriptor.data.isEmpty else {
            NSLog("NotchPop: artwork script returned non-data descriptor type=\(descriptor.descriptorType)")
            return nil
        }
        // If AppleScript handed us a file URL to a temp image, follow it.
        if descriptor.descriptorType == typeFileURL,
           let url = descriptor.fileURLValue,
           let data = try? Data(contentsOf: url),
           let img = NSImage(data: data) {
            return img
        }
        return NSImage(data: descriptor.data)
    }

    /// Apply artwork on the main thread, but only if the song hasn't
    /// changed since we kicked off this fetch (artworkFetchToken match).
    private func applyArtwork(_ img: NSImage, token: UUID) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self, self.artworkFetchToken == token else { return }
            self.track.artwork = img
        }
    }

    /// Public iTunes Search API fallback. URL pattern:
    /// https://itunes.apple.com/search?term={artist}+{title}&limit=1&entity=song
    /// We pull `artworkUrl100` from the first result and rewrite the
    /// "100x100" path component to "300x300" for a higher-res image.
    private func fetchArtworkFromITunesSearch(title: String, artist: String, token: UUID) {
        guard !title.isEmpty else { return }
        let term = "\(artist) \(title)"
        guard let encoded = term.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: "https://itunes.apple.com/search?term=\(encoded)&limit=1&entity=song") else {
            return
        }
        let task = URLSession.shared.dataTask(with: url) { [weak self] data, _, _ in
            guard let self = self,
                  let data = data,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let results = json["results"] as? [[String: Any]],
                  let first = results.first,
                  let artworkURLString = first["artworkUrl100"] as? String else {
                return
            }
            // 100x100 → 300x300 for a sharper image. The CDN serves the
            // requested size on demand; if rewriting fails just use 100x.
            let upgraded = artworkURLString.replacingOccurrences(of: "100x100", with: "300x300")
            guard let imgURL = URL(string: upgraded) else { return }
            URLSession.shared.dataTask(with: imgURL) { [weak self] imgData, _, _ in
                guard let self = self,
                      let imgData = imgData,
                      let img = NSImage(data: imgData) else { return }
                self.applyArtwork(img, token: token)
            }.resume()
        }
        task.resume()
    }

    // MARK: - Transport controls

    /// Toggle play/pause on the active player and OPTIMISTICALLY flip
    /// `track.isPlaying` immediately so the UI updates without waiting
    /// for the next distributed notification (which can lag 100–500ms
    /// or, on macOS 26, never arrive at all for some media-key paths).
    /// If the optimistic guess is wrong the next real notification or
    /// probe will correct it.
    func togglePlayPause() {
        // Flip optimistically first.
        let optimistic = !track.isPlaying
        if Thread.isMainThread {
            self.track.isPlaying = optimistic
        } else {
            DispatchQueue.main.async { [weak self] in self?.track.isPlaying = optimistic }
        }
        switch active {
        case .appleMusic:
            runScript(#"tell application "Music" to playpause"#)
        case .spotify:
            runScript(#"tell application "Spotify" to playpause"#)
        case .none:
            // Nothing's playing — try Apple Music as a sensible default.
            runScript(#"tell application "Music" to playpause"#)
        }
    }

    /// Skip forward. We can't optimistically populate the new track's
    /// metadata (we don't know it yet) but we can at least mark playback
    /// as active so the icon doesn't go stale — most "next track" cases
    /// land on a playing track.
    func nextTrack() {
        if Thread.isMainThread {
            self.track.isPlaying = true
        } else {
            DispatchQueue.main.async { [weak self] in self?.track.isPlaying = true }
        }
        switch active {
        case .appleMusic:
            runScript(#"tell application "Music" to next track"#)
        case .spotify:
            runScript(#"tell application "Spotify" to next track"#)
        case .none:
            break
        }
    }

    /// Skip back. Same optimistic isPlaying = true as nextTrack().
    func previousTrack() {
        if Thread.isMainThread {
            self.track.isPlaying = true
        } else {
            DispatchQueue.main.async { [weak self] in self?.track.isPlaying = true }
        }
        switch active {
        case .appleMusic:
            // "back track" rewinds; "previous track" jumps to prev song.
            // We want the latter to match user expectation of a "skip back".
            runScript(#"tell application "Music" to previous track"#)
        case .spotify:
            runScript(#"tell application "Spotify" to previous track"#)
        case .none:
            break
        }
    }

    // MARK: - Helpers

    private func publish(_ t: NowPlayingTrack) {
        // Preserve any artwork already on the previous track if title/artist
        // match — otherwise the UI flickers when a Position-only update
        // arrives without artwork bundled. The artwork fetcher will replace
        // it shortly if the song actually changed.
        var next = t
        if next.artwork == nil,
           track.title == next.title,
           track.artist == next.artist {
            next.artwork = track.artwork
        }
        if Thread.isMainThread {
            self.track = next
        } else {
            DispatchQueue.main.async { [weak self] in self?.track = next }
        }
    }

    private func runScript(_ source: String) {
        DispatchQueue.global(qos: .userInitiated).async {
            var err: NSDictionary?
            NSAppleScript(source: source)?.executeAndReturnError(&err)
        }
    }

    /// Run an AppleScript that should return a string. Defends against:
    ///   • Script compilation failure (nil from init).
    ///   • Runtime errors (non-nil err, returns nil).
    ///   • Non-string return types — descriptor.stringValue is nil if
    ///     AppleScript handed back e.g. a record or a boolean. We log
    ///     the descriptor type so we can debug the macOS 26 cases where
    ///     `(player state as text)` started returning non-text values.
    private func runScriptReturningString(_ source: String) -> String? {
        var err: NSDictionary?
        guard let script = NSAppleScript(source: source) else {
            NSLog("NotchPop: AppleScript failed to compile")
            return nil
        }
        let descriptor = script.executeAndReturnError(&err)
        if let err = err {
            NSLog("NotchPop: AppleScript runtime error: \(err)")
            return nil
        }
        guard let value = descriptor.stringValue else {
            NSLog("NotchPop: AppleScript returned non-string descriptor type=\(descriptor.descriptorType)")
            return nil
        }
        return value
    }

    deinit {
        pollTimer?.invalidate()
        DistributedNotificationCenter.default().removeObserver(self)
    }
}
