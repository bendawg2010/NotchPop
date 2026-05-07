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

    typealias MRGetNowPlayingInfo = @convention(c) (DispatchQueue, @escaping ([String: Any]) -> Void) -> Void
    typealias MRRegister = @convention(c) (Bool) -> Void

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

        registerForNotificationsFn?(true)

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

    deinit {
        if let h = dylib { dlclose(h) }
    }
}
