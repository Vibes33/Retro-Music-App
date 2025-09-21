//
//  RetroApp.swift
//  Retro
//
//  Created by Ryan on 20/09/2025.
//

import SwiftUI
import Observation
import SwiftData

@main
struct RetroApp: App {
    @State private var library = LibraryStore()
    @StateObject private var player = PlayerManager()
    
    var body: some Scene {
        WindowGroup {
            RootTabView()
                .environmentObject(player)
                .environment(library)
                .modelContainer(for: [Track.self, Tag.self])
        }
    }
}

#Preview {
    RootTabView()
        .environmentObject(PlayerManager())
        .environment(LibraryStore())
        .modelContainer(for: [Track.self, Tag.self])
}
