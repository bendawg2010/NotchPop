# Claude Animation Design Prompts

Paste these into Claude (or any image / motion-design AI) when you
want concept art / storyboards / SVG sprites for new NotchPop +
WallPop animations. Each is self-contained — drop the whole block
in, get back something usable.

The brand palette to reference:

| Color | Hex | Use |
|---|---|---|
| Hot pink | `#FF6B6B` | Primary accent |
| Magenta | `#C147FF` | Secondary accent |
| Blue | `#47A0FF` | Tertiary accent |
| Mint | `#2EE6A0` | Highlight |
| Yellow | `#FFD960` | Warm accent |
| Background | `#06010f` | Site / notch interior |

---

## 1. New WallPop preset

```
Design a new animated wallpaper preset for WallPop, a free macOS
animated-wallpaper app. The preset will render in SwiftUI Canvas at
~1440×900 (any display size — should scale).

CONSTRAINTS
- Pure CPU, no Metal shaders. Drawing primitives are: linear /
  radial / angular gradients, Path, Ellipse, Rectangle, Capsule,
  Canvas drawing API. Cap at ~120 sprites or you'll dropframes.
- Animation runs forever — design the LOOP, not a one-shot intro.
  Should look the same at t=2.5s as t=8.7s in motion character.
- Brand palette (use 1-3 of these): hot pink #FF6B6B, magenta
  #C147FF, blue #47A0FF, mint #2EE6A0, yellow #FFD960. Plus pure
  black #000 and a deep purple bg #06010f are fair game.
- DO NOT design something realistic / photographic. Should look
  like generative art or a NotchNook-aesthetic mood piece.

STYLE BUCKET
Pick one and stay in it:
  • Cosmic — galaxies, nebulas, black holes, constellations
  • Atmospheric — rain, snow, fireflies, cherry blossoms
  • Aesthetic — vaporwave, lo-fi, cyberpunk, y2k
  • Abstract — plasma, mesh, particles, glitch, waveform

THEME (your prompt-specific bit)
[REPLACE THIS — e.g. "deep ocean bioluminescent jellyfish drifting
upward in a column with caustic light shimmer"]

DELIVERABLES
1. A short description (≤3 sentences) of the visual.
2. The animation loop — what changes over time, in plain English.
3. A sketched SwiftUI view (Swift code or pseudocode is fine), one
   function returning some View, ~30-60 lines.
4. Notes on what dial users would want to control (speed, density,
   intensity).
```

---

## 2. New Notch Pet evolution stage

```
Design a new evolution stage for the Notch Pet — the SwiftUI-shaped
creature that lives in the NotchPop expanded notch. Existing stages
(in order): Egg → Hatchling → Kid → Teen → Adult → Sage. Each gets
a bigger body and a different gradient palette, and pet evolves at
XP thresholds 0/5/50/200/600/1500.

YOU'RE DESIGNING
Stage name: [e.g. "Mythic", "Astral", "Crowned", "Legend"]
XP threshold: [≥1500, post-Sage]

CONSTRAINTS
- Pure SwiftUI shapes — no images, no SF Symbols (except small
  accessories like a crown). Body is a gradient ellipse / blob;
  face is two eyes + a mouth that morph with mood (asleep / hungry /
  sad / neutral / happy / excited).
- Body width 38-72pt — readable at small size, no fine detail.
- Brand-palette gradient body. Sage already uses a 3-stop rainbow
  (#FF8B3D → #C147FF → #2EE6A0). New stage should feel like a
  step UP from there.

DELIVERABLES
1. One paragraph describing the look + vibe.
2. Body palette — 2 to 4 colors with hex.
3. ANY accessories — a halo, wings, sparkles, particles. Keep
   small enough to fit in a 70x70 sprite.
4. A SwiftUI fragment for the body (10-30 lines) that I can drop
   into the existing PetStage `bodyColors` + render path.
```

---

## 3. New welcome scene

```
Design a 4th scene for the NotchPop welcome animation. Existing
scenes (each 1.5s): Scene 1 ("Your workflow, faster"), Scene 2
("Drop files in / drag them out"), Scene 3 ("Tabs are yours").
Adding a 4th means the welcome takes ~6s instead of ~4.5s.

CONSTRAINTS
- Each scene = emoji + headline + bold accent line + one-line
  caption. Total content lives in a 520x178pt panel inside the
  expanded notch.
- The welcome glow halo cycles a hue rainbow behind everything;
  scene content is static after fade-in.
- Headline ≤ 24 chars. Accent line ≤ 22 chars (renders at 30pt
  black weight). Caption ≤ 70 chars.
- Tone: friendly, slightly mischievous, indie. Not corporate.

YOUR PROMPT
What concept should this new scene introduce? E.g., "celebrate the
Pomodoro feature" / "show off the App Shortcuts launcher" / "tease
the secret konami-code Easter egg".

DELIVERABLES
1. emoji
2. headline (the regular-weight white line)
3. accent (the BIG gradient-stroked line)
4. caption (the small subdued explanation)
5. brief reasoning on why this concept earns its 1.5s of welcome
   real estate
```

---

## 4. New live-activity right-side signal

