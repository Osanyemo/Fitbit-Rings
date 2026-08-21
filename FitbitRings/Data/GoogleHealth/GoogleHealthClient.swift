import Foundation

protocol GoogleHealthServing {
    func fetchDashboard(goals: ActivityGoals, date: Date) async throws -> DashboardSnapshot
    func fetchActivityData(date: Date) async throws -> ActivityDashboardData
    func fetchWorkoutData(date: Date) async throws -> [WorkoutDetail]
    func fetchHealthData(date: Date) async throws -> HealthDashboardData
    func fetchEarlierMetricSeries(_ type: GoogleHealthDataType, before: Date) async throws -> NumericMetricSeries
}

extension GoogleHealthServing {
    func fetchActivityData(date: Date) async throws -> ActivityDashboardData {
        ActivityDashboardData.empty
    }

    func fetchWorkoutData(date: Date) async throws -> [WorkoutDetail] {
        []
    }

    func fetchHealthData(date: Date) async throws -> HealthDashboardData {
        HealthDashboardData.empty
    }

    func fetchEarlierMetricSeries(_ type: GoogleHealthDataType, before: Date) async throws -> NumericMetricSeries {
        NumericMetricSeries(type: type, rangeEnd: before)
    }
}

final class GoogleHealthClient: GoogleHealthServing {
    private let networkClient: HTTPClient
    private let endpoint = GoogleHealthEndpoint()
    private let calendar: Calendar
    private let encoder = JSONEncoder()

    init(networkClient: HTTPClient, calendar: Calendar = .current) {
        self.networkClient = networkClient
        self.calendar = calendar
    }

    func fetchDashboard(goals: ActivityGoals, date: Date) async throws -> DashboardSnapshot {
        let interval = dayInterval(for: date)

        async let steps = dailyRollUp(.steps, interval: interval)
        async let activeMinutes = dailyRollUp(.activeMinutes, interval: interval)
        async let activeEnergy = dailyRollUp(.activeEnergyBurned, interval: interval)
        async let distance = dailyRollUp(.distance, interval: interval)
        async let totalCalories = dailyRollUp(.totalCalories, interval: interval)
        async let workout = latestRecord(.exercise, interval: recentInterval(days: 14, endingAt: date))
        async let heartRate = latestRecord(.heartRate, interval: recentInterval(days: 1, endingAt: date))
        async let restingHeartRate = latestRecord(.dailyRestingHeartRate, interval: recentInterval(days: 7, endingAt: date))
        async let sleep = latestRecord(.sleep, interval: recentInterval(days: 2, endingAt: date))

        let rollups: [GoogleHealthDataType: GoogleHealthRollUpResponse] = [
            .steps: try await steps,
            .activeMinutes: try await activeMinutes,
            .activeEnergyBurned: try await activeEnergy,
            .distance: try await distance,
            .totalCalories: try await totalCalories
        ]

        let latestWorkout = try await workout
        let latestHeartRate = try await heartRate
        let latestRestingHeartRate = try await restingHeartRate
        let latestSleep = try await sleep

        return GoogleHealthMapper.map(
            goals: goals,
            date: date,
            rollups: rollups,
            latestWorkout: latestWorkout,
            latestHeartRate: latestHeartRate,
            restingHeartRate: latestRestingHeartRate,
            sleep: latestSleep
        )
    }

    func fetchActivityData(date: Date) async throws -> ActivityDashboardData {
        let range = recentInterval(days: 14, endingAt: date)
        let today = dayInterval(for: date)

        var dailyRollups: [GoogleHealthDataType: GoogleHealthRollUpResponse] = [:]
        var hourlyRollups: [GoogleHealthDataType: GoogleHealthRollUpResponse] = [:]
        var records: [GoogleHealthDataType: [GoogleHealthDataPoint]] = [:]

        for type in Self.activityRollupTypes {
            if let response = try await optionalData({ try await dailyRollUpAll(type, interval: range) }) {
                dailyRollups[type] = response
            }
        }

        for type in [GoogleHealthDataType.steps, .distance] {
            if let response = try await optionalData({ try await rollUpAll(type, interval: today, windowSize: "3600s") }) {
                hourlyRollups[type] = response
            }
        }

        for type in Self.activityReconcileTypes {
            if let response = try await optionalData({ try await reconcileAll(type, interval: range) }) {
                records[type] = response.dataPoints
            }
        }

        return GoogleHealthMapper.mapActivityData(
            dailyRollups: dailyRollups,
            hourlyRollups: hourlyRollups,
            records: records,
            range: range,
            calendar: calendar
        )
    }

