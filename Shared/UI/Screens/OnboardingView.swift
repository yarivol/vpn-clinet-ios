//
//  OnboardingView.swift
//  pantherapp
//
//  First-launch consent gate - shown once, before anything else (even
//  AuthRequiredView), gated by a plain UserDefaults flag. Directly addresses
//  the App Store review requirement for a visible, accessible Privacy
//  Policy/Terms link (see the review-readiness discussion this was prompted
//  by) - not just a policy that exists somewhere on the website.
//
//  The body text is deliberately generic ("by continuing you agree to...")
//  rather than asserting specific claims like "we don't collect any data" -
//  the backend does collect hwid/telegram_id/subscription/traffic data for
//  the service to function, so a blanket "we collect nothing" claim here
//  would be false and a real App Store / legal risk. The actual data
//  practices belong in the linked Privacy Policy page itself, which the
//  business controls independently of this app build.
//

import SwiftUI

private let privacyPolicyURL = URL(string: "https://panthervpn.store/privacy")!
private let termsOfUseURL = URL(string: "https://panthervpn.store/agreement")!

enum OnboardingStore {
    private static let acceptedKey = "onboarding.accepted"

    static var hasAccepted: Bool {
        UserDefaults.standard.bool(forKey: acceptedKey)
    }

    static func markAccepted() {
        UserDefaults.standard.set(true, forKey: acceptedKey)
    }
}

struct OnboardingView: View {
    let onAccept: () -> Void

    @Environment(\.pantherColors) private var colors
    @Environment(\.openURL) private var openURL

    var body: some View {
        GradientBackground {
            VStack {
                Spacer()

                IconTile(systemImage: "shield.checkerboard", size: 88, cornerRadius: 26, containerColor: colors.accent, contentColor: .white)

                Spacer().frame(height: 24)
                Text("onboarding_title")
                    .font(.title2.weight(.bold))
                    .foregroundStyle(colors.textPrimary)
                    .multilineTextAlignment(.center)

                Spacer().frame(height: 12)
                Text("onboarding_body")
                    .font(.body)
                    .foregroundStyle(colors.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 8)

                Spacer()

                Button {
                    OnboardingStore.markAccepted()
                    onAccept()
                } label: {
                    Text("onboarding_accept")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 4)
                }
                .buttonStyle(.borderedProminent)
                .tint(colors.accent)

                Spacer().frame(height: 16)
                HStack(spacing: 6) {
                    Button {
                        openURL(privacyPolicyURL)
                    } label: {
                        Text("onboarding_privacy_policy")
                            .font(.footnote.weight(.medium))
                            .foregroundStyle(colors.accent)
                    }
                    Text("&")
                        .font(.footnote)
                        .foregroundStyle(colors.textSecondary)
                    Button {
                        openURL(termsOfUseURL)
                    } label: {
                        Text("onboarding_terms_of_use")
                            .font(.footnote.weight(.medium))
                            .foregroundStyle(colors.accent)
                    }
                }
                .multilineTextAlignment(.center)

                Spacer().frame(height: 8)
            }
            .padding(.horizontal, 32)
        }
    }
}
