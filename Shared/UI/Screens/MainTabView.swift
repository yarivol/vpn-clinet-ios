//
//  MainTabView.swift
//  pantherapp
//
//  Mirrors Android's ui/components/PantherBottomBar.kt + PantherNavGraph.kt —
//  same four tabs (Home/Servers/Protection/Profile), same order. Servers
//  auto-returns to Home after picking a server (same as Android's
//  onBack()-after-select behavior) via the shared `selectedTab` binding.
//  Protection/Profile are still placeholders — see PlaceholderScreens.swift.
//

import SwiftUI

struct MainTabView: View {
    @Environment(\.pantherColors) private var colors
    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            HomeView()
                .tabItem { Label("tab_home", systemImage: "house") }
                .tag(0)

            ServersView(onServerPicked: { selectedTab = 0 })
                .tabItem { Label("tab_servers", systemImage: "globe") }
                .tag(1)

            ProtectionView()
                .tabItem { Label("tab_protection", systemImage: "shield") }
                .tag(2)

            ProfileView()
                .tabItem { Label("tab_profile", systemImage: "person") }
                .tag(3)
        }
        .tint(colors.accent)
    }
}
