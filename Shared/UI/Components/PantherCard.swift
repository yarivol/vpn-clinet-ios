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
        VStack(alignment: .leading, spacing: 0) {
            content()
        }
        .padding(contentPadding)
        .background(colors.cardFill, in: shape)
        .overlay(shape.stroke(colors.cardStroke, lineWidth: 1))
        .contentShape(shape)
        .onTapGesture { onTap?() }
    }
}
