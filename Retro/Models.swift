//
//  Models.swift
//  Retro
//
//  Created by Ryan on 21/09/2025.
//

import Foundation
import SwiftData

// MARK: - Tag Model
/// User-defined tag (Many-to-Many with Track)
@Model
final class Tag {
    @Attribute(.unique) var name: String
    var tracks: [Track] = []

    init(name: String) {
        self.name = name
    }
}

// MARK: - Track Model
@Model
final class Track {
    /// Identifiant stable
    @Attribute(.unique) var id: UUID

    /// Nom du son (obligatoire)
    var title: String
    /// "Unknown" si non renseigné
    var artist: String
    /// "Unknown" si non renseigné
    var album: String

    /// Date d'ajout auto
    var dateAdded: Date
    /// 1, 2, 3… selon l'ordre d'import
    var downloadIndex: Int

    /// Nom de fichier audio relatif dans Documents/Audio (ex: "<uuid>.mp3")
    var filePath: String
    /// Nom de fichier artwork relatif dans Documents/Artwork (optionnel)
    var artworkPath: String?

    /// Durée en secondes
    var duration: Double

    /// Relation N-N avec Tag
    var tags: [Tag] = []

    init(id: UUID = UUID(),
         title: String,
         artist: String = "Unknown",
         album: String = "Unknown",
         dateAdded: Date = .now,
         downloadIndex: Int,
         filePath: String,
         artworkPath: String? = nil,
         duration: Double = 0,
         tags: [Tag] = []) {
        self.id = id
        self.title = title
        self.artist = artist
        self.album = album
        self.dateAdded = dateAdded
        self.downloadIndex = downloadIndex
        self.filePath = filePath
        self.artworkPath = artworkPath
        self.duration = duration
        self.tags = tags
    }
}

// MARK: - Convenience
extension Track {
    var formattedDuration: String {
        guard duration.isFinite, duration > 0 else { return "--:--" }
        let total = Int(duration.rounded())
        let m = total / 60
        let s = total % 60
        return String(format: "%d:%02d", m, s)
    }
}

// MARK: - Sample Data (for previews)
#if DEBUG
extension Track {
    static func sample(title: String = "Demo Song", artist: String = "Unknown", album: String = "Unknown") -> Track {
        Track(title: title, artist: artist, album: album, downloadIndex: 1, filePath: "demo.m4a", artworkPath: nil, duration: 213, tags: [])
    }
}
#endif
