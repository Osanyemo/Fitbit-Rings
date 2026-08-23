import Foundation

@MainActor
protocol DashboardCaching {
    func loadDashboard() -> DashboardSnapshot?
    func saveDashboard(_ snapshot: DashboardSnapshot)
    func loadSummary() -> DashboardSnapshot?
    func saveSummary(_ snapshot: DashboardSnapshot)
    func loadActivityData() -> ActivityDashboardData?
    func saveActivityData(_ data: ActivityDashboardData)
    func loadWorkouts() -> (workouts: [WorkoutDetail], loadedAt: Date?)?
    func saveWorkouts(_ workouts: [WorkoutDetail], loadedAt: Date?)
    func loadHealthData() -> HealthDashboardData?
    func saveHealthData(_ data: HealthDashboardData)
    func loadFitnessData() -> FitnessDataSnapshot?
    func saveFitnessData(_ snapshot: FitnessDataSnapshot)
    func clearHealthData()
    func loadPreferences() -> DashboardPreferences
    func savePreferences(_ preferences: DashboardPreferences)
}

extension DashboardCaching {
    func loadSummary() -> DashboardSnapshot? {
        loadDashboard()
    }

    func saveSummary(_ snapshot: DashboardSnapshot) {
        saveDashboard(snapshot)
    }

    func loadActivityData() -> ActivityDashboardData? {
        loadFitnessData()?.activity
    }

    func saveActivityData(_ data: ActivityDashboardData) {
        var snapshot = loadFitnessData() ?? .empty()
        snapshot.activity = data
        saveFitnessData(snapshot)
    }

    func loadWorkouts() -> (workouts: [WorkoutDetail], loadedAt: Date?)? {
        guard let snapshot = loadFitnessData() else { return nil }
        return (snapshot.workouts, snapshot.workoutsLoadedAt)
    }

    func saveWorkouts(_ workouts: [WorkoutDetail], loadedAt: Date?) {
        var snapshot = loadFitnessData() ?? .empty()
        snapshot.workouts = workouts
        snapshot.workoutsLoadedAt = loadedAt
        saveFitnessData(snapshot)
    }

    func loadHealthData() -> HealthDashboardData? {
        loadFitnessData()?.health
    }

    func saveHealthData(_ data: HealthDashboardData) {
        var snapshot = loadFitnessData() ?? .empty()
        snapshot.health = data
        saveFitnessData(snapshot)
    }

    func loadFitnessData() -> FitnessDataSnapshot? {
        loadDashboard().map(FitnessDataSnapshot.fromLegacyDashboard)
    }

    func saveFitnessData(_ snapshot: FitnessDataSnapshot) {
        saveDashboard(snapshot.summary)
    }

    func clearHealthData() {}
}
