import Foundation

enum FitnessDashboardTab: String, CaseIterable, Codable, Identifiable, Sendable {
    case summary
    case activity
    case workouts
    case health

    var id: String { rawValue }

    var title: String {
        switch self {
        case .summary:
            return "Summary"
        case .activity:
            return "Activity"
        case .workouts:
            return "Workouts"
        case .health:
            return "Health"
        }
    }

    var symbolName: String {
        switch self {
        case .summary:
            return "circle.grid.cross"
        case .activity:
            return "figure.run.circle.fill"
        case .workouts:
            return "dumbbell.fill"
        case .health:
            return "heart.text.square.fill"
        }
    }

    var section: FitnessDashboardSection {
        switch self {
        case .summary:
            return .summary
        case .activity:
            return .activity
        case .workouts:
            return .workouts
        case .health:
            return .health
        }
    }
}

enum FitnessDashboardSection: String, CaseIterable, Codable, Hashable, Sendable {
    case summary
    case activity
    case workouts
    case health
}

struct DashboardRoute: Hashable, Codable, Sendable {
    enum Kind: String, Codable, Sendable {
        case metric
        case workout
        case sleep
    }

    var kind: Kind
    var identifier: String
    var dataType: GoogleHealthDataType?

    static func metric(_ type: GoogleHealthDataType) -> DashboardRoute {
        DashboardRoute(kind: .metric, identifier: type.rawValue, dataType: type)
    }

    static func workout(_ id: String) -> DashboardRoute {
        DashboardRoute(kind: .workout, identifier: id, dataType: nil)
    }

    static func sleep(_ id: String) -> DashboardRoute {
        DashboardRoute(kind: .sleep, identifier: id, dataType: .sleep)
    }
}

enum FitnessLoadingPhase: String, Codable, Sendable {
    case idle
    case loading
    case loaded
    case failed
}

struct FitnessSectionState: Codable, Equatable, Sendable {
    var phase: FitnessLoadingPhase
    var lastUpdated: Date
    var errorMessage: String?

    static let idle = FitnessSectionState(
        phase: .idle,
        lastUpdated: .distantPast,
        errorMessage: nil
    )

    var isLoaded: Bool {
        phase == .loaded || lastUpdated > .distantPast
    }
}

enum MetricAvailability<Value: Equatable & Sendable>: Equatable, Sendable {
    case unavailable
    case value(Value)

    var value: Value? {
        switch self {
        case .unavailable:
            return nil
        case .value(let value):
            return value
        }
    }

    var isAvailable: Bool {
        value != nil
    }
}

extension MetricAvailability: Codable where Value: Codable {
    private enum CodingKeys: String, CodingKey {
        case available
        case value
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let available = try container.decode(Bool.self, forKey: .available)
        guard available else {
            self = .unavailable
            return
        }
        self = .value(try container.decode(Value.self, forKey: .value))
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .unavailable:
            try container.encode(false, forKey: .available)
        case .value(let value):
            try container.encode(true, forKey: .available)
            try container.encode(value, forKey: .value)
        }
    }
}

struct NumericMetricPoint: Codable, Hashable, Identifiable, Sendable {
    var id: String
    var startDate: Date
    var endDate: Date?
    var value: Double
    var unit: String

    init(
        id: String,
        startDate: Date,
        endDate: Date? = nil,
        value: Double,
        unit: String
    ) {
        self.id = id
        self.startDate = startDate
        self.endDate = endDate
        self.value = value
        self.unit = unit
    }
}

struct NumericMetricSeries: Codable, Hashable, Identifiable, Sendable {
    var id: String { type.rawValue }
    var type: GoogleHealthDataType
    var title: String
    var unit: String
    var points: [NumericMetricPoint]
    var rangeStart: Date?
    var rangeEnd: Date?
    var nextPageToken: String?

    init(
        type: GoogleHealthDataType,
        title: String? = nil,
        unit: String? = nil,
        points: [NumericMetricPoint] = [],
        rangeStart: Date? = nil,
        rangeEnd: Date? = nil,
        nextPageToken: String? = nil
    ) {
        self.type = type
        self.title = title ?? type.displayName
        self.unit = unit ?? type.unit
        self.points = points.sorted { $0.startDate < $1.startDate }
        self.rangeStart = rangeStart
        self.rangeEnd = rangeEnd
        self.nextPageToken = nextPageToken
    }

    var latestPoint: NumericMetricPoint? {
        points.max { $0.startDate < $1.startDate }
    }

    var latestValue: MetricAvailability<Double> {
        guard let latestPoint else { return .unavailable }
        return .value(latestPoint.value)
    }

