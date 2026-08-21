import Foundation

@MainActor
protocol DashboardCaching {
    func loadDashboard() -> DashboardSnapshot?
    func saveDashboard(_ snapshot: DashboardSnapshot)
    func loadPreferences() -> DashboardPreferences
    func savePreferences(_ preferences: DashboardPreferences)
}
