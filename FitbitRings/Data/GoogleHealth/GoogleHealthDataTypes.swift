import Foundation

enum GoogleHealthDataType: String, CaseIterable {
    case steps = "steps"
    case activeMinutes = "active-minutes"
    case activeEnergyBurned = "active-energy-burned"
    case distance = "distance"
    case totalCalories = "total-calories"
    case exercise = "exercise"
    case heartRate = "heart-rate"
    case dailyRestingHeartRate = "daily-resting-heart-rate"
    case sleep = "sleep"
}

enum GoogleHealthValueKey: String {
    case intVal
    case fpVal
    case stringVal
    case mapVal
}
