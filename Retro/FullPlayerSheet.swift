//
//  FullPlayerSheet.swift
//  Retro
//
//  Created by Ryan on 21/09/2025.
//

import SwiftUI

struct FullPlayerSheet: View {
    @EnvironmentObject var player: PlayerManager
    @Environment(\.dismiss) private var dismiss

    @State private var isScrubbing = false
    @State private var scrubProgress: Double = 0

    var body: some View {
        ZStack {
            // Fond “liquid glass”
            Color(.systemGray6).ignoresSafeArea()

            VStack(spacing: 20) {

                HStack {
                    GlassCircleButton(systemName: "xmark") { dismiss() }
                    Spacer()
                    Text("Lecture")
                        .font(.headline)
                        .foregroundStyle(.primary)
                    Spacer()
                    // Espace symétrique au bouton gauche
                    Color.clear.frame(width: 36, height: 36)
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)

                // Artwork
                if let t = player.currentTrack {
                    ArtworkView(artworkPath: t.artworkPath)
                        .frame(width: 290, height: 290)
                        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                        .shadow(color: .black.opacity(0.15), radius: 20, y: 12)

                    // Title + artist
                    VStack(spacing: 6) {
                        Text(t.title)
                            .font(.system(size: 28, weight: .bold))
                            .lineLimit(2)
                            .multilineTextAlignment(.center)
                        Text(t.artist)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }
                    .padding(.horizontal, 24)
                }

                VStack(spacing: 8) {
                    HStack {
                        Text(player.elapsedString).font(.caption).foregroundStyle(.secondary)
                        Spacer()
                        Text(player.remainingString).font(.caption).foregroundStyle(.secondary)
                    }
                    .padding(.horizontal, 24)

                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule().fill(Color.secondary.opacity(0.25))
                            Capsule()
                                .fill(.primary.opacity(0.9))
                                .frame(width: geo.size.width * CGFloat(scrubProgress))
                        }
                        .frame(height: 5)
                        .contentShape(Rectangle())
                        .gesture(
                            DragGesture(minimumDistance: 0)
                                .onChanged { value in
                                    isScrubbing = true
                                    let ratio = max(0, min(1, value.location.x / max(geo.size.width, 1)))
                                    scrubProgress = ratio
                                }
                                .onEnded { _ in
                                    player.seek(to: scrubProgress)
                                    isScrubbing = false
                                }
                        )
                    }
                    .frame(height: 16)
                    .padding(.horizontal, 24)
                }

                HStack(spacing: 24) {
                    GlassCircleButton(systemName: "backward.fill") {
                        player.playPrevious()
                    }
                    .disabled(!player.canPlayPrevious)
                    .opacity(player.canPlayPrevious ? 1 : 0.5)

                    GlassCircleButton(systemName: player.isPlaying ? "pause.fill" : "play.fill") {
                        player.togglePlayPause()
                    }

                    GlassCircleButton(systemName: "forward.fill") {
                        player.playNext()
                    }
                    .disabled(!player.canPlayNext)
                    .opacity(player.canPlayNext ? 1 : 0.5)
                }
                .padding(.top, 8)

                Spacer()

                HStack {
                    Spacer()
                    GlassCircleButton(systemName: player.isRepeatOne ? "repeat.1.circle.fill" : "repeat.1.circle") {
                        player.toggleRepeatOne()
                    }
                    .foregroundStyle(player.isRepeatOne ? .primary : .secondary)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 20)
            }
        }
        .onAppear {
            scrubProgress = player.progress
        }
        .onChange(of: player.currentTrack) { _, _ in
            scrubProgress = player.progress
        }
        .onChange(of: player.currentTime) { _, _ in
            if !isScrubbing { scrubProgress = player.progress }
        }
    }
}
