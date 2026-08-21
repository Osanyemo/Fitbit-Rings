import Foundation

enum GoogleHealthDataType: String, CaseIterable, Codable, Hashable, Identifiable, Sendable {
    case steps = "steps"
    case activeMinutes = "active-minutes"
    case activeEnergyBurned = "active-energy-burned"
    case distance = "distance"
    case totalCalories = "total-calories"
    case activeZoneMinutes = "active-zone-minutes"
    case caloriesInHeartRateZone = "calories-in-heart-rate-zone"
    case timeInHeartRateZone = "time-in-heart-rate-zone"
    case floors = "floors"
    case altitude = "altitude"
    case sedentaryPeriod = "sedentary-period"
    case activityLevel = "activity-level"
    case swimLengthsData = "swim-lengths-data"
    case exercise = "exercise"
    case heartRate = "heart-rate"
    case dailyRestingHeartRate = "daily-resting-heart-rate"
    case heartRateVariability = "heart-rate-variability"
    case dailyHeartRateVariability = "daily-heart-rate-variability"
    case dailyHeartRateZones = "daily-heart-rate-zones"
    case oxygenSaturation = "oxygen-saturation"
    case dailyOxygenSaturation = "daily-oxygen-saturation"
    case respiratoryRateSleepSummary = "respiratory-rate-sleep-summary"
    case dailyRespiratoryRate = "daily-respiratory-rate"
    case dailySleepTemperatureDerivations = "daily-sleep-temperature-derivations"
    case vo2Max = "vo2-max"
    case dailyVo2Max = "daily-vo2-max"
    case runVo2Max = "run-vo2-max"
    case weight = "weight"
    case bodyFat = "body-fat"
    case height = "height"
    case bloodGlucose = "blood-glucose"
    case coreBodyTemperature = "core-body-temperature"
    case sleep = "sleep"

    var id: String { rawValue }
}

enum GoogleHealthValueKey: String, Codable, Sendable {
    case intVal
    case fpVal
    case stringVal
    case mapVal
}

enum GoogleHealthDataCategory: String, Codable, Sendable {
    case activity
    case workout
    case heart
    case sleep
    case vitals
    case cardioFitness
    case body
}

enum GoogleHealthQueryStrategy: String, Codable, Sendable {
    case dailyRollUp
    case rollUp
    case reconcile
}

enum GoogleHealthStatistic: String, Codable, CaseIterable, Hashable, Sendable {
    case sum
    case min
    case average
    case max
    case count
}

enum GoogleHealthRecordKind: String, Codable, Sendable {
    case interval
    case sample
    case session
    case daily
}

extension GoogleHealthDataType {
    var endpointIdentifier: String { rawValue }

