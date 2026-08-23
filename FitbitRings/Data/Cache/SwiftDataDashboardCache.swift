import Foundation
import SwiftData

@MainActor
final class SwiftDataDashboardCache: DashboardCaching {
    private let modelContext: ModelContext
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    private var legacyFallbackSnapshot: FitnessDataSnapshot?

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
        encoder.dateEncodingStrategy = .iso8601
        decoder.dateDecodingStrategy = .iso8601
    }

    func loadDashboard() -> DashboardSnapshot? {
        loadSummary()
    }

    func saveDashboard(_ snapshot: DashboardSnapshot) {
        saveFitnessData(FitnessDataSnapshot.fromLegacyDashboard(snapshot))
    }

    func loadSummary() -> DashboardSnapshot? {
        loadSectionSummary() ?? loadLegacyDashboard()
    }

    func saveSummary(_ snapshot: DashboardSnapshot) {
        guard let data = try? encoder.encode(DashboardSnapshot.CodableSnapshot(snapshot)) else {
            return
        }

        saveSection(.summary, data: data, updatedAt: snapshot.lastUpdated)
        try? modelContext.save()
    }

    func loadActivityData() -> ActivityDashboardData? {
        guard let data = loadSectionData(.activity) else {
            return loadLegacySectionIfNeeded()?.activity
        }

        return try? decoder.decode(ActivityDashboardData.self, from: data)
    }

    func saveActivityData(_ data: ActivityDashboardData) {
        guard let encoded = try? encoder.encode(data) else {
            return
        }

        saveSection(.activity, data: encoded, updatedAt: data.loadedAt ?? .now)
        try? modelContext.save()
    }

    func loadWorkouts() -> (workouts: [WorkoutDetail], loadedAt: Date?)? {
        guard let data = loadSectionData(.workouts) else {
            guard let legacy = loadLegacySectionIfNeeded() else {
                return nil
            }

            return (legacy.workouts, legacy.workoutsLoadedAt)
        }

        guard let section = try? decoder.decode(CachedWorkoutsSection.self, from: data) else {
            return nil
        }

        return (section.workouts, section.loadedAt)
    }

    func saveWorkouts(_ workouts: [WorkoutDetail], loadedAt: Date?) {
        let section = CachedWorkoutsSection(workouts: workouts, loadedAt: loadedAt)
        guard let data = try? encoder.encode(section) else {
            return
        }

        saveSection(.workouts, data: data, updatedAt: loadedAt ?? .now)
        try? modelContext.save()
    }

    func loadHealthData() -> HealthDashboardData? {
        guard let data = loadSectionData(.health) else {
            return loadLegacySectionIfNeeded()?.health
        }

        return try? decoder.decode(HealthDashboardData.self, from: data)
    }

    func saveHealthData(_ data: HealthDashboardData) {
        guard let encoded = try? encoder.encode(data) else {
            return
        }

        saveSection(.health, data: encoded, updatedAt: data.loadedAt ?? .now)
        try? modelContext.save()
    }

    func loadFitnessData() -> FitnessDataSnapshot? {
        guard let summary = loadSectionSummary() else {
            return loadLegacyFitnessData()
        }

        var snapshot = FitnessDataSnapshot.fromLegacyDashboard(summary)

        if let activity = loadActivityData() {
            snapshot.activity = activity
        }

        if let workouts = loadWorkouts() {
            snapshot.workouts = workouts.workouts
            snapshot.workoutsLoadedAt = workouts.loadedAt
        }

        if let health = loadHealthData() {
            snapshot.health = health
        }

        snapshot.lastUpdated = [
            snapshot.summary.lastUpdated,
            snapshot.activity.loadedAt,
            snapshot.workoutsLoadedAt,
            snapshot.health.loadedAt
        ]
        .compactMap { $0 }
        .max() ?? snapshot.summary.lastUpdated

        return snapshot
    }

    func saveFitnessData(_ snapshot: FitnessDataSnapshot) {
        guard
            let summary = try? encoder.encode(DashboardSnapshot.CodableSnapshot(snapshot.summary)),
            let activity = try? encoder.encode(snapshot.activity),
            let workouts = try? encoder.encode(
                CachedWorkoutsSection(
                    workouts: snapshot.workouts,
                    loadedAt: snapshot.workoutsLoadedAt
                )
            ),
            let health = try? encoder.encode(snapshot.health)
        else {
            return
        }

        saveSection(.summary, data: summary, updatedAt: snapshot.summary.lastUpdated)
        saveSection(.activity, data: activity, updatedAt: snapshot.activity.loadedAt ?? snapshot.lastUpdated)
        saveSection(.workouts, data: workouts, updatedAt: snapshot.workoutsLoadedAt ?? snapshot.lastUpdated)
        saveSection(.health, data: health, updatedAt: snapshot.health.loadedAt ?? snapshot.lastUpdated)

        try? modelContext.save()
        legacyFallbackSnapshot = nil
    }

    func clearHealthData() {
        let legacyDescriptor = FetchDescriptor<CachedDashboardSnapshot>(
            predicate: #Predicate { $0.id == "current" }
        )

        if let cached = try? modelContext.fetch(legacyDescriptor).first {
            modelContext.delete(cached)
        }

        let sectionDescriptor = FetchDescriptor<CachedDashboardSection>()
        if let sections = try? modelContext.fetch(sectionDescriptor) {
            for section in sections {
                modelContext.delete(section)
            }
        }

        try? modelContext.save()
        legacyFallbackSnapshot = nil
    }

    func loadPreferences() -> DashboardPreferences {
        let descriptor = FetchDescriptor<CachedPreferences>(
            predicate: #Predicate { $0.id == "current" }
        )

        guard let cached = try? modelContext.fetch(descriptor).first else {
            return .defaults
        }

        return DashboardPreferences(
            goals: ActivityGoals(
                moveCalories: cached.moveCalories,
                activeMinutes: cached.activeMinutes,
                steps: cached.steps
            ),
            units: UnitPreferences(
                distanceUnit: DistanceUnit(rawValue: cached.distanceUnitRawValue) ?? .kilometers,
                appearance: AppearancePreference(rawValue: cached.appearanceRawValue) ?? .system
            )
        )
    }

    func savePreferences(_ preferences: DashboardPreferences) {
        let descriptor = FetchDescriptor<CachedPreferences>(
            predicate: #Predicate { $0.id == "current" }
        )

        if let cached = try? modelContext.fetch(descriptor).first {
            cached.moveCalories = preferences.goals.moveCalories
            cached.activeMinutes = preferences.goals.activeMinutes
            cached.steps = preferences.goals.steps
            cached.distanceUnitRawValue = preferences.units.distanceUnit.rawValue
            cached.appearanceRawValue = preferences.units.appearance.rawValue
        } else {
            modelContext.insert(
                CachedPreferences(
                    moveCalories: preferences.goals.moveCalories,
                    activeMinutes: preferences.goals.activeMinutes,
                    steps: preferences.goals.steps,
                    distanceUnitRawValue: preferences.units.distanceUnit.rawValue,
                    appearanceRawValue: preferences.units.appearance.rawValue
                )
            )
        }

        try? modelContext.save()
    }

    private func loadLegacyDashboard() -> DashboardSnapshot? {
        loadLegacyFitnessData()?.summary
    }

    private func loadLegacyFitnessData() -> FitnessDataSnapshot? {
        if let legacyFallbackSnapshot {
            return legacyFallbackSnapshot
        }

        let descriptor = FetchDescriptor<CachedDashboardSnapshot>(
            predicate: #Predicate { $0.id == "current" }
        )

        guard let cached = try? modelContext.fetch(descriptor).first else {
            return nil
        }

        if let snapshot = try? decoder.decode(FitnessDataSnapshot.CodableSnapshot.self, from: cached.data).domainValue {
            legacyFallbackSnapshot = snapshot
            return snapshot
        }

        let snapshot = loadLegacyDashboard(from: cached.data).map(FitnessDataSnapshot.fromLegacyDashboard)
        legacyFallbackSnapshot = snapshot
        return snapshot
    }

    private func loadLegacyDashboard(from data: Data) -> DashboardSnapshot? {
        try? decoder.decode(DashboardSnapshot.CodableSnapshot.self, from: data).domainValue
    }

    private func loadSectionSummary() -> DashboardSnapshot? {
        guard let data = loadSectionData(.summary) else {
            return nil
        }

        return try? decoder.decode(DashboardSnapshot.CodableSnapshot.self, from: data).domainValue
    }

    private func loadLegacySectionIfNeeded() -> FitnessDataSnapshot? {
        guard loadSectionData(.summary) == nil else {
            return nil
        }

        return loadLegacyFitnessData()
    }

    private func loadSectionData(_ section: DashboardCacheSection) -> Data? {
        let id = section.rawValue
        let descriptor = FetchDescriptor<CachedDashboardSection>(
            predicate: #Predicate { $0.id == id }
        )

        guard let cached = try? modelContext.fetch(descriptor).first else {
            return nil
        }

        return cached.data
    }

    private func saveSection(_ section: DashboardCacheSection, data: Data, updatedAt: Date) {
        let id = section.rawValue
        let descriptor = FetchDescriptor<CachedDashboardSection>(
            predicate: #Predicate { $0.id == id }
        )

        if let cached = try? modelContext.fetch(descriptor).first {
            cached.data = data
            cached.updatedAt = updatedAt
        } else {
            modelContext.insert(CachedDashboardSection(id: id, data: data, updatedAt: updatedAt))
        }
    }
}

