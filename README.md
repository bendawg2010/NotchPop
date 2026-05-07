# NotchPop

> Your MacBook notch, but useful. Free, open-source competitor to NotchNook / NotchBox.

NotchPop is a tiny native macOS app that turns the notch into a hover-to-expand utility surface with **8 swappable widgets**:

- **📥 File shelf** — drag any file onto the notch, drag it back out anywhere
- **🎵 Music controls** — play / pause / skip Apple Music, Spotify, YouTube, podcasts
- **🍅 Pomodoro** — focus timer with strict mode + auto-start + daily goal
- **🕐 Stopwatch** — count-up timer with lap support + millisecond precision
- **⏱ Countdown Timer** — single-shot timer with ±30s nudges + final-5s flash
- **🌍 World Clock** — up to 4 cities, any of macOS's 600+ timezones
- **📝 Quick Notes** — auto-saving scratchpad
- **⚡ Charging peek** — plug-in cheer + battery readout

**Pick whichever ones you want, in whatever order.** Settings → Tabs lets you toggle and reorder.

- 🫥 **Blends with the hardware notch** — collapsed shape matches the physical notch width/height/corner-radius exactly. Invisible until you hover.
- ⚙️ **20+ customization knobs** — hover/collapse delay, auto-hide in fullscreen, launch at login, strict-mode Pomodoro, custom timezones, etc.

Works on non-notch Macs too — the UI just pins to the top-center of your main display.

## Install (no Xcode, no Homebrew, no Terminal)

**[⬇ Download NotchPop.zip from the latest release](https://github.com/bendawg2010/NotchPop/releases/latest/download/NotchPop.zip)** (~410 KB, universal binary, macOS 14+)

1. Click the link above — your browser saves `NotchPop.zip`.
2. Double-click the zip — you get `NotchPop.app`.
3. Drag `NotchPop.app` into `/Applications`.
4. **First-time launch:**
   1. Double-click NotchPop.app — macOS shows a security dialog ("can't verify the app"). Click **Done**.
   2. Open **System Settings → Privacy & Security**. Scroll down — you'll see *"NotchPop was blocked"*.
   3. Click **Open Anyway** → confirm with **Open**.

   This is a one-time thing. After this, double-click works normally — macOS adds NotchPop to its allow-list permanently.

   *Why? Apple charges $99/year for a Developer ID that lets unsigned apps open with a single click. NotchPop is free and open source, so we skip the fee — at the cost of one extra click on first launch. Same friction as HandBrake, OBS, and most other free Mac apps.*

That's it. The notch auto-expands for 5 seconds on first launch with a welcome card so you can see what it does. After that, hover any time to expand. Settings, Pomodoro reset, and Quit live in the menu-bar item (the rectangle icon, top-right of your screen).

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
