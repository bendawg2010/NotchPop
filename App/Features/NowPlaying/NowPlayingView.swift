// NowPlayingView.swift
//
// "Now Playing" pane inside the expanded notch. Shows album art on
// the left, title + artist + scrubbing line on the right. We don't
// (yet) implement playback control — read-only first.

import SwiftUI

struct NowPlayingView: View {
    @ObservedObject var service: NowPlayingService

    var body: some View {
        HStack(spacing: 12) {
            artworkView
                .frame(width: 60, height: 60)
                .background(Color.white.opacity(0.06))
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

            VStack(alignment: .leading, spacing: 3) {
                Text(service.track.title.isEmpty ? "Nothing playing" : service.track.title)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.white)
                    .lineLimit(1)
                Text(service.track.artist.isEmpty
                     ? "Open Music, Spotify, or any app with media controls"
                     : service.track.artist)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.white.opacity(0.62))
                    .lineLimit(1)
                progressBar
                    .frame(height: 3)
                    .padding(.top, 6)
            }
            Spacer()
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

    @ViewBuilder
    private var artworkView: some View {
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

    private var progressBar: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(Color.white.opacity(0.08))
                Capsule()
                    .fill(LinearGradient(
                        colors: [Color(red: 1.00, green: 0.71, blue: 0.33),
                                 Color(red: 1.00, green: 0.42, blue: 0.42)],
                        startPoint: .leading, endPoint: .trailing))
                    .frame(width: progressWidth(in: geo.size.width))
            }
        }
    }

    private func progressWidth(in total: CGFloat) -> CGFloat {
        let d = service.track.duration
        guard d > 0 else { return 0 }
        let pct = max(0, min(1, service.track.elapsed / d))
        return total * CGFloat(pct)
    }
}
