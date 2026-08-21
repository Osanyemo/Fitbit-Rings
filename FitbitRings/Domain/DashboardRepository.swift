import Foundation

protocol DashboardServing {
    func fetchDashboard(goals: ActivityGoals, date: Date) async throws -> DashboardSnapshot
}

@MainActor
struct DashboardRepository {
    private let googleHealthClient: GoogleHealthServing
    private let cache: DashboardCaching

    init(googleHealthClient: GoogleHealthServing, cache: DashboardCaching) {
        self.googleHealthClient = googleHealthClient
        self.cache = cache
    }

    func cachedSnapshot() -> DashboardSnapshot? {
        cache.loadDashboard()
    }

    func preferences() -> DashboardPreferences {
        cache.loadPreferences()
    }

    func savePreferences(_ preferences: DashboardPreferences) {
        cache.savePreferences(preferences)
    }

    func refresh(date: Date = .now) async throws -> DashboardSnapshot {
        let preferences = cache.loadPreferences()
        let snapshot = try await googleHealthClient.fetchDashboard(
            goals: preferences.goals,
            date: date
        )
        cache.saveDashboard(snapshot)
        return snapshot
    }
}

struct DashboardPreferences: Equatable, Sendable {
    var goals: ActivityGoals
    var units: UnitPreferences

    static let defaults = DashboardPreferences(goals: .defaultGoals, units: .defaults)
}