    func mergingEarlier(_ earlier: NumericMetricSeries) -> NumericMetricSeries {
        var keyedPoints = Dictionary(uniqueKeysWithValues: points.map { ($0.id, $0) })
        for point in earlier.points {
            keyedPoints[point.id] = point
        }
        return NumericMetricSeries(
            type: type,
            title: title,
            unit: unit,
            points: Array(keyedPoints.values),
            rangeStart: [rangeStart, earlier.rangeStart].compactMap { $0 }.min(),
            rangeEnd: [rangeEnd, earlier.rangeEnd].compactMap { $0 }.max(),
            nextPageToken: earlier.nextPageToken ?? nextPageToken
        )
    }
}

struct MetricBucket: Codable, Hashable, Identifiable, Sendable {
    var id: String { label }
    var label: String
    var value: Double
    var unit: String
}

struct BucketedMetricSeries: Codable, Hashable, Identifiable, Sendable {
    var id: String { type.rawValue }
    var type: GoogleHealthDataType
    var title: String
    var buckets: [MetricBucket]
    var rangeStart: Date?
    var rangeEnd: Date?

    var displayTitle: String {
        type == .activeMinutes ? "Activity Intensity" : title
    }

    var displayBuckets: [MetricBucket] {
        let aggregated = aggregateBuckets(buckets)
        guard type == .activeMinutes else {
            return aggregated
        }
        return orderedBuckets(aggregated, labels: ["Light", "Moderate", "Vigorous"])
    }
}

struct ActivityDashboardData: Codable, Equatable, Sendable {
    var dailySeries: [NumericMetricSeries]
    var hourlySeries: [NumericMetricSeries]
    var bucketedSeries: [BucketedMetricSeries]
    var loadedAt: Date?

    static let empty = ActivityDashboardData(
        dailySeries: [],
        hourlySeries: [],
        bucketedSeries: [],
        loadedAt: nil
    )

    func series(for type: GoogleHealthDataType) -> NumericMetricSeries? {
        dailySeries(for: type) ?? hourlySeries(for: type)
    }

    func dailySeries(for type: GoogleHealthDataType) -> NumericMetricSeries? {
        dailySeries.first { $0.type == type }
    }

    func hourlySeries(for type: GoogleHealthDataType) -> NumericMetricSeries? {
        hourlySeries.first { $0.type == type }
    }

    var isEmpty: Bool {
        !dailySeries.containsVisiblePoints
            && !hourlySeries.containsVisiblePoints
            && bucketedSeries.isEmpty
    }

    mutating func mergeEarlier(_ earlier: NumericMetricSeries) {
        guard let index = dailySeries.firstIndex(where: { $0.type == earlier.type }) else {
            dailySeries.append(earlier)
            return
        }
        dailySeries[index] = dailySeries[index].mergingEarlier(earlier)
    }
}

struct WorkoutMetricsSummary: Codable, Equatable, Sendable {
    var caloriesKcal: Double?
    var distanceMeters: Double?
    var steps: Int?
    var elevationGainMeters: Double?
    var averageHeartRate: Double?
    var maxHeartRate: Double?
    var averageSpeedMetersPerSecond: Double?
    var averagePaceSecondsPerKilometer: Double?

    var isEmpty: Bool {
        caloriesKcal == nil
            && distanceMeters == nil
            && steps == nil
            && elevationGainMeters == nil
            && averageHeartRate == nil
            && maxHeartRate == nil
            && averageSpeedMetersPerSecond == nil
            && averagePaceSecondsPerKilometer == nil
    }
}

struct WorkoutSplit: Codable, Hashable, Identifiable, Sendable {
    var id: String
    var label: String
    var distanceMeters: Double?
    var durationSeconds: TimeInterval?
    var paceSecondsPerKilometer: Double?
    var speedMetersPerSecond: Double?
    var elevationGainMeters: Double?
    var heartRateAverage: Double?
}

struct WorkoutDetail: Codable, Equatable, Identifiable, Sendable {
    var id: String
    var type: String
    var startTime: Date
    var endTime: Date?
    var activeDurationSeconds: TimeInterval?
    var metricsSummary: WorkoutMetricsSummary
    var splits: [WorkoutSplit]
    var zoneMinutes: [MetricBucket]

    var durationSeconds: TimeInterval {
        if let activeDurationSeconds {
            return max(0, activeDurationSeconds)
        }
        guard let endTime else { return 0 }
        return max(0, endTime.timeIntervalSince(startTime))
    }

    var summaryValue: WorkoutSummary {
        WorkoutSummary(
            type: type,
            startTime: startTime,
            durationSeconds: durationSeconds,
            distanceMeters: metricsSummary.distanceMeters,
            calories: metricsSummary.caloriesKcal,
            averageHeartRate: metricsSummary.averageHeartRate
        )
    }
}