    func fetchWorkoutData(date: Date) async throws -> [WorkoutDetail] {
        let range = recentInterval(days: 14, endingAt: date)
        let response = try await reconcileAll(.exercise, interval: range, pageSize: 25)
        return GoogleHealthMapper.mapWorkouts(response.dataPoints)
    }

    func fetchHealthData(date: Date) async throws -> HealthDashboardData {
        let range = recentInterval(days: 14, endingAt: date)
        var records: [GoogleHealthDataType: [GoogleHealthDataPoint]] = [:]

        for type in Self.healthReconcileTypes {
            if let response = try await optionalData({ try await reconcileAll(type, interval: range) }) {
                records[type] = response.dataPoints
            }
        }

        if let sleepResponse = try await optionalData({ try await reconcileAll(.sleep, interval: range, pageSize: 25) }) {
            records[.sleep] = sleepResponse.dataPoints
        }

        return GoogleHealthMapper.mapHealthData(
            records: records,
            range: range,
            calendar: calendar
        )
    }

    func fetchEarlierMetricSeries(
        _ type: GoogleHealthDataType,
        before: Date
    ) async throws -> NumericMetricSeries {
        let range = recentInterval(days: 14, endingAt: before)

        switch type.defaultQueryStrategy {
        case .dailyRollUp, .rollUp:
            let response = try await dailyRollUpAll(type, interval: range)
            return GoogleHealthMapper.mapRollupSeries(type, response: response, range: range)
        case .reconcile:
            let response = try await reconcileAll(type, interval: range)
            return GoogleHealthMapper.metricSeries(type, from: response.dataPoints, range: range, calendar: calendar)
        }
    }

    private func dailyRollUp(
        _ dataType: GoogleHealthDataType,
        interval: DateInterval,
        pageSize: Int? = nil,
        pageToken: String? = nil
    ) async throws -> GoogleHealthRollUpResponse {
        var request = try endpoint.request(
            path: "users/me/dataTypes/\(dataType.endpointIdentifier)/dataPoints:dailyRollUp"
        )
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try encoder.encode(
            GoogleHealthDailyRollUpRequest(
                range: civilTimeInterval(for: interval),
                pageSize: pageSize,
                pageToken: pageToken
            )
        )

        return try await networkClient.send(request, decoding: GoogleHealthRollUpResponse.self)
    }

    private func dailyRollUpAll(
        _ dataType: GoogleHealthDataType,
        interval: DateInterval,
        pageSize: Int? = nil
    ) async throws -> GoogleHealthRollUpResponse {
        var allPoints: [GoogleHealthRollupDataPoint] = []
        var pageToken: String?
        var nextPageToken: String?

        repeat {
            let response = try await dailyRollUp(
                dataType,
                interval: interval,
                pageSize: pageSize,
                pageToken: pageToken
            )
            allPoints.append(contentsOf: response.rollupDataPoints)
            nextPageToken = response.nextPageToken?.nilIfEmpty
            pageToken = nextPageToken
        } while nextPageToken != nil

        return GoogleHealthRollUpResponse(rollupDataPoints: allPoints)
    }

