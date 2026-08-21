import Foundation

enum GoogleHealthMapper {
    static func map(
        goals: ActivityGoals,
        date: Date,
        rollups: [GoogleHealthDataType: GoogleHealthRollUpResponse],
        latestWorkout: GoogleHealthRecord?,
        latestHeartRate: GoogleHealthRecord?,
        restingHeartRate: GoogleHealthRecord?,
        sleep: GoogleHealthRecord?
    ) -> DashboardSnapshot {
        let steps = Int(rollupValue(.steps, in: rollups).rounded())
        let activeMinutes = rollupValue(.activeMinutes, in: rollups)
        let activeCalories = rollupValue(.activeEnergyBurned, in: rollups)
        let distance = rollupValue(.distance, in: rollups)
        let totalCalories = rollupValue(.totalCalories, in: rollups)

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
                restingHeartRate: heartRate(from: restingHeartRate),
                measuredAt: latestHeartRate?.endTime ?? latestHeartRate?.startTime
            ),
            sleep: sleepSummary(from: sleep),
            lastUpdated: .now,
            syncState: .idle
        )
    }

    private static func rollupValue(
        _ type: GoogleHealthDataType,
        in rollups: [GoogleHealthDataType: GoogleHealthRollUpResponse]
    ) -> Double {
        rollups[type]?.bucket
            .flatMap(\.dataset)
            .flatMap(\.point)
            .flatMap(\.value)
            .compactMap(\.numericValue)
            .reduce(0, +) ?? 0
    }

    private static func workout(from record: GoogleHealthRecord?) -> WorkoutSummary? {
        guard let record, let startTime = record.startTime else { return nil }
        let endTime = record.endTime ?? startTime
        let duration = max(0, endTime.timeIntervalSince(startTime))

        return WorkoutSummary(
            type: record.values?["type"]?.stringVal
                ?? record.metadata?["activityType"]
                ?? "Workout",
            startTime: startTime,
            durationSeconds: duration,
            distanceMeters: record.values?["distance"]?.numericValue,
            calories: record.values?["calories"]?.numericValue
        )
    }

    private static func heartRate(from record: GoogleHealthRecord?) -> Int? {
        guard let values = record?.values else { return nil }
        return [
            values["beatsPerMinute"]?.numericValue,
            values["bpm"]?.numericValue,
            values["heartRate"]?.numericValue,
            values.values.compactMap(\.numericValue).first
        ]
        .compactMap { $0 }
        .map { Int($0.rounded()) }
        .first
    }

    private static func sleepSummary(from record: GoogleHealthRecord?) -> SleepSummary? {
        guard let record else { return nil }

        let start = record.startTime
        let end = record.endTime
        let duration = record.values?["duration"]?.numericValue
            ?? end.flatMap { end in start.map { end.timeIntervalSince($0) } }
            ?? 0

        return SleepSummary(
            durationSeconds: max(0, duration),
            startTime: start,
            endTime: end
        )
    }
}