struct SleepStageSummary: Codable, Hashable, Identifiable, Sendable {
    var id: String { stage }
    var stage: String
    var durationSeconds: TimeInterval
}

struct SleepSession: Codable, Equatable, Identifiable, Sendable {
    var id: String
    var startTime: Date?
    var endTime: Date?
    var durationSeconds: TimeInterval?
    var stages: [SleepStageSummary]

    var summaryValue: SleepSummary {
        let intervalDuration = endTime.flatMap { end in startTime.map { end.timeIntervalSince($0) } }
        return SleepSummary(
            durationSeconds: max(0, durationSeconds ?? intervalDuration ?? 0),
            startTime: startTime,
            endTime: endTime
        )
    }
}

enum HealthDashboardMetricGroup: String, CaseIterable, Codable, Hashable, Sendable {
    case heart
    case sleepMetrics
    case vitals
    case cardioFitness
    case body
}

struct HealthDashboardData: Codable, Equatable, Sendable {
    var heartSeries: [NumericMetricSeries]
    var sleepMetricSeries: [NumericMetricSeries]
    var vitalSeries: [NumericMetricSeries]
    var cardioFitnessSeries: [NumericMetricSeries]
    var bodySeries: [NumericMetricSeries]
    var sleepSessions: [SleepSession]
    var loadedAt: Date?

    static let empty = HealthDashboardData(
        heartSeries: [],
        sleepMetricSeries: [],
        vitalSeries: [],
        cardioFitnessSeries: [],
        bodySeries: [],
        sleepSessions: [],
        loadedAt: nil
    )

    var allSeries: [NumericMetricSeries] {
        heartSeries + sleepMetricSeries + vitalSeries + cardioFitnessSeries + bodySeries
    }

    func series(for type: GoogleHealthDataType) -> NumericMetricSeries? {
        allSeries.first { $0.type == type }
    }

    var visibleMetricGroups: [HealthDashboardMetricGroup] {
        var groups: [HealthDashboardMetricGroup] = []
        if heartSeries.containsVisiblePoints { groups.append(.heart) }
        if sleepMetricSeries.containsVisiblePoints { groups.append(.sleepMetrics) }
        if vitalSeries.containsVisiblePoints { groups.append(.vitals) }
        if cardioFitnessSeries.containsVisiblePoints { groups.append(.cardioFitness) }
        if bodySeries.containsVisiblePoints { groups.append(.body) }
        return groups
    }

    var isEmpty: Bool {
        sleepSessions.isEmpty && visibleMetricGroups.isEmpty
    }

    mutating func mergeEarlier(_ earlier: NumericMetricSeries) {
        switch earlier.type.category {
        case .heart:
            heartSeries.merge(earlier)
        case .sleep:
            sleepMetricSeries.merge(earlier)
        case .vitals:
            vitalSeries.merge(earlier)
        case .cardioFitness:
            cardioFitnessSeries.merge(earlier)
        case .body:
            bodySeries.merge(earlier)
        case .activity, .workout:
            break
        }
    }
}

struct FitnessDataSnapshot: Equatable, Sendable {
    static let cacheVersion = 2

    var cacheVersion: Int
    var summary: DashboardSnapshot
    var activity: ActivityDashboardData
    var workouts: [WorkoutDetail]
    var workoutsLoadedAt: Date?
    var health: HealthDashboardData
    var lastUpdated: Date

    init(
        cacheVersion: Int = FitnessDataSnapshot.cacheVersion,
        summary: DashboardSnapshot,
        activity: ActivityDashboardData = .empty,
        workouts: [WorkoutDetail] = [],
        workoutsLoadedAt: Date? = nil,
        health: HealthDashboardData = .empty,
        lastUpdated: Date? = nil
    ) {
        self.cacheVersion = cacheVersion
        self.summary = summary
        self.activity = activity
        self.workouts = workouts.sorted { $0.startTime > $1.startTime }
        self.workoutsLoadedAt = workoutsLoadedAt
        self.health = health
        self.lastUpdated = lastUpdated ?? summary.lastUpdated
    }

    static func empty(goals: ActivityGoals = .defaultGoals) -> FitnessDataSnapshot {
        FitnessDataSnapshot(summary: .empty(goals: goals), lastUpdated: .distantPast)
    }

