import Foundation

protocol DashboardServing {
    func fetchDashboard(goals: ActivityGoals, date: Date) async throws -> DashboardSnapshot
}

@MainActor
struct DashboardRepository {
    private let googleHealthClient: GoogleHealthServing
    private let cache: DashboardCaching

    init(googleHealthClient: GoogleHealthServing, cache: DashboardCaching) {
        self.googleHealthClient = googleHealthClient
        self.cache = cache
    }

    func cachedSnapshot() -> DashboardSnapshot? {
        cachedFitnessData()?.summary
            ?? cache.loadDashboard()
    }

    func cachedFitnessData() -> FitnessDataSnapshot? {
        cache.loadFitnessData()
    }

    func preferences() -> DashboardPreferences {
        cache.loadPreferences()
    }

    func savePreferences(_ preferences: DashboardPreferences) {
        cache.savePreferences(preferences)
    }

    func refresh(date: Date = .now) async throws -> DashboardSnapshot {
        let preferences = cache.loadPreferences()
        let snapshot = try await googleHealthClient.fetchDashboard(
            goals: preferences.goals,
            date: date
        )
        cache.saveDashboard(snapshot)
        return snapshot
    }

    func refreshSummary(
        preserving cachedSnapshot: FitnessDataSnapshot? = nil,
        date: Date = .now
    ) async throws -> FitnessDataSnapshot {
        let preferences = cache.loadPreferences()
        let summary = try await googleHealthClient.fetchDashboard(
            goals: preferences.goals,
            date: date
        )

        var snapshot = cachedSnapshot ?? cache.loadFitnessData() ?? .empty(goals: preferences.goals)
        snapshot.summary = summary
        if let latestWorkout = summary.latestWorkout,
           !snapshot.workouts.contains(where: { $0.startTime == latestWorkout.startTime }) {
            snapshot.workouts.insert(WorkoutDetail(summary: latestWorkout), at: 0)
        }
        if let sleep = summary.sleep,
           !snapshot.health.sleepSessions.contains(where: { $0.startTime == sleep.startTime && $0.endTime == sleep.endTime }) {
            snapshot.health.sleepSessions.insert(
                SleepSession(
                    id: sleep.startTime?.timeIntervalSince1970.description ?? "summary-sleep",
                    startTime: sleep.startTime,
                    endTime: sleep.endTime,
                    durationSeconds: sleep.durationSeconds,
                    stages: []
                ),
                at: 0
            )
        }
        if let heartRate = summary.heart.mostRecentHeartRate,
           let measuredAt = summary.heart.measuredAt {
            snapshot.health.mergeEarlier(
                NumericMetricSeries(
                    type: .heartRate,
                    points: [
                        NumericMetricPoint(
                            id: "summary-heart-rate-\(measuredAt.timeIntervalSince1970)",
                            startDate: measuredAt,
                            value: Double(heartRate),
                            unit: GoogleHealthDataType.heartRate.unit
                        )
                    ],
                    rangeStart: measuredAt,
                    rangeEnd: measuredAt
                )
            )
        }
        snapshot.lastUpdated = summary.lastUpdated
        cache.saveFitnessData(snapshot)
        return snapshot
    }

    func refreshActivity(
        preserving cachedSnapshot: FitnessDataSnapshot,
        date: Date = .now
    ) async throws -> FitnessDataSnapshot {
        var snapshot = cachedSnapshot
        snapshot.activity = try await googleHealthClient.fetchActivityData(date: date)
        snapshot.lastUpdated = .now
        cache.saveActivityData(snapshot.activity)
        return snapshot
    }

    func refreshWorkouts(
        preserving cachedSnapshot: FitnessDataSnapshot,
        date: Date = .now
    ) async throws -> FitnessDataSnapshot {
        var snapshot = cachedSnapshot
        let loadedAt = Date.now
        snapshot.workouts = try await googleHealthClient.fetchWorkoutData(date: date)
        snapshot.workoutsLoadedAt = loadedAt
        snapshot.lastUpdated = loadedAt
        cache.saveWorkouts(snapshot.workouts, loadedAt: loadedAt)
        return snapshot
    }

    func refreshHealth(
        preserving cachedSnapshot: FitnessDataSnapshot,
        date: Date = .now
    ) async throws -> FitnessDataSnapshot {
        var snapshot = cachedSnapshot
        snapshot.health = try await googleHealthClient.fetchHealthData(date: date)
        snapshot.lastUpdated = .now
        cache.saveHealthData(snapshot.health)
        return snapshot
    }

    func loadEarlierMetric(
        _ type: GoogleHealthDataType,
        preserving cachedSnapshot: FitnessDataSnapshot,
        before: Date
    ) async throws -> FitnessDataSnapshot {
        let earlier = try await googleHealthClient.fetchEarlierMetricSeries(type, before: before)
        var snapshot = cachedSnapshot

        switch type.category {
        case .activity:
            snapshot.activity.mergeEarlier(earlier)
        case .heart, .sleep, .vitals, .cardioFitness, .body:
            snapshot.health.mergeEarlier(earlier)
        case .workout:
            break
        }

        snapshot.lastUpdated = .now
        switch type.category {
        case .activity:
            cache.saveActivityData(snapshot.activity)
        case .heart, .sleep, .vitals, .cardioFitness, .body:
            cache.saveHealthData(snapshot.health)
        case .workout:
            break
        }
        return snapshot
    }

    func refreshMetricChart(
        _ type: GoogleHealthDataType,
        range: MetricChartRange,
        preserving cachedSnapshot: FitnessDataSnapshot,
        date: Date = .now
    ) async throws -> FitnessDataSnapshot {
        let chartSeries = try await googleHealthClient.fetchMetricChartSeries(
            type,
            range: range,
            anchorDate: date
        )
        var snapshot = cachedSnapshot
        snapshot.activity.upsertChartSeries(chartSeries)
        snapshot.lastUpdated = .now
        cache.saveActivityData(snapshot.activity)
        return snapshot
    }

    func clearHealthData() {
        cache.clearHealthData()
    }
}

struct DashboardPreferences: Equatable, Sendable {
    var goals: ActivityGoals
    var units: UnitPreferences

    static let defaults = DashboardPreferences(goals: .defaultGoals, units: .defaults)
}
