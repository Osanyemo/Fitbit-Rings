import XCTest
@testable import FitbitRings

final class DashboardTests: XCTestCase {
    func testRingProgressCapsAtOneForRendering() {
        let metric = RingMetric(title: "Steps", value: 12_500, goal: 10_000, unit: "")

        XCTAssertEqual(metric.progress, 1.25)
        XCTAssertEqual(metric.cappedProgress, 1)
    }

    func testDistanceFormattingUsesSelectedUnit() {
        XCTAssertEqual(DashboardFormatting.distance(1_000, unit: .kilometers), "1.00 km")
        XCTAssertEqual(DashboardFormatting.distance(1_609.344, unit: .miles), "1.00 mi")
    }

    func testGoogleHealthMapperBuildsDashboardSnapshot() throws {
        let response = GoogleHealthRollUpResponse(
            rollupDataPoints: [
                GoogleHealthRollupDataPoint(
                    steps: GoogleHealthStepsRollup(countSum: GoogleHealthNumericValue(7_842)),
                    activeMinutes: nil,
                    activeEnergyBurned: nil,
                    distance: nil,
                    totalCalories: nil
                )
            ]
        )

        let snapshot = GoogleHealthMapper.map(
            goals: .defaultGoals,
            date: Date(timeIntervalSince1970: 0),
            rollups: [.steps: response],
            latestWorkout: nil,
            latestHeartRate: nil,
            restingHeartRate: nil,
            sleep: nil
        )

        XCTAssertEqual(snapshot.activity.steps, 7_842)
        XCTAssertEqual(snapshot.rings.steps.value, 7_842)
        XCTAssertEqual(snapshot.rings.steps.goal, 10_000)
    }

    @MainActor
    func testSummaryRefreshIgnoresCancelledRequests() async {
        let cache = InMemoryDashboardCache()
        let repository = DashboardRepository(
            googleHealthClient: ThrowingGoogleHealthClient(error: URLError(.cancelled)),
            cache: cache
        )
        let viewModel = SummaryViewModel(repository: repository, cache: cache)

        await viewModel.refresh()

        XCTAssertNil(viewModel.errorMessage)
        XCTAssertEqual(viewModel.snapshot.syncState, .idle)
    }

    func testMissingScopesErrorNamesScopes() {
        let error = AuthenticationError.missingScopes(["scope-a", "scope-b"])

        XCTAssertTrue(error.localizedDescription.contains("scope-a"))
        XCTAssertTrue(error.localizedDescription.contains("scope-b"))
    }

    func testGoogleSignInConfigurationDetectsPlaceholderClientID() {
        let info: [String: Any] = [
            "GIDClientID": "REPLACE_WITH_GOOGLE_CLIENT_ID",
            "CFBundleURLTypes": [
                ["CFBundleURLSchemes": ["replace_with_google_client_id"]]
            ]
        ]

        let error = GoogleSignInConfiguration.validationError(infoDictionary: info)

        XCTAssertNotNil(error)
        XCTAssertTrue(error?.localizedDescription.contains("GOOGLE_CLIENT_ID") == true)
    }

    func testGoogleSignInConfigurationBuildsCallbackURLScheme() {
        XCTAssertEqual(
            GoogleSignInConfiguration.callbackURLScheme(
                forClientID: "1234567890-abcdef.apps.googleusercontent.com"
            ),
            "com.googleusercontent.apps.1234567890-abcdef"
        )
    }

    func testGoogleSignInConfigurationAcceptsMatchingCallbackURLScheme() {
        let info: [String: Any] = [
            "GIDClientID": "1234567890-abcdef.apps.googleusercontent.com",
            "CFBundleURLTypes": [
                ["CFBundleURLSchemes": ["com.googleusercontent.apps.1234567890-abcdef"]]
            ]
        ]

        XCTAssertNil(GoogleSignInConfiguration.validationError(infoDictionary: info))
    }

    func testGoogleSignInConfigurationRejectsMissingCallbackURLScheme() {
        let info: [String: Any] = [
            "GIDClientID": "1234567890-abcdef.apps.googleusercontent.com",
            "CFBundleURLTypes": [
                ["CFBundleURLSchemes": ["com.example.unrelated"]]
            ]
        ]

        let error = GoogleSignInConfiguration.validationError(infoDictionary: info)

        XCTAssertTrue(
            error?.localizedDescription.contains("com.googleusercontent.apps.1234567890-abcdef") == true
        )
    }
}

private struct ThrowingGoogleHealthClient: GoogleHealthServing {
    var error: Error

    func fetchDashboard(goals: ActivityGoals, date: Date) async throws -> DashboardSnapshot {
        throw error
    }
}

@MainActor
private final class InMemoryDashboardCache: DashboardCaching {
    var snapshot: DashboardSnapshot?
    var preferences: DashboardPreferences = .defaults

    func loadDashboard() -> DashboardSnapshot? {
        snapshot
    }

    func saveDashboard(_ snapshot: DashboardSnapshot) {
        self.snapshot = snapshot
    }

    func loadPreferences() -> DashboardPreferences {
        preferences
    }

    func savePreferences(_ preferences: DashboardPreferences) {
        self.preferences = preferences
    }
}
