//
//  LogsView.swift
//  pantherapp
//
//  Shows AppLogger's buffer (app + tunnel events) with share/clear actions -
//  mirrors Android's log viewer. Requested after real-device testing left no
//  way to see what actually happened during a connect attempt.
//

import SwiftUI

struct LogsView: View {
    @Environment(\.pantherColors) private var colors
    @Environment(\.dismiss) private var dismiss
    @Environment(\.locale) private var locale

    @State private var entries: [AppLogger.Entry] = []

    var body: some View {
        GradientBackground {
            VStack(alignment: .leading, spacing: 16) {
                header
                Text("logs_title")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundStyle(colors.textPrimary)

                if entries.isEmpty {
                    Text("logs_empty")
                        .font(.footnote)
                        .foregroundStyle(colors.textSecondary)
                } else {
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 8) {
                            ForEach(entries) { entry in
                                LogRow(entry: entry, locale: locale)
                            }
                        }
                        .padding(.bottom, 24)
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 4)
        }
        .navigationBarHidden(true)
        .onAppear { reload() }
        // AppLogger isn't observed reactively (no Combine/notification, see
        // its header comment) - without this, a log written while this
        // screen is already open (e.g. watching a connect attempt happen)
        // wouldn't show up until leaving and re-entering. Cheap enough at
        // this scale (JSON-decoding <=300 small entries) to just poll.
        .task {
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 1_500_000_000)
                guard !Task.isCancelled else { return }
                reload()
            }
        }
    }

    private var header: some View {
        HStack {
            IconTile(systemImage: "chevron.left", size: 52, cornerRadius: 16, containerColor: colors.cardFill, contentColor: colors.textPrimary) {
                dismiss()
            }
            .accessibilityLabel(Text("action_back"))
            .accessibilityAddTraits(.isButton)
            Spacer()
            if !entries.isEmpty {
                ShareLink(item: AppLogger.exportText()) {
                    IconTile(systemImage: "square.and.arrow.up", size: 40)
                }
                IconTile(systemImage: "trash", size: 40) {
                    AppLogger.clear()
                    reload()
                }
                .accessibilityLabel(Text("logs_clear"))
                .accessibilityAddTraits(.isButton)
            }
        }
        .padding(.top, 4)
    }

    private func reload() {
        entries = AppLogger.allEntries().reversed()
    }
}

private struct LogRow: View {
    let entry: AppLogger.Entry
    let locale: Locale
    @Environment(\.pantherColors) private var colors

    private static let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm:ss"
        return f
    }()

    var body: some View {
        PantherCard(contentPadding: EdgeInsets(top: 10, leading: 14, bottom: 10, trailing: 14)) {
            HStack(alignment: .top, spacing: 8) {
                Text(Self.timeFormatter.string(from: entry.date))
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(colors.textSecondary)
                Text(entry.source)
                    .font(.system(.caption, design: .monospaced).weight(.semibold))
                    .foregroundStyle(entry.source == "tunnel" ? colors.accent : colors.statusGood)
                Text(entry.message)
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(colors.textPrimary)
                    .textSelection(.enabled)
                Spacer(minLength: 0)
            }
        }
    }
}
