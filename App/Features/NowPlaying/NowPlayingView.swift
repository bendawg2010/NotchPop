// NowPlayingView.swift
//
// "Now Playing" pane inside the expanded notch. Shows album art on
// the left, title + artist + scrubbing line on the right, and
// transport controls on the far right.
//
// Polish features layered on top of the read-only baseline:
//   • Draggable scrubber knob — visually mirrors user intent during
//     a drag, snaps back to the real elapsed on release. There is
//     no AppleScript writeback exposed by the service yet, so the
//     drag is purely cosmetic until that's wired up.
//   • Elapsed-of-duration timestamp under the bar (monospaced).
//   • Centered empty state with a single-line hint.
//   • Marquee-scrolling track title when it overflows.
//   • Subtle pulse on the artwork while playing.
//
// The visual contract (88pt card, 60×60 art, brand gradient ONLY on
// the play button) is preserved.

import SwiftUI

struct NowPlayingView: View {
    @ObservedObject var service: NowPlayingService

    /// Ephemeral scrub position. While the user is dragging the
    /// playhead this holds their *intended* elapsed time so the bar
    /// and timestamp follow the finger. We never write this back to
    /// `service.track.elapsed` — there's no exposed API to seek
    /// Apple Music / Spotify yet (TODO below). On release we just
    /// drop it and let the real elapsed re-take control.
    @State private var scrubElapsed: TimeInterval? = nil

    /// True while a drag is active. Used to pause animations on the
    /// progress fill so it follows the finger 1:1.
    @State private var isScrubbing: Bool = false

