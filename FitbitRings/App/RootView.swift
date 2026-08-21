import SwiftData
import SwiftUI
#if canImport(GoogleSignIn)
import GoogleSignIn
#endif

struct RootView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    @State private var store: FitnessDashboardStore?
    @State private var isSignedIn = false

    private let authenticator = GoogleSignInAuthenticator()

    var body: some View {
        Group {
            if let store, isSignedIn {
                FitnessDashboardView(
                    store: store,
                    accountEmail: authenticator.currentUserEmail,
                    onSignOut: {
                        store.clearHealthDataForDisconnect()
                        authenticator.signOut()
                        isSignedIn = false
                        self.store = nil
                    }
                )
            } else {
                OnboardingView(authenticator: authenticator) {
                    await restoreSessionAndLoad()
                }
            }
        }
        .task {
            await restoreSessionAndLoad()
        }
        .onChange(of: scenePhase) { _, phase in
            guard phase == .active, let store, isSignedIn else { return }
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
        isSignedIn = await authenticator.restorePreviousSignIn()
        guard isSignedIn else { return }

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

        await store?.load()
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
