//
//  ServersView.swift
//  pantherapp
//
//  Mirrors Android's ui/screens/servers/ServersScreen.kt — optimal-server
//  card, ping/refresh header buttons, server list with single-line name +
//  ping-on-its-own-line (same fix Android got for the wrapping bug), radio
//  selection.
//

import SwiftUI

struct ServersView: View {
    /// Called after a server is picked (manually or via "optimal") — the
    /// containing MainTabView uses this to switch back to the Home tab,
    /// same as Android's onBack()-after-select behavior.
    var onServerPicked: () -> Void = {}

    @Environment(VpnViewModel.self) private var viewModel
    @Environment(\.pantherColors) private var colors

    // Server list order is kept exactly as the API returns it — same order
    // as Remnawave's Hosts panel / what Happ shows. Never re-sorted here.

    var body: some View {
        GradientBackground {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    header
                    OptimalServerCard {
                        Task {
                            await viewModel.selectOptimalServer()
                            onServerPicked()
                        }
                    }
                    Text("servers_all_section")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(colors.textSecondary)

                    if viewModel.servers.isEmpty {
                        Text("servers_empty")
                            .font(.footnote)
                            .foregroundStyle(colors.textSecondary)
                    }

                    ForEach(viewModel.servers) { server in
                        ServerRow(
                            server: server,
                            selected: server.id == viewModel.selectedServer?.id,
                            pingText: pingText(for: server.id)
                        ) {
                            Task {
                                await viewModel.selectServer(server.id)
                                onServerPicked()
                            }
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 14)
                .padding(.bottom, 140)
            }
        }
    }

    private var header: some View {
        HStack {
            Text("servers_title")
                .font(.system(size: 28, weight: .bold))
                .foregroundStyle(colors.textPrimary)
            Spacer()
            if viewModel.isPinging {
                ProgressView().tint(colors.accent)
            } else {
                IconTile(systemImage: "waveform.path.ecg", size: 40) {
                    Task { await viewModel.pingAllServers() }
                }
            }
            if viewModel.isLoadingDashboard {
                ProgressView().tint(colors.accent)
            } else {
                IconTile(systemImage: "arrow.clockwise", size: 40) {
                    Task { await viewModel.loadDashboard(showFeedback: true) }
                }
            }
        }
    }

    /// nil = not pinged yet (nothing shown); "—" stands in for a
    /// timed-out/unreachable attempt so it still reads as "pinged, but bad"
    /// rather than looking identical to "never pinged".
    private func pingText(for serverId: String) -> String? {
        guard let value = viewModel.serverPings[serverId] else { return nil }
        if let ms = value { return "\(ms) ms" }
        return "—"
    }
}

private struct OptimalServerCard: View {
    let onTap: () -> Void
    @Environment(\.pantherColors) private var colors

    var body: some View {
        PantherCard(onTap: onTap) {
            HStack(spacing: 14) {
                IconTile(systemImage: "bolt.fill", containerColor: colors.accent, contentColor: .white)
                VStack(alignment: .leading, spacing: 2) {
                    Text("servers_optimal_title")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(colors.textPrimary)
                    Text("servers_optimal_subtitle")
                        .font(.caption)
                        .foregroundStyle(colors.textSecondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

private struct ServerRow: View {
    let server: VpnServer
    let selected: Bool
    let pingText: String?
    let onTap: () -> Void

    @Environment(\.pantherColors) private var colors

    var body: some View {
        PantherCard(
            contentPadding: EdgeInsets(top: 12, leading: 16, bottom: 12, trailing: 16),
            onTap: onTap
        ) {
            HStack(alignment: .center, spacing: 8) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(server.name)
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(colors.textPrimary)
                        .lineLimit(1)
                        .truncationMode(.tail)
                    if let pingText {
                        Text(pingText)
                            .font(.footnote)
                            .foregroundStyle(colors.textSecondary)
                    }
                }
                Spacer()
                Image(systemName: selected ? "largecircle.fill.circle" : "circle")
                    .foregroundStyle(selected ? colors.accent : colors.textSecondary)
                    .font(.title3)
            }
        }
    }
}
