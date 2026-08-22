import Foundation

struct GoogleHealthRollUpResponse: Decodable {
    var rollupDataPoints: [GoogleHealthRollupDataPoint]
    var nextPageToken: String? = nil

    private enum CodingKeys: String, CodingKey {
        case rollupDataPoints
        case nextPageToken
    }

    init(rollupDataPoints: [GoogleHealthRollupDataPoint] = [], nextPageToken: String? = nil) {
        self.rollupDataPoints = rollupDataPoints
        self.nextPageToken = nextPageToken
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        rollupDataPoints = try container.decodeIfPresent(
            [GoogleHealthRollupDataPoint].self,
            forKey: .rollupDataPoints
        ) ?? []
        nextPageToken = try container.decodeIfPresent(String.self, forKey: .nextPageToken)
    }
}

struct GoogleHealthRollupDataPoint: Decodable {
    var startTime: Date? = nil
    var endTime: Date? = nil
    var civilStartTime: GoogleHealthCivilDateTime? = nil
    var civilEndTime: GoogleHealthCivilDateTime? = nil
    var steps: GoogleHealthStepsRollup? = nil
    var activeMinutes: GoogleHealthActiveMinutesRollup? = nil
    var activeEnergyBurned: GoogleHealthEnergyRollup? = nil
    var distance: GoogleHealthDistanceRollup? = nil
    var totalCalories: GoogleHealthEnergyRollup? = nil
    var activeZoneMinutes: GoogleHealthActiveZoneMinutesRollup? = nil
    var caloriesInHeartRateZone: GoogleHealthZoneEnergyRollup? = nil
    var timeInHeartRateZone: GoogleHealthHeartZoneRollup? = nil
    var floors: GoogleHealthCountRollup? = nil
    var altitude: GoogleHealthScalarRollup? = nil
    var sedentaryPeriod: GoogleHealthDurationRollup? = nil
    var activityLevel: GoogleHealthBucketedRollup? = nil
    var swimLengthsData: GoogleHealthCountRollup? = nil
    var heartRate: GoogleHealthHeartRateRollup? = nil
    var heartRateVariability: GoogleHealthScalarRollup? = nil
    var oxygenSaturation: GoogleHealthScalarRollup? = nil
    var respiratoryRateSleepSummary: GoogleHealthScalarRollup? = nil
    var vo2Max: GoogleHealthScalarRollup? = nil
    var runVo2Max: GoogleHealthScalarRollup? = nil
    var weight: GoogleHealthScalarRollup? = nil
    var bodyFat: GoogleHealthScalarRollup? = nil
    var height: GoogleHealthScalarRollup? = nil
    var bloodGlucose: GoogleHealthScalarRollup? = nil
    var coreBodyTemperature: GoogleHealthScalarRollup? = nil
}

struct GoogleHealthStepsRollup: Decodable {
    var countSum: GoogleHealthNumericValue?
}

struct GoogleHealthActiveMinutesRollup: Decodable {
    var activeMinutesRollupByActivityLevel: [GoogleHealthActiveMinutesByActivityLevel]

    private enum CodingKeys: String, CodingKey {
        case activeMinutesRollupByActivityLevel
    }

    init(activeMinutesRollupByActivityLevel: [GoogleHealthActiveMinutesByActivityLevel] = []) {
        self.activeMinutesRollupByActivityLevel = activeMinutesRollupByActivityLevel
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        activeMinutesRollupByActivityLevel = try container.decodeIfPresent(
            [GoogleHealthActiveMinutesByActivityLevel].self,
            forKey: .activeMinutesRollupByActivityLevel
        ) ?? []
    }
}

struct GoogleHealthActiveMinutesByActivityLevel: Decodable {
    var activityLevel: String?
    var activeMinutesSum: GoogleHealthNumericValue?
}

struct GoogleHealthEnergyRollup: Decodable {
    var kcalSum: Double?

