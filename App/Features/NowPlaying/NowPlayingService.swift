// NowPlayingService.swift
//
// Reads the system "now playing" info via Apple's private MediaRemote
// framework. Same trick used by every app in this category — there is
// no public API for "what is currently playing on this Mac" other
// than through this private framework.
//
// We dlopen MediaRemote and resolve four symbols:
//   MRMediaRemoteGetNowPlayingInfo
//   MRMediaRemoteRegisterForNowPlayingNotifications
//   MRMediaRemoteSendCommand                  (skip, play, pause)
//   kMRMediaRemoteNowPlayingInfoArtwork etc.
//
// If MediaRemote is unavailable (rare, but not impossible on locked-down
// macOS), the service silently no-ops and the UI shows a friendly
// "Nothing playing" state.

import AppKit
import Combine

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

    private var dylib: UnsafeMutableRawPointer?
    private var nowPlayingInfoFn: MRGetNowPlayingInfo?
    private var registerForNotificationsFn: MRRegister?
    private var sendCommandFn: MRSendCommand?

    typealias MRGetNowPlayingInfo = @convention(c) (DispatchQueue, @escaping ([String: Any]) -> Void) -> Void
    /// `MRMediaRemoteRegisterForNowPlayingNotifications(dispatch_queue_t)`
    /// — takes the queue notifications should fire on. Mis-declared as
    /// (Bool) before, which crashed because passing `true` resulted in
    /// MRMediaRemote treating address 0x1 as a queue object and segfaulting
    /// during the internal objc_retain.
    typealias MRRegister = @convention(c) (DispatchQueue) -> Void
    /// `MRMediaRemoteSendCommand(commandID, options)` — returns a Bool
    /// success but we don't use the return value.
    typealias MRSendCommand = @convention(c) (Int32, AnyObject?) -> Bool

    /// MediaRemote command IDs — these are stable across macOS versions
    /// because Apple's own Control Center uses them too. Sourcing:
    /// https://github.com/PrivateFrameworks/MediaRemote (community-
    /// reverse-engineered headers).
    private struct Cmd {
        static let play: Int32 = 0
        static let pause: Int32 = 1
        static let togglePlayPause: Int32 = 2
        static let stop: Int32 = 3
        static let nextTrack: Int32 = 4
        static let previousTrack: Int32 = 5
        static let toggleShuffle: Int32 = 26
        static let toggleRepeat: Int32 = 27
    }

    func start() {
        let path = "/System/Library/PrivateFrameworks/MediaRemote.framework/MediaRemote"
        guard let h = dlopen(path, RTLD_LAZY) else {
            // MediaRemote not available — leave track empty.
            return
        }
        self.dylib = h

        if let sym = dlsym(h, "MRMediaRemoteGetNowPlayingInfo") {
            self.nowPlayingInfoFn = unsafeBitCast(sym, to: MRGetNowPlayingInfo.self)
        }
        if let sym = dlsym(h, "MRMediaRemoteRegisterForNowPlayingNotifications") {
            self.registerForNotificationsFn = unsafeBitCast(sym, to: MRRegister.self)
        }
        if let sym = dlsym(h, "MRMediaRemoteSendCommand") {
            self.sendCommandFn = unsafeBitCast(sym, to: MRSendCommand.self)
        }

        registerForNotificationsFn?(.main)

        NotificationCenter.default.addObserver(
            forName: NSNotification.Name("kMRMediaRemoteNowPlayingInfoDidChangeNotification"),
            object: nil, queue: .main) { [weak self] _ in self?.refresh() }
        NotificationCenter.default.addObserver(
            forName: NSNotification.Name("kMRMediaRemoteNowPlayingApplicationIsPlayingDidChangeNotification"),
            object: nil, queue: .main) { [weak self] _ in self?.refresh() }

        refresh()
        // Periodic refresh every 5s in case notifications get dropped
        Timer.scheduledTimer(withTimeInterval: 5, repeats: true) { [weak self] _ in self?.refresh() }
    }

    private func refresh() {
        guard let fn = nowPlayingInfoFn else { return }
        fn(.main) { [weak self] info in
            guard let self = self else { return }
            var t = NowPlayingTrack.empty
            t.title = (info["kMRMediaRemoteNowPlayingInfoTitle"] as? String) ?? ""
            t.artist = (info["kMRMediaRemoteNowPlayingInfoArtist"] as? String) ?? ""
            t.album = (info["kMRMediaRemoteNowPlayingInfoAlbum"] as? String) ?? ""
            t.duration = (info["kMRMediaRemoteNowPlayingInfoDuration"] as? Double) ?? 0
            t.elapsed = (info["kMRMediaRemoteNowPlayingInfoElapsedTime"] as? Double) ?? 0
            t.isPlaying = (info["kMRMediaRemoteNowPlayingInfoPlaybackRate"] as? Double ?? 0) > 0
            if let data = info["kMRMediaRemoteNowPlayingInfoArtworkData"] as? Data {
                t.artwork = NSImage(data: data)
            }
            self.track = t
        }
    }

    // MARK: - Transport controls (work with Apple Music, Spotify,
    // YouTube, podcasts, anything that registers with the system
    // Now-Playing center). These all forward to MRMediaRemoteSendCommand.

    func togglePlayPause() { _ = sendCommandFn?(Cmd.togglePlayPause, nil) }
    func nextTrack()       { _ = sendCommandFn?(Cmd.nextTrack, nil) }
    func previousTrack()   { _ = sendCommandFn?(Cmd.previousTrack, nil) }

    deinit {
        if let h = dylib { dlclose(h) }
    }
}