private enum DashboardCacheSection: String {
    case summary
    case activity
    case workouts
    case health
}

private struct CachedWorkoutsSection: Codable {
    var workouts: [WorkoutDetail]
    var loadedAt: Date?
}

extension DashboardSnapshot {
    struct CodableSnapshot: Codable {
        var date: Date
        var rings: CodableRingSet
        var activity: CodableActivitySummary
        var latestWorkout: CodableWorkoutSummary?
        var heart: CodableHeartSummary
        var sleep: CodableSleepSummary?
        var lastUpdated: Date
        var syncState: SyncState

        init(_ snapshot: DashboardSnapshot) {
            date = snapshot.date
            rings = CodableRingSet(snapshot.rings)
            activity = CodableActivitySummary(snapshot.activity)
            latestWorkout = snapshot.latestWorkout.map(CodableWorkoutSummary.init)
            heart = CodableHeartSummary(snapshot.heart)
            sleep = snapshot.sleep.map(CodableSleepSummary.init)
            lastUpdated = snapshot.lastUpdated
            syncState = snapshot.syncState
        }

        var domainValue: DashboardSnapshot {
            DashboardSnapshot(
                date: date,
                rings: rings.domainValue,
                activity: activity.domainValue,
                latestWorkout: latestWorkout?.domainValue,
                heart: heart.domainValue,
                sleep: sleep?.domainValue,
                lastUpdated: lastUpdated,
                syncState: syncState
            )
        }
    }

