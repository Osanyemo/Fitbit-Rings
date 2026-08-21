import SwiftUI
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

    func testPercentFormattingRoundsProgress() {
        XCTAssertEqual(DashboardFormatting.percent(0), "0%")
        XCTAssertEqual(DashboardFormatting.percent(0.865), "87%")
        XCTAssertEqual(DashboardFormatting.percent(1.25), "125%")
        XCTAssertEqual(DashboardFormatting.percent(-0.2), "0%")
        XCTAssertEqual(DashboardFormatting.percent(.infinity), "0%")
    }

    func testAppearancePreferenceMapsToPreferredColorScheme() {
        XCTAssertNil(AppearancePreference.system.preferredColorScheme)
        XCTAssertEqual(AppearancePreference.light.preferredColorScheme, ColorScheme.light)
        XCTAssertEqual(AppearancePreference.dark.preferredColorScheme, ColorScheme.dark)
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

    @MainActor
    func testSummaryViewModelInitializesWithCachedSnapshot() {
        let cached = dashboardSnapshot(steps: 4_321, lastUpdated: Date(timeIntervalSince1970: 100))
        let cache = InMemoryDashboardCache()
        cache.snapshot = cached
        let repository = DashboardRepository(
            googleHealthClient: StubGoogleHealthClient(response: .success(cached)),
            cache: cache
        )

        let viewModel = SummaryViewModel(repository: repository, cache: cache)

        XCTAssertEqual(viewModel.snapshot, cached)
    }

    @MainActor
    func testRefreshIfStaleSkipsFreshCachedSnapshot() async {
        let now = Date(timeIntervalSince1970: 1_000)
        let cached = dashboardSnapshot(steps: 1_234, lastUpdated: now.addingTimeInterval(-30))
        let fresh = dashboardSnapshot(steps: 5_678, lastUpdated: now)
        let cache = InMemoryDashboardCache()
        cache.snapshot = cached
        let client = StubGoogleHealthClient(response: .success(fresh))
        let repository = DashboardRepository(googleHealthClient: client, cache: cache)
        let viewModel = SummaryViewModel(repository: repository, cache: cache, staleAfter: 60)

        await viewModel.refreshIfStale(now: now)

        let fetchCount = await client.numberOfFetches()
        XCTAssertEqual(fetchCount, 0)
        XCTAssertEqual(viewModel.snapshot, cached)
    }

    @MainActor
    func testRefreshIfStaleRefreshesOldCachedSnapshot() async {
        let now = Date(timeIntervalSince1970: 1_000)
        let cached = dashboardSnapshot(steps: 1_234, lastUpdated: now.addingTimeInterval(-61))
        let fresh = dashboardSnapshot(steps: 5_678, lastUpdated: now)
        let cache = InMemoryDashboardCache()
        cache.snapshot = cached
        let client = StubGoogleHealthClient(response: .success(fresh))
        let repository = DashboardRepository(googleHealthClient: client, cache: cache)
        let viewModel = SummaryViewModel(repository: repository, cache: cache, staleAfter: 60)

        await viewModel.refreshIfStale(now: now)

        let fetchCount = await client.numberOfFetches()
        XCTAssertEqual(fetchCount, 1)
        XCTAssertEqual(viewModel.snapshot, fresh)
    }

    @MainActor
    func testManualRefreshBypassesFreshnessWindow() async {
        let now = Date(timeIntervalSince1970: 1_000)
        let cached = dashboardSnapshot(steps: 1_234, lastUpdated: now.addingTimeInterval(-5))
        let fresh = dashboardSnapshot(steps: 5_678, lastUpdated: now)
        let cache = InMemoryDashboardCache()
        cache.snapshot = cached
        let client = StubGoogleHealthClient(response: .success(fresh))
        let repository = DashboardRepository(googleHealthClient: client, cache: cache)
        let viewModel = SummaryViewModel(repository: repository, cache: cache, staleAfter: 60)

        await viewModel.refresh()

        let fetchCount = await client.numberOfFetches()
        XCTAssertEqual(fetchCount, 1)
        XCTAssertEqual(viewModel.snapshot, fresh)
    }

    @MainActor
    func testFailedRefreshPreservesCachedDashboard() async {
        let now = Date(timeIntervalSince1970: 1_000)
        let cached = dashboardSnapshot(steps: 1_234, lastUpdated: now.addingTimeInterval(-120))
        let cache = InMemoryDashboardCache()
        cache.snapshot = cached
        let client = StubGoogleHealthClient(response: .failure(URLError(.notConnectedToInternet)))
        let repository = DashboardRepository(googleHealthClient: client, cache: cache)
        let viewModel = SummaryViewModel(repository: repository, cache: cache, staleAfter: 60)

        await viewModel.refresh()

        let fetchCount = await client.numberOfFetches()
        XCTAssertEqual(fetchCount, 1)
        XCTAssertEqual(viewModel.snapshot.activity, cached.activity)
        XCTAssertEqual(viewModel.snapshot.lastUpdated, cached.lastUpdated)
        XCTAssertEqual(viewModel.snapshot.syncState, .failed)
        XCTAssertNotNil(viewModel.errorMessage)
    }

    @MainActor
    func testConcurrentRefreshesOnlyFetchOnce() async {
        let now = Date(timeIntervalSince1970: 1_000)
        let cached = dashboardSnapshot(steps: 1_234, lastUpdated: now.addingTimeInterval(-120))
        let fresh = dashboardSnapshot(steps: 5_678, lastUpdated: now)
        let cache = InMemoryDashboardCache()
        cache.snapshot = cached
        let client = BlockingGoogleHealthClient(snapshot: fresh)
        let repository = DashboardRepository(googleHealthClient: client, cache: cache)
        let viewModel = SummaryViewModel(repository: repository, cache: cache, staleAfter: 60)

        let firstRefresh = Task { @MainActor in
            await viewModel.refresh()
        }
        await waitForFetchCount(1, client: client)

        let secondRefresh = Task { @MainActor in
            await viewModel.refresh()
        }
        await secondRefresh.value

        let fetchCount = await client.numberOfFetches()
        XCTAssertEqual(fetchCount, 1)

        await client.finish()
        await firstRefresh.value

        XCTAssertEqual(viewModel.snapshot, fresh)
    }

    func testCompactUpdateFormatting() {
        let now = Date(timeIntervalSince1970: 10_000)

        XCTAssertEqual(DashboardFormatting.compactUpdate(.distantPast, relativeTo: now), "Not synced")
        XCTAssertEqual(
            DashboardFormatting.compactUpdate(now.addingTimeInterval(-10), relativeTo: now),
            "Updated just now"
        )
        XCTAssertEqual(
            DashboardFormatting.compactUpdate(now.addingTimeInterval(-185), relativeTo: now),
            "Updated 3m ago"
        )
        XCTAssertEqual(
            DashboardFormatting.compactUpdate(now.addingTimeInterval(-7_200), relativeTo: now),
            "Updated 2h ago"
        )
        XCTAssertEqual(
            DashboardFormatting.compactUpdateAge(now.addingTimeInterval(-185), relativeTo: now),
            "3m ago"
        )
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

private actor StubGoogleHealthClient: GoogleHealthServing {
    enum Response {
        case success(DashboardSnapshot)
        case failure(URLError)
    }

    private(set) var fetchCount = 0
    private let response: Response

    init(response: Response) {
        self.response = response
    }

    func fetchDashboard(goals: ActivityGoals, date: Date) async throws -> DashboardSnapshot {
        fetchCount += 1

        switch response {
        case .success(let snapshot):
            return snapshot
        case .failure(let error):
            throw error
        }
    }

    func numberOfFetches() -> Int {
        fetchCount
    }
}

private actor BlockingGoogleHealthClient: GoogleHealthServing {
    private(set) var fetchCount = 0
    private let snapshot: DashboardSnapshot
    private var continuation: CheckedContinuation<Void, Never>?

    init(snapshot: DashboardSnapshot) {
        self.snapshot = snapshot
    }

    func fetchDashboard(goals: ActivityGoals, date: Date) async throws -> DashboardSnapshot {
        fetchCount += 1
        await withCheckedContinuation { continuation in
            self.continuation = continuation
        }
        return snapshot
    }

    func finish() {
        continuation?.resume()
        continuation = nil
    }

    func numberOfFetches() -> Int {
        fetchCount
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

private func dashboardSnapshot(
    steps: Int,
    lastUpdated: Date,
    syncState: SyncState = .idle
) -> DashboardSnapshot {
    DashboardSnapshot(
        date: lastUpdated,
        rings: RingSet(
            move: RingMetric(title: "Move", value: 320, goal: 500, unit: "kcal"),
            active: RingMetric(title: "Active", value: 28, goal: 30, unit: "min"),
            steps: RingMetric(title: "Steps", value: Double(steps), goal: 10_000, unit: "")
        ),
        activity: ActivitySummary(
            steps: steps,
            distanceMeters: Double(steps) * 0.75,
            activeCalories: 320,
            totalCalories: 2_000
        ),
        latestWorkout: nil,
        heart: HeartSummary(mostRecentHeartRate: nil, restingHeartRate: nil, measuredAt: nil),
        sleep: nil,
        lastUpdated: lastUpdated,
        syncState: syncState
    )
}

private func waitForFetchCount(
    _ expectedCount: Int,
    client: BlockingGoogleHealthClient,
    file: StaticString = #filePath,
    line: UInt = #line
) async {
    for _ in 0..<500 {
        if await client.numberOfFetches() >= expectedCount {
            return
        }
        try? await Task.sleep(nanoseconds: 1_000_000)
    }

    XCTFail("Timed out waiting for fetch count \(expectedCount)", file: file, line: line)
}
