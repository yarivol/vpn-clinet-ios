//
//  HomeView.swift
//  pantherapp
//
//  Mirrors Android's ui/screens/home/HomeScreen.kt — big connect button,
//  status text, current-server pill.
//

import SwiftUI

struct HomeView: View {
    @Environment(VpnViewModel.self) private var viewModel
    @Environment(\.pantherColors) private var colors
    @Environment(\.locale) private var locale

    var body: some View {
        GradientBackground {
            ScrollView {
                VStack(spacing: 24) {
                    Spacer().frame(height: 12)

                    Text("PantherVPN")
                        .font(.system(size: 32, weight: .heavy, design: .rounded))
                        .foregroundStyle(colors.textPrimary)

                    VStack(spacing: 0) {
                        ConnectButton(state: viewModel.connectionState) {
                            Task { await viewModel.toggleConnection() }
                        }
                        Spacer().frame(height: 20)
                        Text(statusText)
                            .font(.title2.weight(.semibold))
                            .foregroundStyle(colors.textPrimary)
                        Spacer().frame(height: 4)
                        Text(subtitleText)
                            .font(.footnote)
                            .foregroundStyle(colors.textSecondary)
                        Spacer().frame(height: 14)
                        Text(serverName)
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(colors.textSecondary)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(colors.cardFill, in: Capsule())
                    }
                    .padding(.vertical, 8)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 140)
            }
        }
    }

    private var serverName: String {
        viewModel.selectedServer?.name ?? String(localized: "home_server_loading", locale: locale)
    }

    private var statusText: String {
        switch viewModel.connectionState {
        case .disconnected: return String(localized: "home_status_disconnected", locale: locale)
        case .connecting: return String(localized: "home_status_connecting", locale: locale)
        case .connected: return String(localized: "home_status_connected", locale: locale)
        }
    }

    private var subtitleText: String {
        switch viewModel.connectionState {
        case .disconnected: return String(localized: "home_subtitle_disconnected", locale: locale)
        case .connecting: return String(localized: "home_subtitle_connecting", locale: locale)
        case .connected: return String(localized: "home_subtitle_connected", locale: locale)
        }
    }
}