    private func rollUp(
        _ dataType: GoogleHealthDataType,
        interval: DateInterval,
        windowSize: String,
        pageSize: Int? = nil,
        pageToken: String? = nil
    ) async throws -> GoogleHealthRollUpResponse {
        var request = try endpoint.request(
            path: "users/me/dataTypes/\(dataType.endpointIdentifier)/dataPoints:rollUp"
        )
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try encoder.encode(
            GoogleHealthRollUpRequest(
                range: physicalTimeInterval(for: interval),
                windowSize: windowSize,
                pageSize: pageSize,
                pageToken: pageToken,
                dataSourceFamily: nil
            )
        )

        return try await networkClient.send(request, decoding: GoogleHealthRollUpResponse.self)
    }

    private func rollUpAll(
        _ dataType: GoogleHealthDataType,
        interval: DateInterval,
        windowSize: String
    ) async throws -> GoogleHealthRollUpResponse {
        var allPoints: [GoogleHealthRollupDataPoint] = []
        var pageToken: String?
        var nextPageToken: String?

        repeat {
            let response = try await rollUp(
                dataType,
                interval: interval,
                windowSize: windowSize,
                pageToken: pageToken
            )
            allPoints.append(contentsOf: response.rollupDataPoints)
            nextPageToken = response.nextPageToken?.nilIfEmpty
            pageToken = nextPageToken
        } while nextPageToken != nil

        return GoogleHealthRollUpResponse(rollupDataPoints: allPoints)
    }

    private func latestRecord(
        _ dataType: GoogleHealthDataType,
        interval: DateInterval
    ) async throws -> GoogleHealthDataPoint? {
        try await reconcile(dataType, interval: interval, pageSize: 1).dataPoints.first
    }

    private func reconcile(
        _ dataType: GoogleHealthDataType,
        interval: DateInterval,
        pageSize: Int? = nil,
        pageToken: String? = nil
    ) async throws -> GoogleHealthListResponse {
        let cappedPageSize = pageSize.map { dataType.isPageLimitedToTwentyFive ? min($0, 25) : $0 }
        var queryItems = [
            URLQueryItem(name: "filter", value: filter(for: dataType, interval: interval))
        ]

        if let cappedPageSize {
            queryItems.append(URLQueryItem(name: "pageSize", value: "\(cappedPageSize)"))
        } else if dataType.isPageLimitedToTwentyFive {
            queryItems.append(URLQueryItem(name: "pageSize", value: "25"))
        }

        if let pageToken {
            queryItems.append(URLQueryItem(name: "pageToken", value: pageToken))
        }

        let request = try endpoint.request(
            path: "users/me/dataTypes/\(dataType.endpointIdentifier)/dataPoints:reconcile",
            queryItems: queryItems
        )

        return try await networkClient.send(request, decoding: GoogleHealthListResponse.self)
    }

    private func reconcileAll(
        _ dataType: GoogleHealthDataType,
        interval: DateInterval,
        pageSize: Int? = nil
    ) async throws -> GoogleHealthListResponse {
        var pointsByID: [String: GoogleHealthDataPoint] = [:]
        var orderedIDs: [String] = []
        var pageToken: String?
        var nextPageToken: String?

        repeat {
            let response = try await reconcile(
                dataType,
                interval: interval,
                pageSize: pageSize,
                pageToken: pageToken
            )

            for point in response.dataPoints {
                let id = point.identifier
                if pointsByID[id] == nil {
                    orderedIDs.append(id)
                }
                pointsByID[id] = point
            }

            nextPageToken = response.nextPageToken?.nilIfEmpty
            pageToken = nextPageToken
        } while nextPageToken != nil

        return GoogleHealthListResponse(dataPoints: orderedIDs.compactMap { pointsByID[$0] })
    }

    private func dayInterval(for date: Date) -> DateInterval {
        calendar.dateInterval(of: .day, for: date) ?? DateInterval(start: date, duration: 86_400)
    }

    private func recentInterval(days: Int, endingAt date: Date) -> DateInterval {
        DateInterval(start: calendar.date(byAdding: .day, value: -days, to: date) ?? date, end: date)
    }