    var filterIdentifier: String {
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
        case .activeZoneMinutes:
            return "active_zone_minutes"
        case .caloriesInHeartRateZone:
            return "calories_in_heart_rate_zone"
        case .timeInHeartRateZone:
            return "time_in_heart_rate_zone"
        case .floors:
            return "floors"
        case .altitude:
            return "altitude"
        case .sedentaryPeriod:
            return "sedentary_period"
        case .activityLevel:
            return "activity_level"
        case .swimLengthsData:
            return "swim_lengths_data"
        case .exercise:
            return "exercise"
        case .heartRate:
            return "heart_rate"
        case .dailyRestingHeartRate:
            return "daily_resting_heart_rate"
        case .heartRateVariability:
            return "heart_rate_variability"
        case .dailyHeartRateVariability:
            return "daily_heart_rate_variability"
        case .dailyHeartRateZones:
            return "daily_heart_rate_zones"
        case .oxygenSaturation:
            return "oxygen_saturation"
        case .dailyOxygenSaturation:
            return "daily_oxygen_saturation"
        case .respiratoryRateSleepSummary:
            return "respiratory_rate_sleep_summary"
        case .dailyRespiratoryRate:
            return "daily_respiratory_rate"
        case .dailySleepTemperatureDerivations:
            return "daily_sleep_temperature_derivations"
        case .vo2Max:
            return "vo2_max"
        case .dailyVo2Max:
            return "daily_vo2_max"
        case .runVo2Max:
            return "run_vo2_max"
        case .weight:
            return "weight"
        case .bodyFat:
            return "body_fat"
        case .height:
            return "height"
        case .bloodGlucose:
            return "blood_glucose"
        case .coreBodyTemperature:
            return "core_body_temperature"
        case .sleep:
            return "sleep"
        }
    }

    var displayName: String {
        switch self {
        case .steps:
            return "Steps"
        case .activeMinutes:
            return "Active Minutes"
        case .activeEnergyBurned:
            return "Active Calories"
        case .distance:
            return "Distance"
        case .totalCalories:
            return "Total Calories"
        case .activeZoneMinutes:
            return "Zone Minutes"
        case .caloriesInHeartRateZone:
            return "Zone Calories"
        case .timeInHeartRateZone:
            return "Heart Zones"
        case .floors:
            return "Floors"
        case .altitude:
            return "Altitude"
        case .sedentaryPeriod:
            return "Sedentary"
        case .activityLevel:
            return "Activity Level"
        case .swimLengthsData:
            return "Swimming"
        case .exercise:
            return "Workouts"
        case .heartRate:
            return "Heart Rate"
        case .dailyRestingHeartRate:
            return "Resting Heart"
        case .heartRateVariability:
            return "HRV"
        case .dailyHeartRateVariability:
            return "Daily HRV"
        case .dailyHeartRateZones:
            return "Heart Rate Zones"
        case .oxygenSaturation:
            return "SpO2"
        case .dailyOxygenSaturation:
            return "Daily SpO2"
        case .respiratoryRateSleepSummary:
            return "Sleep Respiration"
        case .dailyRespiratoryRate:
            return "Respiratory Rate"
        case .dailySleepTemperatureDerivations:
            return "Sleep Temperature"
        case .vo2Max:
            return "VO2 Max"
        case .dailyVo2Max:
            return "Daily VO2 Max"
        case .runVo2Max:
            return "Run VO2 Max"
        case .weight:
            return "Weight"
        case .bodyFat:
            return "Body Fat"
        case .height:
            return "Height"
        case .bloodGlucose:
            return "Blood Glucose"
        case .coreBodyTemperature:
            return "Core Temperature"
        case .sleep:
            return "Sleep"
        }
    }

    var category: GoogleHealthDataCategory {
        switch self {
        case .exercise:
            return .workout
        case .heartRate, .dailyRestingHeartRate, .heartRateVariability,
             .dailyHeartRateVariability, .dailyHeartRateZones, .timeInHeartRateZone,
             .caloriesInHeartRateZone:
            return .heart
        case .sleep, .dailySleepTemperatureDerivations:
            return .sleep
        case .oxygenSaturation, .dailyOxygenSaturation,
             .respiratoryRateSleepSummary, .dailyRespiratoryRate,
             .bloodGlucose, .coreBodyTemperature:
            return .vitals
        case .vo2Max, .dailyVo2Max, .runVo2Max:
            return .cardioFitness
        case .weight, .bodyFat, .height:
            return .body
        case .steps, .activeMinutes, .activeEnergyBurned, .distance, .totalCalories,
             .activeZoneMinutes, .floors, .altitude, .sedentaryPeriod,
             .activityLevel, .swimLengthsData:
            return .activity
        }
    }

    var defaultQueryStrategy: GoogleHealthQueryStrategy {
        switch self {
        case .exercise, .sleep, .activityLevel, .sedentaryPeriod,
             .dailyRestingHeartRate, .dailyHeartRateVariability,
             .dailyHeartRateZones, .dailyOxygenSaturation,
             .dailyRespiratoryRate, .dailySleepTemperatureDerivations:
            return .reconcile
        case .heartRate, .heartRateVariability, .oxygenSaturation,
             .respiratoryRateSleepSummary, .vo2Max, .runVo2Max,
             .weight, .bodyFat, .height, .bloodGlucose, .coreBodyTemperature:
            return .reconcile
        case .steps, .activeMinutes, .activeEnergyBurned, .distance,
             .totalCalories, .activeZoneMinutes, .caloriesInHeartRateZone,
             .timeInHeartRateZone, .floors, .altitude, .swimLengthsData,
             .dailyVo2Max:
            return .dailyRollUp
        }
    }

    var supportedStatistics: Set<GoogleHealthStatistic> {
        switch self {
        case .steps, .activeMinutes, .activeEnergyBurned, .distance, .totalCalories,
             .activeZoneMinutes, .caloriesInHeartRateZone, .timeInHeartRateZone,
             .floors, .swimLengthsData:
            return [.sum]
        case .heartRate, .heartRateVariability, .oxygenSaturation,
             .respiratoryRateSleepSummary, .vo2Max, .runVo2Max,
             .weight, .bodyFat, .height, .bloodGlucose, .coreBodyTemperature,
             .altitude, .dailyVo2Max:
            return [.min, .average, .max]
        case .sedentaryPeriod, .activityLevel, .exercise, .sleep,
             .dailyRestingHeartRate, .dailyHeartRateVariability,
             .dailyHeartRateZones, .dailyOxygenSaturation,
             .dailyRespiratoryRate, .dailySleepTemperatureDerivations:
            return [.count]
        }
    }

    var recordKind: GoogleHealthRecordKind {
        switch self {
        case .exercise, .sleep:
            return .session
        case .heartRate, .heartRateVariability, .oxygenSaturation,
             .respiratoryRateSleepSummary, .vo2Max, .runVo2Max,
             .weight, .bodyFat, .height, .bloodGlucose, .coreBodyTemperature:
            return .sample
        case .dailyRestingHeartRate, .dailyHeartRateVariability,
             .dailyHeartRateZones, .dailyOxygenSaturation,
             .dailyRespiratoryRate, .dailySleepTemperatureDerivations,
             .activityLevel, .dailyVo2Max:
            return .daily
        case .steps, .activeMinutes, .activeEnergyBurned, .distance, .totalCalories,
             .activeZoneMinutes, .caloriesInHeartRateZone, .timeInHeartRateZone,
             .floors, .altitude, .sedentaryPeriod, .swimLengthsData:
            return .interval
        }
    }

    var unit: String {
        switch self {
        case .steps:
            return "steps"
        case .activeMinutes, .activeZoneMinutes, .timeInHeartRateZone, .dailyHeartRateZones:
            return "min"
        case .activeEnergyBurned, .totalCalories, .caloriesInHeartRateZone:
            return "kcal"
        case .distance, .altitude, .height:
            return "m"
        case .floors:
            return "floors"
        case .heartRate, .dailyRestingHeartRate:
            return "bpm"
        case .heartRateVariability, .dailyHeartRateVariability:
            return "ms"
        case .oxygenSaturation, .dailyOxygenSaturation, .bodyFat:
            return "%"
        case .respiratoryRateSleepSummary, .dailyRespiratoryRate:
            return "brpm"
        case .dailySleepTemperatureDerivations, .coreBodyTemperature:
            return "deg"
        case .vo2Max, .dailyVo2Max, .runVo2Max:
            return "ml/kg/min"
        case .weight:
            return "kg"
        case .bloodGlucose:
            return "mg/dL"
        case .sedentaryPeriod:
            return "min"
        case .activityLevel:
            return "level"
        case .swimLengthsData:
            return "lengths"
        case .exercise, .sleep:
            return ""
        }
    }

    var symbolName: String {
        switch self {
        case .steps:
            return "shoeprints.fill"
        case .activeMinutes:
            return "figure.run"
        case .activeEnergyBurned:
            return "flame.fill"
        case .distance:
            return "map.fill"
        case .totalCalories:
            return "fork.knife"
        case .activeZoneMinutes, .caloriesInHeartRateZone, .timeInHeartRateZone:
            return "bolt.heart.fill"
        case .floors:
            return "stairs"
        case .altitude:
            return "mountain.2.fill"
        case .sedentaryPeriod:
            return "figure.seated.side"
        case .activityLevel:
            return "gauge.with.dots.needle.33percent"
        case .swimLengthsData:
            return "figure.pool.swim"
        case .exercise:
            return "dumbbell.fill"
        case .heartRate, .dailyRestingHeartRate, .heartRateVariability,
             .dailyHeartRateVariability, .dailyHeartRateZones:
            return "heart.fill"
        case .sleep, .dailySleepTemperatureDerivations,
             .respiratoryRateSleepSummary:
            return "moon.zzz.fill"
        case .oxygenSaturation, .dailyOxygenSaturation,
             .dailyRespiratoryRate, .bloodGlucose, .coreBodyTemperature:
            return "waveform.path.ecg"
        case .vo2Max, .dailyVo2Max, .runVo2Max:
            return "lungs.fill"
        case .weight, .bodyFat, .height:
            return "figure.stand"
        }
    }

    var usesCivilDateFilter: Bool {
        switch recordKind {
        case .daily:
            return true
        case .session:
            return self == .exercise
        case .interval, .sample:
            return false
        }
    }

    var defaultFilterField: String {
        switch self {
        case .heartRate:
            return "heart_rate.sample_time.physical_time"
        case .dailyRestingHeartRate:
            return "daily_resting_heart_rate.date"
        case .exercise:
            return "exercise.interval.civil_start_time"
        case .sleep:
            return "sleep.interval.end_time"
        case .heartRateVariability:
            return "heart_rate_variability.sample_time.physical_time"
        case .dailyHeartRateVariability:
            return "daily_heart_rate_variability.date"
        case .dailyHeartRateZones:
            return "daily_heart_rate_zones.date"
        case .oxygenSaturation:
            return "oxygen_saturation.sample_time.physical_time"
        case .dailyOxygenSaturation:
            return "daily_oxygen_saturation.date"
        case .respiratoryRateSleepSummary:
            return "respiratory_rate_sleep_summary.sample_time.physical_time"
        case .dailyRespiratoryRate:
            return "daily_respiratory_rate.date"
        case .dailySleepTemperatureDerivations:
            return "daily_sleep_temperature_derivations.date"
        case .vo2Max:
            return "vo2_max.sample_time.physical_time"
        case .dailyVo2Max:
            return "daily_vo2_max.date"
        case .runVo2Max:
            return "run_vo2_max.sample_time.physical_time"
        case .weight:
            return "weight.measurement_time.physical_time"
        case .bodyFat:
            return "body_fat.measurement_time.physical_time"
        case .height:
            return "height.measurement_time.physical_time"
        case .bloodGlucose:
            return "blood_glucose.sample_time.physical_time"
        case .coreBodyTemperature:
            return "core_body_temperature.sample_time.physical_time"
        case .activityLevel:
            return "activity_level.date"
        case .steps, .activeMinutes, .activeEnergyBurned, .distance,
             .totalCalories, .activeZoneMinutes, .caloriesInHeartRateZone,
             .timeInHeartRateZone, .floors, .altitude, .sedentaryPeriod,
             .swimLengthsData:
            return "\(filterIdentifier).interval.start_time"
        }
    }

    var supportsRollup: Bool {
        defaultQueryStrategy == .dailyRollUp || defaultQueryStrategy == .rollUp
    }

    var isPageLimitedToTwentyFive: Bool {
        self == .exercise || self == .sleep
    }
}
