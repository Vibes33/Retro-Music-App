//
//  HomeView.swift
//  Retro
//
//  Created by Ryan on 20/09/2025.
//
import SwiftUI
import Observation

struct HomeView: View {
    @Environment(LibraryStore.self) private var library

    // MARK: Layout Config (edit values here)
    private let cardWidth: CGFloat = 165
    private let cardHeight: CGFloat = 113
    private let bigWidth: CGFloat = 346
    private let bigHeight: CGFloat = 207
    private let heroHeight: CGFloat = 320
    private let cardCornerRadius: CGFloat = 15

    // Offsets (positions)
    private let heroOffsetX: CGFloat = 0
    private let heroOffsetY: CGFloat = 0

    private let playlistsTitleOffsetX: CGFloat = 0
    private let playlistsTitleOffsetY: CGFloat = 0
    private let playlistsRowOffsetX: CGFloat = 0
    private let playlistsRowOffsetY: CGFloat = 0

    private let nouveautesTitleOffsetX: CGFloat = 0
    private let nouveautesTitleOffsetY: CGFloat = 0
    private let nouveaute1OffsetX: CGFloat = 0
    private let nouveaute1OffsetY: CGFloat = 0
    private let nouveaute2OffsetX: CGFloat = 0
    private let nouveaute2OffsetY: CGFloat = 0

    private let bigPromoOffsetX: CGFloat = 0
    private let bigPromoOffsetY: CGFloat = 0

    // Derived sizes
    private var cardSize: CGSize { .init(width: cardWidth, height: cardHeight) }
    private var bigCardSize: CGSize { .init(width: bigWidth, height: bigHeight) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // HERO section that scrolls with content (full-bleed + parallax)
                ZStack {
                    GeometryReader { proxy in
                        let minY = proxy.frame(in: .global).minY
                        AppImage("image1")
                            .frame(width: proxy.size.width,
                                   height: minY > 0 ? heroHeight + minY : heroHeight)
                            .clipped()
                            .offset(y: minY > 0 ? -minY : 0)
                            .ignoresSafeArea(.container, edges: .top)
                    }
                    .frame(height: heroHeight)

                    // Overlay title + button anchored at the bottom of the hero
                    VStack(spacing: 12) {
                        Text("Retro")
                            .font(.system(size: 50, weight: .bold))
                            .foregroundStyle(.white)
                            .shadow(radius: 6)

                        Button(action: {}) {
                            HStack(spacing: 10) {
                                Image(systemName: "play.fill").imageScale(.medium)
                                Text("Play latest song").font(.system(size: 16, weight: .heavy))
                            }
                            .foregroundStyle(.white)
                            .padding(.vertical, 12)
                            .padding(.horizontal, 18)
                            .background(
                                Capsule(style: .continuous)
                                    .fill(Color(hex: "FF8400").gradient)
                                    .shadow(color: Color(hex: "FF8400").opacity(0.45), radius: 12, y: 6)
                            )
                        }
                    }
                    .padding(20)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                }
                .padding(.horizontal, -16)
                .offset(x: heroOffsetX, y: heroOffsetY)

                // Sections below the hero
                playlistsSection
                nouveautesSection
                bigPromo
                    .offset(x: bigPromoOffsetX, y: bigPromoOffsetY)
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 24)
        }
        .navigationTitle("")
        .background(Color(.systemBackground))
    }

    // MARK: Playlists section
    private var playlistsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text("Mes playlists")
                    .font(.system(.title2, design: .default, weight: .heavy))
                Spacer()
                HStack(spacing: 6) {
                    Circle().frame(width: 8).foregroundStyle(.primary)
                    Circle().frame(width: 8).foregroundStyle(.secondary)
                }
                .opacity(0.6)
            }
            .offset(x: playlistsTitleOffsetX, y: playlistsTitleOffsetY)

            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 14) {
                    AppImage("image3")
                        .frame(width: cardSize.width, height: cardSize.height)
                        .clipShape(RoundedRectangle(cornerRadius: cardCornerRadius, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: cardCornerRadius, style: .continuous)
                                .stroke(.black.opacity(0.08))
                        )
                        .contentShape(.rect)
                        .onTapGesture { }

                    AppImage("image4")
                        .frame(width: cardSize.width, height: cardSize.height)
                        .clipShape(RoundedRectangle(cornerRadius: cardCornerRadius, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: cardCornerRadius, style: .continuous)
                                .stroke(.black.opacity(0.08))
                        )
                        .contentShape(.rect)
                        .onTapGesture { }
                }
                .padding(.vertical, 6)
                .offset(x: playlistsRowOffsetX, y: playlistsRowOffsetY)
            }
        }
        .padding(.top, 8)
        .offset(x: 35, y: 0)
    }

    // MARK: Nouveautés
    private var nouveautesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Nouveautés")
                .font(.system(.title2, design: .default, weight: .heavy))
                .offset(x: nouveautesTitleOffsetX, y: nouveautesTitleOffsetY)

            HStack(spacing: 14) {
                AppImage("imagep1")
                    .frame(width: cardSize.width, height: cardSize.height)
                    .clipShape(RoundedRectangle(cornerRadius: cardCornerRadius, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: cardCornerRadius, style: .continuous)
                            .stroke(.black.opacity(0.08))
                    )
                    .contentShape(.rect)
                    .onTapGesture { }
                    .offset(x: nouveaute1OffsetX, y: nouveaute1OffsetY)

                AppImage("imagep2")
                    .frame(width: cardSize.width, height: cardSize.height)
                    .clipShape(RoundedRectangle(cornerRadius: cardCornerRadius, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: cardCornerRadius, style: .continuous)
                            .stroke(.black.opacity(0.08))
                    )
                    .contentShape(.rect)
                    .onTapGesture { }
                    .offset(x: nouveaute2OffsetX, y: nouveaute2OffsetY)
                Spacer(minLength: 0)
            }

        }
        .offset(x: 35, y: 0)
    }

    // MARK: Big promo image
    private var bigPromo: some View {
        AppImage("imagep3")
            .frame(width: bigCardSize.width, height: bigCardSize.height)
            .clipShape(RoundedRectangle(cornerRadius: cardCornerRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: cardCornerRadius, style: .continuous)
                    .stroke(.black.opacity(0.08))
            )
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.top, 8)
            .onTapGesture { }
            .offset(x: 0, y: 0)
    }
}

