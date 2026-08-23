import Foundation
import SwiftData

@Model
final class CachedDashboardSnapshot {
    @Attribute(.unique) var id: String
    var data: Data
    var updatedAt: Date

    init(id: String = "current", data: Data, updatedAt: Date) {
        self.id = id
        self.data = data
        self.updatedAt = updatedAt
    }
}

@Model
final class CachedDashboardSection {
    @Attribute(.unique) var id: String
    var data: Data
    var updatedAt: Date

    init(id: String, data: Data, updatedAt: Date) {
        self.id = id
        self.data = data
        self.updatedAt = updatedAt
    }
}

@Model
final class CachedPreferences {
    @Attribute(.unique) var id: String
    var moveCalories: Int
    var activeMinutes: Int
    var steps: Int
    var distanceUnitRawValue: String
    var appearanceRawValue: String

    init(
        id: String = "current",
        moveCalories: Int,
        activeMinutes: Int,
        steps: Int,
        distanceUnitRawValue: String,
        appearanceRawValue: String
    ) {
        self.id = id
        self.moveCalories = moveCalories
        self.activeMinutes = activeMinutes
        self.steps = steps
        self.distanceUnitRawValue = distanceUnitRawValue
        self.appearanceRawValue = appearanceRawValue
    }
}
