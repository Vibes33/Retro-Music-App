//
//  AudioLibrary.swift
//  Retro
//
//  Created by Ryan on 21/09/2025.
//

import Foundation
import SwiftData
import AVFoundation
import UniformTypeIdentifiers

// MARK: - Errors
enum AudioImportError: Error, LocalizedError {
    case unsupportedType
    case copyFailed
    case fileMissing

    public var errorDescription: String? {
        switch self {
        case .unsupportedType: return "Format audio non supporté (utilise MP3, AAC, M4A ou WAV)."
        case .copyFailed: return "Échec de la copie du fichier."
        case .fileMissing: return "Le fichier audio est introuvable."
        }
    }
}

// MARK: - Audio Library Helper
enum AudioLibrary {
    static let audioDirName = "Audio"
    static let artworkDirName = "Artwork"

    // MARK: Directories
    static func documentsDir() throws -> URL {
        guard let url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            throw AudioImportError.copyFailed
        }
        return url
    }

    @discardableResult
    static func ensureSubdir(_ name: String) throws -> URL {
        let dir = try documentsDir().appendingPathComponent(name, isDirectory: true)
        if !FileManager.default.fileExists(atPath: dir.path) {
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        return dir
    }

    // MARK: Allowed Types
    static var allowedFileExtensions: Set<String> { ["mp3", "m4a", "aac", "wav"] }
    static var allowedUTTypes: [UTType] { [.audio] }

    /// Produce a local, readable snapshot URL for a given (possibly iCloud/Drive) URL using NSFileCoordinator.
    /// This works even when the original file is not yet fully downloaded locally.
    static func snapshotForReading(_ url: URL) throws -> URL {
        var coordError: NSError?
        var result: URL?
        let coordinator = NSFileCoordinator()
        coordinator.coordinate(readingItemAt: url, options: .forUploading, error: &coordError) { readableURL in
            result = readableURL
        }
        if let e = coordError { throw e }
        return result ?? url
    }

    // MARK: iCloud/Security helpers
    /// Ensure the URL is locally reachable (trigger iCloud download if needed) and return a URL safe to read.
    /// Caller is expected to have started security-scoped access if the URL requires it.
    static func makeLocalIfNeeded(_ url: URL) throws -> URL {
        // If already reachable, use as-is
        if (try? url.checkResourceIsReachable()) == true { return url }

        // If it's an iCloud ubiquitous item, attempt download and poll its status a bit longer
        let keys: Set<URLResourceKey> = [.isUbiquitousItemKey, .ubiquitousItemDownloadingStatusKey]
        let values = try? url.resourceValues(forKeys: keys)
        if values?.isUbiquitousItem == true {
            try? FileManager.default.startDownloadingUbiquitousItem(at: url)
            let deadline = Date().addingTimeInterval(5.0)
            while Date() < deadline {
                if (try? url.checkResourceIsReachable()) == true { return url }
                let v = try? url.resourceValues(forKeys: keys)
                if v?.ubiquitousItemDownloadingStatus == .current { return url }
                RunLoop.current.run(mode: .default, before: Date().addingTimeInterval(0.05))
            }
        }

        // Final quick check
        if (try? url.checkResourceIsReachable()) == true { return url }
        throw AudioImportError.fileMissing
    }

    /// Fallback copy when FileManager.copyItem fails (some providers block direct copy). Streams data to destination.
    static func streamCopy(from src: URL, to dst: URL) throws {
        guard let input = InputStream(url: src), let output = OutputStream(url: dst, append: false) else {
            throw AudioImportError.copyFailed
        }
        input.open(); output.open()
        defer { input.close(); output.close() }
        let bufferSize = 1 * 1024 * 1024 // 1 MB
        let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: bufferSize)
        defer { buffer.deallocate() }
        while input.hasBytesAvailable {
            let read = input.read(buffer, maxLength: bufferSize)
            if read < 0 { throw AudioImportError.copyFailed }
            var writtenTotal = 0
            while writtenTotal < read {
                let written = output.write(buffer.advanced(by: writtenTotal), maxLength: read - writtenTotal)
                if written <= 0 { throw AudioImportError.copyFailed }
                writtenTotal += written
            }
        }
    }

    // MARK: Import
    /// Copie un fichier audio dans le sandbox, calcule la durée, crée/associe les tags et insère un `Track` SwiftData.
    @MainActor
    @discardableResult
    static func importAudio(from sourceURL: URL,
                                   title: String,
                                   artist: String?,
                                   album: String?,
                                   tagNames: [String],
                                   context: ModelContext,
                                   artworkURL: URL? = nil) throws -> Track {
        // Resolve to a readable local URL (fast‑path for already‑local files)
        let resolvedURL: URL
        if sourceURL.isFileURL {
            resolvedURL = sourceURL
        } else {
            let snapURL = try snapshotForReading(sourceURL)
            resolvedURL = try makeLocalIfNeeded(snapURL)
        }
        // Validate extension after resolving (fallback to source if empty)
        var ext = resolvedURL.pathExtension.lowercased()
        if ext.isEmpty { ext = sourceURL.pathExtension.lowercased() }
        guard allowedFileExtensions.contains(ext) else { throw AudioImportError.unsupportedType }

        // Ensure dirs
        let audioDir = try ensureSubdir(audioDirName)

        // Destination unique
        let id = UUID()
        let destURL = audioDir.appendingPathComponent("\(id).\(ext)")

        // Copy file in sandbox (try direct copy, then fallback to stream copy)
        do {
            try FileManager.default.copyItem(at: resolvedURL, to: destURL)
        } catch {
            do {
                try streamCopy(from: resolvedURL, to: destURL)
            } catch {
                throw AudioImportError.copyFailed
            }
        }

        // Duration via AVFoundation
        let asset = AVURLAsset(url: destURL, options: [AVURLAssetPreferPreciseDurationAndTimingKey: true])
        let seconds = CMTimeGetSeconds(asset.duration)
        let durationSec: Double = seconds.isFinite && !seconds.isNaN && seconds >= 0 ? seconds : 0

        // Download index (count + 1)
        let count = (try? context.fetch(FetchDescriptor<Track>()).count) ?? 0

        // Tags
        var tags: [Tag] = []
        for name in tagNames {
            if name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { continue }
            if let tag = try? fetchOrCreateTag(named: name, in: context) { tags.append(tag) }
        }

        // Artwork copy (optional)
        let artworkPath = try saveArtworkIfNeeded(artworkURL)

        // Create Track
        let track = Track(
            id: id,
            title: title,
            artist: (artist?.isEmpty == false) ? artist! : "Unknown",
            album: (album?.isEmpty == false) ? album! : "Unknown",
            downloadIndex: count + 1,
            filePath: destURL.lastPathComponent,
            artworkPath: artworkPath,
            duration: durationSec,
            tags: tags
        )
        context.insert(track)
        try context.save()
        return track
    }

    // MARK: Update
    /// Met à jour les métadonnées d'un track (titre, artiste, album, tags, artwork)
    @MainActor
    static func update(track: Track,
                              title: String?,
                              artist: String?,
                              album: String?,
                              tagNames: [String]?,
                              newArtworkURL: URL?,
                              context: ModelContext) throws {
        if let title = title, !title.isEmpty { track.title = title }
        if let artist = artist { track.artist = artist.isEmpty ? "Unknown" : artist }
        if let album = album { track.album = album.isEmpty ? "Unknown" : album }

        if let names = tagNames {
            // Re-map tags entirely from provided names
            var newTags: [Tag] = []
            for name in names where !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                if let tag = try? fetchOrCreateTag(named: name, in: context) { newTags.append(tag) }
            }
            track.tags = newTags
        }

        if let art = newArtworkURL {
            // Delete old artwork file if exists
            if let old = track.artworkPath {
                try? deleteArtwork(filename: old)
            }
            track.artworkPath = try saveArtworkIfNeeded(art)
        }

        try context.save()
    }

    // MARK: Delete
    /// Supprime un track + ses fichiers associés (audio + artwork)
    @MainActor
    static func delete(track: Track, context: ModelContext) throws {
        // 1) Try to delete files on disk, but do not block if missing
        if !track.filePath.isEmpty {
            try? deleteAudio(filename: track.filePath)
        }
        if let art = track.artworkPath, !art.isEmpty {
            try? deleteArtwork(filename: art)
        }

        // 2) Remove from DB
        context.delete(track)

        // 3) Reindex remaining tracks to keep a stable ordering
        try reindexDownloadIndices(context: context)

        // 4) Persist
        try context.save()
    }

    @MainActor
    private static func reindexDownloadIndices(context: ModelContext) throws {
        // Fetch all tracks ordered by downloadIndex then title for stable ordering
        var descriptor = FetchDescriptor<Track>()
        descriptor.sortBy = [
            SortDescriptor(\.downloadIndex, order: .forward),
            SortDescriptor(\.title, order: .forward)
        ]
        let all = try context.fetch(descriptor)
        for (i, t) in all.enumerated() {
            let wanted = i + 1
            if t.downloadIndex != wanted { t.downloadIndex = wanted }
        }
    }

    // MARK: File ops
    @discardableResult
    static func saveArtworkIfNeeded(_ url: URL?) throws -> String? {
        guard let src = url else { return nil }
        let artDir = try ensureSubdir(artworkDirName)
        let filename = UUID().uuidString + "." + (src.pathExtension.isEmpty ? "jpg" : src.pathExtension)
        let dest = artDir.appendingPathComponent(filename)
        try FileManager.default.copyItem(at: src, to: dest)
        return filename
    }

    static func absoluteURLForAudio(filename: String) throws -> URL {
        try ensureSubdir(audioDirName).appendingPathComponent(filename)
    }

    static func absoluteURLForArtwork(filename: String) throws -> URL {
        try ensureSubdir(artworkDirName).appendingPathComponent(filename)
    }

    static func deleteAudio(filename: String) throws {
        let url = try absoluteURLForAudio(filename: filename)
        if FileManager.default.fileExists(atPath: url.path) {
            try FileManager.default.removeItem(at: url)
        }
    }

    static func deleteArtwork(filename: String) throws {
        let url = try absoluteURLForArtwork(filename: filename)
        if FileManager.default.fileExists(atPath: url.path) {
            try FileManager.default.removeItem(at: url)
        }
    }

    // MARK: Tag helper
    @MainActor
    static func fetchOrCreateTag(named name: String, in context: ModelContext) throws -> Tag {
        if let existing = try context.fetch(FetchDescriptor<Tag>(predicate: #Predicate { $0.name == name })).first {
            return existing
        }
        let tag = Tag(name: name)
        context.insert(tag)
        return tag
    }
}
