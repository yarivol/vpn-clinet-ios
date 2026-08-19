//
//  Sparkline.swift
//  pantherapp
//
//  Minimal sparkline: a smoothed line through `points` with a gradient fill
//  beneath it, normalized to the min/max of the data — mirrors Android's
//  ui/components/Sparkline.kt.
//

import SwiftUI

struct Sparkline: View {
    let points: [Double]
    var lineColor: Color?

    @Environment(\.pantherColors) private var colors

    var body: some View {
        let color = lineColor ?? colors.accent
        Canvas { context, size in
            guard points.count >= 2 else { return }

            let minValue = points.min() ?? 0
            let maxValue = points.max() ?? 0
            let range = (maxValue - minValue) > 0 ? (maxValue - minValue) : 1
            let stepX = size.width / CGFloat(points.count - 1)
            let topInset = size.height * 0.1
            let usableHeight = size.height - topInset

            func y(for value: Double) -> CGFloat {
                topInset + usableHeight - CGFloat((value - minValue) / range) * usableHeight
            }

            var linePath = Path()
            var prevX: CGFloat = 0
            var prevY = y(for: points[0])
            linePath.move(to: CGPoint(x: prevX, y: prevY))
            for i in 1..<points.count {
                let x = CGFloat(i) * stepX
                let yPos = y(for: points[i])
                let midX = (prevX + x) / 2
                linePath.addCurve(
                    to: CGPoint(x: x, y: yPos),
                    control1: CGPoint(x: midX, y: prevY),
                    control2: CGPoint(x: midX, y: yPos)
                )
                prevX = x
                prevY = yPos
            }

            var fillPath = linePath
            fillPath.addLine(to: CGPoint(x: size.width, y: size.height))
            fillPath.addLine(to: CGPoint(x: 0, y: size.height))
            fillPath.closeSubpath()

            context.fill(
                fillPath,
                with: .linearGradient(
                    Gradient(colors: [color.opacity(0.35), .clear]),
                    startPoint: CGPoint(x: 0, y: 0),
                    endPoint: CGPoint(x: 0, y: size.height)
                )
            )
            context.stroke(linePath, with: .color(color), style: StrokeStyle(lineWidth: 2, lineCap: .round))
        }
    }
}
