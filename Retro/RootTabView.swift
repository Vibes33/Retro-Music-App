//
//  RootTabView.swift
//  Retro
//
//  Created by Ryan on 20/09/2025.
//
import SwiftUI


struct RootTabView: View {
    var body: some View {
        TabView {
            HomeView()
                .tabItem {
                    Label("Home", systemImage: "diamond.fill")
                }
            MusicView()
                .tabItem {
                    Label("Music", systemImage: "music.note.list")
                }
            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gearshape")
                }
            AccountView()
                .tabItem {
                    Label("Account", systemImage: "person.crop.circle")
                }
        }
    }
}
