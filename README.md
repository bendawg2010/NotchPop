# NotchPop

> Your MacBook notch, but useful. Free, open-source competitor to NotchNook / NotchBox.

NotchPop is a tiny native macOS app that turns the notch on 14" / 16" MacBook Pros into a hover-to-expand utility surface:

- **📥 File shelf** — drag any file onto the notch, drag it out anywhere later. No copies, no syncing, no upload.
- **🎵 Now Playing** — album art + track info from Music, Spotify, YouTube, anything with media controls.
- **⚡ Charging peek** — plug in your MacBook and the notch briefly expands with a battery cheer.

Works on non-notch Macs too — the UI just pins to the top-center of your main display.

## Install (no Xcode, no Homebrew, no Terminal)

**[⬇ Download NotchPop.zip from the latest release](https://github.com/bendawg2010/NotchPop/releases/latest/download/NotchPop.zip)** (248 KB, universal binary, macOS 14+)

1. Click the link above. Your browser saves `NotchPop.zip`.
2. Open the zip — you'll get `NotchPop.app`.
3. Drag `NotchPop.app` into `/Applications`.
4. **First-time launch:** macOS will say *"Apple cannot check it for malicious software."* This is because the app isn't signed by a paid Apple Developer ID (this is free and open source). To allow it:
   - **Right-click** `NotchPop.app` → **Open** → click **Open** in the dialog.
   - You only need to do this once.

That's it. The notch starts expanding on hover immediately. Quit / settings live in the menubar (the rectangle icon, top-right of your screen).

### Requirements
- macOS 14 (Sonoma) or later
- Apple Silicon **or** Intel (universal binary)
- Looks best on 14" / 16" MacBook Pros with notches, but works on any Mac

## Build from source (optional)

If you'd rather not run a downloaded binary, you can build it yourself:

```sh
git clone https://github.com/bendawg2010/NotchPop.git
cd NotchPop
./scripts/build.sh
```

The build script auto-installs `xcodegen` via Homebrew, generates the Xcode project, and runs `xcodebuild` in Release. Output lands at `build/Build/Products/Release/NotchPop.app`.

### Build prerequisites
- [Homebrew](https://brew.sh) — for `xcodegen`
- [Xcode 15+](https://apps.apple.com/us/app/xcode/id497799835) **OR** Xcode Command Line Tools (`xcode-select --install`, ~2 minutes / ~3 GB vs. Xcode's 15 GB)

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
