import SwiftData
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

    func testDistancePartsUseSelectedUnitForMetricCards() {
        XCTAssertEqual(
            DashboardFormatting.distanceParts(6_840, unit: .kilometers),
            DashboardFormatting.MetricValue(value: "6.84", unit: "km")
        )
        XCTAssertEqual(
            DashboardFormatting.distanceParts(1_609.344, unit: .miles),
            DashboardFormatting.MetricValue(value: "1.00", unit: "mi")
        )
    }

    func testActivitySeriesLookupsKeepDailyAndHourlyDistinct() {
        let day = Date(timeIntervalSince1970: 1_800)
        let hour = Date(timeIntervalSince1970: 3_600)
        let dailySteps = NumericMetricSeries(
            type: .steps,
            points: [
                NumericMetricPoint(
                    id: "daily-steps",
                    startDate: day,
                    value: 8_000,
                    unit: "steps"
                )
            ]
        )
        let hourlySteps = NumericMetricSeries(
            type: .steps,
            points: [
                NumericMetricPoint(
                    id: "hourly-steps",
                    startDate: hour,
                    value: 450,
                    unit: "steps"
                )
            ]
        )
        let activityData = ActivityDashboardData(
            dailySeries: [dailySteps],
            hourlySeries: [hourlySteps],
            bucketedSeries: [],
            loadedAt: nil
        )

        XCTAssertEqual(activityData.series(for: .steps), dailySteps)
        XCTAssertEqual(activityData.dailySeries(for: .steps), dailySteps)
        XCTAssertEqual(activityData.hourlySeries(for: .steps), hourlySteps)
    }

    func testDurationPartsUseCompactMetricCardUnits() {
        XCTAssertEqual(
            DashboardFormatting.durationParts(2_940),
            DashboardFormatting.MetricValue(value: "49", unit: "m")
        )
        XCTAssertEqual(
            DashboardFormatting.durationParts(3_900),
            DashboardFormatting.MetricValue(value: "1h 5m", unit: "")
        )
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

    func testActivityGoalPriorityKeepsStepsPrimaryWhenMoveIsFurtherBehind() throws {
        let insights = [
            activityGoalInsight(
                title: "Steps",
                value: 453,
                goal: 10_000,
                displayUnit: "steps",
                dataType: .steps,
                systemImage: "shoeprints.fill",
                accentColor: .stepsRing
            ),
            activityGoalInsight(
                title: "Exercise",
                value: 5,
                goal: 30,
                displayUnit: "min",
                dataType: .activeMinutes,
                systemImage: "figure.run",
                accentColor: .activeRing
            ),
            activityGoalInsight(
                title: "Move",
                value: 5,
                goal: 500,
                displayUnit: "kcal",
                dataType: .activeEnergyBurned,
                systemImage: "flame.fill",
                accentColor: .moveRing
            )
        ]

        let primary = try XCTUnwrap(ActivityGoalPriority.primaryInsight(from: insights))

        XCTAssertEqual(primary.dataType, .steps)
        XCTAssertEqual(primary.primaryUnit, "steps left")
    }

    func testActivityGoalPriorityFallsThroughAfterStepsAreComplete() throws {
        let insights = [
            activityGoalInsight(
                title: "Steps",
                value: 10_000,
                goal: 10_000,
                displayUnit: "steps",
                dataType: .steps,
                systemImage: "shoeprints.fill",
                accentColor: .stepsRing
            ),
            activityGoalInsight(
                title: "Exercise",
                value: 5,
                goal: 30,
                displayUnit: "min",
                dataType: .activeMinutes,
                systemImage: "figure.run",
                accentColor: .activeRing
            ),
            activityGoalInsight(
                title: "Move",
                value: 5,
                goal: 500,
                displayUnit: "kcal",
                dataType: .activeEnergyBurned,
                systemImage: "flame.fill",
                accentColor: .moveRing
            )
        ]

        let primary = try XCTUnwrap(ActivityGoalPriority.primaryInsight(from: insights))

        XCTAssertEqual(primary.dataType, .activeMinutes)
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

    @MainActor
    func testFitnessDashboardStoreLazyLoadsActivityOnce() async {
        let summary = dashboardSnapshot(steps: 1_234, lastUpdated: Date(timeIntervalSince1970: 1_000))
        let cache = InMemoryDashboardCache()
        cache.fitnessSnapshot = FitnessDataSnapshot.fromLegacyDashboard(summary)
        let client = SectionedGoogleHealthClient(summary: summary)
        let repository = DashboardRepository(googleHealthClient: client, cache: cache)
        let store = FitnessDashboardStore(
            repository: repository,
            cache: cache,
            staleAfter: .greatestFiniteMagnitude
        )

        await store.loadIfNeeded(.activity)
        await store.loadIfNeeded(.activity)

        let count = await client.activityFetchCount
        XCTAssertEqual(count, 1)
        XCTAssertEqual(store.sectionState(.activity).phase, .loaded)
        XCTAssertEqual(store.snapshot.activity.dailySeries.first?.type, .steps)
    }

    @MainActor
    func testFitnessDashboardStoreLoadHydratesCachedSectionsWithoutNetwork() async {
        let summary = dashboardSnapshot(steps: 1_234, lastUpdated: Date(timeIntervalSince1970: 1_000))
        let activity = cachedActivityData(loadedAt: Date(timeIntervalSince1970: 1_100))
        let workoutLoadedAt = Date(timeIntervalSince1970: 1_200)
        let workout = workoutDetail(startTime: Date(timeIntervalSince1970: 900))
        let health = cachedHealthData(loadedAt: Date(timeIntervalSince1970: 1_300))
        let cache = InMemoryDashboardCache()
        cache.fitnessSnapshot = FitnessDataSnapshot(
            summary: summary,
            activity: activity,
            workouts: [workout],
            workoutsLoadedAt: workoutLoadedAt,
            health: health,
            lastUpdated: health.loadedAt
        )
        let fresh = dashboardSnapshot(steps: 5_678, lastUpdated: Date(timeIntervalSince1970: 2_000))
        let client = StubGoogleHealthClient(response: .success(fresh))
        let repository = DashboardRepository(googleHealthClient: client, cache: cache)
        let store = FitnessDashboardStore(repository: repository, cache: cache, staleAfter: 0)

        await store.load()

        let fetchCount = await client.numberOfFetches()
        XCTAssertEqual(fetchCount, 0)
        XCTAssertEqual(store.snapshot.summary, summary)
        XCTAssertEqual(store.snapshot.activity, activity)
        XCTAssertEqual(store.snapshot.workouts, [workout])
        XCTAssertEqual(store.snapshot.workoutsLoadedAt, workoutLoadedAt)
        XCTAssertEqual(store.snapshot.health, health)
        XCTAssertEqual(store.sectionState(.activity).phase, .loaded)
        XCTAssertEqual(store.sectionState(.workouts).phase, .loaded)
        XCTAssertEqual(store.sectionState(.health).phase, .loaded)
    }

    @MainActor
    func testFitnessDashboardStoreDefaultFreshnessWindowIsFiveMinutes() async {
        let now = Date(timeIntervalSince1970: 1_000)
        let cached = dashboardSnapshot(steps: 1_234, lastUpdated: now.addingTimeInterval(-299))
        let fresh = dashboardSnapshot(steps: 5_678, lastUpdated: now)
        let cache = InMemoryDashboardCache()
        cache.fitnessSnapshot = FitnessDataSnapshot.fromLegacyDashboard(cached)
        let client = StubGoogleHealthClient(response: .success(fresh))
        let repository = DashboardRepository(googleHealthClient: client, cache: cache)
        let store = FitnessDashboardStore(repository: repository, cache: cache)

        await store.refreshSummaryIfStale(now: now)

        let fetchCount = await client.numberOfFetches()
        XCTAssertEqual(fetchCount, 0)
        XCTAssertEqual(store.snapshot.summary, cached)
    }

    @MainActor
    func testFitnessDashboardStoreManualRefreshBypassesFreshnessWindow() async {
        let now = Date(timeIntervalSince1970: 1_000)
        let cached = dashboardSnapshot(steps: 1_234, lastUpdated: now.addingTimeInterval(-5))
        let fresh = dashboardSnapshot(steps: 5_678, lastUpdated: now)
        let cache = InMemoryDashboardCache()
        cache.fitnessSnapshot = FitnessDataSnapshot.fromLegacyDashboard(cached)
        let client = StubGoogleHealthClient(response: .success(fresh))
        let repository = DashboardRepository(googleHealthClient: client, cache: cache)
        let store = FitnessDashboardStore(repository: repository, cache: cache)

        await store.refreshSummary()

        let fetchCount = await client.numberOfFetches()
        XCTAssertEqual(fetchCount, 1)
        XCTAssertEqual(store.snapshot.summary, fresh)
    }

    @MainActor
    func testFitnessDashboardStoreFetchesWorkoutsWhenCacheOnlyHasSummaryWorkout() async {
        var summary = dashboardSnapshot(steps: 1_234, lastUpdated: Date(timeIntervalSince1970: 1_000))
        summary.latestWorkout = WorkoutSummary(
            type: "Walk",
            startTime: Date(timeIntervalSince1970: 900),
            durationSeconds: 1_200,
            distanceMeters: 1_140,
            calories: 154
        )
        let cache = InMemoryDashboardCache()
        cache.fitnessSnapshot = FitnessDataSnapshot.fromLegacyDashboard(summary)
        let client = SectionedGoogleHealthClient(summary: summary)
        let repository = DashboardRepository(googleHealthClient: client, cache: cache)
        let store = FitnessDashboardStore(
            repository: repository,
            cache: cache,
            staleAfter: .greatestFiniteMagnitude
        )

        await store.loadIfNeeded(.workouts)

        let count = await client.workoutFetchCount
        XCTAssertEqual(count, 1)
        XCTAssertEqual(store.sectionState(.workouts).phase, .loaded)
        XCTAssertEqual(store.snapshot.workouts.first?.metricsSummary.averageHeartRate, 122)
        XCTAssertNotNil(store.snapshot.workoutsLoadedAt)
    }

    @MainActor
    func testFitnessDashboardStoreRefreshesStaleCachedActivity() async {
        let oldDate = Date(timeIntervalSince1970: 1_000)
        let summary = dashboardSnapshot(steps: 1_234, lastUpdated: oldDate)
        let cachedPoint = NumericMetricPoint(
            id: "cached-steps",
            startDate: oldDate,
            value: 42,
            unit: "steps"
        )
        let cache = InMemoryDashboardCache()
        cache.fitnessSnapshot = FitnessDataSnapshot(
            summary: summary,
            activity: ActivityDashboardData(
                dailySeries: [NumericMetricSeries(type: .steps, points: [cachedPoint])],
                hourlySeries: [],
                bucketedSeries: [],
                loadedAt: oldDate
            ),
            lastUpdated: oldDate
        )
        let client = SectionedGoogleHealthClient(summary: summary)
        let repository = DashboardRepository(googleHealthClient: client, cache: cache)
        let store = FitnessDashboardStore(repository: repository, cache: cache, staleAfter: 60)

        await store.loadIfNeeded(.activity)

        let count = await client.activityFetchCount
        XCTAssertEqual(count, 1)
        XCTAssertEqual(store.snapshot.activity.dailySeries.first?.points.first?.value, 1_234)
    }

    @MainActor
    func testFitnessDashboardStoreRoutesSummaryCardsToOwningTabs() {
        let summary = dashboardSnapshot(steps: 1_234, lastUpdated: Date(timeIntervalSince1970: 1_000))
        let cache = InMemoryDashboardCache()
        let client = StubGoogleHealthClient(response: .success(summary))
        let repository = DashboardRepository(googleHealthClient: client, cache: cache)
        let store = FitnessDashboardStore(repository: repository, cache: cache)

        store.route(to: .metric(.heartRate))

        XCTAssertEqual(store.selectedTab, .health)
        XCTAssertEqual(store.healthPath.last, .metric(.heartRate))
    }

    @MainActor
    func testFitnessDashboardStoreClearsCachedHealthDataOnDisconnect() {
        let summary = dashboardSnapshot(steps: 1_234, lastUpdated: Date(timeIntervalSince1970: 1_000))
        let cache = InMemoryDashboardCache()
        cache.fitnessSnapshot = FitnessDataSnapshot.fromLegacyDashboard(summary)
        let client = StubGoogleHealthClient(response: .success(summary))
        let repository = DashboardRepository(googleHealthClient: client, cache: cache)
        let store = FitnessDashboardStore(repository: repository, cache: cache)

        store.clearHealthDataForDisconnect()

        XCTAssertNil(cache.fitnessSnapshot)
        XCTAssertNil(cache.snapshot)
        XCTAssertEqual(cache.preferences, .defaults)
        XCTAssertEqual(store.snapshot.summary.lastUpdated, .distantPast)
    }

    @MainActor
    func testSwiftDataDashboardCacheSavesAndLoadsSplitSections() throws {
        let context = try makeInMemoryModelContext()
        let cache = SwiftDataDashboardCache(modelContext: context)
        let summary = dashboardSnapshot(steps: 2_468, lastUpdated: Date(timeIntervalSince1970: 1_000))
        let activity = cachedActivityData(loadedAt: Date(timeIntervalSince1970: 1_100))
        let workoutLoadedAt = Date(timeIntervalSince1970: 1_200)
        let workout = workoutDetail(startTime: Date(timeIntervalSince1970: 900))
        let health = cachedHealthData(loadedAt: Date(timeIntervalSince1970: 1_300))

        cache.saveSummary(summary)
        cache.saveActivityData(activity)
        cache.saveWorkouts([workout], loadedAt: workoutLoadedAt)
        cache.saveHealthData(health)

        let loaded = try XCTUnwrap(cache.loadFitnessData())
        XCTAssertEqual(cache.loadSummary(), summary)
        XCTAssertEqual(loaded.summary, summary)
        XCTAssertEqual(loaded.activity, activity)
        XCTAssertEqual(loaded.workouts, [workout])
        XCTAssertEqual(loaded.workoutsLoadedAt, workoutLoadedAt)
        XCTAssertEqual(loaded.health, health)
    }

    @MainActor
    func testSwiftDataDashboardCacheFallsBackToLegacyFullSnapshot() throws {
        let context = try makeInMemoryModelContext()
        let summary = dashboardSnapshot(steps: 2_468, lastUpdated: Date(timeIntervalSince1970: 1_000))
        let legacy = FitnessDataSnapshot(
            summary: summary,
            activity: cachedActivityData(loadedAt: Date(timeIntervalSince1970: 1_100)),
            workouts: [workoutDetail(startTime: Date(timeIntervalSince1970: 900))],
            workoutsLoadedAt: Date(timeIntervalSince1970: 1_200),
            health: cachedHealthData(loadedAt: Date(timeIntervalSince1970: 1_300)),
            lastUpdated: Date(timeIntervalSince1970: 1_300)
        )
        context.insert(
            CachedDashboardSnapshot(
                data: try encodeLegacyFitnessSnapshot(legacy),
                updatedAt: legacy.lastUpdated
            )
        )
        try context.save()

        let cache = SwiftDataDashboardCache(modelContext: context)

        XCTAssertEqual(cache.loadFitnessData(), legacy)
        XCTAssertEqual(cache.loadSummary(), summary)
    }

    @MainActor
    func testSwiftDataDashboardCacheClearHealthDataDeletesLegacyAndSplitRows() throws {
        let context = try makeInMemoryModelContext()
        let cache = SwiftDataDashboardCache(modelContext: context)
        let summary = dashboardSnapshot(steps: 2_468, lastUpdated: Date(timeIntervalSince1970: 1_000))
        let legacy = FitnessDataSnapshot.fromLegacyDashboard(summary)
        context.insert(
            CachedDashboardSnapshot(
                data: try encodeLegacyFitnessSnapshot(legacy),
                updatedAt: legacy.lastUpdated
            )
        )
        cache.saveSummary(summary)
        cache.saveActivityData(cachedActivityData(loadedAt: Date(timeIntervalSince1970: 1_100)))
        cache.saveWorkouts(
            [workoutDetail(startTime: Date(timeIntervalSince1970: 900))],
            loadedAt: Date(timeIntervalSince1970: 1_200)
        )
        cache.saveHealthData(cachedHealthData(loadedAt: Date(timeIntervalSince1970: 1_300)))

        cache.clearHealthData()

        XCTAssertNil(cache.loadFitnessData())
        XCTAssertNil(cache.loadSummary())
        XCTAssertTrue(try context.fetch(FetchDescriptor<CachedDashboardSnapshot>()).isEmpty)
        XCTAssertTrue(try context.fetch(FetchDescriptor<CachedDashboardSection>()).isEmpty)
    }

    func testHealthDashboardVisibilityHidesEmptyGroups() {
        let health = HealthDashboardData.empty

        XCTAssertTrue(health.isEmpty)
        XCTAssertEqual(health.visibleMetricGroups, [])
    }

    func testHealthDashboardVisibilityKeepsSleepSessionsAsContent() {
        var health = HealthDashboardData.empty
        health.sleepSessions = [
            SleepSession(
                id: "sleep",
                startTime: Date(timeIntervalSince1970: 0),
                endTime: Date(timeIntervalSince1970: 3_600),
                durationSeconds: 3_600,
                stages: []
            )
        ]

        XCTAssertFalse(health.isEmpty)
        XCTAssertEqual(health.visibleMetricGroups, [])
    }

    func testHealthDashboardVisibilityIncludesPopulatedMetricGroups() {
        let date = Date(timeIntervalSince1970: 1_000)
        let point = NumericMetricPoint(id: "point", startDate: date, value: 1, unit: "")
        let health = HealthDashboardData(
            heartSeries: [NumericMetricSeries(type: .heartRate, points: [point])],
            sleepMetricSeries: [NumericMetricSeries(type: .dailySleepTemperatureDerivations, points: [point])],
            vitalSeries: [NumericMetricSeries(type: .dailyRespiratoryRate, points: [point])],
            cardioFitnessSeries: [NumericMetricSeries(type: .dailyVo2Max, points: [point])],
            bodySeries: [NumericMetricSeries(type: .weight, points: [point])],
            sleepSessions: [],
            loadedAt: date
        )

        XCTAssertFalse(health.isEmpty)
        XCTAssertEqual(
            health.visibleMetricGroups,
            [.heart, .sleepMetrics, .vitals, .cardioFitness, .body]
        )
    }

    func testBucketedMetricSeriesDisplayCollapsesCachedDuplicateIntensityRows() {
        let series = BucketedMetricSeries(
            type: .activeMinutes,
            title: "Activity Level",
            buckets: [
                MetricBucket(label: "Light", value: 120, unit: "min"),
                MetricBucket(label: "Moderate", value: 62, unit: "min"),
                MetricBucket(label: "Vigorous", value: 72, unit: "min"),
                MetricBucket(label: "Light", value: 98, unit: "min"),
                MetricBucket(label: " moderately-active ", value: 20, unit: "min"),
                MetricBucket(label: "VERY_ACTIVE", value: 51, unit: "min")
            ],
            rangeStart: nil,
            rangeEnd: nil
        )

        XCTAssertEqual(series.displayTitle, "Activity Intensity")
        XCTAssertEqual(series.displayBuckets.map(\.label), ["Light", "Moderate", "Vigorous"])
        XCTAssertEqual(series.displayBuckets.map(\.value), [218, 82, 123])
    }

    @MainActor
    func testRefreshSummarySeedsMeasuredHeartRateIntoHealthSeries() async throws {
        let measuredAt = Date(timeIntervalSince1970: 1_500)
        var summary = dashboardSnapshot(steps: 1_234, lastUpdated: measuredAt)
        summary.heart = HeartSummary(
            mostRecentHeartRate: 72,
            restingHeartRate: 58,
            measuredAt: measuredAt
        )
        let cache = InMemoryDashboardCache()
        let repository = DashboardRepository(
            googleHealthClient: StubGoogleHealthClient(response: .success(summary)),
            cache: cache
        )

        let snapshot = try await repository.refreshSummary(
            preserving: .empty(goals: .defaultGoals),
            date: measuredAt
        )

        let heartSeries = try XCTUnwrap(snapshot.health.series(for: .heartRate))
        XCTAssertEqual(heartSeries.latestPoint?.value, 72)
        XCTAssertEqual(heartSeries.latestPoint?.startDate, measuredAt)
        XCTAssertNil(snapshot.health.series(for: .dailyRestingHeartRate))
    }

    @MainActor
    func testRefreshSummaryDoesNotSeedHeartRateWithoutMeasurementTime() async throws {
        let date = Date(timeIntervalSince1970: 1_500)
        var summary = dashboardSnapshot(steps: 1_234, lastUpdated: date)
        summary.heart = HeartSummary(
            mostRecentHeartRate: 72,
            restingHeartRate: nil,
            measuredAt: nil
        )
        let cache = InMemoryDashboardCache()
        let repository = DashboardRepository(
            googleHealthClient: StubGoogleHealthClient(response: .success(summary)),
            cache: cache
        )

        let snapshot = try await repository.refreshSummary(
            preserving: .empty(goals: .defaultGoals),
            date: date
        )

        XCTAssertTrue(snapshot.health.heartSeries.isEmpty)
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

    func testCompactDayLabelUsesTodayForCurrentDay() throws {
        let calendar = utcCalendar()
        let now = try date(year: 2026, month: 8, day: 22, hour: 16, calendar: calendar)
        let earlierToday = try date(year: 2026, month: 8, day: 22, hour: 6, calendar: calendar)

        XCTAssertEqual(
            DashboardFormatting.compactDayLabel(for: earlierToday, relativeTo: now, calendar: calendar),
            "Today"
        )
    }

    func testCompactDayLabelUsesMonthDayForPastDay() throws {
        let calendar = utcCalendar()
        let now = try date(year: 2026, month: 8, day: 22, calendar: calendar)
        let pastDay = try date(year: 2026, month: 8, day: 8, calendar: calendar)

        XCTAssertEqual(
            DashboardFormatting.compactDayLabel(for: pastDay, relativeTo: now, calendar: calendar),
            "Aug 8"
        )
    }

    func testCompactDayLabelUsesYesterdayForPreviousDay() throws {
        let calendar = utcCalendar()
        let now = try date(year: 2026, month: 8, day: 22, hour: 16, calendar: calendar)
        let previousDay = try date(year: 2026, month: 8, day: 21, hour: 23, calendar: calendar)

        XCTAssertEqual(
            DashboardFormatting.compactDayLabel(for: previousDay, relativeTo: now, calendar: calendar),
            "Yesterday"
        )
    }

    func testCompactDayLabelIncludesYearWhenNeeded() throws {
        let calendar = utcCalendar()
        let now = try date(year: 2026, month: 1, day: 2, calendar: calendar)
        let previousYear = try date(year: 2025, month: 12, day: 31, calendar: calendar)

        XCTAssertEqual(
            DashboardFormatting.compactDayLabel(for: previousYear, relativeTo: now, calendar: calendar),
            "Dec 31, 2025"
        )
    }

    func testCompactRangeLabelUsesMonthDayRange() throws {
        let calendar = utcCalendar()
        let now = try date(year: 2026, month: 8, day: 22, calendar: calendar)
        let start = try date(year: 2026, month: 8, day: 8, calendar: calendar)
        let end = try date(year: 2026, month: 8, day: 22, calendar: calendar)

        XCTAssertEqual(
            DashboardFormatting.compactRangeLabel(start: start, end: end, relativeTo: now, calendar: calendar),
            "Aug 8 - Today"
        )
    }

    func testCompactRangeLabelHandlesExclusiveMidnightEnd() throws {
        let calendar = utcCalendar()
        let now = try date(year: 2026, month: 8, day: 22, hour: 16, calendar: calendar)
        let start = try date(year: 2026, month: 8, day: 9, calendar: calendar)
        let exclusiveEnd = try date(year: 2026, month: 8, day: 23, calendar: calendar)

        XCTAssertEqual(
            DashboardFormatting.compactRangeLabel(
                start: start,
                end: exclusiveEnd,
                relativeTo: now,
                calendar: calendar,
                treatsEndAsExclusive: true
            ),
            "Aug 9 - Today"
        )
    }

    func testCompactDateTimeRangeLabelUsesInlineDayTimesAcrossDays() throws {
        let calendar = utcCalendar()
        let now = try date(year: 2026, month: 8, day: 22, calendar: calendar)
        let start = try date(year: 2026, month: 8, day: 20, hour: 23, minute: 37, calendar: calendar)
        let end = try date(year: 2026, month: 8, day: 21, hour: 7, minute: 31, calendar: calendar)

        XCTAssertEqual(
            DashboardFormatting.compactDateTimeRangeLabel(
                start: start,
                end: end,
                relativeTo: now,
                calendar: calendar
            ),
            "Aug 20, 11:37 PM - Yesterday, 7:31 AM"
        )
    }

    func testCompactDateTimeRangeLabelUsesSingleDayForSameDayRange() throws {
        let calendar = utcCalendar()
        let now = try date(year: 2026, month: 8, day: 22, calendar: calendar)
        let start = try date(year: 2026, month: 8, day: 22, hour: 6, minute: 15, calendar: calendar)
        let end = try date(year: 2026, month: 8, day: 22, hour: 7, minute: 45, calendar: calendar)

        XCTAssertEqual(
            DashboardFormatting.compactDateTimeRangeLabel(
                start: start,
                end: end,
                relativeTo: now,
                calendar: calendar
            ),
            "Today, 6:15 AM - 7:45 AM"
        )
    }

    func testCompactDateTimeRangeLabelOmitsMissingEndpointPlaceholders() throws {
        let calendar = utcCalendar()
        let now = try date(year: 2026, month: 8, day: 22, calendar: calendar)
        let end = try date(year: 2026, month: 8, day: 22, hour: 7, minute: 31, calendar: calendar)

        XCTAssertEqual(
            DashboardFormatting.compactDateTimeRangeLabel(
                start: nil,
                end: end,
                relativeTo: now,
                calendar: calendar
            ),
            "Ends Today, 7:31 AM"
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

private actor SectionedGoogleHealthClient: GoogleHealthServing {
    private let summary: DashboardSnapshot
    private(set) var activityFetchCount = 0
    private(set) var workoutFetchCount = 0

    init(summary: DashboardSnapshot) {
        self.summary = summary
    }

    func fetchDashboard(goals: ActivityGoals, date: Date) async throws -> DashboardSnapshot {
        summary
    }

    func fetchActivityData(date: Date) async throws -> ActivityDashboardData {
        activityFetchCount += 1
        let point = NumericMetricPoint(
            id: "steps",
            startDate: Date(timeIntervalSince1970: 1_000),
            value: 1_234,
            unit: "steps"
        )
        return ActivityDashboardData(
            dailySeries: [NumericMetricSeries(type: .steps, points: [point])],
            hourlySeries: [],
            bucketedSeries: [],
            loadedAt: Date(timeIntervalSince1970: 1_000)
        )
    }

    func fetchWorkoutData(date: Date) async throws -> [WorkoutDetail] {
        workoutFetchCount += 1
        let startTime = summary.latestWorkout?.startTime ?? Date(timeIntervalSince1970: 900)
        return [
            WorkoutDetail(
                id: "detailed-workout",
                type: summary.latestWorkout?.type ?? "Walk",
                startTime: startTime,
                endTime: startTime.addingTimeInterval(1_200),
                activeDurationSeconds: 1_200,
                metricsSummary: WorkoutMetricsSummary(
                    caloriesKcal: 154,
                    distanceMeters: 1_140,
                    steps: 1_512,
                    elevationGainMeters: nil,
                    averageHeartRate: 122,
                    maxHeartRate: nil,
                    averageSpeedMetersPerSecond: nil,
                    averagePaceSecondsPerKilometer: nil
                ),
                splits: [],
                zoneMinutes: []
            )
        ]
    }
}

@MainActor
private final class InMemoryDashboardCache: DashboardCaching {
    var snapshot: DashboardSnapshot?
    var fitnessSnapshot: FitnessDataSnapshot?
    var preferences: DashboardPreferences = .defaults

    func loadDashboard() -> DashboardSnapshot? {
        fitnessSnapshot?.summary ?? snapshot
    }

    func saveDashboard(_ snapshot: DashboardSnapshot) {
        self.snapshot = snapshot
        fitnessSnapshot = FitnessDataSnapshot.fromLegacyDashboard(snapshot)
    }

    func loadSummary() -> DashboardSnapshot? {
        fitnessSnapshot?.summary ?? snapshot
    }

    func saveSummary(_ snapshot: DashboardSnapshot) {
        self.snapshot = snapshot
        if fitnessSnapshot == nil {
            fitnessSnapshot = FitnessDataSnapshot.fromLegacyDashboard(snapshot)
        } else {
            fitnessSnapshot?.summary = snapshot
        }
    }

    func loadActivityData() -> ActivityDashboardData? {
        fitnessSnapshot?.activity
    }

    func saveActivityData(_ data: ActivityDashboardData) {
        var snapshot = loadFitnessData() ?? .empty(goals: preferences.goals)
        snapshot.activity = data
        saveFitnessData(snapshot)
    }

    func loadWorkouts() -> (workouts: [WorkoutDetail], loadedAt: Date?)? {
        guard let snapshot = loadFitnessData() else { return nil }
        return (snapshot.workouts, snapshot.workoutsLoadedAt)
    }

    func saveWorkouts(_ workouts: [WorkoutDetail], loadedAt: Date?) {
        var snapshot = loadFitnessData() ?? .empty(goals: preferences.goals)
        snapshot.workouts = workouts
        snapshot.workoutsLoadedAt = loadedAt
        saveFitnessData(snapshot)
    }

    func loadHealthData() -> HealthDashboardData? {
        fitnessSnapshot?.health
    }

    func saveHealthData(_ data: HealthDashboardData) {
        var snapshot = loadFitnessData() ?? .empty(goals: preferences.goals)
        snapshot.health = data
        saveFitnessData(snapshot)
    }

    func loadFitnessData() -> FitnessDataSnapshot? {
        fitnessSnapshot ?? snapshot.map(FitnessDataSnapshot.fromLegacyDashboard)
    }

    func saveFitnessData(_ snapshot: FitnessDataSnapshot) {
        fitnessSnapshot = snapshot
        self.snapshot = snapshot.summary
    }

    func clearHealthData() {
        fitnessSnapshot = nil
        snapshot = nil
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

private func cachedActivityData(loadedAt: Date) -> ActivityDashboardData {
    ActivityDashboardData(
        dailySeries: [
            NumericMetricSeries(
                type: .steps,
                points: [
                    NumericMetricPoint(
                        id: "cached-steps-\(loadedAt.timeIntervalSince1970)",
                        startDate: loadedAt,
                        value: 2_468,
                        unit: "steps"
                    )
                ],
                rangeStart: loadedAt.addingTimeInterval(-86_400),
                rangeEnd: loadedAt
            )
        ],
        hourlySeries: [
            NumericMetricSeries(
                type: .distance,
                points: [
                    NumericMetricPoint(
                        id: "cached-distance-\(loadedAt.timeIntervalSince1970)",
                        startDate: loadedAt,
                        value: 1_851,
                        unit: "m"
                    )
                ],
                rangeStart: loadedAt.addingTimeInterval(-3_600),
                rangeEnd: loadedAt
            )
        ],
        bucketedSeries: [
            BucketedMetricSeries(
                type: .activeMinutes,
                title: "Activity Intensity",
                buckets: [
                    MetricBucket(label: "Light", value: 30, unit: "min")
                ],
                rangeStart: loadedAt.addingTimeInterval(-86_400),
                rangeEnd: loadedAt
            )
        ],
        loadedAt: loadedAt
    )
}

private func workoutDetail(startTime: Date) -> WorkoutDetail {
    WorkoutDetail(
        id: "workout-\(startTime.timeIntervalSince1970)",
        type: "Walk",
        startTime: startTime,
        endTime: startTime.addingTimeInterval(1_200),
        activeDurationSeconds: 1_200,
        metricsSummary: WorkoutMetricsSummary(
            caloriesKcal: 154,
            distanceMeters: 1_140,
            steps: 1_512,
            elevationGainMeters: nil,
            averageHeartRate: 122,
            maxHeartRate: nil,
            averageSpeedMetersPerSecond: nil,
            averagePaceSecondsPerKilometer: nil
        ),
        splits: [],
        zoneMinutes: []
    )
}

private func cachedHealthData(loadedAt: Date) -> HealthDashboardData {
    let point = NumericMetricPoint(
        id: "heart-\(loadedAt.timeIntervalSince1970)",
        startDate: loadedAt,
        value: 72,
        unit: "bpm"
    )

    return HealthDashboardData(
        heartSeries: [NumericMetricSeries(type: .heartRate, points: [point])],
        sleepMetricSeries: [],
        vitalSeries: [],
        cardioFitnessSeries: [],
        bodySeries: [],
        sleepSessions: [
            SleepSession(
                id: "sleep-\(loadedAt.timeIntervalSince1970)",
                startTime: loadedAt.addingTimeInterval(-28_800),
                endTime: loadedAt.addingTimeInterval(-3_600),
                durationSeconds: 25_200,
                stages: []
            )
        ],
        loadedAt: loadedAt
    )
}

@MainActor
private func makeInMemoryModelContext() throws -> ModelContext {
    let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try ModelContainer(
        for: CachedDashboardSnapshot.self,
        CachedDashboardSection.self,
        CachedPreferences.self,
        configurations: configuration
    )

    return ModelContext(container)
}

private func encodeLegacyFitnessSnapshot(_ snapshot: FitnessDataSnapshot) throws -> Data {
    let encoder = JSONEncoder()
    encoder.dateEncodingStrategy = .iso8601
    return try encoder.encode(FitnessDataSnapshot.CodableSnapshot(snapshot))
}

private func activityGoalInsight(
    title: String,
    value: Double,
    goal: Double,
    displayUnit: String,
    dataType: GoogleHealthDataType,
    systemImage: String,
    accentColor: Color,
    isAvailable: Bool = true
) -> ActivityGoalInsight {
    ActivityGoalInsight(
        title: title,
        metric: RingMetric(title: title, value: value, goal: goal, unit: displayUnit),
        displayUnit: displayUnit,
        dataType: dataType,
        systemImage: systemImage,
        accentColor: accentColor,
        isAvailable: isAvailable
    )
}

private func utcCalendar() -> Calendar {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(secondsFromGMT: 0)!
    return calendar
}

private func date(
    year: Int,
    month: Int,
    day: Int,
    hour: Int = 0,
    minute: Int = 0,
    calendar: Calendar
) throws -> Date {
    let components = DateComponents(
        calendar: calendar,
        timeZone: calendar.timeZone,
        year: year,
        month: month,
        day: day,
        hour: hour,
        minute: minute
    )
    return try XCTUnwrap(components.date)
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
