//
//  PantherColorsEnvironment.swift
//  pantherapp
//
//  Propagates the resolved PantherColors palette down the view tree — the
//  SwiftUI equivalent of Compose's LocalPantherColors CompositionLocal. Set
//  once at the root (see RootView) from VpnViewModel's themeMode/themeStyle +
//  the real @Environment(\.colorScheme), which is only reliably readable from
//  inside a View (not from the ViewModel itself).
//

import SwiftUI

private struct PantherColorsKey: EnvironmentKey {
    static let defaultValue = PantherColors.dark
}

extension EnvironmentValues {
    var pantherColors: PantherColors {
        get { self[PantherColorsKey.self] }
        set { self[PantherColorsKey.self] = newValue }
    }
}