```
Design a new "right side" signal for the NotchPop live-activity
pill (the wide black pill that flanks the collapsed notch when
something's happening on your Mac).

EXISTING SIGNALS (the right-side area when activity is live)
- Music playing → 4 vertical audio bars dancing at varied heights
- Pomodoro / Countdown running → giant 13pt heavy rounded text
  showing remaining time

NEW SIGNAL FOR — [user-supplied event, e.g. "GitHub PR opened",
"Slack message received", "Spotify track liked", "Battery hit 100%"]

CONSTRAINTS
- 38pt wide × 22pt tall area to play with
- Animated; loops forever while active
- High contrast against pure black
- Branded — uses the palette colors above (or a clear semantic
  accent: green for success, yellow for warning, red for urgent)

DELIVERABLES
1. Short description of the visual
2. SwiftUI fragment (≤25 lines) producing a `View` for the signal
3. The trigger condition (what event fires it) and how long it
   stays visible
```

---

## 5. New Pomodoro phase variant

```
Design a new visual phase for the Pomodoro tab beyond the existing
Focus / Short Break / Long Break.

EXAMPLES
- "Deep Work" mode (45-90 min focus block, no breaks)
- "Sprint" mode (5 × 5-min mini-focus blocks back to back)
- "Wind-down" mode (gradual end-of-day timer with shrinking
  intensity)

CONSTRAINTS
- The Pomodoro tab has a 64x64pt ring with a gradient stroke that
  slowly orbits when the timer is running, plus a center text with
  remaining time, plus three transport buttons (start/pause, skip,
  reset). Plus a phase picker with emoji + label pills.
- Each phase has a tint color used in the ring stroke + the live
  activity bar.

YOUR PHASE
[name + concept]

DELIVERABLES
1. Phase name + emoji
2. Tint color (hex)
3. Default duration in minutes
4. Quick-pick chip presets (4-8 minute values)
5. Behavior — does it auto-start the next phase? Strict mode?
```

---

## 6. New "Connections" trigger event

```
Design a new trigger event for NotchPop's Connections automation
engine. Existing triggers: pomodoroFocusStart/End,
pomodoroBreakStart/End, countdownEnd, chargingStart, musicStart/End,
appLaunched.

YOUR TRIGGER
What system / app / state change should fire it?
[e.g. "WiFi network changed", "AirPods connected", "Caffeine kicks
in", "Stand-up reminder time"]

CONSTRAINTS
- Must be detectable from a SwiftUI macOS app without Accessibility
  permission (we don't ask for it). Available paths: Distributed
  Notifications, NotificationCenter, NSWorkspace observers,
  CoreLocation (already permissioned), Calendar (EventKit),
  Network reachability, IOPowerSources.
- Should be a discrete EVENT not a continuous state — e.g.
  "WiFi changed" (event) not "still on WiFi" (state).
- Plays well with all existing actions: launch app, open URL, run
  Shortcut, play sound, copy text.

DELIVERABLES
1. Trigger name (camelCase enum case)
2. Friendly label ("Wi-Fi network changes")
3. The macOS API + observer pattern to detect it (one paragraph)
4. SwiftUI / Combine code skeleton (~20 lines) for the observer
5. Example automation — what would a user wire to it?
```

---

## 7. Hero animation for a new project's website

```
Design the hero animation for a new free + open-source [macOS app /
web tool / browser extension]. The project is named [NAME] and
does [what]. Site uses the standard "Gravy" promo template:
animated gradient title, drifting orb backgrounds, shimmer-sweep
download button, dark `#06010f` bg.

YOUR JOB
Design what plays BEHIND the hero copy at full viewport size. Has
to:
- Render in HTML5 Canvas with vanilla JS (NO three.js / pixi /
  webgl). 60fps via requestAnimationFrame.
- Loop forever, look the same at any timestamp.
- Sit BEHIND a translucent dark gradient fade so it never overpowers
  the title text.
- Fit the brand: pink/magenta/blue/mint palette.
- Be DIFFERENT from existing project hero animations: NotchPop has
  a black notch + welcome glow; WallPop has a galaxy preset; we
  don't want a copy.

DELIVERABLES
1. One-paragraph description of the hero visual + motion character
2. Implementable Canvas code (≤80 lines, single drawFrame function
   taking ctx, width, height, time-in-seconds).
3. Optional: a tiny static fallback gradient if the user has
   prefers-reduced-motion enabled
```

---

## 8. Logo concept for a new project

```
Design a logo for [PROJECT NAME] — a free + open-source [tool / app
/ game] that does [what]. Will be rendered at:
- 16x16 favicon (data: SVG)
- 64x64 in-app icon
- 128x128 macOS app icon
- 1024x1024 download artwork

CONSTRAINTS
- Brand palette: pink #FF6B6B, magenta #C147FF, blue #47A0FF, mint
  #2EE6A0, yellow #FFD960. Pick 2-3, no more.
- ALWAYS uses gradient (linear or angular). No flat colors.
- Body shape sits in a rounded square with corner radius 14pt
  (matches macOS app icon shape).
- White / very-light glyph drawn ON TOP of the gradient.
- No text — pure mark.
- Should read at 16x16 — bold shapes, no fine detail, no thin
  strokes (<2px equivalents).

REFERENCE the existing family:
- NotchPop = a curved notch shape / dynamic-island silhouette in
  white over pink-purple-blue gradient
- WallPop = a checkmark-shaped path in white over pink-purple-blue
- DeckGrab = a card-stack with arrow + smaller card slot, white
  over orange-pink-purple

YOUR ASK
Design a NEW mark for [PROJECT]. Suggest 3 directions in the same
visual family.

DELIVERABLES
1. Three concept names with one-line elevator pitch
2. For your favorite: full SVG (paste-able) at 64x64 viewBox
3. CSS-encoded data URL for use in `<link rel="icon">`
```

Use these by replacing the [BRACKETED] sections with whatever
you're working on, then paste the whole block to Claude.
