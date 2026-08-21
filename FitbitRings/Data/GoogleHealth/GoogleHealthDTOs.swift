import Foundation

struct GoogleHealthRollUpResponse: Decodable {
    var rollupDataPoints: [GoogleHealthRollupDataPoint]
}

struct GoogleHealthRollupDataPoint: Decodable {
    var steps: GoogleHealthStepsRollup?
    var activeMinutes: GoogleHealthActiveMinutesRollup?
    var activeEnergyBurned: GoogleHealthEnergyRollup?
    var distance: GoogleHealthDistanceRollup?
    var totalCalories: GoogleHealthEnergyRollup?
}

struct GoogleHealthStepsRollup: Decodable {
    var countSum: GoogleHealthNumericValue?
}

struct GoogleHealthActiveMinutesRollup: Decodable {
    var activeMinutesRollupByActivityLevel: [GoogleHealthActiveMinutesByActivityLevel]
}

struct GoogleHealthActiveMinutesByActivityLevel: Decodable {
    var activityLevel: String?
    var activeMinutesSum: GoogleHealthNumericValue?
}

struct GoogleHealthEnergyRollup: Decodable {
    var kcalSum: Double?
}

struct GoogleHealthDistanceRollup: Decodable {
    var millimetersSum: GoogleHealthNumericValue?
}

struct GoogleHealthListResponse: Decodable {
    var dataPoints: [GoogleHealthDataPoint]
}

struct GoogleHealthDataPoint: Decodable {
    var name: String?
    var heartRate: GoogleHealthHeartRate?
    var dailyRestingHeartRate: GoogleHealthDailyRestingHeartRate?
    var sleep: GoogleHealthSleep?
    var exercise: GoogleHealthExercise?
}

struct GoogleHealthHeartRate: Decodable {
    var sampleTime: GoogleHealthObservationSampleTime?
    var beatsPerMinute: GoogleHealthNumericValue?
}

struct GoogleHealthDailyRestingHeartRate: Decodable {
    var beatsPerMinute: GoogleHealthNumericValue?
}

struct GoogleHealthSleep: Decodable {
    var interval: GoogleHealthSessionTimeInterval?
    var summary: GoogleHealthSleepSummary?
}

struct GoogleHealthSleepSummary: Decodable {
    var minutesAsleep: GoogleHealthNumericValue?
    var minutesInSleepPeriod: GoogleHealthNumericValue?
}

struct GoogleHealthExercise: Decodable {
    var interval: GoogleHealthSessionTimeInterval?
    var exerciseType: String?
    var displayName: String?
    var activeDuration: String?
    var metricsSummary: GoogleHealthMetricsSummary?
}

struct GoogleHealthMetricsSummary: Decodable {
    var caloriesKcal: Double?
    var distanceMillimeters: Double?
}

struct GoogleHealthObservationSampleTime: Decodable {
    var physicalTime: Date?
}

struct GoogleHealthSessionTimeInterval: Decodable {
    var startTime: Date?
    var endTime: Date?
}

struct GoogleHealthNumericValue: Decodable, Equatable {
    var doubleValue: Double

    var intValue: Int {
        Int(doubleValue.rounded())
    }

    init(_ value: Double) {
        doubleValue = value
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let double = try? container.decode(Double.self) {
            doubleValue = double
        } else if let string = try? container.decode(String.self), let double = Double(string) {
            doubleValue = double
        } else {
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Expected numeric value encoded as a number or string."
            )
        }
    }
}

struct GoogleHealthDailyRollUpRequest: Encodable {
    var range: GoogleHealthCivilTimeInterval
    var windowSizeDays: Int = 1
}

struct GoogleHealthCivilTimeInterval: Encodable {
    var start: GoogleHealthCivilDateTime
    var end: GoogleHealthCivilDateTime
}

struct GoogleHealthCivilDateTime: Encodable {
    var date: GoogleHealthCivilDate
    var time: GoogleHealthTimeOfDay?
}

struct GoogleHealthCivilDate: Encodable {
    var year: Int
    var month: Int
    var day: Int
}

struct GoogleHealthTimeOfDay: Encodable {
    var hours: Int
    var minutes: Int
    var seconds: Int
    var nanos: Int = 0
}
