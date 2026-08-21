import Foundation

@MainActor
protocol DashboardCaching {
    func loadDashboard() -> DashboardSnapshot?
    func saveDashboard(_ snapshot: DashboardSnapshot)
    func loadFitnessData() -> FitnessDataSnapshot?
    func saveFitnessData(_ snapshot: FitnessDataSnapshot)
    func clearHealthData()
    func loadPreferences() -> DashboardPreferences
    func savePreferences(_ preferences: DashboardPreferences)
}

extension DashboardCaching {
    func loadFitnessData() -> FitnessDataSnapshot? {
        loadDashboard().map(FitnessDataSnapshot.fromLegacyDashboard)
    }

    func saveFitnessData(_ snapshot: FitnessDataSnapshot) {
        saveDashboard(snapshot.summary)
    }

    func clearHealthData() {}
}
