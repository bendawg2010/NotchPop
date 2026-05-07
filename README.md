# NotchPop

> Your MacBook notch, but useful. Free, open-source competitor to NotchNook / NotchBox.

NotchPop is a tiny native macOS app that turns the notch on 14" / 16" MacBook Pros into a hover-to-expand utility surface:

- **📥 File shelf** — drag any file onto the notch, drag it out anywhere later. No copies, no syncing, no upload.
- **🎵 Now Playing** — album art + track info from Music, Spotify, YouTube, anything with media controls.
- **⚡ Charging peek** — plug in your MacBook and the notch briefly expands with a battery cheer.

Works on non-notch Macs too — the UI just pins to the top-center of your main display.

## Build it

```sh
git clone https://github.com/bendawg2010/NotchPop.git
cd NotchPop
./scripts/build.sh
```

The build script installs `xcodegen` via Homebrew if it's not already there, generates the Xcode project, and runs `xcodebuild` in Release. Output lands at `build/Build/Products/Release/NotchPop.app`.

Move it into `/Applications` and launch — the notch starts expanding on hover immediately. Quit / settings live in the menubar (the rectangle icon top-right).

### Prerequisites
- macOS 14+ (Sonoma)
- [Homebrew](https://brew.sh)
- [Xcode 15+](https://apps.apple.com/us/app/xcode/id497799835)

## How it works

A single borderless `NSWindow` is pinned at the top-center of the main display, sized to hug the notch. SwiftUI renders a `NotchShape` (flat top, rounded bottom corners) that animates on hover via `onHover`. When expanded, three tabs swap in: file shelf, now-playing, battery.

- **File shelf** uses standard SwiftUI `onDrop(of: [.fileURL])` and `onDrag` with `NSItemProvider(object: url as NSURL)`. Drag in from any source, drag out to any sink.
- **Now Playing** dlopens `/System/Library/PrivateFrameworks/MediaRemote.framework/MediaRemote` to read the system Now-Playing center. Same trick used by every app in this category.
- **Charging** watches `IOPSNotificationCreateRunLoopSource` for power-source changes and triggers a 4-second peek when you plug in.

Window detection of the notch dimensions uses `NSScreen.main.safeAreaInsets.top` (height) and `auxiliaryTopLeftArea` / `auxiliaryTopRightArea` (width).

## Compared to NotchNook / Boring Notch

|                   | NotchPop  | NotchNook       | Boring Notch |
|-------------------|-----------|-----------------|--------------|
| Price             | Free      | $24.99          | Free         |
| Open source       | Yes (MIT) | No              | Yes          |
| File shelf        | ✓         | ✓               | Limited      |
| Now Playing       | ✓         | ✓               | ✓            |
| Charging peek     | ✓         | ✓               | ✓            |
| Login required    | No        | Yes             | No           |

## License

MIT. See [LICENSE](LICENSE).

## Sponsor

If this saved you $25, the [tip jar](https://cash.app/$Dryeetsolutions) is open. Or [GitHub Sponsors](https://github.com/sponsors/bendawg2010).