    private enum CodingKeys: String, CodingKey {
        case kcalSum
    }

    init(kcalSum: Double?) {
        self.kcalSum = kcalSum
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        kcalSum = try container.decodeGoogleHealthDoubleIfPresent(forKey: .kcalSum)
    }
}

struct GoogleHealthDistanceRollup: Decodable {
    var millimetersSum: GoogleHealthNumericValue?
}

struct GoogleHealthActiveZoneMinutesRollup: Decodable {
    var activeZoneMinutesSum: GoogleHealthNumericValue?
    var fatBurnMinutesSum: GoogleHealthNumericValue?
    var cardioMinutesSum: GoogleHealthNumericValue?
    var peakMinutesSum: GoogleHealthNumericValue?
}

struct GoogleHealthZoneEnergyRollup: Decodable {
    var caloriesKcalSum: GoogleHealthNumericValue?
    var kcalSum: GoogleHealthNumericValue?
    var heartRateZone: String?
}

struct GoogleHealthHeartZoneRollup: Decodable {
    var minutesSum: GoogleHealthNumericValue?
    var durationMillisSum: GoogleHealthNumericValue?
    var heartRateZone: String?
}

struct GoogleHealthCountRollup: Decodable {
    var countSum: GoogleHealthNumericValue?
    var floorsSum: GoogleHealthNumericValue?
    var lengthsSum: GoogleHealthNumericValue?
}

struct GoogleHealthDurationRollup: Decodable {
    var durationMillisSum: GoogleHealthNumericValue?
    var durationSecondsSum: GoogleHealthNumericValue?
    var minutesSum: GoogleHealthNumericValue?
}

struct GoogleHealthBucketedRollup: Decodable {
    var activityLevel: String?
    var durationMillisSum: GoogleHealthNumericValue?
    var minutesSum: GoogleHealthNumericValue?
}

struct GoogleHealthScalarRollup: Decodable {
    var valueMin: GoogleHealthNumericValue?
    var valueAvg: GoogleHealthNumericValue?
    var valueMax: GoogleHealthNumericValue?
    var valueSum: GoogleHealthNumericValue?
    var countSum: GoogleHealthNumericValue?
    var millimetersMin: GoogleHealthNumericValue?
    var millimetersAvg: GoogleHealthNumericValue?
    var millimetersMax: GoogleHealthNumericValue?
    var metersMin: GoogleHealthNumericValue?
    var metersAvg: GoogleHealthNumericValue?
    var metersMax: GoogleHealthNumericValue?
    var bpmMin: GoogleHealthNumericValue?
    var bpmAvg: GoogleHealthNumericValue?
    var bpmMax: GoogleHealthNumericValue?
    var beatsPerMinuteMin: GoogleHealthNumericValue?
    var beatsPerMinuteAvg: GoogleHealthNumericValue?
    var beatsPerMinuteMax: GoogleHealthNumericValue?
    var percentageMin: GoogleHealthNumericValue?
    var percentageAvg: GoogleHealthNumericValue?
    var percentageMax: GoogleHealthNumericValue?
    var millisecondsMin: GoogleHealthNumericValue?
    var millisecondsAvg: GoogleHealthNumericValue?
    var millisecondsMax: GoogleHealthNumericValue?
    var kilogramsMin: GoogleHealthNumericValue?
    var kilogramsAvg: GoogleHealthNumericValue?
    var kilogramsMax: GoogleHealthNumericValue?
    var mgPerDLMin: GoogleHealthNumericValue?
    var mgPerDLAvg: GoogleHealthNumericValue?
    var mgPerDLMax: GoogleHealthNumericValue?
    var celsiusMin: GoogleHealthNumericValue?
    var celsiusAvg: GoogleHealthNumericValue?
    var celsiusMax: GoogleHealthNumericValue?
}

