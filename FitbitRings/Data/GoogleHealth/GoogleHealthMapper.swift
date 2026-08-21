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
        let stepsValue = rollupValue(.steps, in: rollups)
        let activeMinutesValue = rollupValue(.activeMinutes, in: rollups)
        let activeCaloriesValue = rollupValue(.activeEnergyBurned, in: rollups)
        let distanceValue = rollupValue(.distance, in: rollups)
        let totalCaloriesValue = rollupValue(.totalCalories, in: rollups)

        let steps = stepsValue?.intValue ?? 0
        let activeMinutes = activeMinutesValue?.doubleValue ?? 0
        let activeCalories = activeCaloriesValue?.doubleValue ?? 0
        let distance = distanceValue?.doubleValue ?? 0
        let totalCalories = totalCaloriesValue?.doubleValue ?? 0

        var providedMetrics = Set<GoogleHealthDataType>()
        if stepsValue != nil { providedMetrics.insert(.steps) }
        if activeMinutesValue != nil { providedMetrics.insert(.activeMinutes) }
        if activeCaloriesValue != nil { providedMetrics.insert(.activeEnergyBurned) }
        if distanceValue != nil { providedMetrics.insert(.distance) }
        if totalCaloriesValue != nil { providedMetrics.insert(.totalCalories) }

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
                totalCalories: totalCalories,
                providedMetrics: providedMetrics
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

    static func mapActivityData(
        dailyRollups: [GoogleHealthDataType: GoogleHealthRollUpResponse],
        hourlyRollups: [GoogleHealthDataType: GoogleHealthRollUpResponse],
        currentDayRollups: [GoogleHealthDataType: GoogleHealthRollUpResponse] = [:],
        records: [GoogleHealthDataType: [GoogleHealthDataPoint]] = [:],
        range: DateInterval,
        calendar: Calendar = .current,
        currentDate: Date = .now,
        loadedAt: Date = .now
    ) -> ActivityDashboardData {
        var dailySeries = GoogleHealthDataType.activitySeriesTypes.compactMap { type in
            numericSeries(
                type,
                from: dailyRollups[type],
                fallbackRange: range,
                calendar: calendar
            )
        }
        .filter { !$0.points.isEmpty }

        for type in GoogleHealthDataType.activityRecordSeriesTypes {
            let recordSeries = metricSeries(type, from: records[type] ?? [], range: range, calendar: calendar)
            if !recordSeries.points.isEmpty {
                dailySeries.append(recordSeries)
            }
        }

        let hourlySeries = [GoogleHealthDataType.steps, .distance].compactMap { type in
            numericSeries(
                type,
                from: hourlyRollups[type],
                fallbackRange: nil,
                calendar: calendar
            )
        }
        .filter { !$0.points.isEmpty }

        let currentRollups = hourlyRollups.merging(currentDayRollups) { _, current in current }
        upsertCurrentDayRollups(
            from: currentRollups,
            into: &dailySeries,
            range: range,
            currentDate: currentDate,
            calendar: calendar
        )

        let bucketedSeries = bucketedSeries(from: dailyRollups, range: range)

        return ActivityDashboardData(
            dailySeries: dailySeries,
            hourlySeries: hourlySeries,
            bucketedSeries: bucketedSeries,
            loadedAt: loadedAt
        )
    }

    static func mapRollupSeries(
        _ type: GoogleHealthDataType,
        response: GoogleHealthRollUpResponse,
        range: DateInterval,
        calendar: Calendar = .current
    ) -> NumericMetricSeries {
        numericSeries(type, from: response, fallbackRange: range, calendar: calendar)
            ?? NumericMetricSeries(type: type, points: [], rangeStart: range.start, rangeEnd: range.end)
    }

    static func mapWorkouts(_ records: [GoogleHealthDataPoint]) -> [WorkoutDetail] {
        records.compactMap(workoutDetail(from:))
            .sorted { $0.startTime > $1.startTime }
    }

    static func mapHealthData(
        records: [GoogleHealthDataType: [GoogleHealthDataPoint]],
        range: DateInterval,
        loadedAt: Date = .now,
        calendar: Calendar = .current
    ) -> HealthDashboardData {
        var health = HealthDashboardData.empty
        health.loadedAt = loadedAt

        for type in GoogleHealthDataType.healthSeriesTypes {
            let series = metricSeries(type, from: records[type] ?? [], range: range, calendar: calendar)
            guard !series.points.isEmpty else { continue }

            switch type.category {
            case .heart:
                health.heartSeries.append(series)
            case .sleep:
                health.sleepMetricSeries.append(series)
            case .vitals:
                health.vitalSeries.append(series)
            case .cardioFitness:
                health.cardioFitnessSeries.append(series)
            case .body:
                health.bodySeries.append(series)
            case .activity, .workout:
                break
            }
        }

        health.sleepSessions = (records[.sleep] ?? [])
            .compactMap(sleepSession(from:))
            .sorted {
                ($0.endTime ?? $0.startTime ?? .distantPast) > ($1.endTime ?? $1.startTime ?? .distantPast)
            }

        return health
    }

    static func metricSeries(
        _ type: GoogleHealthDataType,
        from records: [GoogleHealthDataPoint],
        range: DateInterval,
        calendar: Calendar = .current
    ) -> NumericMetricSeries {
        let points = records.compactMap { record -> NumericMetricPoint? in
            guard let sample = metricSample(type, from: record, calendar: calendar) else {
                return nil
            }
            return NumericMetricPoint(
                id: record.identifier,
                startDate: sample.date,
                endDate: sample.endDate,
                value: sample.value,
                unit: type.unit
            )
        }

        return NumericMetricSeries(
            type: type,
            points: points,
            rangeStart: range.start,
            rangeEnd: range.end
        )
    }

    private static func rollupValue(
        _ type: GoogleHealthDataType,
        in rollups: [GoogleHealthDataType: GoogleHealthRollUpResponse]
    ) -> GoogleHealthNumericValue? {
        let dataPoints = rollups[type]?.rollupDataPoints ?? []
        switch type {
        case .steps:
            return summed(dataPoints.compactMap { $0.steps?.countSum?.doubleValue })
        case .activeMinutes:
            return summed(
                dataPoints
                    .compactMap(\.activeMinutes)
                    .flatMap(\.activeMinutesRollupByActivityLevel)
                    .compactMap { $0.activeMinutesSum?.doubleValue }
            )
        case .activeEnergyBurned:
            return summed(dataPoints.compactMap { $0.activeEnergyBurned?.kcalSum })
        case .distance:
            return summed(dataPoints.compactMap { $0.distance?.millimetersSum?.doubleValue })
                .map { GoogleHealthNumericValue($0.doubleValue / 1_000) }
        case .totalCalories:
            return summed(dataPoints.compactMap { $0.totalCalories?.kcalSum })
        case .activeZoneMinutes, .caloriesInHeartRateZone, .timeInHeartRateZone,
             .floors, .altitude, .sedentaryPeriod, .activityLevel, .swimLengthsData,
             .exercise, .heartRate, .dailyRestingHeartRate, .heartRateVariability,
             .dailyHeartRateVariability, .dailyHeartRateZones, .oxygenSaturation,
             .dailyOxygenSaturation, .respiratoryRateSleepSummary, .dailyRespiratoryRate,
             .dailySleepTemperatureDerivations, .vo2Max, .dailyVo2Max, .runVo2Max,
             .weight, .bodyFat, .height, .bloodGlucose, .coreBodyTemperature, .sleep:
            return nil
        }
    }

    private static func summed(_ values: [Double]) -> GoogleHealthNumericValue? {
        guard !values.isEmpty else { return nil }
        return GoogleHealthNumericValue(values.reduce(0, +))
    }

    private static func numericSeries(
        _ type: GoogleHealthDataType,
        from response: GoogleHealthRollUpResponse?,
        fallbackRange: DateInterval?,
        calendar: Calendar = .current
    ) -> NumericMetricSeries? {
        guard let response else {
            return nil
        }

        let points = response.rollupDataPoints.enumerated().compactMap { index, point -> NumericMetricPoint? in
            guard let value = rollupValue(type, in: point) else {
                return nil
            }

            let startDate = point.startTime
                ?? point.civilStartTime?.dateValue(calendar: calendar)
                ?? fallbackRange.flatMap { fallbackStart(for: $0, index: index, calendar: calendar) }
            guard let startDate else {
                return nil
            }

            return NumericMetricPoint(
                id: "\(type.rawValue)-\(startDate.timeIntervalSince1970)",
                startDate: startDate,
                endDate: point.endTime ?? point.civilEndTime?.dateValue(calendar: calendar),
                value: value,
                unit: type.unit
            )
        }

        guard !points.isEmpty else {
            return NumericMetricSeries(
                type: type,
                points: [],
                rangeStart: fallbackRange?.start,
                rangeEnd: fallbackRange?.end,
                nextPageToken: response.nextPageToken
            )
        }

        return NumericMetricSeries(
            type: type,
            points: points,
            rangeStart: fallbackRange?.start ?? points.first?.startDate,
            rangeEnd: fallbackRange?.end ?? points.last?.endDate,
            nextPageToken: response.nextPageToken
        )
    }

    private static func upsertCurrentDayRollups(
        from hourlyRollups: [GoogleHealthDataType: GoogleHealthRollUpResponse],
        into dailySeries: inout [NumericMetricSeries],
        range: DateInterval,
        currentDate: Date,
        calendar: Calendar
    ) {
        for type in GoogleHealthDataType.activitySeriesTypes {
            guard let point = currentDayPoint(
                for: type,
                response: hourlyRollups[type],
                currentDate: currentDate,
                calendar: calendar
            ) else { continue }

            if let seriesIndex = dailySeries.firstIndex(where: { $0.type == type }) {
                dailySeries[seriesIndex] = upsertingCurrentDayPoint(
                    point,
                    in: dailySeries[seriesIndex],
                    calendar: calendar
                )
            } else {
                dailySeries.append(
                    NumericMetricSeries(
                        type: type,
                        points: [point],
                        rangeStart: range.start,
                        rangeEnd: range.end
                    )
                )
            }
        }
    }

    private static func currentDayPoint(
        for type: GoogleHealthDataType,
        response: GoogleHealthRollUpResponse?,
        currentDate: Date,
        calendar: Calendar
    ) -> NumericMetricPoint? {
        guard let response else { return nil }

        let values = response.rollupDataPoints.compactMap { point -> Double? in
            if let startTime = point.startTime,
               !calendar.isDate(startTime, inSameDayAs: currentDate) {
                return nil
            }
            return rollupValue(type, in: point)
        }

        guard !values.isEmpty else { return nil }

        let dayStart = calendar.startOfDay(for: currentDate)
        return NumericMetricPoint(
            id: "\(type.rawValue)-\(dayStart.timeIntervalSince1970)",
            startDate: dayStart,
            endDate: currentDate,
            value: values.reduce(0, +),
            unit: type.unit
        )
    }

    private static func upsertingCurrentDayPoint(
        _ point: NumericMetricPoint,
        in series: NumericMetricSeries,
        calendar: Calendar
    ) -> NumericMetricSeries {
        var points = series.points.filter {
            !calendar.isDate($0.startDate, inSameDayAs: point.startDate)
        }
        points.append(point)

        return NumericMetricSeries(
            type: series.type,
            title: series.title,
            unit: series.unit,
            points: points,
            rangeStart: series.rangeStart,
            rangeEnd: series.rangeEnd,
            nextPageToken: series.nextPageToken
        )
    }

    private static func rollupValue(
        _ type: GoogleHealthDataType,
        in point: GoogleHealthRollupDataPoint
    ) -> Double? {
        switch type {
        case .steps:
            return point.steps?.countSum?.doubleValue
        case .activeMinutes:
            let values = point.activeMinutes?.activeMinutesRollupByActivityLevel
                .compactMap { $0.activeMinutesSum?.doubleValue } ?? []
            return values.isEmpty ? nil : values.reduce(0, +)
        case .activeEnergyBurned:
            return point.activeEnergyBurned?.kcalSum
        case .distance:
            return point.distance?.millimetersSum.map { $0.doubleValue / 1_000 }
        case .totalCalories:
            return point.totalCalories?.kcalSum
        case .activeZoneMinutes:
            if let total = point.activeZoneMinutes?.activeZoneMinutesSum?.doubleValue {
                return total
            }
            let values = [
                point.activeZoneMinutes?.fatBurnMinutesSum?.doubleValue,
                point.activeZoneMinutes?.cardioMinutesSum?.doubleValue,
                point.activeZoneMinutes?.peakMinutesSum?.doubleValue
            ].compactMap { $0 }
            return values.isEmpty ? nil : values.reduce(0, +)
        case .caloriesInHeartRateZone:
            return point.caloriesInHeartRateZone?.caloriesKcalSum?.doubleValue
                ?? point.caloriesInHeartRateZone?.kcalSum?.doubleValue
        case .timeInHeartRateZone:
            return point.timeInHeartRateZone?.minutesSum?.doubleValue
                ?? point.timeInHeartRateZone?.durationMillisSum.map { $0.doubleValue / 60_000 }
        case .floors:
            return point.floors?.floorsSum?.doubleValue
                ?? point.floors?.countSum?.doubleValue
        case .altitude:
            return point.altitude?.preferredScalarValue
        case .sedentaryPeriod:
            return point.sedentaryPeriod?.minutesSum?.doubleValue
                ?? point.sedentaryPeriod?.durationSecondsSum.map { $0.doubleValue / 60 }
                ?? point.sedentaryPeriod?.durationMillisSum.map { $0.doubleValue / 60_000 }
        case .activityLevel:
            return point.activityLevel?.minutesSum?.doubleValue
                ?? point.activityLevel?.durationMillisSum.map { $0.doubleValue / 60_000 }
        case .swimLengthsData:
            return point.swimLengthsData?.lengthsSum?.doubleValue
                ?? point.swimLengthsData?.countSum?.doubleValue
        case .heartRate:
            return point.heartRate?.beatsPerMinuteAvg?.doubleValue
                ?? point.heartRate?.beatsPerMinuteMax?.doubleValue
                ?? point.heartRate?.beatsPerMinuteMin?.doubleValue
        case .heartRateVariability:
            return point.heartRateVariability?.preferredScalarValue
        case .oxygenSaturation:
            return point.oxygenSaturation?.preferredScalarValue
        case .respiratoryRateSleepSummary:
            return point.respiratoryRateSleepSummary?.preferredScalarValue
        case .vo2Max:
            return point.vo2Max?.preferredScalarValue
        case .dailyVo2Max:
            return point.vo2Max?.preferredScalarValue ?? point.runVo2Max?.preferredScalarValue
        case .runVo2Max:
            return point.runVo2Max?.preferredScalarValue
        case .weight:
            return point.weight?.preferredScalarValue
        case .bodyFat:
            return point.bodyFat?.preferredScalarValue
        case .height:
            return point.height?.preferredScalarValue
        case .bloodGlucose:
            return point.bloodGlucose?.preferredScalarValue
        case .coreBodyTemperature:
            return point.coreBodyTemperature?.preferredScalarValue
        case .exercise, .dailyRestingHeartRate, .dailyHeartRateVariability,
             .dailyHeartRateZones, .dailyOxygenSaturation, .dailyRespiratoryRate,
             .dailySleepTemperatureDerivations, .sleep:
            return nil
        }
    }

    private static func fallbackStart(for range: DateInterval, index: Int, calendar: Calendar) -> Date {
        calendar.date(byAdding: .day, value: index, to: range.start) ?? range.start
    }

    private static func bucketedSeries(
        from rollups: [GoogleHealthDataType: GoogleHealthRollUpResponse],
        range: DateInterval
    ) -> [BucketedMetricSeries] {
        var series: [BucketedMetricSeries] = []

        let activeBuckets = aggregateBuckets(
            (rollups[.activeMinutes]?.rollupDataPoints ?? [])
            .compactMap(\.activeMinutes)
            .flatMap(\.activeMinutesRollupByActivityLevel)
            .compactMap { bucket -> MetricBucket? in
                guard let label = bucket.activityLevel,
                      let value = bucket.activeMinutesSum?.doubleValue else { return nil }
                return MetricBucket(label: activityLevelBucketLabel(label), value: value, unit: "min")
            }
        )
        if !activeBuckets.isEmpty {
            series.append(
                BucketedMetricSeries(
                    type: .activeMinutes,
                    title: "Activity Intensity",
                    buckets: orderedBuckets(activeBuckets, labels: ["Light", "Moderate", "Vigorous"]),
                    rangeStart: range.start,
                    rangeEnd: range.end
                )
            )
        }

        let zoneBuckets = aggregateBuckets(
            (rollups[.timeInHeartRateZone]?.rollupDataPoints ?? [])
            .compactMap(\.timeInHeartRateZone)
            .compactMap { bucket -> MetricBucket? in
                guard let label = bucket.heartRateZone,
                      let value = bucket.minutesSum?.doubleValue
                        ?? bucket.durationMillisSum.map({ $0.doubleValue / 60_000 }) else { return nil }
                return MetricBucket(label: label.displayNameFromEnum, value: value, unit: "min")
            }
        )
        if !zoneBuckets.isEmpty {
            series.append(
                BucketedMetricSeries(
                    type: .timeInHeartRateZone,
                    title: "Heart Rate Zones",
                    buckets: zoneBuckets,
                    rangeStart: range.start,
                    rangeEnd: range.end
                )
            )
        }

        return series
    }

    private static func workout(from record: GoogleHealthDataPoint?) -> WorkoutSummary? {
        workoutDetail(from: record)?.summaryValue
    }

    private static func workoutDetail(from record: GoogleHealthDataPoint?) -> WorkoutDetail? {
        guard let record,
              let exercise = record.exercise,
              let startTime = exercise.interval?.startTime else { return nil }

        let endTime = exercise.interval?.endTime ?? startTime
        let duration = max(0, endTime.timeIntervalSince(startTime))

        return WorkoutDetail(
            id: record.identifier,
            type: exercise.displayName?.nilIfEmpty
                ?? exercise.exerciseType?.displayNameFromEnum
                ?? "Workout",
            startTime: startTime,
            endTime: exercise.interval?.endTime,
            activeDurationSeconds: exercise.activeDuration?.durationSeconds ?? duration,
            metricsSummary: WorkoutMetricsSummary(
                caloriesKcal: exercise.metricsSummary?.caloriesKcal,
                distanceMeters: exercise.metricsSummary?.distanceMillimeters.map { $0 / 1_000 },
                steps: exercise.metricsSummary?.steps?.intValue,
                elevationGainMeters: exercise.metricsSummary?.elevationGainMillimeters.map { $0 / 1_000 },
                averageHeartRate: exercise.metricsSummary?.averageHeartRate?.doubleValue,
                maxHeartRate: exercise.metricsSummary?.maxHeartRate?.doubleValue,
                averageSpeedMetersPerSecond: exercise.metricsSummary?.averageSpeedMetersPerSecond?.doubleValue,
                averagePaceSecondsPerKilometer: exercise.metricsSummary?.averagePaceSecondsPerKilometer?.doubleValue
            ),
            splits: (exercise.splits ?? []).enumerated().map { index, split in
                WorkoutSplit(
                    id: split.name ?? "\(record.identifier)-split-\(index)",
                    label: split.label ?? split.name ?? "Split \(index + 1)",
                    distanceMeters: split.distanceMillimeters.map { $0 / 1_000 },
                    durationSeconds: split.durationSeconds?.doubleValue ?? split.duration?.durationSeconds,
                    paceSecondsPerKilometer: split.paceSecondsPerKilometer?.doubleValue,
                    speedMetersPerSecond: split.speedMetersPerSecond?.doubleValue,
                    elevationGainMeters: split.elevationGainMillimeters.map { $0 / 1_000 },
                    heartRateAverage: split.averageHeartRate?.doubleValue
                )
            },
            zoneMinutes: aggregateBuckets(
                (exercise.zoneMinutes ?? []).compactMap { zone in
                    guard let label = zone.zone,
                          let value = zone.minutes?.doubleValue
                            ?? zone.durationMillis.map({ $0.doubleValue / 60_000 }) else {
                        return nil
                    }
                    return MetricBucket(label: label.displayNameFromEnum, value: value, unit: "min")
                }
            )
        )
    }

    private static func aggregateBuckets(_ buckets: [MetricBucket]) -> [MetricBucket] {
        var orderedLabels: [String] = []
        var bucketsByLabel: [String: MetricBucket] = [:]

        for bucket in buckets {
            let label = bucket.label.trimmingCharacters(in: .whitespacesAndNewlines)
            let key = normalizedBucketKey(label)
            let bucket = MetricBucket(label: label, value: bucket.value, unit: bucket.unit)

            if var existing = bucketsByLabel[key] {
                existing.value += bucket.value
                bucketsByLabel[key] = existing
            } else {
                orderedLabels.append(key)
                bucketsByLabel[key] = bucket
            }
        }

        return orderedLabels.compactMap { bucketsByLabel[$0] }
    }

    private static func orderedBuckets(_ buckets: [MetricBucket], labels: [String]) -> [MetricBucket] {
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

    private static func activityLevelBucketLabel(_ value: String) -> String {
        switch normalizedBucketKey(value) {
        case "LIGHT", "LIGHTLY_ACTIVE":
            return "Light"
        case "MODERATE", "MODERATELY_ACTIVE":
            return "Moderate"
        case "VIGOROUS", "VERY_ACTIVE":
            return "Vigorous"
        default:
            return value.displayNameFromEnum
        }
    }

    private static func normalizedBucketKey(_ value: String) -> String {
        value
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .uppercased()
            .replacingOccurrences(of: " ", with: "_")
            .replacingOccurrences(of: "-", with: "_")
    }

    private static func heartRate(from record: GoogleHealthDataPoint?) -> Int? {
        record?.heartRate?.beatsPerMinute?.intValue
    }

    private static func dailyRestingHeartRate(from record: GoogleHealthDataPoint?) -> Int? {
        record?.dailyRestingHeartRate?.beatsPerMinute?.intValue
    }

    private static func sleepSummary(from record: GoogleHealthDataPoint?) -> SleepSummary? {
        sleepSession(from: record)?.summaryValue
    }

    private static func sleepSession(from record: GoogleHealthDataPoint?) -> SleepSession? {
        guard let record,
              let sleep = record.sleep else { return nil }

        let start = sleep.interval?.startTime
        let end = sleep.interval?.endTime
        let minutesAsleep = sleep.summary?.minutesAsleep?.doubleValue
        let minutesInSleepPeriod = sleep.summary?.minutesInSleepPeriod?.doubleValue
        let summaryDuration = (minutesAsleep ?? minutesInSleepPeriod).map { $0 * 60 }
        let intervalDuration = end.flatMap { end in start.map { end.timeIntervalSince($0) } }
        let duration = summaryDuration
            ?? intervalDuration
            ?? 0

        return SleepSession(
            id: record.identifier,
            startTime: start,
            endTime: end,
            durationSeconds: max(0, duration),
            stages: sleepStageSummaries(from: sleep)
        )
    }

    private static func sleepStageSummaries(from sleep: GoogleHealthSleep) -> [SleepStageSummary] {
        let listedStages = sleep.stages ?? sleep.sleepStages ?? []
        let fromList = listedStages.compactMap { stage -> SleepStageSummary? in
            let value = stage.durationSeconds?.doubleValue
                ?? stage.durationMillis.map { $0.doubleValue / 1_000 }
                ?? stage.minutes.map { $0.doubleValue * 60 }
            guard let value else { return nil }
            return SleepStageSummary(
                stage: (stage.stage ?? stage.sleepStage ?? "Stage").displayNameFromEnum,
                durationSeconds: value
            )
        }
        if !fromList.isEmpty {
            return fromList
        }

        let summaryStages: [(String, GoogleHealthNumericValue?)] = [
            ("Awake", sleep.summary?.minutesAwake),
            ("Deep", sleep.summary?.minutesDeep),
            ("Light", sleep.summary?.minutesLight),
            ("REM", sleep.summary?.minutesRem)
        ]
        return summaryStages.compactMap { stage, minutes in
            minutes.map { SleepStageSummary(stage: stage, durationSeconds: $0.doubleValue * 60) }
        }
    }

    private static func metricSample(
        _ type: GoogleHealthDataType,
        from record: GoogleHealthDataPoint,
        calendar: Calendar
    ) -> (date: Date, endDate: Date?, value: Double)? {
        switch type {
        case .heartRate:
            return sample(
                date: record.heartRate?.sampleTime?.physicalTime,
                value: record.heartRate?.beatsPerMinute?.doubleValue
            )
        case .dailyRestingHeartRate:
            return dailySample(
                date: record.dailyRestingHeartRate?.date,
                calendar: calendar,
                value: record.dailyRestingHeartRate?.beatsPerMinute?.doubleValue
            )
        case .heartRateVariability:
            return scalarSample(record.heartRateVariability, calendar: calendar)
        case .dailyHeartRateVariability:
            return dailyScalarSample(record.dailyHeartRateVariability, calendar: calendar)
        case .oxygenSaturation:
            return scalarSample(record.oxygenSaturation, calendar: calendar)
        case .dailyOxygenSaturation:
            return dailyScalarSample(record.dailyOxygenSaturation, calendar: calendar)
        case .respiratoryRateSleepSummary:
            return scalarSample(record.respiratoryRateSleepSummary, calendar: calendar)
        case .dailyRespiratoryRate:
            return dailyScalarSample(record.dailyRespiratoryRate, calendar: calendar)
        case .dailySleepTemperatureDerivations:
            return dailyScalarSample(record.dailySleepTemperatureDerivations, calendar: calendar)
        case .vo2Max:
            return scalarSample(record.vo2Max, calendar: calendar)
        case .dailyVo2Max:
            return dailyScalarSample(record.dailyVo2Max, calendar: calendar)
        case .runVo2Max:
            return scalarSample(record.runVo2Max, calendar: calendar)
        case .weight:
            return scalarSample(record.weight, calendar: calendar)
        case .bodyFat:
            return scalarSample(record.bodyFat, calendar: calendar)
        case .height:
            return scalarSample(record.height, calendar: calendar)
        case .bloodGlucose:
            return scalarSample(record.bloodGlucose, calendar: calendar)
        case .coreBodyTemperature:
            return scalarSample(record.coreBodyTemperature, calendar: calendar)
        case .steps:
            return intervalSample(record.steps?.interval, value: record.steps?.count?.doubleValue)
        case .activeMinutes:
            return intervalSample(record.activeMinutes?.interval, value: record.activeMinutes?.activeMinutes?.doubleValue)
        case .activeEnergyBurned:
            return intervalSample(
                record.activeEnergyBurned?.interval,
                value: record.activeEnergyBurned?.kcal?.doubleValue
                    ?? record.activeEnergyBurned?.caloriesKcal?.doubleValue
            )
        case .distance:
            return intervalSample(record.distance?.interval, value: record.distance?.millimeters.map { $0.doubleValue / 1_000 })
        case .totalCalories:
            return intervalSample(
                record.totalCalories?.interval,
                value: record.totalCalories?.kcal?.doubleValue
                    ?? record.totalCalories?.caloriesKcal?.doubleValue
            )
        case .activeZoneMinutes:
            return intervalSample(record.activeZoneMinutes?.interval, value: record.activeZoneMinutes?.activeZoneMinutes?.doubleValue)
        case .floors:
            return intervalSample(
                record.floors?.interval,
                value: record.floors?.floors?.doubleValue ?? record.floors?.count?.doubleValue
            )
        case .altitude:
            return intervalSample(
                record.altitude?.interval,
                value: record.altitude?.meters?.doubleValue
                    ?? record.altitude?.millimeters.map { $0.doubleValue / 1_000 }
                    ?? record.altitude?.value?.doubleValue
            )
        case .sedentaryPeriod:
            return intervalSample(
                record.sedentaryPeriod?.interval,
                value: record.sedentaryPeriod?.minutes?.doubleValue
                    ?? record.sedentaryPeriod?.durationSeconds.map { $0.doubleValue / 60 }
                    ?? record.sedentaryPeriod?.durationMillis.map { $0.doubleValue / 60_000 }
            )
        case .activityLevel:
            return dailySample(
                date: record.activityLevel?.date,
                calendar: calendar,
                value: record.activityLevel?.minutes?.doubleValue
                    ?? record.activityLevel?.durationMillis.map { $0.doubleValue / 60_000 }
            )
        case .swimLengthsData:
            return intervalSample(
                record.swimLengthsData?.interval,
                value: record.swimLengthsData?.lengths?.doubleValue ?? record.swimLengthsData?.count?.doubleValue
            )
        case .caloriesInHeartRateZone:
            return intervalSample(
                record.caloriesInHeartRateZone?.interval,
                value: record.caloriesInHeartRateZone?.caloriesKcal?.doubleValue
                    ?? record.caloriesInHeartRateZone?.kcal?.doubleValue
            )
        case .timeInHeartRateZone:
            return intervalSample(
                record.timeInHeartRateZone?.interval,
                value: record.timeInHeartRateZone?.minutes?.doubleValue
                    ?? record.timeInHeartRateZone?.durationMillis.map { $0.doubleValue / 60_000 }
            )
        case .exercise, .dailyHeartRateZones, .sleep:
            return nil
        }
    }

    private static func sample(date: Date?, value: Double?) -> (date: Date, endDate: Date?, value: Double)? {
        guard let date, let value else { return nil }
        return (date, nil, value)
    }

    private static func dailySample(
        date: GoogleHealthCivilDate?,
        calendar: Calendar,
        value: Double?
    ) -> (date: Date, endDate: Date?, value: Double)? {
        guard let date = date?.date(calendar: calendar), let value else { return nil }
        return (date, nil, value)
    }

    private static func intervalSample(
        _ interval: GoogleHealthSessionTimeInterval?,
        value: Double?
    ) -> (date: Date, endDate: Date?, value: Double)? {
        guard let start = interval?.startTime, let value else { return nil }
        return (start, interval?.endTime, value)
    }

    private static func scalarSample(
        _ sample: GoogleHealthScalarSample?,
        calendar: Calendar
    ) -> (date: Date, endDate: Date?, value: Double)? {
        guard let sample else { return nil }
        return self.sample(
            date: sample.sampleTime?.physicalTime ?? sample.measurementTime?.physicalTime,
            value: sample.preferredValue
        )
    }

    private static func dailyScalarSample(
        _ sample: GoogleHealthDailyScalar?,
        calendar: Calendar
    ) -> (date: Date, endDate: Date?, value: Double)? {
        dailySample(date: sample?.date, calendar: calendar, value: sample?.preferredValue)
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

private extension GoogleHealthScalarRollup {
    var preferredScalarValue: Double? {
        let values: [Double?] = [
            valueAvg?.doubleValue,
            valueMax?.doubleValue,
            valueMin?.doubleValue,
            valueSum?.doubleValue,
            metersAvg?.doubleValue,
            metersMax?.doubleValue,
            metersMin?.doubleValue,
            millimetersAvg.map { $0.doubleValue / 1_000 },
            millimetersMax.map { $0.doubleValue / 1_000 },
            millimetersMin.map { $0.doubleValue / 1_000 },
            bpmAvg?.doubleValue,
            bpmMax?.doubleValue,
            bpmMin?.doubleValue,
            beatsPerMinuteAvg?.doubleValue,
            beatsPerMinuteMax?.doubleValue,
            beatsPerMinuteMin?.doubleValue,
            percentageAvg?.doubleValue,
            percentageMax?.doubleValue,
            percentageMin?.doubleValue,
            millisecondsAvg?.doubleValue,
            millisecondsMax?.doubleValue,
            millisecondsMin?.doubleValue,
            kilogramsAvg?.doubleValue,
            kilogramsMax?.doubleValue,
            kilogramsMin?.doubleValue,
            mgPerDLAvg?.doubleValue,
            mgPerDLMax?.doubleValue,
            mgPerDLMin?.doubleValue,
            celsiusAvg?.doubleValue,
            celsiusMax?.doubleValue,
            celsiusMin?.doubleValue
        ]
        return values.compactMap { $0 }.first
    }
}

private extension GoogleHealthScalarSample {
    var preferredValue: Double? {
        let values: [Double?] = [
            value?.doubleValue,
            percentage?.doubleValue,
            milliseconds?.doubleValue,
            kilograms?.doubleValue,
            meters?.doubleValue,
            millimeters.map { $0.doubleValue / 1_000 },
            beatsPerMinute?.doubleValue,
            breathsPerMinute?.doubleValue,
            mgPerDL?.doubleValue,
            celsius?.doubleValue,
            mlPerMinPerKg?.doubleValue
        ]
        return values.compactMap { $0 }.first
    }
}

private extension GoogleHealthDailyScalar {
    var preferredValue: Double? {
        let values: [Double?] = [
            value?.doubleValue,
            percentage?.doubleValue,
            milliseconds?.doubleValue,
            beatsPerMinute?.doubleValue,
            breathsPerMinute?.doubleValue,
            celsius?.doubleValue,
            mlPerMinPerKg?.doubleValue
        ]
        return values.compactMap { $0 }.first
    }
}

private extension GoogleHealthDataType {
    static var activitySeriesTypes: [GoogleHealthDataType] {
        [
            .activeEnergyBurned,
            .activeMinutes,
            .activeZoneMinutes,
            .steps,
            .distance,
            .floors,
            .altitude,
            .sedentaryPeriod,
            .activityLevel,
            .swimLengthsData,
            .totalCalories,
            .timeInHeartRateZone,
            .caloriesInHeartRateZone
        ]
    }

    static var activityRecordSeriesTypes: [GoogleHealthDataType] {
        [
            .sedentaryPeriod,
            .activityLevel
        ]
    }

    static var healthSeriesTypes: [GoogleHealthDataType] {
        [
            .heartRate,
            .dailyRestingHeartRate,
            .heartRateVariability,
            .dailyHeartRateVariability,
            .dailyHeartRateZones,
            .dailySleepTemperatureDerivations,
            .oxygenSaturation,
            .dailyOxygenSaturation,
            .respiratoryRateSleepSummary,
            .dailyRespiratoryRate,
            .vo2Max,
            .dailyVo2Max,
            .runVo2Max,
            .weight,
            .bodyFat,
            .height,
            .bloodGlucose,
            .coreBodyTemperature
        ]
    }
}
