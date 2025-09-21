//
//  Models.swift
//  Retro
//
//  Created by Ryan on 21/09/2025.
//

import Foundation
import SwiftData


@Model
final class Tag {
    @Attribute(.unique) var name: String
    var tracks: [Track] = []

    init(name: String) {
        self.name = name
    }
}

@Model
final class Track {
    
    @Attribute(.unique) var id: UUID

    var title: String
    var artist: String
    var album: String

    var dateAdded: Date
    var downloadIndex: Int

    var filePath: String
    var artworkPath: String?

    var duration: Double

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

extension Track {
    var formattedDuration: String {
        guard duration.isFinite, duration > 0 else { return "--:--" }
        let total = Int(duration.rounded())
        let m = total / 60
        let s = total % 60
        return String(format: "%d:%02d", m, s)
    }
}

#if DEBUG
extension Track {
    static func sample(title: String = "Demo Song", artist: String = "Unknown", album: String = "Unknown") -> Track {
        Track(title: title, artist: artist, album: album, downloadIndex: 1, filePath: "demo.m4a", artworkPath: nil, duration: 213, tags: [])
    }
}
#endif
