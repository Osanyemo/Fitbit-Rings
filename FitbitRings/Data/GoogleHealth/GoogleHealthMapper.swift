import Foundation

enum GoogleHealthMapper {
    static func map(
        goals: ActivityGoals,
        date: Date,
        rollups: [GoogleHealthDataType: GoogleHealthRollUpResponse],
        latestWorkout: GoogleHealthDataPoint?,
        latestHeartRate: GoogleHealthDataPoint?,
        restingHeartRate: GoogleHealthDataPoint?,
        sleep: GoogleHealthDataPoint?
    ) -> DashboardSnapshot {
        let steps = rollupValue(.steps, in: rollups).intValue
        let activeMinutes = rollupValue(.activeMinutes, in: rollups).doubleValue
        let activeCalories = rollupValue(.activeEnergyBurned, in: rollups).doubleValue
        let distance = rollupValue(.distance, in: rollups).doubleValue
        let totalCalories = rollupValue(.totalCalories, in: rollups).doubleValue

        return DashboardSnapshot(
            date: date,
            rings: RingSet(
                move: RingMetric(
                    title: "Move",
                    value: activeCalories,
                    goal: Double(goals.moveCalories),
                    unit: "kcal"
                ),
                active: RingMetric(
                    title: "Active",
                    value: activeMinutes,
                    goal: Double(goals.activeMinutes),
                    unit: "min"
                ),
                steps: RingMetric(
                    title: "Steps",
                    value: Double(steps),
                    goal: Double(goals.steps),
                    unit: ""
                )
            ),
            activity: ActivitySummary(
                steps: steps,
                distanceMeters: distance,
                activeCalories: activeCalories,
                totalCalories: totalCalories
            ),
            latestWorkout: workout(from: latestWorkout),
            heart: HeartSummary(
                mostRecentHeartRate: heartRate(from: latestHeartRate),
                restingHeartRate: dailyRestingHeartRate(from: restingHeartRate),
                measuredAt: latestHeartRate?.heartRate?.sampleTime?.physicalTime
            ),
            sleep: sleepSummary(from: sleep),
            lastUpdated: .now,
            syncState: .idle
        )
    }

    private static func rollupValue(
        _ type: GoogleHealthDataType,
        in rollups: [GoogleHealthDataType: GoogleHealthRollUpResponse]
    ) -> GoogleHealthNumericValue {
        let dataPoints = rollups[type]?.rollupDataPoints ?? []
        switch type {
        case .steps:
            return GoogleHealthNumericValue(
                dataPoints.compactMap { $0.steps?.countSum?.doubleValue }.reduce(0, +)
            )
        case .activeMinutes:
            return GoogleHealthNumericValue(
                dataPoints
                    .compactMap(\.activeMinutes)
                    .flatMap(\.activeMinutesRollupByActivityLevel)
                    .compactMap { $0.activeMinutesSum?.doubleValue }
                    .reduce(0, +)
            )
        case .activeEnergyBurned:
            return GoogleHealthNumericValue(
                dataPoints.compactMap { $0.activeEnergyBurned?.kcalSum }.reduce(0, +)
            )
        case .distance:
            let millimeters = dataPoints.compactMap { $0.distance?.millimetersSum?.doubleValue }.reduce(0, +)
            return GoogleHealthNumericValue(millimeters / 1_000)
        case .totalCalories:
            return GoogleHealthNumericValue(
                dataPoints.compactMap { $0.totalCalories?.kcalSum }.reduce(0, +)
            )
        case .exercise, .heartRate, .dailyRestingHeartRate, .sleep:
            return GoogleHealthNumericValue(0)
        }
    }

    private static func workout(from record: GoogleHealthDataPoint?) -> WorkoutSummary? {
        guard let exercise = record?.exercise,
              let startTime = exercise.interval?.startTime else { return nil }

        let endTime = exercise.interval?.endTime ?? startTime
        let duration = max(0, endTime.timeIntervalSince(startTime))

        return WorkoutSummary(
            type: exercise.displayName?.nilIfEmpty
                ?? exercise.exerciseType?.displayNameFromEnum
                ?? "Workout",
            startTime: startTime,
            durationSeconds: exercise.activeDuration?.durationSeconds ?? duration,
            distanceMeters: exercise.metricsSummary?.distanceMillimeters.map { $0 / 1_000 },
            calories: exercise.metricsSummary?.caloriesKcal
        )
    }

    private static func heartRate(from record: GoogleHealthDataPoint?) -> Int? {
        record?.heartRate?.beatsPerMinute?.intValue
    }

    private static func dailyRestingHeartRate(from record: GoogleHealthDataPoint?) -> Int? {
        record?.dailyRestingHeartRate?.beatsPerMinute?.intValue
    }

    private static func sleepSummary(from record: GoogleHealthDataPoint?) -> SleepSummary? {
        guard let sleep = record?.sleep else { return nil }

        let start = sleep.interval?.startTime
        let end = sleep.interval?.endTime
        let minutesAsleep = sleep.summary?.minutesAsleep?.doubleValue
        let minutesInSleepPeriod = sleep.summary?.minutesInSleepPeriod?.doubleValue
        let summaryDuration = (minutesAsleep ?? minutesInSleepPeriod).map { $0 * 60 }
        let intervalDuration = end.flatMap { end in start.map { end.timeIntervalSince($0) } }
        let duration = summaryDuration
            ?? intervalDuration
            ?? 0

        return SleepSummary(
            durationSeconds: max(0, duration),
            startTime: start,
            endTime: end
        )
    }
}

private extension String {
    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }

    var displayNameFromEnum: String {
        split(separator: "_")
            .map { word in
                word.prefix(1).uppercased() + word.dropFirst().lowercased()
            }
            .joined(separator: " ")
    }

    var durationSeconds: TimeInterval? {
        guard hasSuffix("s") else { return nil }
        return Double(dropLast())
    }
}
