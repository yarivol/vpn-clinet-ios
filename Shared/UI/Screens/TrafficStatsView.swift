//
//  TrafficStatsView.swift
//  pantherapp
//
//  Mirrors Android's ui/screens/traffic/TrafficStatsScreen.kt — 30-day total
//  + sparkline, per-day breakdown.
//

import SwiftUI

/// "2026-08-16" -> "16 авг"/"16 Aug" — no date-formatting libs needed for
/// this simple, fixed format; the month name is looked up per the active
/// language override rather than device locale, matching Localizable.strings.
private func formatShortDate(_ isoDate: String, locale: Locale) -> String {
    let parts = isoDate.split(separator: "-")
    guard parts.count == 3, let day = Int(parts[2]), let monthNum = Int(parts[1]), (1...12).contains(monthNum)
    else { return isoDate }
    let monthName = String(localized: String.LocalizationValue("month_short_\(monthNum)"), locale: locale)
    return "\(day) \(monthName)"
}

private func formatBytes(_ bytes: Int64, locale: Locale) -> String {
    let gb = Double(bytes) / (1024 * 1024 * 1024)
    let unit = gb >= 1
        ? String(localized: "unit_gb", locale: locale)
        : String(localized: "unit_mb", locale: locale)
    let value = gb >= 1 ? gb : Double(bytes) / (1024 * 1024)
    let format = gb >= 1 ? "%.2f %@" : "%.0f %@"
    return String(format: format, value, unit)
}

struct TrafficStatsView: View {
    @Environment(VpnViewModel.self) private var viewModel
    @Environment(\.pantherColors) private var colors
    @Environment(\.dismiss) private var dismiss
    @Environment(\.locale) private var locale

    private var history: [TrafficHistoryPoint] { viewModel.trafficStats?.history ?? [] }
    private var monthTotalBytes: Int64 { history.reduce(0) { $0 + $1.bytes } }

    var body: some View {
        GradientBackground {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    header
                    Text("traffic_title")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundStyle(colors.textPrimary)

                    PantherCard {
                        HStack(spacing: 14) {
                            IconTile(systemImage: "chart.bar", containerColor: colors.accent, contentColor: .white)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("traffic_last_30_days")
                                    .font(.footnote.weight(.semibold))
                                    .foregroundStyle(colors.textSecondary)
                                Text(formatBytes(monthTotalBytes, locale: locale))
                                    .font(.system(size: 28, weight: .bold))
                                    .foregroundStyle(colors.textPrimary)
                            }
                            Spacer()
                        }
                        if history.count >= 2 {
                            Spacer().frame(height: 18)
                            Sparkline(points: history.map { Double($0.bytes) })
                                .frame(height: 60)
                        }
                    }

                    if history.isEmpty {
                        Text("traffic_empty")
                            .font(.footnote)
                            .foregroundStyle(colors.textSecondary)
                    } else {
                        Text("traffic_by_day")
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(colors.textSecondary)
                        ForEach(history.reversed(), id: \.date) { point in
                            DayRow(point: point)
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 4)
                .padding(.bottom, 40)
            }
        }
        .navigationBarHidden(true)
    }

    private var header: some View {
        HStack {
            IconTile(systemImage: "chevron.left", size: 52, cornerRadius: 16, containerColor: colors.cardFill, contentColor: colors.textPrimary) {
                dismiss()
            }
            Spacer()
        }
        .padding(.top, 4)
    }
}

private struct DayRow: View {
    let point: TrafficHistoryPoint
    @Environment(\.pantherColors) private var colors
    @Environment(\.locale) private var locale

    var body: some View {
        PantherCard(contentPadding: EdgeInsets(top: 12, leading: 16, bottom: 12, trailing: 16)) {
            HStack {
                Text(formatShortDate(point.date, locale: locale))
                    .font(.headline)
                    .foregroundStyle(colors.textPrimary)
                Spacer()
                Text(formatBytes(point.bytes, locale: locale))
                    .font(.footnote)
                    .foregroundStyle(colors.textSecondary)
            }
        }
    }
}
