import Foundation
import SwiftUI

@MainActor
@Observable
final class SummaryViewModel {
    private let repository: DashboardRepository
    private let cache: DashboardCaching
    private let staleAfter: TimeInterval = 5 * 60

    var snapshot: DashboardSnapshot
    var preferences: DashboardPreferences
    var errorMessage: String?

    init(repository: DashboardRepository, cache: DashboardCaching) {
        let cachedPreferences = cache.loadPreferences()
        let cachedSnapshot = cache.loadDashboard()

        self.repository = repository
        self.cache = cache
        preferences = cachedPreferences
        snapshot = cachedSnapshot ?? .empty(goals: cachedPreferences.goals)
    }

    func load() async {
        preferences = cache.loadPreferences()
        if let cached = cache.loadDashboard() {
            snapshot = cached
        }
        await refreshIfStale()
    }

    func refreshIfStale() async {
        guard Date().timeIntervalSince(snapshot.lastUpdated) > staleAfter else {
            return
        }
        await refresh()
    }

    func refresh() async {
        errorMessage = nil
        snapshot.syncState = .refreshing

        do {
            preferences = cache.loadPreferences()
            withAnimation(.snappy(duration: 0.35)) {
                snapshot = DashboardSnapshot.empty(goals: preferences.goals)
                if let cached = cache.loadDashboard() {
                    snapshot = cached
                    snapshot.syncState = .refreshing
                }
            }

            let fresh = try await repository.refresh()
            withAnimation(.snappy(duration: 0.45)) {
                snapshot = fresh
            }
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
