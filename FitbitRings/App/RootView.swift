import SwiftData
import SwiftUI
#if canImport(GoogleSignIn)
import GoogleSignIn
#endif

enum AppSessionPhase: Equatable {
    case restoring
    case signedOut
    case signedIn

    static func afterRestoration(isSignedIn: Bool) -> AppSessionPhase {
        isSignedIn ? .signedIn : .signedOut
    }
}

struct RootView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    @State private var store: FitnessDashboardStore?
    @State private var sessionPhase: AppSessionPhase = .restoring
    @State private var didScheduleInitialLoad = false

    private let authenticator = GoogleSignInAuthenticator()

    var body: some View {
        Group {
            switch sessionPhase {
            case .restoring:
                SessionRestoringView()
            case .signedIn:
                if let store {
                FitnessDashboardView(
                    store: store,
                    accountEmail: authenticator.currentUserEmail,
                    onSignOut: {
                        store.clearHealthDataForDisconnect()
                        authenticator.signOut()
                        sessionPhase = .signedOut
                        didScheduleInitialLoad = false
                        self.store = nil
                    }
                )
                } else {
                    SessionRestoringView()
                }
            case .signedOut:
                OnboardingView(authenticator: authenticator) {
                    await restoreSessionAndLoad()
                }
            }
        }
        .task {
            #if DEBUG
            if installDebugLaunchFixtureIfRequested() {
                return
            }
            #endif
            await restoreSessionAndLoad()
        }
        .onChange(of: scenePhase) { _, phase in
            guard phase == .active, let store, sessionPhase == .signedIn else { return }
            Task {
                await store.refreshSummaryIfStale()
            }
        }
        .onOpenURL { url in
            GIDURLHandler.handle(url)
        }
    }

    @MainActor
    private func restoreSessionAndLoad() async {
        let isSignedIn = await authenticator.restorePreviousSignIn()
        let restoredPhase = AppSessionPhase.afterRestoration(isSignedIn: isSignedIn)
        guard restoredPhase == .signedIn else {
            sessionPhase = restoredPhase
            return
        }

        if store == nil {
            let cache = SwiftDataDashboardCache(modelContext: modelContext)
            let client = GoogleHealthClient(
                networkClient: AuthenticatedHTTPClient(authProvider: authenticator)
            )
            store = FitnessDashboardStore(
                repository: DashboardRepository(
                    googleHealthClient: client,
                    cache: cache
                ),
                cache: cache
            )
        }

        sessionPhase = .signedIn

        guard let store, !didScheduleInitialLoad else { return }
        didScheduleInitialLoad = true

        Task { @MainActor in
            await Task.yield()
            await store.load()
            await Task.yield()
            await store.refreshSummaryIfStale()
        }
    }

    #if DEBUG
    @MainActor
    private func installDebugLaunchFixtureIfRequested() -> Bool {
        let arguments = ProcessInfo.processInfo.arguments

        if arguments.contains("-ui-test-signed-out") {
            store = nil
            sessionPhase = .signedOut
            didScheduleInitialLoad = true
            return true
        }

        let fixtureStore: FitnessDashboardStore?
        if arguments.contains("-ui-test-populated") {
            fixtureStore = .preview(snapshot: .previewPopulatedFitness)
        } else if arguments.contains("-ui-test-empty") {
            fixtureStore = .preview(snapshot: .empty())
        } else if arguments.contains("-ui-test-loading") {
            fixtureStore = .previewInitialActivityLoading()
        } else if arguments.contains("-ui-test-failed") {
            fixtureStore = .previewFailedHealth()
        } else {
            fixtureStore = nil
        }

        guard let fixtureStore else { return false }
        fixtureStore.automaticallyRefreshes = false
        store = fixtureStore
        sessionPhase = .signedIn
        didScheduleInitialLoad = true
        return true
    }
    #endif
}

private struct SessionRestoringView: View {
    var body: some View {
        VStack(spacing: 20) {
            MotionRingsMark(size: 112)

            VStack(spacing: 8) {
                Text("Fitbit Rings")
                    .font(.largeTitle.weight(.bold))
                    .accessibilityAddTraits(.isHeader)

                HStack(spacing: 10) {
                    ProgressView()
                        .controlSize(.small)
                        .accessibilityHidden(true)
                    Text("Preparing your dashboard")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.fitbitBackground.ignoresSafeArea())
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Fitbit Rings. Preparing your dashboard.")
    }
}

enum GIDURLHandler {
    static func handle(_ url: URL) {
        #if canImport(GoogleSignIn)
        guard GoogleSignInConfiguration.validationError() == nil else {
            return
        }

        GIDSignIn.sharedInstance.handle(url)
        #endif
    }
}
