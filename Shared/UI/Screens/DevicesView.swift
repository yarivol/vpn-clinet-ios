//
//  DevicesView.swift
//  pantherapp
//
//  Mirrors Android's ui/screens/devices/DevicesScreen.kt — list of HWID
//  devices from Remnawave, remove-with-confirmation, current device
//  protected (hint to use Log out instead).
//

import SwiftUI

/// "2026-08-16T20:16:17.387Z" -> "16 авг, 20:16"/"16 Aug, 20:16" — no
/// date-formatting libs needed here either; month name follows the active
/// language override, same as TrafficStatsView's formatShortDate.
private func formatDeviceDate(_ iso: String?, locale: Locale) -> String {
    guard let iso, !iso.isEmpty else { return "" }
    let datePart = iso.split(separator: "T").first.map(String.init) ?? iso
    let timePart = iso.split(separator: "T").count > 1
        ? String(iso.split(separator: "T")[1].prefix(5))
        : ""
    let dateParts = datePart.split(separator: "-")
    guard dateParts.count == 3, let day = Int(dateParts[2]), let monthNum = Int(dateParts[1]), (1...12).contains(monthNum) else { return iso }
    let monthName = String(localized: String.LocalizationValue("month_short_\(monthNum)"), locale: locale)
    return timePart.isEmpty ? "\(day) \(monthName)" : "\(day) \(monthName), \(timePart)"
}

private func deviceMeta(_ device: DeviceDto, locale: Locale) -> String {
    [device.platform, device.osVersion, formatDeviceDate(device.updatedAt, locale: locale)]
        .compactMap { $0 }
        .filter { !$0.isEmpty }
        .joined(separator: " • ")
}

struct DevicesView: View {
    @Environment(VpnViewModel.self) private var viewModel
    @Environment(\.pantherColors) private var colors
    @Environment(\.dismiss) private var dismiss

    @State private var pendingRemoveHwid: String?

    var body: some View {
        GradientBackground {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    header
                    Text("devices_title")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundStyle(colors.textPrimary)

                    if viewModel.devices.isEmpty {
                        Text("devices_empty")
                            .font(.footnote)
                            .foregroundStyle(colors.textSecondary)
                    } else {
                        ForEach(viewModel.devices, id: \.hwid) { device in
                            DeviceRow(
                                device: device,
                                isCurrent: device.hwid != nil && device.hwid == viewModel.currentDeviceHwid,
                                onRemove: { pendingRemoveHwid = device.hwid }
                            )
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 4)
                .padding(.bottom, 40)
            }
        }
        .navigationBarHidden(true)
        .task { await viewModel.loadDevices() }
        .confirmationDialog(
            "devices_remove_confirm_title",
            isPresented: Binding(get: { pendingRemoveHwid != nil }, set: { if !$0 { pendingRemoveHwid = nil } }),
            titleVisibility: .visible
        ) {
            Button("devices_remove_action", role: .destructive) {
                if let hwid = pendingRemoveHwid {
                    Task { await viewModel.removeDevice(hwid) }
                }
                pendingRemoveHwid = nil
            }
            Button("action_cancel", role: .cancel) { pendingRemoveHwid = nil }
        } message: {
            Text("devices_remove_confirm_message")
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
            if viewModel.isLoadingDevices {
                ProgressView().tint(colors.accent)
            } else {
                IconTile(systemImage: "arrow.clockwise", size: 40) {
                    Task { await viewModel.loadDevices() }
                }
                .accessibilityLabel(Text("action_refresh"))
                .accessibilityAddTraits(.isButton)
            }
        }
        .padding(.top, 4)
    }
}

private struct DeviceRow: View {
    let device: DeviceDto
    let isCurrent: Bool
    let onRemove: () -> Void

    @Environment(\.pantherColors) private var colors
    @Environment(\.locale) private var locale

    var body: some View {
        PantherCard {
            HStack(spacing: 14) {
                IconTile(systemImage: "laptopcomputer.and.iphone")
                VStack(alignment: .leading, spacing: 2) {
                    Text(device.deviceModel ?? device.platform ?? String(localized: "devices_unknown_device", locale: locale))
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(colors.textPrimary)
                    let meta = deviceMeta(device, locale: locale)
                    if !meta.isEmpty {
                        Text(meta)
                            .font(.caption)
                            .foregroundStyle(colors.textSecondary)
                    }
                }
                Spacer()
                if isCurrent {
                    Text("devices_current_device")
                        .font(.footnote)
                        .foregroundStyle(colors.accent)
                } else {
                    Button(action: onRemove) {
                        Image(systemName: "trash")
                            .foregroundStyle(colors.statusPoor)
                    }
                    .accessibilityLabel(Text("devices_remove_action"))
                }
            }
            if isCurrent {
                Spacer().frame(height: 8)
                Text("devices_current_hint")
                    .font(.caption)
                    .foregroundStyle(colors.textSecondary)
            }
        }
    }
}
