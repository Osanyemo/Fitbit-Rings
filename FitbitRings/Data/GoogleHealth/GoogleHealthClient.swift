import Foundation

protocol GoogleHealthServing {
    func fetchDashboard(goals: ActivityGoals, date: Date) async throws -> DashboardSnapshot
}

final class GoogleHealthClient: GoogleHealthServing {
    private let networkClient: HTTPClient
    private let endpoint = GoogleHealthEndpoint()
    private let calendar: Calendar

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
        let request = try endpoint.request(
            path: "users/me/dataTypes/\(dataType.rawValue):dailyRollUp",
            queryItems: [
                URLQueryItem(name: "startTime", value: interval.start.googleHealthQueryValue),
                URLQueryItem(name: "endTime", value: interval.end.googleHealthQueryValue)
            ]
        )

        return try await networkClient.send(request, decoding: GoogleHealthRollUpResponse.self)
    }

    private func latestRecord(
        _ dataType: GoogleHealthDataType,
        interval: DateInterval
    ) async throws -> GoogleHealthRecord? {
        let request = try endpoint.request(
            path: "users/me/dataTypes/\(dataType.rawValue)/records",
            queryItems: [
                URLQueryItem(name: "startTime", value: interval.start.googleHealthQueryValue),
                URLQueryItem(name: "endTime", value: interval.end.googleHealthQueryValue),
                URLQueryItem(name: "orderBy", value: "endTime desc"),
                URLQueryItem(name: "pageSize", value: "1")
            ]
        )

        return try await networkClient
            .send(request, decoding: GoogleHealthListResponse.self)
            .records
            .first
    }

    private func dayInterval(for date: Date) -> DateInterval {
        calendar.dateInterval(of: .day, for: date) ?? DateInterval(start: date, duration: 86_400)
    }

    private func recentInterval(days: Int, endingAt date: Date) -> DateInterval {
        DateInterval(start: calendar.date(byAdding: .day, value: -days, to: date) ?? date, end: date)
    }
}

private extension Date {
    var googleHealthQueryValue: String {
        ISO8601DateFormatter.googleHealth.string(from: self)
    }
}
