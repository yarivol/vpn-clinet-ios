//
//  ToastBanner.swift
//  pantherapp
//
//  Simple auto-dismissing top banner — the SwiftUI stand-in for Android's
//  Toast.makeText(...).show() calls in MainActivity.kt (auth outcome,
//  dashboard refresh feedback, VPN errors). Not a general-purpose toast
//  queue: at most one banner shows at a time, a new one replaces whatever
//  was showing — matches how those events fire in practice (rare, one at a
//  time), no need for more machinery than that.
//

import SwiftUI

struct ToastMessage: Identifiable, Equatable {
    let id = UUID()
    let text: String
    var isError = false
}

/// Add to the root of the view hierarchy: `.toastOverlay(message: $toast)`.
struct ToastOverlay: ViewModifier {
    @Binding var message: ToastMessage?
    @Environment(\.pantherColors) private var colors

    func body(content: Content) -> some View {
        content.overlay(alignment: .top) {
            if let message {
                Text(message.text)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(
                        (message.isError ? colors.statusPoor : colors.accent),
                        in: RoundedRectangle(cornerRadius: 14)
                    )
                    .padding(.horizontal, 24)
                    .padding(.top, 8)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .task(id: message.id) {
                        try? await Task.sleep(nanoseconds: 2_500_000_000)
                        withAnimation { self.message = nil }
                    }
            }
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: message)
    }
}

extension View {
    func toastOverlay(message: Binding<ToastMessage?>) -> some View {
        modifier(ToastOverlay(message: message))
    }
}
