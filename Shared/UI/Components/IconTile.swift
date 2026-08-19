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
        Image(systemName: systemImage)
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
            .onTapGesture { onTap?() }
    }
}
