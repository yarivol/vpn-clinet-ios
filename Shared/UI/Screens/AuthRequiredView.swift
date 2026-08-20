//
//  AuthRequiredView.swift
//  pantherapp
//
//  Shown instead of the main tab UI whenever there's no valid session.
//  Mirrors Android's ui/screens/auth/AuthRequiredScreen.kt — two ways in:
//  paste an existing subscription link directly, or open the bot to get one.
//

import SwiftUI

private let botURL = URL(string: "https://t.me/PantherVPNBot")!

struct AuthRequiredView: View {
    @Environment(VpnViewModel.self) private var viewModel
    @Environment(\.pantherColors) private var colors
    @Environment(\.openURL) private var openURL

    @State private var linkInput = ""

    private var isAuthenticating: Bool {
        if case .authenticating = viewModel.authState { return true }
        return false
    }

    private var hasError: Bool {
        if case .error = viewModel.authState { return true }
        return false
    }

    var body: some View {
        GradientBackground {
            VStack {
                Spacer()
                if isAuthenticating {
                    ProgressView()
                        .tint(colors.accent)
                    Text("auth_signing_in")
                        .font(.body)
                        .foregroundStyle(colors.textSecondary)
                        .padding(.top, 16)
                } else {
                    content
                }
                Spacer()
            }
            .padding(.horizontal, 32)
        }
    }

    private var content: some View {
        VStack(spacing: 0) {
            Image(systemName: "lock")
                .font(.system(size: 28))
                .foregroundStyle(colors.iconTint)
                .frame(width: 64, height: 64)
                .background(colors.iconTileFill, in: RoundedRectangle(cornerRadius: 20))

            Spacer().frame(height: 24)
            Text("auth_required_title")
                .font(.title3.weight(.semibold))
                .foregroundStyle(colors.textPrimary)
                .multilineTextAlignment(.center)

            Spacer().frame(height: 12)
            Text("auth_required_subtitle")
                .font(.body)
                .foregroundStyle(colors.textSecondary)
                .multilineTextAlignment(.center)

            Spacer().frame(height: 24)
            TextField("auth_link_placeholder", text: $linkInput)
                .textFieldStyle(.roundedBorder)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .foregroundStyle(colors.textPrimary)

            if hasError {
                Spacer().frame(height: 8)
                Text("auth_link_error")
                    .font(.footnote)
                    .foregroundStyle(.red)
            }

            Spacer().frame(height: 12)
            Button {
                Task { await viewModel.handleSubscriptionLink(linkInput.trimmingCharacters(in: .whitespaces)) }
            } label: {
                Text("action_login_with_link")
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 4)
            }
            .buttonStyle(.borderedProminent)
            .tint(colors.accent)
            .disabled(linkInput.trimmingCharacters(in: .whitespaces).isEmpty)

            Spacer().frame(height: 20)
            HStack(spacing: 12) {
                Rectangle().fill(colors.cardStroke).frame(height: 1)
                Text("action_or")
                    .font(.footnote)
                    .foregroundStyle(colors.textSecondary)
                Rectangle().fill(colors.cardStroke).frame(height: 1)
            }

            Spacer().frame(height: 20)
            Text("auth_bot_hint")
                .font(.body)
                .foregroundStyle(colors.textSecondary)
                .multilineTextAlignment(.center)

            Spacer().frame(height: 16)
            Button {
                openURL(botURL)
            } label: {
                Text("auth_login_via_telegram")
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 4)
            }
            .buttonStyle(.bordered)
        }
    }
}
