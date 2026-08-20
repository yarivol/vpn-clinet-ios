//
//  ProfileView.swift
//  pantherapp
//
//  Mirrors Android's ui/screens/profile/ProfileScreen.kt — subscription
//  card, monthly traffic card (→ TrafficStatsView), menu rows (Devices,
//  Support, Settings, Log out).
//

import SwiftUI

private let botURL = URL(string: "https://t.me/PantherVPNBot")!
private let supportURL = URL(string: "https://t.me/TechPantherVPN")!

/// Small amounts round away to "0.0 GB" — pick whichever unit actually shows the value.
private func formatTrafficParts(_ bytes: Int64, locale: Locale) -> (String, String) {
    let gb = Double(bytes) / (1024 * 1024 * 1024)
    let mb = Double(bytes) / (1024 * 1024)
    let kb = Double(bytes) / 1024
    if gb >= 1 { return (String(format: "%.1f", gb), String(localized: "unit_gb", locale: locale)) }
    if mb >= 1 { return (String(format: "%.1f", mb), String(localized: "unit_mb", locale: locale)) }
    return (String(format: "%.0f", kb), String(localized: "unit_kb", locale: locale))
}

struct ProfileView: View {
    @Environment(VpnViewModel.self) private var viewModel
    @Environment(\.pantherColors) private var colors
    @Environment(\.openURL) private var openURL
    @Environment(\.locale) private var locale

    var body: some View {
        NavigationStack {
            GradientBackground {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        Text("profile_title")
                            .font(.system(size: 28, weight: .bold))
                            .foregroundStyle(colors.textPrimary)

                        subscriptionCard
                        trafficCard

                        NavigationLink(value: ProfileDestination.devices) {
                            MenuRow(
                                systemImage: "laptopcomputer.and.iphone",
                                titleKey: "profile_menu_devices",
                                trailing: deviceCountText
                            )
                        }
                        .buttonStyle(.plain)

                        Button { openURL(supportURL) } label: {
                            MenuRow(systemImage: "questionmark.circle", titleKey: "profile_menu_support")
                        }
                        .buttonStyle(.plain)

                        NavigationLink(value: ProfileDestination.settings) {
                            MenuRow(systemImage: "gearshape", titleKey: "profile_menu_settings")
                        }
                        .buttonStyle(.plain)

                        Button {
                            Task { await viewModel.logout() }
                        } label: {
                            MenuRow(systemImage: "rectangle.portrait.and.arrow.right", titleKey: "profile_menu_logout", tint: colors.statusPoor, showChevron: false)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 4)
                    .padding(.bottom, 140)
                }
            }
            .navigationDestination(for: ProfileDestination.self) { destination in
                switch destination {
                case .devices: DevicesView()
                case .settings: SettingsView()
                case .trafficStats: TrafficStatsView()
                }
            }
            .navigationBarHidden(true)
        }
    }

    private var deviceCountText: String {
        guard let subscription = viewModel.subscription else { return String(localized: "profile_device_count_placeholder", locale: locale) }
        return "\(subscription.currentDevices)/\(subscription.deviceLimit)"
    }

    private var subscriptionCard: some View {
        PantherCard {
            HStack(spacing: 14) {
                IconTile(systemImage: "crown.fill", containerColor: colors.accent, contentColor: .white)
                VStack(alignment: .leading, spacing: 2) {
                    Text(viewModel.subscription?.displayName ?? String(localized: "profile_premium_default_name", locale: locale))
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(colors.textPrimary)
                    Text(subscriptionStatusText)
                        .font(.footnote.weight(.medium))
                        .foregroundStyle(colors.accent)
                }
                Spacer()
            }

            Spacer().frame(height: 10)
            Text(daysLeftText)
                .font(.caption)
                .foregroundStyle(colors.textSecondary)

            Spacer().frame(height: 14)
            Button {
                openURL(botURL)
            } label: {
                Text("action_open_bot")
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 4)
            }
            .buttonStyle(.borderedProminent)
            .tint(colors.accent)
        }
    }

    private var subscriptionStatusText: String {
        let key = viewModel.subscription?.isActive == true ? "profile_subscription_active" : "profile_subscription_inactive"
        return String(localized: String.LocalizationValue(key), locale: locale)
    }

    private var daysLeftText: String {
        guard let subscription = viewModel.subscription, subscription.isActive else {
            return String(localized: "profile_subscription_inactive", locale: locale)
        }
        return String(format: String(localized: "profile_days_left_format", locale: locale), subscription.daysLeft)
    }

    private var trafficCard: some View {
        let (value, unit) = formatTrafficParts(viewModel.trafficStats?.usedBytes ?? 0, locale: locale)
        return NavigationLink(value: ProfileDestination.trafficStats) {
            PantherCard {
                HStack(spacing: 14) {
                    IconTile(systemImage: "chart.bar.fill", containerColor: colors.accent, contentColor: .white)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("profile_traffic_month")
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(colors.textSecondary)
                        HStack(alignment: .lastTextBaseline, spacing: 4) {
                            Text(value)
                                .font(.system(size: 26, weight: .bold))
                                .foregroundStyle(colors.textPrimary)
                            Text(unit)
                                .font(.subheadline)
                                .foregroundStyle(colors.textSecondary)
                        }
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.footnote)
                        .foregroundStyle(colors.textSecondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .buttonStyle(.plain)
    }
}

private enum ProfileDestination: Hashable {
    case devices
    case settings
    case trafficStats
}

private struct MenuRow: View {
    let systemImage: String
    let titleKey: LocalizedStringKey
    var trailing: String?
    var tint: Color?
    var showChevron: Bool = true

    @Environment(\.pantherColors) private var colors

    var body: some View {
        PantherCard {
            HStack(spacing: 14) {
                IconTile(systemImage: systemImage, contentColor: tint)
                Text(titleKey)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(tint ?? colors.textPrimary)
                Spacer()
                if let trailing {
                    Text(trailing)
                        .font(.footnote)
                        .foregroundStyle(colors.textSecondary)
                }
                if showChevron {
                    Image(systemName: "chevron.right")
                        .font(.footnote)
                        .foregroundStyle(colors.textSecondary)
                }
            }
        }
    }
}