    var body: some View {
        Group {
            if service.track.isEmpty {
                emptyState
            } else {
                playingContent
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity)
        .frame(height: 88)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.white.opacity(0.04))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(Color.white.opacity(0.08), lineWidth: 1)
                )
        )
    }

    // MARK: - Empty state

    /// Shown when nothing is playing. Single centered SF Symbol +
    /// one-line hint. Less verbose than the previous "Nothing playing"
    /// + suggested-apps copy.
    private var emptyState: some View {
        HStack(spacing: 10) {
            Spacer(minLength: 0)
            Image(systemName: "music.note.list")
                .font(.system(size: 18, weight: .regular))
                .foregroundColor(.white.opacity(0.45))
            Text("No music · open Apple Music or Spotify")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.white.opacity(0.55))
                .lineLimit(1)
            Spacer(minLength: 0)
        }
    }

    // MARK: - Playing content

    private var playingContent: some View {
        HStack(spacing: 12) {
            artworkView
                .frame(width: 60, height: 60)
                .background(Color.white.opacity(0.06))
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

            VStack(alignment: .leading, spacing: 3) {
                MarqueeTitle(text: service.track.title)
                    .frame(height: 18)
                Text(service.track.artist)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.white.opacity(0.62))
                    .lineLimit(1)

                progressBar
                    .frame(height: 10)        // 3pt bar + room for the knob
                    .padding(.top, 3)

                timestampRow
            }
            Spacer(minLength: 4)

            // Transport controls — always rendered, even when nothing
            // is playing, since the user can hit Play to resume the
            // last queued track in Music/Spotify.
            HStack(spacing: 4) {
                controlButton(icon: "backward.fill", label: "Previous") {
                    service.previousTrack()
                }
                controlButton(
                    icon: service.track.isPlaying ? "pause.fill" : "play.fill",
                    label: service.track.isPlaying ? "Pause" : "Play",
                    primary: true
                ) {
                    service.togglePlayPause()
                }
                controlButton(icon: "forward.fill", label: "Next") {
                    service.nextTrack()
                }
            }
        }
    }

    // MARK: - Artwork (with subtle play-pulse)

    @ViewBuilder
    private var artworkView: some View {
        // TimelineView drives the pulse so we don't need a @State
        // animation flag. When isPlaying flips off the time-derived
        // scale just freezes wherever the curve was — the next time
        // it flips on we resume from there. Cheap and self-cleaning.
        TimelineView(.animation) { ctx in
            let t = ctx.date.timeIntervalSinceReferenceDate
            let scale: CGFloat = service.track.isPlaying
                ? 1.0 + 0.01 * CGFloat(easeInOutSine(phase01(t, period: 1.5)))
                : 1.0
            artworkContent
                .scaleEffect(scale)
        }
    }

    @ViewBuilder
    private var artworkContent: some View {
        if let art = service.track.artwork {
            Image(nsImage: art)
                .resizable()
                .interpolation(.high)
                .scaledToFill()
        } else {
            Image(systemName: "music.note")
                .font(.system(size: 22, weight: .regular))
                .foregroundColor(.white.opacity(0.45))
        }
    }

    /// Returns a 0…1 value cycling at `period` seconds (triangle-ish
    /// when fed into easeInOutSine: 0 → 1 → 0 over `period`).
    private func phase01(_ t: Double, period: Double) -> Double {
        let p = t.truncatingRemainder(dividingBy: period) / period
        // 0…0.5 ramps 0→1, 0.5…1 ramps 1→0 — matches a "breathing" feel.
        return p < 0.5 ? p * 2 : (1 - p) * 2
    }

    /// Smooth ease-in-out shaping for a 0…1 input.
    private func easeInOutSine(_ x: Double) -> Double {
        return 0.5 - cos(.pi * x) / 2
    }

    // MARK: - Progress bar with draggable scrubber

    private var progressBar: some View {
        GeometryReader { geo in
            // Effective elapsed: the user's drag position if they're
            // scrubbing, otherwise the real elapsed from the service.
            let effectiveElapsed = scrubElapsed ?? service.track.elapsed
            let pct = progressPct(for: effectiveElapsed)
            let filledWidth = geo.size.width * CGFloat(pct)
            let knobDiameter: CGFloat = 10

            ZStack(alignment: .leading) {
                // Track
                Capsule()
                    .fill(Color.white.opacity(0.08))
                    .frame(height: 3)

                // Filled portion
                Capsule()
                    .fill(LinearGradient(
                        colors: [Color(red: 1.00, green: 0.71, blue: 0.33),
                                 Color(red: 1.00, green: 0.42, blue: 0.42)],
                        startPoint: .leading, endPoint: .trailing))
                    .frame(width: filledWidth, height: 3)
                    // Don't animate while scrubbing — the bar must
                    // track the finger 1:1. Once released we go back
                    // to the gentle 0.4s linear catchup.
                    .animation(isScrubbing ? nil : .linear(duration: 0.4),
                               value: effectiveElapsed)

                // Draggable knob — sits on the played-portion edge.
                Circle()
                    .fill(Color.white)
                    .overlay(
                        Circle().stroke(Color.black.opacity(0.18), lineWidth: 0.5)
                    )
                    .shadow(color: .black.opacity(0.25), radius: 1.5, x: 0, y: 0.5)
                    .frame(width: knobDiameter, height: knobDiameter)
                    .offset(x: max(0, filledWidth - knobDiameter / 2))
                    .scaleEffect(isScrubbing ? 1.25 : 1.0)
                    .animation(.easeOut(duration: 0.12), value: isScrubbing)
            }
            // Make the entire bar height grabbable so users don't
            // have to land precisely on the 10pt knob.
            .frame(height: 10, alignment: .center)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        guard service.track.duration > 0 else { return }
                        isScrubbing = true
                        // Scrubber math:
                        //   newElapsed = clamp(x / totalWidth, 0…1) × duration
                        let frac = max(0, min(1, value.location.x / geo.size.width))
                        scrubElapsed = service.track.duration * Double(frac)
                    }
                    .onEnded { _ in
                        // TODO: when the service exposes a seek API
                        // (`tell application "Music" to set player
                        // position to X` for Apple Music; equivalent
                        // for Spotify), call it here with
                        // `scrubElapsed` before clearing it. For now
                        // we just drop the ephemeral value and let
                        // the real elapsed re-take control — the
                        // playhead snaps back.
                        scrubElapsed = nil
                        isScrubbing = false
                    }
            )
        }
    }

    /// Right-aligned `1:42 / 3:28` timestamp, monospaced, ~9pt.
    private var timestampRow: some View {
        let displayed = scrubElapsed ?? service.track.elapsed
        return HStack {
            Spacer(minLength: 0)
            Text("\(formatTime(displayed)) / \(formatTime(service.track.duration))")
                .font(.system(size: 9, weight: .medium, design: .monospaced))
                .foregroundColor(.white.opacity(0.50))
                .monospacedDigit()
        }
    }

    private func progressPct(for elapsed: TimeInterval) -> Double {
        let d = service.track.duration
        guard d > 0 else { return 0 }
        return max(0, min(1, elapsed / d))
    }

    private func formatTime(_ t: TimeInterval) -> String {
        guard t.isFinite, t >= 0 else { return "0:00" }
        let total = Int(t.rounded())
        let m = total / 60
        let s = total % 60
        return String(format: "%d:%02d", m, s)
    }

    // MARK: - Transport buttons

    private func controlButton(icon: String, label: String,
                               primary: Bool = false,
                               action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: primary ? 13 : 11, weight: .heavy))
                .foregroundColor(.white)
                .frame(width: primary ? 32 : 26, height: primary ? 32 : 26)
                .background(
                    Circle()
                        .fill(primary
                              ? AnyShapeStyle(LinearGradient(
                                  colors: [
                                      Color(red: 1.00, green: 0.24, blue: 0.67), // #FF3CAC
                                      Color(red: 0.47, green: 0.29, blue: 0.63), // #784BA0
                                      Color(red: 0.17, green: 0.52, blue: 0.77)  // #2B86C5
                                  ],
                                  startPoint: .topLeading,
                                  endPoint: .bottomTrailing))
                              : AnyShapeStyle(Color.white.opacity(0.10))
                        )
                )
        }
        .buttonStyle(.plain)
        .help(label)
    }
}