    struct CodableRingSet: Codable {
        var move: CodableRingMetric
        var active: CodableRingMetric
        var steps: CodableRingMetric

        init(_ rings: RingSet) {
            move = CodableRingMetric(rings.move)
            active = CodableRingMetric(rings.active)
            steps = CodableRingMetric(rings.steps)
        }

        var domainValue: RingSet {
            RingSet(move: move.domainValue, active: active.domainValue, steps: steps.domainValue)
        }
    }

    struct CodableRingMetric: Codable {
        var title: String
        var value: Double
        var goal: Double
        var unit: String

        init(_ metric: RingMetric) {
            title = metric.title
            value = metric.value
            goal = metric.goal
            unit = metric.unit
        }

        var domainValue: RingMetric {
            RingMetric(title: title, value: value, goal: goal, unit: unit)
        }
    }

    struct CodableActivitySummary: Codable {
        var steps: Int
        var distanceMeters: Double
        var activeCalories: Double
        var totalCalories: Double
        var providedMetrics: Set<GoogleHealthDataType>

        init(_ summary: ActivitySummary) {
            steps = summary.steps
            distanceMeters = summary.distanceMeters
            activeCalories = summary.activeCalories
            totalCalories = summary.totalCalories
            providedMetrics = summary.providedMetrics
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            steps = try container.decode(Int.self, forKey: .steps)
            distanceMeters = try container.decode(Double.self, forKey: .distanceMeters)
            activeCalories = try container.decode(Double.self, forKey: .activeCalories)
            totalCalories = try container.decode(Double.self, forKey: .totalCalories)
            providedMetrics = try container.decodeIfPresent(
                Set<GoogleHealthDataType>.self,
                forKey: .providedMetrics
            ) ?? [
                .steps,
                .distance,
                .activeEnergyBurned,
                .totalCalories
            ]
        }

        var domainValue: ActivitySummary {
            ActivitySummary(
                steps: steps,
                distanceMeters: distanceMeters,
                activeCalories: activeCalories,
                totalCalories: totalCalories,
                providedMetrics: providedMetrics
            )
        }
    }

    struct CodableWorkoutSummary: Codable {
        var type: String
        var startTime: Date
        var durationSeconds: TimeInterval
        var distanceMeters: Double?
        var calories: Double?
        var averageHeartRate: Double?

        init(_ workout: WorkoutSummary) {
            type = workout.type
            startTime = workout.startTime
            durationSeconds = workout.durationSeconds
            distanceMeters = workout.distanceMeters
            calories = workout.calories
            averageHeartRate = workout.averageHeartRate
        }

        var domainValue: WorkoutSummary {
            WorkoutSummary(
                type: type,
                startTime: startTime,
                durationSeconds: durationSeconds,
                distanceMeters: distanceMeters,
                calories: calories,
                averageHeartRate: averageHeartRate
            )
        }
    }

    struct CodableHeartSummary: Codable {
        var mostRecentHeartRate: Int?
        var restingHeartRate: Int?
        var measuredAt: Date?

        init(_ heart: HeartSummary) {
            mostRecentHeartRate = heart.mostRecentHeartRate
            restingHeartRate = heart.restingHeartRate
            measuredAt = heart.measuredAt
        }

        var domainValue: HeartSummary {
            HeartSummary(
                mostRecentHeartRate: mostRecentHeartRate,
                restingHeartRate: restingHeartRate,
                measuredAt: measuredAt
            )
        }
    }

    struct CodableSleepSummary: Codable {
        var durationSeconds: TimeInterval
        var startTime: Date?
        var endTime: Date?

        init(_ sleep: SleepSummary) {
            durationSeconds = sleep.durationSeconds
            startTime = sleep.startTime
            endTime = sleep.endTime
        }

        var domainValue: SleepSummary {
            SleepSummary(durationSeconds: durationSeconds, startTime: startTime, endTime: endTime)
        }
    }
}
