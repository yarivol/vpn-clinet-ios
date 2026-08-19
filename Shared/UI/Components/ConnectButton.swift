//
//  ConnectButton.swift
//  pantherapp
//
//  The big central power button — mirrors Android's
//  ui/components/ConnectButton.kt: ring color animates between states, sonar
//  rings emanate while connected, a spinning gradient arc plays while
//  connecting, a press-down scale gives tactile feedback, and a spring "pop"
//  plays on every state change. Ported to SwiftUI's declarative animation
//  model rather than a literal line-by-line translation of Compose's
//  imperative Animatable APIs — same visual result, idiomatic on each side.
//

import SwiftUI

struct ConnectButton: View {
    let state: ConnectionState
    let onClick: () -> Void

    @Environment(\.pantherColors) private var colors
    @State private var isPressed = false
    @State private var spinnerAngle: Angle = .degrees(0)
    @State private var glowPulse: CGFloat = 0.55

    private var isConnected: Bool { state == .connected }
    private var isConnecting: Bool { state == .connecting }

    private var ringColor: Color {
        switch state {
        case .connected: return colors.accent
        case .connecting: return colors.accentMuted
        case .disconnected: return colors.textSecondary
        }
    }

    var body: some View {
        ZStack {
            if isConnected {
                pulseRing(delay: 0)
                pulseRing(delay: 1.1)
            }

            // Outer glow.
            Circle()
                .fill(RadialGradient(colors: [colors.glow.opacity(0.55), .clear], center: .center, startRadius: 0, endRadius: 130))
                .frame(width: 260, height: 260)
                .opacity(isConnected ? glowPulse : 0.4)
                .blur(radius: 36)
                .animation(.easeInOut(duration: 2.2).repeatForever(autoreverses: true), value: glowPulse)

            // Static outer ring.
            Circle()
                .stroke(ringColor.opacity(0.35), lineWidth: 2)
                .frame(width: 250, height: 250)

            // Spinning gradient arc while connecting.
            if isConnecting {
                Circle()
                    .trim(from: 0, to: 300.0 / 360.0)
                    .stroke(
                        AngularGradient(colors: [.clear, ringColor, ringColor], center: .center),
                        style: StrokeStyle(lineWidth: 4, lineCap: .round)
                    )
                    .frame(width: 238, height: 238)
                    .rotationEffect(spinnerAngle)
                    .transition(.opacity)
            }

            // Main button.
            Circle()
                .fill(RadialGradient(colors: [ringColor.opacity(0.18), .clear], center: .center, startRadius: 0, endRadius: 115))
                .frame(width: 230, height: 230)
                .overlay(Circle().stroke(ringColor, lineWidth: 3))
                .overlay(
                    Image(systemName: "power")
                        .font(.system(size: 56, weight: .regular))
                        .foregroundStyle(colors.textPrimary)
                )
                .contentShape(Circle())
                .scaleEffect(isPressed ? 0.94 : 1)
                .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isPressed)
                .onTapGesture {
                    guard !isConnecting else { return }
                    let generator = UIImpactFeedbackGenerator(style: .medium)
                    generator.impactOccurred()
                    onClick()
                }
                .simultaneousGesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { _ in isPressed = true }
                        .onEnded { _ in isPressed = false }
                )
        }
        .frame(width: 280, height: 280)
        .animation(.easeInOut(duration: 0.45), value: ringColor)
        .scaleEffect(stateBounceScale)
        .onAppear {
            withAnimation(.linear(duration: 1).repeatForever(autoreverses: false)) {
                spinnerAngle = .degrees(360)
            }
            withAnimation(.easeInOut(duration: 2.2).repeatForever(autoreverses: true)) {
                glowPulse = 1
            }
        }
        .onChange(of: state) { _, _ in
            stateBounceScale = 0.86
            withAnimation(.spring(response: 0.5, dampingFraction: 0.55)) {
                stateBounceScale = 1
            }
        }
    }

    @State private var stateBounceScale: CGFloat = 1

    @ViewBuilder
    private func pulseRing(delay: Double) -> some View {
        TimelineView(.animation) { context in
            let period = 2.2
            let elapsed = context.date.timeIntervalSinceReferenceDate + delay
            let progress = (elapsed.truncatingRemainder(dividingBy: period)) / period
            Circle()
                .stroke(ringColor, lineWidth: 2)
                .frame(width: 230, height: 230)
                .scaleEffect(1 + progress * 0.35)
                .opacity((1 - progress) * 0.5)
        }
    }
}

#Preview {
    ZStack {
        Color(hex: 0x1E0E38).ignoresSafeArea()
        ConnectButton(state: .connected, onClick: {})
            .environment(\.pantherColors, .dark)
    }
}
