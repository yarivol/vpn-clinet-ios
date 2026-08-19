//
//  PantherCard.swift
//  pantherapp
//
//  Base card surface used across the app — mirrors Android's
//  ui/components/PantherCard.kt: translucent fill over the gradient
//  background, hairline stroke, 24pt rounded corner.
//

import SwiftUI

struct PantherCard<Content: View>: View {
    var contentPadding: EdgeInsets = EdgeInsets(top: 16, leading: 16, bottom: 16, trailing: 16)
    var onTap: (() -> Void)?
    @ViewBuilder var content: () -> Content

    @Environment(\.pantherColors) private var colors

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 24)
        let card = VStack(alignment: .leading, spacing: 0) {
            content()
        }
        .padding(contentPadding)
        .background(colors.cardFill, in: shape)
        .overlay(shape.stroke(colors.cardStroke, lineWidth: 1))
        .contentShape(shape)

        // Only attach a tap gesture when there's actually a handler - cards
        // used purely as visual containers (e.g. MenuRow's PantherCard
        // inside a NavigationLink/Button) would otherwise carry an
        // always-present no-op gesture that can shadow the ancestor
        // NavigationLink/Button's own tap across the whole row.
        if let onTap {
            card.onTapGesture(perform: onTap)
        } else {
            card
        }
    }
}
