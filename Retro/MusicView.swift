//
//  MusicView.swift
//  Retro
//
//  Created by Ryan on 21/09/2025.
//
import SwiftUI
import SwiftData
import UniformTypeIdentifiers
import PhotosUI

struct MusicView: View {
    enum SortOption: String, CaseIterable, Identifiable {
        case date = "Date d'ajout"
        case artist = "Artiste"
        case album = "Album"
        var id: String { rawValue }
        var icon: String {
            switch self {
            case .date: return "clock"
            case .artist: return "person"
            case .album: return "square.stack"
            }
        }
    }

    @State private var sort: SortOption = .date
    @State private var isSearching: Bool = false
    @State private var searchText: String = ""
    @FocusState private var searchFocused: Bool

    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject var player: PlayerManager
    @Query(sort: [SortDescriptor(\Track.dateAdded, order: .reverse)]) var allTracks: [Track]

    @State private var showImporter = false
    @State private var importError: String?

    @State private var selectedTrack: Track?
    @State private var showEditSheet: Bool = false
    @State private var showDeleteConfirm: Bool = false

    @State private var debugLastImportTitle: String? = nil
    @State private var debugMessage: String? = nil
    // Import progress
    @State private var isImporting: Bool = false
    @State private var showFullPlayer: Bool = false

