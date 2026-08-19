//
//  ProtectionView.swift
//  pantherapp
//
//  Mirrors Android's ui/screens/protection/ProtectionScreen.kt — three
//  cosmetic toggles (no real backend yet, same on Android), default off.
//

import SwiftUI

private struct ToggleDef: Identifiable {
    var id: ProtectionToggleType { type }
    let type: ProtectionToggleType
    let titleKey: LocalizedStringKey
    let descriptionKey: LocalizedStringKey
    let systemImage: String
}

private let toggleDefs: [ToggleDef] = [
    ToggleDef(type: .killSwitch, titleKey: "protection_killswitch_title", descriptionKey: "protection_killswitch_desc", systemImage: "power"),
    ToggleDef(type: .adBlock, titleKey: "protection_adblock_title", descriptionKey: "protection_adblock_desc", systemImage: "hand.raised"),
    ToggleDef(type: .trackerBlock, titleKey: "protection_trackerblock_title", descriptionKey: "protection_trackerblock_desc", systemImage: "eye.slash"),
]

struct ProtectionView: View {
    @Environment(VpnViewModel.self) private var viewModel
    @Environment(\.pantherColors) private var colors

    var body: some View {
        GradientBackground {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("protection_title")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundStyle(colors.textPrimary)

                    ForEach(toggleDefs) { def in
                        ToggleRow(
                            systemImage: def.systemImage,
                            titleKey: def.titleKey,
                            descriptionKey: def.descriptionKey,
                            isOn: Binding(
                                get: { viewModel.protectionSettings.value(def.type) },
                                set: { viewModel.setProtectionToggle(def.type, enabled: $0) }
                            )
                        )
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 4)
                .padding(.bottom, 140)
            }
        }
    }
}

private struct ToggleRow: View {
    let systemImage: String
    let titleKey: LocalizedStringKey
    let descriptionKey: LocalizedStringKey
    @Binding var isOn: Bool

    @Environment(\.pantherColors) private var colors

    var body: some View {
        PantherCard {
            HStack(alignment: .center, spacing: 14) {
                IconTile(systemImage: systemImage)
                VStack(alignment: .leading, spacing: 2) {
                    Text(titleKey)
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(colors.textPrimary)
                    Text(descriptionKey)
                        .font(.caption)
                        .foregroundStyle(colors.textSecondary)
                }
                Spacer()
                Toggle("", isOn: $isOn)
                    .labelsHidden()
                    .tint(colors.accent)
            }
        }
    }
}
