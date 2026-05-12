# Claude Animation Design Prompts

Paste any of these into Claude (or any image / motion-design AI)
when you want concept art, storyboards, or SVG sprites for a NEW
ANIMATION inside NotchPop or WallPop. **All prompts are
animation-focused** — no logo / static-asset prompts in this file.
Each one is self-contained. Drop the whole block in.

The brand palette to reference in every prompt:

| Color | Hex | Use |
|---|---|---|
| Hot pink | `#FF6B6B` | Primary accent |
| Magenta | `#C147FF` | Secondary accent |
| Blue | `#47A0FF` | Tertiary accent |
| Mint | `#2EE6A0` | Highlight |
| Yellow | `#FFD960` | Warm accent |
| Background | `#06010f` | Site / notch interior |

---

## 1. New WallPop preset (full-screen animated wallpaper)

```
Design a new animated wallpaper preset for WallPop, a free macOS
animated-wallpaper app. The preset will render in SwiftUI Canvas
at full screen (~1440×900 — should scale to any display).

ANIMATION CONSTRAINTS
- Pure CPU, no Metal shaders. Drawing primitives are: linear /
  radial / angular gradients, Path, Ellipse, Rectangle, Capsule,
  Canvas drawing API. Cap at ~120 sprites or you'll dropframes.
- Animation runs FOREVER — design the LOOP, not a one-shot intro.
  Should look the same in motion character at t=2.5s as t=8.7s.
- Brand palette (use 1-3 of these): hot pink #FF6B6B, magenta
  #C147FF, blue #47A0FF, mint #2EE6A0, yellow #FFD960. Plus pure
  black #000 and a deep purple bg #06010f are fair game.
- DO NOT design something realistic / photographic. Should look
  like generative art or a Notch / Dynamic Island aesthetic.
- Frame rate: 30fps minimum, 60fps preferred. State the budget.

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
1. A short description (≤3 sentences) of the visual + motion.
2. Frame-by-frame animation breakdown — what changes over time.
3. SwiftUI view source (or pseudo-Swift), one function returning
   `some View`, ~30-60 lines.
4. Notes on what dial users would want to control: speed, density,
   intensity. Range each dial.
```

---

## 2. New Notchy mascot pose / animation state

```
Notchy is the official NotchPop mascot — a horizontal pill body
(the notch silhouette itself) with stubby arms and legs, a face
inside the capsule, and a soft radial halo behind that color-
shifts per state.

EXISTING STATES (12 — already implemented)
idle / alert / focused / celebrate / sleep / love / thinking /
listening / charging / dnd / sad / wink

YOU'RE DESIGNING
A 13th animation state for: [REPLACE — e.g. "doing a shrug",
"playing music with headphones on", "stretching after a long
focus session"]

ANIMATION CONSTRAINTS
- Notchy lives in a 200×130 viewBox (matches the SVG handoff).
- Body box is x 30..170, y 36..84 (width 140, height 48,
  corner radius 24). Mostly stays put — pose is mostly arms/legs.
- Limbs are 6pt strokeWidth lines + 6pt circles for hands/feet.
- Face is two eyes + a mouth, both detail-color (white). Each
  state has a unique face — change the eye shape / mouth curve.
- Halo is a radial gradient that color-shifts per state. Pick
  one halo color from the palette and explain why.
- Animation runs in a 1-2 second loop. State which limbs / face
  parts move and at what frequency.

DELIVERABLES
1. Concept name + halo color + one-paragraph description
2. Pose table entry (8 fields: bodyDx, bodyDy, armL, armR, legL,
   legR, handL, handR, footL, footR — coordinates inside 200×130)
3. Face SVG fragment (eyes + mouth, all in `detail` color)
4. Animation loop description — what ticks each frame
5. Trigger condition — what NotchPop event should put Notchy in
   this state? (e.g. "battery <20%" / "user idle 1hr" / etc.)
```

---

## 3. New welcome scene transition

```
Design the animation BETWEEN two welcome scenes in NotchPop's
3-scene welcome sequence. Existing transitions = simple opacity
crossfade (0.45s spring). I want something more interesting.

ANIMATION CONSTRAINTS
- Plays inside the expanded notch (520×178pt panel)
- Scene-out + scene-in happen in <1.0s total
- The welcome glow halo behind the panel keeps cycling unaffected
- Must work for any pair of scenes (don't hard-code emoji /
  headline content)

YOU'RE DESIGNING
A new transition style: [REPLACE — e.g. "vinyl-record spin",
"page-turn", "elastic squish-and-stretch", "shutter close + open",
"letters scatter and reform"]

DELIVERABLES
1. Storyboard: 4-6 frames at 100ms intervals describing what
   the user sees during the transition
2. SwiftUI animation source (~40 lines) — `withAnimation` calls,
   AnyTransition, matchedGeometryEffect if needed
3. Per-element timing — when does the headline move / fade,
   when does the accent line, when do the dots reset, etc.
4. Easing curve recommendation (.spring / .easeInOut / custom
   timing function)
```

---

## 4. New live-activity right-side animated signal

