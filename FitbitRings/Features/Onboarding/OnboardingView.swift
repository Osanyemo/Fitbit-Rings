import SwiftUI
import UIKit

struct OnboardingView: View {
    let authenticator: AuthProviding
    let onConnected: () async -> Void

    @State private var isConnecting = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 30) {
                    VStack(alignment: .leading, spacing: 20) {
                        MotionRingsMark(size: 132)
                            .frame(maxWidth: .infinity)

                        VStack(alignment: .leading, spacing: 10) {
                            Text("Fitbit Rings")
                                .font(.largeTitle.weight(.bold))
                                .accessibilityAddTraits(.isHeader)

                            Text("Your Fitbit activity, workouts, sleep, and health metrics—clear at a glance.")
                                .font(.title3.weight(.medium))
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }

                    VStack(alignment: .leading, spacing: 18) {
                        OnboardingPoint(
                            icon: "lock.shield.fill",
                            title: "Read-only access",
                            text: "Fitbit Rings only requests permission to read the Google Health data you choose to share."
                        )
                        OnboardingPoint(
                            icon: "iphone.and.arrow.forward",
                            title: "Private by design",
                            text: "Your dashboard cache stays on this iPhone and is removed when you disconnect."
                        )
                        OnboardingPoint(
                            icon: "bolt.horizontal.circle.fill",
                            title: "Ready right away",
                            text: "See cached progress immediately while your latest measurements refresh."
                        )
                    }

                    Text("You can change goals, units, appearance, or disconnect at any time in Settings.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.horizontal, 24)
                .padding(.top, 28)
                .padding(.bottom, 132)
            }
            .background(Color.fitbitBackground.ignoresSafeArea())
            .safeAreaInset(edge: .bottom) {
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
                    .frame(minHeight: DashboardDesign.minimumControlSize)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(isConnecting)
                .padding(.horizontal, 24)
                .padding(.vertical, 14)
                .background(.regularMaterial)
            }
            .navigationBarTitleDisplayMode(.inline)
            .alert(
                "Couldn’t Connect",
                isPresented: Binding(
                    get: { errorMessage != nil },
                    set: { if !$0 { errorMessage = nil } }
                )
            ) {
                Button("OK", role: .cancel) {
                    errorMessage = nil
                }
            } message: {
                Text(errorMessage ?? "Please try again.")
            }
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
            UIAccessibility.post(
                notification: .announcement,
                argument: "Google Health connected"
            )
            await onConnected()
        } catch {
            errorMessage = "Google Health couldn’t complete the connection. Please try again."
            UIAccessibility.post(
                notification: .announcement,
                argument: "Google Health could not be connected"
            )
        }
    }
}

private struct OnboardingPoint: View {
    let icon: String
    let title: String
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: icon)
                .font(.title2.weight(.semibold))
                .foregroundStyle(.stepsRing)
                .frame(width: 34, height: 34)
                .padding(.top, 1)

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(.primary)
                Text(text)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .accessibilityElement(children: .combine)
    }
}

struct MotionRingsMark: View {
    var size: CGFloat
    @Environment(\.accessibilityDifferentiateWithoutColor) private var differentiateWithoutColor

    var body: some View {
        ZStack {
            Circle()
                .fill(Color(uiColor: .secondarySystemGroupedBackground))

            motionArc(inset: 12, color: .moveRing, rotation: -28)
            motionArc(inset: 27, color: .activeRing, rotation: 22)
            motionArc(inset: 42, color: .stepsRing, rotation: 72)

            Circle()
                .fill(Color.primary.opacity(0.88))
                .frame(width: size * 0.13, height: size * 0.13)
        }
        .frame(width: size, height: size)
        .overlay {
            Circle()
                .stroke(Color.dashboardStroke, lineWidth: 1)
        }
        .accessibilityHidden(true)
    }

    private func motionArc(inset: CGFloat, color: Color, rotation: Double) -> some View {
        Circle()
            .trim(from: 0.08, to: differentiateWithoutColor ? 0.69 : 0.74)
            .stroke(
                color,
                style: StrokeStyle(
                    lineWidth: max(7, size * 0.105),
                    lineCap: differentiateWithoutColor ? .butt : .round,
                    dash: differentiateWithoutColor ? [size * 0.08, size * 0.035] : []
                )
            )
            .padding(inset)
            .rotationEffect(.degrees(rotation))
    }
}

#if DEBUG
#Preview("Onboarding AX5") {
    OnboardingView(
        authenticator: PreviewOnboardingAuthenticator(),
        onConnected: {}
    )
    .environment(\.dynamicTypeSize, .accessibility5)
}

private final class PreviewOnboardingAuthenticator: AuthProviding {
    var currentUserEmail: String? { nil }

    func restorePreviousSignIn() async -> Bool { false }

    @MainActor
    func signIn(presenting viewController: UIViewController) async throws {}

    func signOut() {}

    func accessToken() async throws -> String {
        throw AuthenticationError.missingAccessToken
    }
}
#endif