struct GoogleHealthHeartRateRollup: Decodable {
    var beatsPerMinuteMin: GoogleHealthNumericValue?
    var beatsPerMinuteAvg: GoogleHealthNumericValue?
    var beatsPerMinuteMax: GoogleHealthNumericValue?
}

struct GoogleHealthListResponse: Decodable {
    var dataPoints: [GoogleHealthDataPoint]
    var nextPageToken: String? = nil

    private enum CodingKeys: String, CodingKey {
        case dataPoints
        case nextPageToken
    }

    init(dataPoints: [GoogleHealthDataPoint] = [], nextPageToken: String? = nil) {
        self.dataPoints = dataPoints
        self.nextPageToken = nextPageToken
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        dataPoints = try container.decodeIfPresent([GoogleHealthDataPoint].self, forKey: .dataPoints) ?? []
        nextPageToken = try container.decodeIfPresent(String.self, forKey: .nextPageToken)
    }
}

struct GoogleHealthDataPoint: Decodable {
    var name: String?
    var dataPointName: String?
    var steps: GoogleHealthSteps?
    var activeMinutes: GoogleHealthActiveMinutes?
    var activeEnergyBurned: GoogleHealthEnergy?
    var distance: GoogleHealthDistance?
    var totalCalories: GoogleHealthEnergy?
    var activeZoneMinutes: GoogleHealthActiveZoneMinutes?
    var timeInHeartRateZone: GoogleHealthTimeInHeartRateZone?
    var caloriesInHeartRateZone: GoogleHealthCaloriesInHeartRateZone?
    var floors: GoogleHealthCountInterval?
    var altitude: GoogleHealthScalarInterval?
    var sedentaryPeriod: GoogleHealthDurationInterval?
    var activityLevel: GoogleHealthActivityLevel?
    var swimLengthsData: GoogleHealthCountInterval?
    var heartRate: GoogleHealthHeartRate?
    var dailyRestingHeartRate: GoogleHealthDailyRestingHeartRate?
    var heartRateVariability: GoogleHealthScalarSample?
    var dailyHeartRateVariability: GoogleHealthDailyScalar?
    var dailyHeartRateZones: GoogleHealthDailyHeartRateZones?
    var oxygenSaturation: GoogleHealthScalarSample?
    var dailyOxygenSaturation: GoogleHealthDailyScalar?
    var respiratoryRateSleepSummary: GoogleHealthScalarSample?
    var dailyRespiratoryRate: GoogleHealthDailyScalar?
    var dailySleepTemperatureDerivations: GoogleHealthDailyScalar?
    var vo2Max: GoogleHealthScalarSample?
    var dailyVo2Max: GoogleHealthDailyScalar?
    var runVo2Max: GoogleHealthScalarSample?
    var weight: GoogleHealthScalarSample?
    var bodyFat: GoogleHealthScalarSample?
    var height: GoogleHealthScalarSample?
    var bloodGlucose: GoogleHealthScalarSample?
    var coreBodyTemperature: GoogleHealthScalarSample?
    var sleep: GoogleHealthSleep?
    var exercise: GoogleHealthExercise?
}

extension GoogleHealthDataPoint {
    var identifier: String {
        dataPointName ?? name ?? UUID().uuidString
    }
}

struct GoogleHealthSteps: Decodable {
    var interval: GoogleHealthSessionTimeInterval?
    var count: GoogleHealthNumericValue?
}

struct GoogleHealthActiveMinutes: Decodable {
    var interval: GoogleHealthSessionTimeInterval?
    var activeMinutes: GoogleHealthNumericValue?
    var activityLevel: String?
}

struct GoogleHealthEnergy: Decodable {
    var interval: GoogleHealthSessionTimeInterval?
    var kcal: GoogleHealthNumericValue?
    var caloriesKcal: GoogleHealthNumericValue?
}

struct GoogleHealthDistance: Decodable {
    var interval: GoogleHealthSessionTimeInterval?
    var millimeters: GoogleHealthNumericValue?
}