    static func fromLegacyDashboard(_ dashboard: DashboardSnapshot) -> FitnessDataSnapshot {
        var health = HealthDashboardData.empty
        if let sleep = dashboard.sleep {
            health.sleepSessions = [
                SleepSession(
                    id: sleep.startTime?.timeIntervalSince1970.description ?? "cached-sleep",
                    startTime: sleep.startTime,
                    endTime: sleep.endTime,
                    durationSeconds: sleep.durationSeconds,
                    stages: []
                )
            ]
        }

        return FitnessDataSnapshot(
            summary: dashboard,
            activity: .empty,
            workouts: dashboard.latestWorkout.map { [WorkoutDetail(summary: $0)] } ?? [],
            health: health,
            lastUpdated: dashboard.lastUpdated
        )
    }
}

extension FitnessDataSnapshot {
    struct CodableSnapshot: Codable {
        var cacheVersion: Int
        var summary: DashboardSnapshot.CodableSnapshot
        var activity: ActivityDashboardData
        var workouts: [WorkoutDetail]
        var workoutsLoadedAt: Date?
        var health: HealthDashboardData
        var lastUpdated: Date

        init(_ snapshot: FitnessDataSnapshot) {
            cacheVersion = snapshot.cacheVersion
            summary = DashboardSnapshot.CodableSnapshot(snapshot.summary)
            activity = snapshot.activity
            workouts = snapshot.workouts
            workoutsLoadedAt = snapshot.workoutsLoadedAt
            health = snapshot.health
            lastUpdated = snapshot.lastUpdated
        }

        var domainValue: FitnessDataSnapshot {
            FitnessDataSnapshot(
                cacheVersion: cacheVersion,
                summary: summary.domainValue,
                activity: activity,
                workouts: workouts,
                workoutsLoadedAt: workoutsLoadedAt,
                health: health,
                lastUpdated: lastUpdated
            )
        }
    }
}

extension WorkoutDetail {
    init(summary: WorkoutSummary) {
        self.init(
            id: String(summary.startTime.timeIntervalSince1970),
            type: summary.type,
            startTime: summary.startTime,
            endTime: summary.startTime.addingTimeInterval(summary.durationSeconds),
            activeDurationSeconds: summary.durationSeconds,
            metricsSummary: WorkoutMetricsSummary(
                caloriesKcal: summary.calories,
                distanceMeters: summary.distanceMeters,
                steps: nil,
                elevationGainMeters: nil,
                averageHeartRate: summary.averageHeartRate,
                maxHeartRate: nil,
                averageSpeedMetersPerSecond: nil,
                averagePaceSecondsPerKilometer: nil
            ),
            splits: [],
            zoneMinutes: []
        )
    }
}

private extension Array where Element == NumericMetricSeries {
    var containsVisiblePoints: Bool {
        contains { !$0.points.isEmpty }
    }

    mutating func merge(_ earlier: NumericMetricSeries) {
        guard let index = firstIndex(where: { $0.type == earlier.type }) else {
            append(earlier)
            return
        }
        self[index] = self[index].mergingEarlier(earlier)
    }
}

private func aggregateBuckets(_ buckets: [MetricBucket]) -> [MetricBucket] {
    var orderedKeys: [String] = []
    var bucketsByKey: [String: MetricBucket] = [:]

    for bucket in buckets {
        let label = displayBucketLabel(bucket.label)
        let key = normalizedBucketKey(label)
        let normalizedBucket = MetricBucket(label: label, value: bucket.value, unit: bucket.unit)

        if var existing = bucketsByKey[key] {
            existing.value += normalizedBucket.value
            bucketsByKey[key] = existing
        } else {
            orderedKeys.append(key)
            bucketsByKey[key] = normalizedBucket
        }
    }

    return orderedKeys.compactMap { bucketsByKey[$0] }
}

private func orderedBuckets(_ buckets: [MetricBucket], labels: [String]) -> [MetricBucket] {
    let orderedKeys = labels.map(normalizedBucketKey)
    return buckets.sorted { left, right in
        let leftIndex = orderedKeys.firstIndex(of: normalizedBucketKey(left.label)) ?? orderedKeys.count
        let rightIndex = orderedKeys.firstIndex(of: normalizedBucketKey(right.label)) ?? orderedKeys.count
        guard leftIndex != rightIndex else {
            return left.label < right.label
        }
        return leftIndex < rightIndex
    }
}

private func displayBucketLabel(_ value: String) -> String {
    switch normalizedBucketKey(value) {
    case "LIGHT", "LIGHTLY_ACTIVE":
        return "Light"
    case "MODERATE", "MODERATELY_ACTIVE":
        return "Moderate"
    case "VIGOROUS", "VERY_ACTIVE":
        return "Vigorous"
    default:
        return value.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

private func normalizedBucketKey(_ value: String) -> String {
    value
        .trimmingCharacters(in: .whitespacesAndNewlines)
        .uppercased()
        .replacingOccurrences(of: " ", with: "_")
        .replacingOccurrences(of: "-", with: "_")
}
