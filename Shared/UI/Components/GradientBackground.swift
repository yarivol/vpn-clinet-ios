//
//  GradientBackground.swift
//  pantherapp
//
//  Full-screen vertical gradient (top -> mid -> bottom) with a soft radial
//  glow behind the top of the screen — mirrors Android's
//  ui/components/GradientBackground.kt exactly (same color stops).
//

import SwiftUI

struct GradientBackground<Content: View>: View {
    @Environment(\.pantherColors) private var colors
    @ViewBuilder var content: () -> Content

    var body: some View {
        ZStack {
            LinearGradient(
                stops: [
                    .init(color: colors.gradientTop, location: 0),
                    .init(color: colors.gradientMid, location: 0.45),
                    .init(color: colors.gradientBottom, location: 1),
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            RadialGradient(
                colors: [colors.glow.opacity(0.25), .clear],
                center: .top,
                startRadius: 0,
                endRadius: 420
            )
        }
        .ignoresSafeArea()
        .overlay(content())
    }
}