    var body: some View {
        ZStack(alignment: .bottom) {
            Color(.systemGray6)
                .ignoresSafeArea()

            VStack(spacing: 16) {
                topControls
                    .padding(.top, 12)
                    .padding(.horizontal, 16)

                VStack(alignment: .leading, spacing: 4) {
                    if !searchText.isEmpty {
                        Text("Filtre actif: \(searchText)")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                    if let msg = debugMessage {
                        Text(msg)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.horizontal, 16)

                Spacer(minLength: 24)

                // List of tracks
                if filteredTracks.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "music.quarternote.3")
                            .font(.system(size: 28, weight: .semibold))
                            .foregroundStyle(.secondary)
                        Text("Aucun titre pour le moment")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(.secondary)
                        Text("Ajoute un fichier audio avec le bouton de téléversement")
                            .font(.system(size: 13))
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, 40)
                    .padding(.bottom, 16)
                } else {
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            ForEach(filteredTracks) { track in
                                TrackRow(
                                    track: track,
                                    onMore: {
                                        selectedTrack = track
                                        showEditSheet = true
                                    },
                                    onDelete: {
                                        selectedTrack = track
                                        showDeleteConfirm = true
                                    }
                                )
                                .padding(.horizontal, 16)
                                .onTapGesture {
                                    if let idx = filteredTracks.firstIndex(where: { $0.id == track.id }) {
                                        player.setQueue(filteredTracks, startAt: idx)
                                    } else {
                                        player.play(track: track)
                                    }
                                }
                            }
                            .padding(.top, 4)
                            .padding(.bottom, 16)
                        }
                    }
                }
            }
        }
        .fileImporter(isPresented: $showImporter,
                      allowedContentTypes: [.audio],
                      allowsMultipleSelection: false) { result in
            switch result {
            case .success(let urls):
                guard let url = urls.first else { return }
                isImporting = true

                let needsStop = url.startAccessingSecurityScopedResource()
                defer { if needsStop { url.stopAccessingSecurityScopedResource() } }

                let reachable = (try? url.checkResourceIsReachable()) ?? false
                if !reachable {
                    try? FileManager.default.startDownloadingUbiquitousItem(at: url)
                }

                let coordinator = NSFileCoordinator()
                var coordError: NSError?
                var localTempURL: URL?

                coordinator.coordinate(readingItemAt: url, options: .forUploading, error: &coordError) { readableURL in
                    do {
                        let ext = readableURL.pathExtension.isEmpty ? url.pathExtension : readableURL.pathExtension
                        let tmpURL = FileManager.default.temporaryDirectory
                            .appendingPathComponent(UUID().uuidString)
                            .appendingPathExtension(ext.isEmpty ? "mp3" : ext)
                        do {
                            try FileManager.default.copyItem(at: readableURL, to: tmpURL)
                        } catch {
                            let data = try Data(contentsOf: readableURL, options: [.mappedIfSafe])
                            try data.write(to: tmpURL, options: [.atomic])
                        }
                        localTempURL = tmpURL
                    } catch {
                        importError = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
                        debugMessage = "Import FAIL: \(importError ?? error.localizedDescription)"
                    }
                }
                if let e = coordError { importError = e.localizedDescription; debugMessage = e.localizedDescription; if coordError != nil { isImporting = false } }

                // Importer depuis le fichier local persistant
                if let tmp = localTempURL {
                    DispatchQueue.main.async {
                        do {
                            let derivedTitle = url.deletingPathExtension().lastPathComponent
                            _ = try AudioLibrary.importAudio(from: tmp,
                                                             title: derivedTitle.isEmpty ? tmp.deletingPathExtension().lastPathComponent : derivedTitle,
                                                             artist: nil,
                                                             album: nil,
                                                             tagNames: [],
                                                             context: modelContext,
                                                             artworkURL: nil)
                            debugLastImportTitle = derivedTitle
                            debugMessage = nil
                            isSearching = false
                            searchText = ""
                            isImporting = false
                        } catch {
                            importError = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
                            debugMessage = "Import FAIL: \(importError ?? error.localizedDescription)"
                            isImporting = false
                        }
                    }
                } else if importError == nil {
                    importError = "Snapshot local indisponible."
                    debugMessage = importError
                    isImporting = false
                }

            case .failure(let err):
                importError = err.localizedDescription
                isImporting = false
            }
        }
        .alert("Import impossible", isPresented: .constant(importError != nil), actions: {
            Button("OK", role: .cancel) { importError = nil }
        }, message: {
            Text(importError ?? "")
        })
        .overlay(alignment: .top) {
            if let title = debugLastImportTitle {
                Text("✅ Importé: \(title)")
                    .font(.footnote)
                    .padding(8)
                    .background(.ultraThinMaterial, in: Capsule())
                    .overlay(Capsule().stroke(Color.white.opacity(0.25), lineWidth: 1))
                    .padding(.top, 8)
                    .transition(.opacity)
                    .onAppear {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                            withAnimation { debugLastImportTitle = nil }
                        }
                    }
            }
        }
        .overlay {
            if isImporting {
                ZStack {
                    Color.black.opacity(0.25).ignoresSafeArea()
                    VStack(spacing: 12) {
                        ProgressView()
                        Text("Import en cours…")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                    .padding(16)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.white.opacity(0.25), lineWidth: 1))
                }
            }
        }
        .alert("Supprimer ce titre ?", isPresented: $showDeleteConfirm, presenting: selectedTrack) { track in
            Button("Supprimer", role: .destructive) {
                do {
                    if let t = selectedTrack {
                        if player.currentTrack?.id == t.id {
                            player.stop(resetTrack: true)
                        }
                        try AudioLibrary.delete(track: t, context: modelContext)
                        withAnimation(.snappy) {
                            selectedTrack = nil
                            showDeleteConfirm = false
                        }
                    }
                } catch {
                    importError = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
                }
            }
            Button("Annuler", role: .cancel) { }
        } message: { track in
            Text("“\(track.title)” sera définitivement supprimé de votre bibliothèque.")
        }
        .sheet(isPresented: $showEditSheet, onDismiss: { selectedTrack = nil }) {
            if let trackToEdit = selectedTrack {
                EditTrackSheet(track: trackToEdit) { result in
                    switch result {
                    case .save(let title, let artist, let album, let tags, let artworkURL):
                        do {
                            try AudioLibrary.update(track: trackToEdit,
                                                    title: title,
                                                    artist: artist,
                                                    album: album,
                                                    tagNames: tags,
                                                    newArtworkURL: artworkURL,
                                                    context: modelContext)
                        } catch {
                            importError = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
                        }
                    case .delete:
                        showDeleteConfirm = true
                    case .cancel:
                        break
                    }
                }
                .presentationDetents([.medium, .large])
            } else {
                Text("Aucun son sélectionné").padding()
            }
        }
        .sheet(isPresented: $showFullPlayer) {
            FullPlayerSheet()
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
                .presentationBackground(.ultraThinMaterial)
        }
        .safeAreaInset(edge: .bottom) {
            MiniPlayerBar()
                .padding(.horizontal, 20)
                .padding(.vertical, 8)
                .onTapGesture { showFullPlayer = true }
        }
        .navigationTitle("")
    }

    private var topControls: some View {
        ZStack {
            if isSearching {
                HStack(spacing: 12) {
                    GlassCircleButton(systemName: "chevron.left") {
                        withAnimation(.snappy) {
                            isSearching = false
                            searchText = ""
                            searchFocused = false
                        }
                    }

                    HStack(spacing: 8) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(.secondary)
                        TextField("Rechercher titre, artiste, album", text: $searchText)
                            .textInputAutocapitalization(.none)
                            .disableAutocorrection(true)
                            .focused($searchFocused)
                            .font(.system(size: 16, weight: .regular))

                        Button(action: { searchText = "" }) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(.ultraThinMaterial)
                    .clipShape(Capsule(style: .continuous))
                    .overlay(
                        Capsule().stroke(Color.white.opacity(0.25), lineWidth: 1)
                    )
                    .shadow(color: Color.black.opacity(0.1), radius: 10, y: 4)
                }
                .transition(.move(edge: .top).combined(with: .opacity))
                .onAppear { DispatchQueue.main.async { self.searchFocused = true } }
            } else {
                HStack {
                    HStack(spacing: 12) {
                        GlassCircleButton(systemName: "magnifyingglass") {
                            withAnimation(.snappy) { isSearching = true }
                        }
                        GlassCircleButton(systemName: "square.and.arrow.up") { showImporter = true }
                    }

                    Spacer()

                    Menu {
                        Picker("Trier par", selection: $sort) {
                            ForEach(SortOption.allCases) { option in
                                Label(option.rawValue, systemImage: option.icon).tag(option)
                            }
                        }
                    } label: {
                        GlassSortPill(title: sort.rawValue)
                    }
                    .menuStyle(.automatic)
                }
                .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .animation(.snappy, value: isSearching)
    }


}

extension MusicView {
    var filteredTracks: [Track] {
        let needle = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        var items = allTracks
        if !needle.isEmpty {
            items = items.filter { t in
                t.title.lowercased().contains(needle) ||
                t.artist.lowercased().contains(needle) ||
                t.album.lowercased().contains(needle)
            }
        }
        switch sort {
        case .date:
            return items.sorted { $0.dateAdded > $1.dateAdded }
        case .artist:
            return items.sorted { $0.artist.localizedCaseInsensitiveCompare($1.artist) == .orderedAscending }
        case .album:
            return items.sorted { $0.album.localizedCaseInsensitiveCompare($1.album) == .orderedAscending }
        }
    }
}
struct TrackRow: View {
    let track: Track
    var onMore: (() -> Void)? = nil
    var onDelete: (() -> Void)? = nil

    var body: some View {
        HStack(spacing: 10) {
            ArtworkView(artworkPath: track.artworkPath)
                .frame(width: 36, height: 36)
                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))

            VStack(alignment: .leading, spacing: 2) {
                Text(track.title)
                    .font(.system(size: 14, weight: .semibold))
                    .lineLimit(1)
                Text(track.artist)
                    .font(.system(size: 12, weight: .regular))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()
            Button(action: { onDelete?() }) {
                Image(systemName: "trash")
                    .font(.system(size: 16, weight: .semibold))
                    .padding(10)
                    .background(.ultraThinMaterial)
                    .clipShape(Circle())
                    .overlay(Circle().stroke(Color.white.opacity(0.25), lineWidth: 1))
            }
            .buttonStyle(.plain)
            .tint(.red)
            .contentShape(Circle())

            // Ellipsis (more) button
            Button(action: { onMore?() }) {
                Image(systemName: "ellipsis")
                    .font(.system(size: 16, weight: .semibold))
                    .padding(10)
                    .background(.ultraThinMaterial)
                    .clipShape(Circle())
                    .overlay(Circle().stroke(Color.white.opacity(0.25), lineWidth: 1))
            }
            .buttonStyle(.plain)
            .contentShape(Circle())
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color.white.opacity(0.25), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.06), radius: 8, y: 4)
    }
}

