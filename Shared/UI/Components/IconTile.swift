//
//  IconTile.swift
//  pantherapp
//
//  Square rounded icon container — mirrors Android's
//  ui/components/IconTile.kt. Reused for both small in-card icons and larger
//  header buttons by varying size/cornerRadius/colors. Pass nil for
//  containerColor/contentColor to use the theme's default icon-tile colors.
//

import SwiftUI

struct IconTile: View {
    let systemImage: String
    var size: CGFloat = 44
    var cornerRadius: CGFloat = 12
    var containerColor: Color?
    var contentColor: Color?
    var borderColor: Color?
    var onTap: (() -> Void)?

    @Environment(\.pantherColors) private var colors

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius)
        let icon = Image(systemName: systemImage)
            .font(.system(size: size * 0.42))
            .foregroundStyle(contentColor ?? colors.iconTint)
            .frame(width: size, height: size)
            .background(containerColor ?? colors.iconTileFill, in: shape)
            .overlay {
                if let borderColor {
                    shape.stroke(borderColor, lineWidth: 1)
                }
            }
            .contentShape(shape)

        // Only attach a tap gesture when there's actually a handler - an
        // always-present no-op gesture on purely decorative icons (e.g.
        // inside a MenuRow/PantherCard(onTap:)) can shadow the parent
        // Button/NavigationLink's own tap in that exact spot.
        if let onTap {
            icon.onTapGesture(perform: onTap)
        } else {
            icon
        }
    }
}
