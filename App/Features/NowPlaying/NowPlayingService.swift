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
            DispatchQueue.global(qos: .utility).async {
                self?.probeInitialState()
            }
        }
    }

    // MARK: - Notification handlers

    private func handleAppleMusicNotification(_ note: Notification) {
        guard let info = note.userInfo else { return }

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
        t.isPlaying = (state == "Playing")
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
        fetchAppleMusicArtwork(matching: token)
    }

    private func handleSpotifyNotification(_ note: Notification) {
        guard let info = note.userInfo else { return }

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
        t.isPlaying = (state == "Playing")
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
        let state = parts[4].lowercased()
        t.isPlaying = state.contains("playing")

        active = source
        let token = UUID()
        artworkFetchToken = token
        publish(t)

        NSLog("NotchPop: probe found \(source) — \(t.title) — \(t.artist)")

        if source == .appleMusic {
            fetchAppleMusicArtwork(matching: token)
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

    private func fetchAppleMusicArtwork(matching token: UUID) {
        // AppleScript returns artwork as raw image data we can hand to
        // NSImage. Wrap in `try` because some tracks (cloud library, DRM)
        // simply have no artwork and the script will throw.
        let source = """
        tell application "Music"
            try
                if player state is not stopped then
                    tell artwork 1 of current track
                        return data
                    end tell
                end if
            on error
                return missing value
            end try
        end tell
        return missing value
        """
        DispatchQueue.global(qos: .utility).async { [weak self] in
            guard let self = self else { return }
            var err: NSDictionary?
            guard let script = NSAppleScript(source: source) else { return }
            let descriptor = script.executeAndReturnError(&err)
            guard err == nil,
                  descriptor.descriptorType != typeNull,
                  let img = NSImage(data: descriptor.data) else { return }
            DispatchQueue.main.async {
                guard self.artworkFetchToken == token else { return }
                self.track.artwork = img
            }
        }
    }

    // MARK: - Transport controls

    func togglePlayPause() {
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

    func nextTrack() {
        switch active {
        case .appleMusic:
            runScript(#"tell application "Music" to next track"#)
        case .spotify:
            runScript(#"tell application "Spotify" to next track"#)
        case .none:
            break
        }
    }

    func previousTrack() {
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

    private func runScriptReturningString(_ source: String) -> String? {
        var err: NSDictionary?
        guard let script = NSAppleScript(source: source) else { return nil }
        let descriptor = script.executeAndReturnError(&err)
        if err != nil { return nil }
        return descriptor.stringValue
    }

    deinit {
        pollTimer?.invalidate()
        DistributedNotificationCenter.default().removeObserver(self)
    }
}