struct ArtworkView: View {
    let artworkPath: String?
    var body: some View {
        Group {
            if let artworkPath,
               let url = try? AudioLibrary.absoluteURLForArtwork(filename: artworkPath),
               let img = UIImage(contentsOfFile: url.path) {
                Image(uiImage: img).resizable().scaledToFill()
            } else {
                ZStack {
                    RoundedRectangle(cornerRadius: 6).fill(Color.white.opacity(0.15))
                    Image(systemName: "music.note").font(.system(size: 12, weight: .medium))
                }
            }
        }
    }
}

struct EditTrackSheet: View {
    enum Action { case save(title: String?, artist: String?, album: String?, tags: [String]?, artworkURL: URL?), delete, cancel }
    let track: Track
    var onAction: (Action) -> Void

    @State private var title: String
    @State private var artist: String
    @State private var album: String
    @State private var tagsText: String

    @State private var pickedItem: PhotosPickerItem?
    @State private var pickedImageData: Data?

    init(track: Track, onAction: @escaping (Action) -> Void) {
        self.track = track
        self.onAction = onAction
        _title = State(initialValue: track.title)
        _artist = State(initialValue: track.artist)
        _album = State(initialValue: track.album)
        _tagsText = State(initialValue: track.tags.map { $0.name }.joined(separator: ", "))
    }

    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Infos")) {
                    TextField("Titre", text: $title)
                    TextField("Artiste", text: $artist)
                    TextField("Album", text: $album)
                    TextField("Tags (séparés par des virgules)", text: $tagsText)
                }

                Section(header: Text("Illustration")) {
                    HStack(spacing: 12) {
                        if let pickedImageData, let ui = UIImage(data: pickedImageData) {
                            Image(uiImage: ui).resizable().scaledToFill()
                                .frame(width: 56, height: 56)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                        } else if let artworkPath = track.artworkPath,
                                  let url = try? AudioLibrary.absoluteURLForArtwork(filename: artworkPath),
                                  let img = UIImage(contentsOfFile: url.path) {
                            Image(uiImage: img).resizable().scaledToFill()
                                .frame(width: 56, height: 56)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                        } else {
                            ZStack {
                                RoundedRectangle(cornerRadius: 8).fill(Color.secondary.opacity(0.2))
                                Image(systemName: "music.note")
                            }
                            .frame(width: 56, height: 56)
                        }

                        PhotosPicker(selection: $pickedItem, matching: .images, photoLibrary: .shared()) {
                            Text("Choisir une image")
                        }
                        .onChange(of: pickedItem) { _, newItem in
                            guard let item = newItem else { return }
                            Task {
                                if let data = try? await item.loadTransferable(type: Data.self) {
                                    await MainActor.run { pickedImageData = data }
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Modifier le son")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annuler") { onAction(.cancel) }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Valider") {
                        var artURL: URL? = nil
                        if let pickedImageData,
                           let tmp = try? writeTempImageAndReturnURL(data: pickedImageData) {
                            artURL = tmp
                        }
                        let tags = tagsText.split(separator: ",").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
                        onAction(.save(title: title, artist: artist, album: album, tags: tags, artworkURL: artURL))
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        onAction(.delete)
                    } label: {
                        Label("Supprimer", systemImage: "trash")
                    }
                }
            }
        }
    }
}