    private func physicalTimeInterval(for interval: DateInterval) -> GoogleHealthPhysicalTimeInterval {
        GoogleHealthPhysicalTimeInterval(
            startTime: ISO8601DateFormatter.googleHealth.string(from: interval.start),
            endTime: ISO8601DateFormatter.googleHealth.string(from: interval.end)
        )
    }

    private func civilTimeInterval(for interval: DateInterval) -> GoogleHealthCivilTimeInterval {
        GoogleHealthCivilTimeInterval(
            start: civilDateTime(for: interval.start),
            end: civilDateTime(for: interval.end)
        )
    }

    private func civilDateTime(for date: Date) -> GoogleHealthCivilDateTime {
        let components = calendar.dateComponents([.year, .month, .day], from: date)
        return GoogleHealthCivilDateTime(
            date: GoogleHealthCivilDate(
                year: components.year ?? 1970,
                month: components.month ?? 1,
                day: components.day ?? 1
            ),
            time: GoogleHealthTimeOfDay(hours: 0, minutes: 0, seconds: 0)
        )
    }

    private func filter(for dataType: GoogleHealthDataType, interval: DateInterval) -> String {
        if dataType.usesCivilDateFilter {
            return civilDateFilter(
                field: dataType.defaultFilterField,
                interval: interval
            )
        }

        return physicalTimeFilter(
            field: dataType.defaultFilterField,
            interval: interval
        )
    }

    private func optionalData<T>(_ load: () async throws -> T) async throws -> T? {
        do {
            return try await load()
        } catch {
            if error.isCancellation || error.isAuthenticationFailure {
                throw error
            }
            return nil
        }
    }

    private func physicalTimeFilter(field: String, interval: DateInterval) -> String {
        "\(field) >= \"\(interval.start.googleHealthQueryValue)\" AND \(field) < \"\(interval.end.googleHealthQueryValue)\""
    }

    private func civilDateFilter(field: String, interval: DateInterval) -> String {
        let endDate = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: interval.end))
            ?? interval.end
        return "\(field) >= \"\(interval.start.googleHealthCivilDateValue(calendar: calendar))\" AND \(field) < \"\(endDate.googleHealthCivilDateValue(calendar: calendar))\""
    }
}

private extension Date {
    var googleHealthQueryValue: String {
        ISO8601DateFormatter.googleHealth.string(from: self)
    }

    func googleHealthCivilDateValue(calendar: Calendar) -> String {
        let components = calendar.dateComponents([.year, .month, .day], from: self)
        return String(
            format: "%04d-%02d-%02d",
            components.year ?? 1970,
            components.month ?? 1,
            components.day ?? 1
        )
    }
}

private extension GoogleHealthClient {
    static let activityRollupTypes: [GoogleHealthDataType] = [
        .activeEnergyBurned,
        .activeMinutes,
        .activeZoneMinutes,
        .steps,
        .distance,
        .floors,
        .altitude,
        .swimLengthsData,
        .totalCalories,
        .timeInHeartRateZone,
        .caloriesInHeartRateZone
    ]

    static let activityReconcileTypes: [GoogleHealthDataType] = [
        .sedentaryPeriod,
        .activityLevel
    ]

    static let healthReconcileTypes: [GoogleHealthDataType] = [
        .heartRate,
        .dailyRestingHeartRate,
        .heartRateVariability,
        .dailyHeartRateVariability,
        .dailyHeartRateZones,
        .oxygenSaturation,
        .dailyOxygenSaturation,
        .respiratoryRateSleepSummary,
        .dailyRespiratoryRate,
        .dailySleepTemperatureDerivations,
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

private extension String {
    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }
}

private extension Error {
    var isCancellation: Bool {
        if self is CancellationError {
            return true
        }

        if let urlError = self as? URLError, urlError.code == .cancelled {
            return true
        }

        let nsError = self as NSError
        return nsError.domain == NSURLErrorDomain && nsError.code == NSURLErrorCancelled
    }

    var isAuthenticationFailure: Bool {
        if let networkError = self as? NetworkError, networkError == .unauthenticated {
            return true
        }

        return false
    }
}
