import Foundation
import SwiftData

@MainActor
final class SwiftDataDashboardCache: DashboardCaching {
    private let modelContext: ModelContext
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
        encoder.dateEncodingStrategy = .iso8601
        decoder.dateDecodingStrategy = .iso8601
    }

    func loadDashboard() -> DashboardSnapshot? {
        let descriptor = FetchDescriptor<CachedDashboardSnapshot>(
            predicate: #Predicate { $0.id == "current" }
        )

        guard let cached = try? modelContext.fetch(descriptor).first else {
            return nil
        }

        return try? decoder.decode(DashboardSnapshot.CodableSnapshot.self, from: cached.data).domainValue
    }

    func saveDashboard(_ snapshot: DashboardSnapshot) {
        let descriptor = FetchDescriptor<CachedDashboardSnapshot>(
            predicate: #Predicate { $0.id == "current" }
        )

        guard let data = try? encoder.encode(DashboardSnapshot.CodableSnapshot(snapshot)) else {
            return
        }

        if let cached = try? modelContext.fetch(descriptor).first {
            cached.data = data
            cached.updatedAt = snapshot.lastUpdated
        } else {
            modelContext.insert(CachedDashboardSnapshot(data: data, updatedAt: snapshot.lastUpdated))
        }

        try? modelContext.save()
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

        init(_ summary: ActivitySummary) {
            steps = summary.steps
            distanceMeters = summary.distanceMeters
            activeCalories = summary.activeCalories
            totalCalories = summary.totalCalories
        }

        var domainValue: ActivitySummary {
            ActivitySummary(
                steps: steps,
                distanceMeters: distanceMeters,
                activeCalories: activeCalories,
                totalCalories: totalCalories
            )
        }
    }

    struct CodableWorkoutSummary: Codable {
        var type: String
        var startTime: Date
        var durationSeconds: TimeInterval
        var distanceMeters: Double?
        var calories: Double?

        init(_ workout: WorkoutSummary) {
            type = workout.type
            startTime = workout.startTime
            durationSeconds = workout.durationSeconds
            distanceMeters = workout.distanceMeters
            calories = workout.calories
        }

        var domainValue: WorkoutSummary {
            WorkoutSummary(
                type: type,
                startTime: startTime,
                durationSeconds: durationSeconds,
                distanceMeters: distanceMeters,
                calories: calories
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
