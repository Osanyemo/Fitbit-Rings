import SwiftUI

struct OnboardingView: View {
    let authenticator: AuthProviding
    let onConnected: () async -> Void

    @State private var isConnecting = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            ZStack {
                DashboardBackground()

                VStack(alignment: .leading, spacing: 28) {
                    Spacer(minLength: 24)

                    VStack(alignment: .leading, spacing: 18) {
                        OnboardingRingMark()

                        VStack(alignment: .leading, spacing: 14) {
                            Text("Fitbit Rings")
                                .font(.system(size: 42, weight: .bold, design: .rounded))
                                .foregroundStyle(.primary)
                                .minimumScaleFactor(0.8)

                            Text("A fast daily dashboard for Fitbit activity on iPhone.")
                                .font(.title3.weight(.medium))
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
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
                    .padding(16)
                    .dashboardSurface(level: .raised, accentColor: .activeRing)

                    Spacer()

                    if let errorMessage {
                        HStack(alignment: .top, spacing: 10) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.subheadline.weight(.bold))
                            Text(errorMessage)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .font(.footnote.weight(.medium))
                        .foregroundStyle(Color(uiColor: .systemRed))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(12)
                        .dashboardSurface(level: .raised, accentColor: Color(uiColor: .systemRed), isHighlighted: true)
                    }

                    Button {
                        Task { await connect() }
                    } label: {
                        HStack {
                            if isConnecting {
                                ProgressView()
                                    .tint(.white)
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
                    .tint(.activeRing)
                    .disabled(isConnecting)
                    .shadow(color: Color.activeRing.opacity(0.24), radius: 12, x: 0, y: 6)
                }
                .padding(24)
            }
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

private struct OnboardingRingMark: View {
    var body: some View {
        ZStack {
            Circle()
                .stroke(.moveRing, style: stroke)
                .frame(width: 86, height: 86)
                .shadow(color: Color.moveRing.opacity(0.24), radius: 7, x: 0, y: 3)
            Circle()
                .stroke(.activeRing, style: stroke)
                .frame(width: 60, height: 60)
                .shadow(color: Color.activeRing.opacity(0.24), radius: 7, x: 0, y: 3)
            Circle()
                .stroke(.stepsRing, style: stroke)
                .frame(width: 34, height: 34)
                .shadow(color: Color.stepsRing.opacity(0.24), radius: 7, x: 0, y: 3)
        }
        .frame(width: 92, height: 92)
        .dashboardSurface(level: .prominent, accentColor: .activeRing)
        .accessibilityHidden(true)
    }

    private var stroke: StrokeStyle {
        StrokeStyle(lineWidth: 9, lineCap: .round, lineJoin: .round)
    }
}

private struct OnboardingPoint: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: icon)
                .font(.title3)
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(.activeRing)
                .frame(width: 26)
                .padding(.top, 1)
            Text(text)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}
