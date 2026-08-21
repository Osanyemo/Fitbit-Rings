import Foundation

protocol GoogleHealthServing {
    func fetchDashboard(goals: ActivityGoals, date: Date) async throws -> DashboardSnapshot
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

    private func dailyRollUp(
        _ dataType: GoogleHealthDataType,
        interval: DateInterval
    ) async throws -> GoogleHealthRollUpResponse {
        var request = try endpoint.request(
            path: "users/me/dataTypes/\(dataType.rawValue)/dataPoints:dailyRollUp"
        )
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try encoder.encode(
            GoogleHealthDailyRollUpRequest(range: civilTimeInterval(for: interval))
        )

        return try await networkClient.send(request, decoding: GoogleHealthRollUpResponse.self)
    }

    private func latestRecord(
        _ dataType: GoogleHealthDataType,
        interval: DateInterval
    ) async throws -> GoogleHealthDataPoint? {
        let request = try endpoint.request(
            path: "users/me/dataTypes/\(dataType.rawValue)/dataPoints",
            queryItems: [
                URLQueryItem(name: "filter", value: filter(for: dataType, interval: interval)),
                URLQueryItem(name: "pageSize", value: "1")
            ]
        )

        return try await networkClient
            .send(request, decoding: GoogleHealthListResponse.self)
            .dataPoints
            .first
    }

    private func dayInterval(for date: Date) -> DateInterval {
        calendar.dateInterval(of: .day, for: date) ?? DateInterval(start: date, duration: 86_400)
    }

    private func recentInterval(days: Int, endingAt date: Date) -> DateInterval {
        DateInterval(start: calendar.date(byAdding: .day, value: -days, to: date) ?? date, end: date)
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
        switch dataType {
        case .heartRate:
            return physicalTimeFilter(
                field: "heart_rate.sample_time.physical_time",
                interval: interval
            )
        case .dailyRestingHeartRate:
            return civilDateFilter(
                field: "daily_resting_heart_rate.date",
                interval: interval
            )
        case .exercise:
            return civilDateFilter(
                field: "exercise.interval.civil_start_time",
                interval: interval
            )
        case .sleep:
            return physicalTimeFilter(
                field: "sleep.interval.end_time",
                interval: interval
            )
        case .steps, .activeMinutes, .activeEnergyBurned, .distance, .totalCalories:
            return physicalTimeFilter(
                field: "\(dataType.filterName).interval.start_time",
                interval: interval
            )
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

private extension GoogleHealthDataType {
    var filterName: String {
        switch self {
        case .steps:
            return "steps"
        case .activeMinutes:
            return "active_minutes"
        case .activeEnergyBurned:
            return "active_energy_burned"
        case .distance:
            return "distance"
        case .totalCalories:
            return "total_calories"
        case .exercise:
            return "exercise"
        case .heartRate:
            return "heart_rate"
        case .dailyRestingHeartRate:
            return "daily_resting_heart_rate"
        case .sleep:
            return "sleep"
        }
    }
}