struct GoogleHealthActiveZoneMinutes: Decodable {
    var interval: GoogleHealthSessionTimeInterval?
    var activeZoneMinutes: GoogleHealthNumericValue?
    var fatBurnMinutes: GoogleHealthNumericValue?
    var cardioMinutes: GoogleHealthNumericValue?
    var peakMinutes: GoogleHealthNumericValue?
}

struct GoogleHealthTimeInHeartRateZone: Decodable {
    var interval: GoogleHealthSessionTimeInterval?
    var heartRateZone: String?
    var minutes: GoogleHealthNumericValue?
    var durationMillis: GoogleHealthNumericValue?
}

struct GoogleHealthCaloriesInHeartRateZone: Decodable {
    var interval: GoogleHealthSessionTimeInterval?
    var heartRateZone: String?
    var caloriesKcal: GoogleHealthNumericValue?
    var kcal: GoogleHealthNumericValue?
}

struct GoogleHealthCountInterval: Decodable {
    var interval: GoogleHealthSessionTimeInterval?
    var count: GoogleHealthNumericValue?
    var floors: GoogleHealthNumericValue?
    var lengths: GoogleHealthNumericValue?
}

struct GoogleHealthScalarInterval: Decodable {
    var interval: GoogleHealthSessionTimeInterval?
    var value: GoogleHealthNumericValue?
    var meters: GoogleHealthNumericValue?
    var millimeters: GoogleHealthNumericValue?
}

struct GoogleHealthDurationInterval: Decodable {
    var interval: GoogleHealthSessionTimeInterval?
    var durationMillis: GoogleHealthNumericValue?
    var durationSeconds: GoogleHealthNumericValue?
    var minutes: GoogleHealthNumericValue?
}

struct GoogleHealthActivityLevel: Decodable {
    var date: GoogleHealthCivilDate?
    var activityLevel: String?
    var durationMillis: GoogleHealthNumericValue?
    var minutes: GoogleHealthNumericValue?
}

struct GoogleHealthHeartRate: Decodable {
    var sampleTime: GoogleHealthObservationSampleTime?
    var beatsPerMinute: GoogleHealthNumericValue?
}

struct GoogleHealthDailyRestingHeartRate: Decodable {
    var date: GoogleHealthCivilDate?
    var beatsPerMinute: GoogleHealthNumericValue?
}

struct GoogleHealthScalarSample: Decodable {
    var sampleTime: GoogleHealthObservationSampleTime?
    var measurementTime: GoogleHealthObservationSampleTime?
    var value: GoogleHealthNumericValue?
    var percentage: GoogleHealthNumericValue?
    var milliseconds: GoogleHealthNumericValue?
    var kilograms: GoogleHealthNumericValue?
    var meters: GoogleHealthNumericValue?
    var millimeters: GoogleHealthNumericValue?
    var beatsPerMinute: GoogleHealthNumericValue?
    var breathsPerMinute: GoogleHealthNumericValue?
    var mgPerDL: GoogleHealthNumericValue?
    var celsius: GoogleHealthNumericValue?
    var mlPerMinPerKg: GoogleHealthNumericValue?
}

struct GoogleHealthDailyScalar: Decodable {
    var date: GoogleHealthCivilDate?
    var value: GoogleHealthNumericValue?
    var percentage: GoogleHealthNumericValue?
    var milliseconds: GoogleHealthNumericValue?
    var beatsPerMinute: GoogleHealthNumericValue?
    var breathsPerMinute: GoogleHealthNumericValue?
    var celsius: GoogleHealthNumericValue?
    var mlPerMinPerKg: GoogleHealthNumericValue?
}

struct GoogleHealthDailyHeartRateZones: Decodable {
    var date: GoogleHealthCivilDate?
    var zones: [GoogleHealthHeartRateZone]?
}

