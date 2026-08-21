import Foundation

struct DashboardSnapshot: Equatable, Sendable {
    var date: Date
    var rings: RingSet
    var activity: ActivitySummary
    var latestWorkout: WorkoutSummary?
    var heart: HeartSummary
    var sleep: SleepSummary?
    var lastUpdated: Date
    var syncState: SyncState

    static func empty(goals: ActivityGoals = .defaultGoals) -> DashboardSnapshot {
        DashboardSnapshot(
            date: .now,
            rings: RingSet(
                move: RingMetric(title: "Move", value: 0, goal: Double(goals.moveCalories), unit: "kcal"),
                active: RingMetric(title: "Active", value: 0, goal: Double(goals.activeMinutes), unit: "min"),
                steps: RingMetric(title: "Steps", value: 0, goal: Double(goals.steps), unit: "")
            ),
            activity: ActivitySummary(steps: 0, distanceMeters: 0, activeCalories: 0, totalCalories: 0),
            latestWorkout: nil,
            heart: HeartSummary(mostRecentHeartRate: nil, restingHeartRate: nil, measuredAt: nil),
            sleep: nil,
            lastUpdated: .distantPast,
            syncState: .idle
        )
    }
}

struct RingSet: Equatable, Sendable {
    var move: RingMetric
    var active: RingMetric
    var steps: RingMetric
}

struct RingMetric: Identifiable, Equatable, Sendable {
    var id: String { title }
    var title: String
    var value: Double
    var goal: Double
    var unit: String

    var progress: Double {
        guard goal > 0 else { return 0 }
        return max(0, value / goal)
    }

    var cappedProgress: Double {
        min(progress, 1)
    }
}

struct ActivitySummary: Equatable, Sendable {
    var steps: Int
    var distanceMeters: Double
    var activeCalories: Double
    var totalCalories: Double
    var providedMetrics: Set<GoogleHealthDataType> = []

    func hasData(for type: GoogleHealthDataType) -> Bool {
        providedMetrics.contains(type)
    }
}

struct WorkoutSummary: Equatable, Sendable {
    var type: String
    var startTime: Date
    var durationSeconds: TimeInterval
    var distanceMeters: Double?
    var calories: Double?
}

struct HeartSummary: Equatable, Sendable {
    var mostRecentHeartRate: Int?
    var restingHeartRate: Int?
    var measuredAt: Date?
}

struct SleepSummary: Equatable, Sendable {
    var durationSeconds: TimeInterval
    var startTime: Date?
    var endTime: Date?
}

struct ActivityGoals: Equatable, Sendable {
    var moveCalories: Int
    var activeMinutes: Int
    var steps: Int

    static let defaultGoals = ActivityGoals(moveCalories: 500, activeMinutes: 30, steps: 10_000)
}

struct UnitPreferences: Equatable, Sendable {
    var distanceUnit: DistanceUnit
    var appearance: AppearancePreference

    static let defaults = UnitPreferences(distanceUnit: .kilometers, appearance: .system)
}

enum DistanceUnit: String, CaseIterable, Codable, Sendable {
    case kilometers
    case miles
}

enum AppearancePreference: String, CaseIterable, Codable, Sendable {
    case system
    case light
    case dark
}

enum SyncState: String, Codable, Equatable, Sendable {
    case idle
    case refreshing
    case failed
}