// MARK: - Marquee title
//
// Recreates the marquee technique from LiveActivityBar's AudioBars
// pattern — a TimelineView(.animation) drives a translateX offset.
// We measure the rendered text width with a hidden copy + .background
// + GeometryReader, compare against the available width, and only
// scroll if it overflows. The scroll is a continuous loop with a
// fade-in/out at the edges so the wrap-around doesn't pop visually.
private struct MarqueeTitle: View {
    let text: String

    @State private var textWidth: CGFloat = 0

    /// Pixels per second the title scrolls at. ~30pps feels readable
    /// without being jittery.
    private let speed: Double = 30
    /// Gap of empty space inserted between the end of one copy and
    /// the start of the next during the scroll loop.
    private let gap: CGFloat = 36

    var body: some View {
        GeometryReader { container in
            let containerWidth = container.size.width
            let needsScroll = textWidth > containerWidth + 0.5

            ZStack(alignment: .leading) {
                // Hidden measurer — same font as the visible copy.
                titleText
                    .fixedSize()
                    .opacity(0)
                    .background(
                        GeometryReader { g in
                            Color.clear
                                .preference(key: TitleWidthKey.self,
                                            value: g.size.width)
                        }
                    )

                if needsScroll {
                    scrollingTitle(containerWidth: containerWidth)
                        .mask(edgeFadeMask)
                } else {
                    titleText
                        .lineLimit(1)
                }
            }
            .frame(width: containerWidth, alignment: .leading)
            .clipped()
        }
        .onPreferenceChange(TitleWidthKey.self) { textWidth = $0 }
    }

    private var titleText: some View {
        Text(text)
            .font(.system(size: 14, weight: .bold))
            .foregroundColor(.white)
    }

    private func scrollingTitle(containerWidth: CGFloat) -> some View {
        // Two copies side-by-side with a `gap` between, translated
        // leftward over time. When the first copy has fully scrolled
        // off (offset == -(textWidth + gap)) we wrap modulo and the
        // second copy is now where the first started — seamless loop.
        TimelineView(.animation) { ctx in
            let t = ctx.date.timeIntervalSinceReferenceDate
            let cycle = Double(textWidth + gap)
            let raw = (t * speed).truncatingRemainder(dividingBy: cycle)
            let offset = -CGFloat(raw)

            HStack(spacing: gap) {
                titleText
                titleText
            }
            .fixedSize()
            .offset(x: offset)
        }
    }

    /// 6pt fade on each edge so the wrap-around doesn't pop visually.
    private var edgeFadeMask: some View {
        LinearGradient(
            stops: [
                .init(color: .clear,                  location: 0.00),
                .init(color: .black,                  location: 0.04),
                .init(color: .black,                  location: 0.96),
                .init(color: .clear,                  location: 1.00),
            ],
            startPoint: .leading, endPoint: .trailing
        )
    }
}

private struct TitleWidthKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}
