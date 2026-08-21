import Foundation
import Observation

@MainActor
@Observable
final class SummaryViewModel {
    private let repository: DashboardRepository
    private let cache: DashboardCaching
    private let staleAfter: TimeInterval
    private var isRefreshing = false

    var snapshot: DashboardSnapshot
    var preferences: DashboardPreferences
    var errorMessage: String?

    init(repository: DashboardRepository, cache: DashboardCaching, staleAfter: TimeInterval = 60) {
        let cachedPreferences = cache.loadPreferences()
        let cachedSnapshot = cache.loadDashboard()

        self.repository = repository
        self.cache = cache
        self.staleAfter = staleAfter
        preferences = cachedPreferences
        snapshot = cachedSnapshot ?? .empty(goals: cachedPreferences.goals)
    }

    func load() async {
        preferences = cache.loadPreferences()
        if let cached = cache.loadDashboard() {
            snapshot = cached
        } else if snapshot.lastUpdated == .distantPast {
            snapshot = .empty(goals: preferences.goals)
        }
        await refreshIfStale()
    }

    func refreshIfStale(now: Date = .now) async {
        guard now.timeIntervalSince(snapshot.lastUpdated) > staleAfter else {
            return
        }
        await refresh()
    }

    func refresh() async {
        guard !isRefreshing else { return }

        isRefreshing = true
        defer { isRefreshing = false }

        errorMessage = nil

        do {
            preferences = cache.loadPreferences()

            if let cached = cache.loadDashboard() {
                snapshot = cached
            } else if snapshot.lastUpdated == .distantPast {
                snapshot = .empty(goals: preferences.goals)
            }
            snapshot.syncState = .refreshing

            let fresh = try await repository.refresh()
            snapshot = fresh
        } catch {
            guard !error.isCancellation else {
                snapshot.syncState = .idle
                errorMessage = nil
                return
            }
            snapshot.syncState = .failed
            errorMessage = error.localizedDescription
        }
    }

    func saveGoals(moveCalories: Int, activeMinutes: Int, steps: Int) {
        preferences.goals = ActivityGoals(
            moveCalories: moveCalories,
            activeMinutes: activeMinutes,
            steps: steps
        )
        cache.savePreferences(preferences)
        snapshot.rings.move.goal = Double(moveCalories)
        snapshot.rings.active.goal = Double(activeMinutes)
        snapshot.rings.steps.goal = Double(steps)
    }

    func saveUnits(_ unit: DistanceUnit) {
        preferences.units.distanceUnit = unit
        cache.savePreferences(preferences)
    }

    func saveAppearance(_ appearance: AppearancePreference) {
        preferences.units.appearance = appearance
        cache.savePreferences(preferences)
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
}