```
Design a new animated signal for the right side of NotchPop's
live-activity pill (the wide black notch shape that flanks the
collapsed hardware notch when something's happening).

EXISTING SIGNALS
- Music playing → 4 vertical audio bars, sin-driven heights
- Pomodoro / Countdown running → countdown text in 13pt heavy
  rounded mono, gradient-colored

YOUR NEW SIGNAL FOR
[REPLACE — e.g. "GitHub PR mention", "AirDrop incoming",
"Spotify track liked", "Battery just hit 100%"]

ANIMATION CONSTRAINTS
- 38pt wide × 22pt tall area to play with
- Loops while active, fades on activity-end
- High contrast against pure black notch background
- Brand palette OR clear semantic color (green/yellow/red)
- Frame budget: 30fps, lightweight, no per-pixel work

DELIVERABLES
1. Description of the visual + motion in plain English
2. Animation timing — what moves on what frequency
3. SwiftUI fragment (≤25 lines) producing a `View`
4. Trigger event — when does this signal start, when does
   it fade out
```

---

## 5. New Pomodoro ring animation variant

```
The current Pomodoro ring shows a gradient stroke that orbits
the perimeter, with the time-remaining in the center. I want a
NEW visual variant the user can swap to.

YOUR VARIANT
[REPLACE — e.g. "particle-fill" (particles fill the ring as time
elapses), "tide" (a wave sloshes around), "petals" (petals close
inward as time runs out), "constellation" (stars connect with
lines as you focus)]

ANIMATION CONSTRAINTS
- Ring is 64×64pt
- Three phases (Focus / Short Break / Long Break) each with a
  tint color baked into the gradient — your variant has to
  respect those tints
- Reduce-motion friendly — must have a static fallback for
  users with prefers-reduced-motion
- Should communicate progress: a glance tells you "near start" /
  "halfway" / "almost done"

DELIVERABLES
1. Description of the visual + how it communicates progress
2. SwiftUI source (~50 lines, TimelineView-driven)
3. Reduce-motion fallback — the static version
4. Color application — how the phase tint folds in
5. State transitions — what happens when the timer is paused,
   skipped, completed
```

---

## 6. New WallPop hero canvas animation (for the website)

```
The WallPop website's hero section has a fullscreen <canvas>
behind the title text. Currently it renders the Galaxy preset.
I want a NEW hero animation that's only used on the website
(doesn't have to ship as an in-app preset).

ANIMATION CONSTRAINTS
- HTML5 Canvas with vanilla JS, no WebGL / three.js / pixi
- 60fps via requestAnimationFrame
- Loops forever, looks identical at any timestamp
- Sits BEHIND a translucent dark gradient fade (so don't make it
  too bright — the title text needs to remain legible)
- Brand palette (pink/magenta/blue/mint), dark background, no
  realistic photography
- Should make someone want to download the app

YOUR HERO CONCEPT
[REPLACE — e.g. "infinite zoom into a fractal", "particles spell
out a different word every loop", "depth field of pulsing rings"]

DELIVERABLES
1. One-paragraph description of the visual + motion character
2. Implementable Canvas code (≤80 lines, single drawFrame
   function: `drawFrame(ctx, width, height, time_seconds)`)
3. Reduced-motion static fallback — what to render if the user
   has prefers-reduced-motion enabled
4. Optional: ideas for how the animation could subtly REACT to
   user inputs (mouse position, scroll Y, etc.) without becoming
   distracting
```

---

## 7. New ambient idle micro-animation for the notch

```
Design a tiny ambient animation that plays inside the COLLAPSED
notch (the small black pill, 178×32pt) when nothing else is
active. Today the collapsed notch is dead-static black.

ANIMATION CONSTRAINTS
- 178pt wide × 32pt tall (the actual hardware notch dimensions)
- Has to read as "alive" without being distracting — user should
  notice it briefly, then forget about it
- Period: 8-30 seconds. Long enough that it doesn't pull focus.
- Pure black background (the notch must blend with the hardware
  cutout when collapsed)
- Brand-color accents only — pink/magenta/blue/mint
- 30fps fine; doesn't need to be smooth

YOUR CONCEPT
[REPLACE — e.g. "tiny sparkle that drifts across once a minute",
"breath-like opacity pulse on the bottom edge", "Notchy peeks out
once every 2 minutes", "a subtle aurora shimmer on the inner
top edge"]

DELIVERABLES
1. Storyboard: 3-5 keyframes describing the motion
2. SwiftUI source (~40 lines, TimelineView-driven)
3. Trigger conditions — when DOES it play (always idle?
   only when no live activity? only certain hours of the day?)
4. User-toggleable? Yes/no + reasoning
```

---

## 8. New welcome glow halo variant

```
The welcome animation currently shows a multi-color radial halo
behind the expanded notch that hue-cycles through pink/purple/
blue/mint over ~5 seconds. I want a new HALO style the user can
switch to in Settings.

YOUR HALO VARIANT
[REPLACE — e.g. "fireworks bursts", "expanding concentric rings",
"sparkle rain falling outward from the notch", "lightning forks
that strike outward then fade"]

ANIMATION CONSTRAINTS
- Renders in the welcome-only padding around the expanded notch
  (110pt sides, 100pt bottom — ~280pt × 250pt available area)
- Plays for the welcome duration (3-15s, configurable)
- Has a ramp-IN (smoothstep first 1.6s) and ramp-OUT (last 1s)
- Brand palette
- Reduce-motion friendly

DELIVERABLES
1. Description of the visual
2. Frame-by-frame animation breakdown for one full loop
3. SwiftUI source (~60 lines, TimelineView-driven)
4. Ramp-in / ramp-out behavior — does the variant adapt to
   the envelope, or is it triggered as a one-shot?
5. How does it interact with the user's chosen accent color?
```

---

That's all 8 — each one tightly scoped to a specific animation
surface in the NotchPop / WallPop family. Replace `[REPLACE]`
sections with whatever you're working on, paste the whole block
to Claude, and you'll get something usable back.