struct GoogleHealthHeartRateZone: Decodable {
    var zone: String?
    var minutes: GoogleHealthNumericValue?
    var durationMillis: GoogleHealthNumericValue?
}

struct GoogleHealthSleep: Decodable {
    var interval: GoogleHealthSessionTimeInterval?
    var summary: GoogleHealthSleepSummary?
    var stages: [GoogleHealthSleepStage]?
    var sleepStages: [GoogleHealthSleepStage]?
}

struct GoogleHealthSleepSummary: Decodable {
    var minutesAsleep: GoogleHealthNumericValue?
    var minutesInSleepPeriod: GoogleHealthNumericValue?
    var minutesAwake: GoogleHealthNumericValue?
    var minutesDeep: GoogleHealthNumericValue?
    var minutesLight: GoogleHealthNumericValue?
    var minutesRem: GoogleHealthNumericValue?
}

struct GoogleHealthSleepStage: Decodable {
    var stage: String?
    var sleepStage: String?
    var durationSeconds: GoogleHealthNumericValue?
    var durationMillis: GoogleHealthNumericValue?
    var minutes: GoogleHealthNumericValue?
}

struct GoogleHealthExercise: Decodable {
    var interval: GoogleHealthSessionTimeInterval?
    var exerciseType: String?
    var displayName: String?
    var activeDuration: String?
    var metricsSummary: GoogleHealthMetricsSummary?
    var splits: [GoogleHealthWorkoutSplit]?
    var zoneMinutes: [GoogleHealthWorkoutZoneMinutes]?
}

struct GoogleHealthMetricsSummary: Decodable {
    var caloriesKcal: Double?
    var distanceMillimeters: Double?
    var steps: GoogleHealthNumericValue?
    var elevationGainMillimeters: Double?
    var averageHeartRate: GoogleHealthNumericValue?
    var maxHeartRate: GoogleHealthNumericValue?
    var averageSpeedMetersPerSecond: GoogleHealthNumericValue?
    var averagePaceSecondsPerKilometer: GoogleHealthNumericValue?

    private enum CodingKeys: String, CodingKey {
        case caloriesKcal
        case distanceMillimeters
        case steps
        case elevationGainMillimeters
        case averageHeartRate
        case maxHeartRate
        case averageSpeedMetersPerSecond
        case averagePaceSecondsPerKilometer
    }

    init(
        caloriesKcal: Double? = nil,
        distanceMillimeters: Double? = nil,
        steps: GoogleHealthNumericValue? = nil,
        elevationGainMillimeters: Double? = nil,
        averageHeartRate: GoogleHealthNumericValue? = nil,
        maxHeartRate: GoogleHealthNumericValue? = nil,
        averageSpeedMetersPerSecond: GoogleHealthNumericValue? = nil,
        averagePaceSecondsPerKilometer: GoogleHealthNumericValue? = nil
    ) {
        self.caloriesKcal = caloriesKcal
        self.distanceMillimeters = distanceMillimeters
        self.steps = steps
        self.elevationGainMillimeters = elevationGainMillimeters
        self.averageHeartRate = averageHeartRate
        self.maxHeartRate = maxHeartRate
        self.averageSpeedMetersPerSecond = averageSpeedMetersPerSecond
        self.averagePaceSecondsPerKilometer = averagePaceSecondsPerKilometer
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        caloriesKcal = try container.decodeGoogleHealthDoubleIfPresent(forKey: .caloriesKcal)
        distanceMillimeters = try container.decodeGoogleHealthDoubleIfPresent(forKey: .distanceMillimeters)
        steps = try container.decodeIfPresent(GoogleHealthNumericValue.self, forKey: .steps)
        elevationGainMillimeters = try container.decodeGoogleHealthDoubleIfPresent(forKey: .elevationGainMillimeters)
        averageHeartRate = try container.decodeIfPresent(GoogleHealthNumericValue.self, forKey: .averageHeartRate)
        maxHeartRate = try container.decodeIfPresent(GoogleHealthNumericValue.self, forKey: .maxHeartRate)
        averageSpeedMetersPerSecond = try container.decodeIfPresent(
            GoogleHealthNumericValue.self,
            forKey: .averageSpeedMetersPerSecond
        )
        averagePaceSecondsPerKilometer = try container.decodeIfPresent(
            GoogleHealthNumericValue.self,
            forKey: .averagePaceSecondsPerKilometer
        )
    }
}

