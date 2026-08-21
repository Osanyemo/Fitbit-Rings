import SwiftData
import SwiftUI
#if canImport(GoogleSignIn)
import GoogleSignIn
#endif

struct RootView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    @State private var viewModel: SummaryViewModel?
    @State private var isSignedIn = false

    private let authenticator = GoogleSignInAuthenticator()

    var body: some View {
        Group {
            if let viewModel, isSignedIn {
                SummaryView(
                    viewModel: viewModel,
                    accountEmail: authenticator.currentUserEmail,
                    onSignOut: {
                        authenticator.signOut()
                        isSignedIn = false
                        self.viewModel = nil
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
            guard phase == .active, let viewModel, isSignedIn else { return }
            Task {
                await viewModel.refreshIfStale()
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

        if viewModel == nil {
            let cache = SwiftDataDashboardCache(modelContext: modelContext)
            let client = GoogleHealthClient(
                networkClient: AuthenticatedHTTPClient(authProvider: authenticator)
            )
            viewModel = SummaryViewModel(
                repository: DashboardRepository(
                    googleHealthClient: client,
                    cache: cache
                ),
                cache: cache
            )
        }

        await viewModel?.load()
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