// MARK: - Playlist Card
struct PlaylistCard: View {
    let playlist: Playlist

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            if let artworkName = playlist.artworkName {
                AppImage(artworkName)
                    .scaledToFill()
            } else {
                RoundedRectangle(cornerRadius: 15, style: .continuous)
                    .fill(LinearGradient(colors: [.blue.opacity(0.85), .purple.opacity(0.85)], startPoint: .topLeading, endPoint: .bottomTrailing))
            }
        }
        .overlay(
            VStack(alignment: .leading, spacing: 4) {
                Spacer()
                Text(playlist.title)
                    .font(.system(size: 13, weight: .semibold))
                    .lineLimit(1)
                    .foregroundStyle(.white)
                    .shadow(radius: 4)
            }
            .padding(10)
        )
        .clipShape(RoundedRectangle(cornerRadius: 15, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 15, style: .continuous)
                .strokeBorder(.black.opacity(0.08))
        )
    }
}
struct SettingsView: View { var body: some View { Text("Settings").frame(maxWidth: .infinity, maxHeight: .infinity).background(Color(.systemBackground)) } }
struct AccountView: View { var body: some View { Text("Account").frame(maxWidth: .infinity, maxHeight: .infinity).background(Color(.systemBackground)) } }


// MARK: - Models & Store
struct Playlist: Identifiable, Hashable {
    let id = UUID()
    var title: String
    var artworkName: String?
}

@Observable final class LibraryStore {
    var playlists: [Playlist] = [
        Playlist(title: "Titres likés", artworkName: "liked_star"),
        Playlist(title: "Rap", artworkName: "rap_cover")
    ]
}

// MARK: - Image helper
struct AppImage: View {
    private let name: String
    init(_ name: String) { self.name = name }
    var body: some View {
        if UIImage(named: name) != nil {
            Image(name)
                .resizable()
                .scaledToFill()
        } else {
            ZStack {
                RoundedRectangle(cornerRadius: 15, style: .continuous)
                    .fill(LinearGradient(colors: [Color(.systemGray5), Color(.systemGray4)], startPoint: .topLeading, endPoint: .bottomTrailing))
                Image(systemName: "photo")
                    .imageScale(.large)
                    .foregroundStyle(.secondary)
            }
            .overlay(
                Text(name)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .padding(6), alignment: .topLeading
            )
        }
    }
}

// MARK: - Utilities
extension Font {
    static func system(_ style: TextStyle, design: Font.Design = .default, weight: Font.Weight) -> Font {
        .system(style, design: design).weight(weight)
    }
}

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default: (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

#Preview {
    HomeView()
        .environment(LibraryStore())
}