struct GoogleHealthWorkoutSplit: Decodable {
    var name: String?
    var label: String?
    var distanceMillimeters: Double?
    var duration: String?
    var durationSeconds: GoogleHealthNumericValue?
    var paceSecondsPerKilometer: GoogleHealthNumericValue?
    var speedMetersPerSecond: GoogleHealthNumericValue?
    var elevationGainMillimeters: Double?
    var averageHeartRate: GoogleHealthNumericValue?
}

struct GoogleHealthWorkoutZoneMinutes: Decodable {
    var zone: String?
    var minutes: GoogleHealthNumericValue?
    var durationMillis: GoogleHealthNumericValue?
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
    var pageSize: Int? = nil
    var pageToken: String? = nil
    var dataSourceFamily: String? = nil
}

struct GoogleHealthCivilTimeInterval: Encodable {
    var start: GoogleHealthCivilDateTime
    var end: GoogleHealthCivilDateTime
}

struct GoogleHealthCivilDateTime: Codable, Hashable, Sendable {
    var date: GoogleHealthCivilDate
    var time: GoogleHealthTimeOfDay?

    func dateValue(calendar: Calendar) -> Date? {
        calendar.date(
            from: DateComponents(
                year: date.year,
                month: date.month,
                day: date.day,
                hour: time?.hours ?? 0,
                minute: time?.minutes ?? 0,
                second: time?.seconds ?? 0,
                nanosecond: time?.nanos ?? 0
            )
        )
    }
}

struct GoogleHealthCivilDate: Codable, Hashable, Sendable {
    var year: Int
    var month: Int
    var day: Int

    func date(calendar: Calendar) -> Date? {
        calendar.date(from: DateComponents(year: year, month: month, day: day))
    }
}

struct GoogleHealthTimeOfDay: Codable, Hashable, Sendable {
    var hours: Int
    var minutes: Int
    var seconds: Int
    var nanos: Int = 0

    private enum CodingKeys: String, CodingKey {
        case hours
        case minutes
        case seconds
        case nanos
    }

    init(hours: Int, minutes: Int, seconds: Int, nanos: Int = 0) {
        self.hours = hours
        self.minutes = minutes
        self.seconds = seconds
        self.nanos = nanos
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        hours = try container.decodeIfPresent(Int.self, forKey: .hours) ?? 0
        minutes = try container.decodeIfPresent(Int.self, forKey: .minutes) ?? 0
        seconds = try container.decodeIfPresent(Int.self, forKey: .seconds) ?? 0
        nanos = try container.decodeIfPresent(Int.self, forKey: .nanos) ?? 0
    }
}

struct GoogleHealthRollUpRequest: Encodable {
    var range: GoogleHealthPhysicalTimeInterval
    var windowSize: String
    var pageSize: Int?
    var pageToken: String?
    var dataSourceFamily: String?
}

struct GoogleHealthPhysicalTimeInterval: Encodable {
    var startTime: String
    var endTime: String
}

private extension KeyedDecodingContainer {
    func decodeGoogleHealthDoubleIfPresent(forKey key: Key) throws -> Double? {
        if let double = try? decode(Double.self, forKey: key) {
            return double
        }
        if let string = try? decode(String.self, forKey: key) {
            return Double(string)
        }
        if let numeric = try? decode(GoogleHealthNumericValue.self, forKey: key) {
            return numeric.doubleValue
        }
        return nil
    }
}