private func writeTempImageAndReturnURL(data: Data) throws -> URL {
    let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).appendingPathExtension("jpg")
    try data.write(to: url)
    return url
}

struct GlassCircleButton: View {
    var systemName: String
    var action: () -> Void
    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.primary)
                .frame(width: 36, height: 36)
                .background(.ultraThinMaterial)
                .clipShape(Circle())
                .overlay(
                    Circle().stroke(Color.white.opacity(0.25), lineWidth: 1)
                )
                .shadow(color: Color.black.opacity(0.1), radius: 10, y: 4)
        }
        .buttonStyle(.plain)
        .contentShape(Circle())
    }
}

struct GlassSortPill: View {
    var title: String
    var body: some View {
        HStack(spacing: 8) {
            Text(title)
                .font(.system(size: 14, weight: .semibold))
            Image(systemName: "arrow.up.arrow.down")
                .font(.system(size: 14, weight: .semibold))
        }
        .foregroundStyle(.primary)
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(.ultraThinMaterial)
        .clipShape(Capsule(style: .continuous))
        .overlay(
            Capsule().stroke(Color.white.opacity(0.25), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.1), radius: 10, y: 4)
    }
}

struct MiniPlayerBar: View {
    @EnvironmentObject var player: PlayerManager

    var body: some View {
        Group {
            if let track = player.currentTrack {
                HStack(spacing: 12) {
                    ArtworkView(artworkPath: track.artworkPath)
                        .frame(width: 34, height: 34)
                        .clipShape(RoundedRectangle(cornerRadius: 8))

                    VStack(alignment: .leading, spacing: 6) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(track.title)
                                .font(.system(size: 14, weight: .semibold))
                                .lineLimit(1)
                            Text(track.artist)
                                .font(.system(size: 12))
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                        // Progress bar
                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                Capsule().fill(Color.secondary.opacity(0.25))
                                Capsule()
                                    .fill(.primary.opacity(0.85))
                                    .frame(width: max(0, geo.size.width * player.progress))
                            }
                            .frame(height: 3)
                            .contentShape(Rectangle())
                            .gesture(
                                DragGesture(minimumDistance: 0)
                                    .onEnded { value in
                                        let ratio = max(0, min(1, value.location.x / max(geo.size.width, 1)))
                                        player.seek(to: ratio)
                                    }
                            )
                        }
                        .frame(height: 6)
                    }

                    Spacer()

                    HStack(spacing: 8) {
                        Button { player.playPrevious() } label: {
                            Image(systemName: "backward.fill")
                                .font(.system(size: 13, weight: .bold))
                                .padding(10)
                                .background(.ultraThinMaterial)
                                .clipShape(Circle())
                                .overlay(Circle().stroke(Color.white.opacity(0.25), lineWidth: 1))
                        }
                        .buttonStyle(.plain)

                        Button { player.togglePlayPause() } label: {
                            Image(systemName: player.isPlaying ? "pause.fill" : "play.fill")
                                .font(.system(size: 14, weight: .bold))
                                .padding(10)
                                .background(.ultraThinMaterial)
                                .clipShape(Circle())
                                .overlay(Circle().stroke(Color.white.opacity(0.25), lineWidth: 1))
                        }
                        .buttonStyle(.plain)

                        Button { player.playNext() } label: {
                            Image(systemName: "forward.fill")
                                .font(.system(size: 13, weight: .bold))
                                .padding(10)
                                .background(.ultraThinMaterial)
                                .clipShape(Circle())
                                .overlay(Circle().stroke(Color.white.opacity(0.25), lineWidth: 1))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(.ultraThinMaterial)
                .clipShape(Capsule(style: .continuous))
                .overlay(Capsule().stroke(Color.white.opacity(0.25), lineWidth: 1))
                .shadow(color: Color.black.opacity(0.15), radius: 16, y: 8)
            }
        }
    }
}



#Preview {
    NavigationStack { MusicView() }
}
