import SwiftUI

struct OnboardingView: View {
    let authenticator: AuthProviding
    let onConnected: () async -> Void

    @State private var isConnecting = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 28) {
                Spacer(minLength: 24)

                VStack(alignment: .leading, spacing: 16) {
                    Text("Fitbit Rings")
                        .font(.system(size: 42, weight: .bold, design: .rounded))
                        .foregroundStyle(.primary)
                        .minimumScaleFactor(0.8)

                    Text("A fast daily dashboard for Fitbit activity on iPhone.")
                        .font(.title3.weight(.medium))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                VStack(alignment: .leading, spacing: 16) {
                    OnboardingPoint(
                        icon: "heart.text.square",
                        text: "Reads your Google Health activity, heart, workout, and sleep summaries."
                    )
                    OnboardingPoint(
                        icon: "arrow.triangle.2.circlepath",
                        text: "Shows cached progress immediately while fresh data syncs."
                    )
                    OnboardingPoint(
                        icon: "circle.dashed.inset.filled",
                        text: "Keeps the focus on today's Move, Active, and Steps progress."
                    )
                }
                .font(.callout)
                .foregroundStyle(.secondary)

                Spacer()

                if let errorMessage {
                    Text(errorMessage)
                        .font(.footnote.weight(.medium))
                        .foregroundStyle(.red)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                Button {
                    Task { await connect() }
                } label: {
                    HStack {
                        if isConnecting {
                            ProgressView()
                        } else {
                            Image(systemName: "person.crop.circle.badge.checkmark")
                        }
                        Text(isConnecting ? "Connecting..." : "Connect Google Health")
                    }
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(isConnecting)
            }
            .padding(24)
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    @MainActor
    private func connect() async {
        guard let presenter = ViewControllerResolver.topMostViewController() else {
            errorMessage = AuthenticationError.missingPresenter.localizedDescription
            return
        }

        isConnecting = true
        defer { isConnecting = false }

        do {
            try await authenticator.signIn(presenting: presenter)
            await onConnected()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

private struct OnboardingPoint: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: icon)
                .font(.title3)
                .frame(width: 26)
                .padding(.top, 1)
            Text(text)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}
