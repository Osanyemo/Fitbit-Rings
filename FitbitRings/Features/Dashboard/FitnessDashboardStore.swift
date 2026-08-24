import Foundation
import Observation
import UIKit

@MainActor
@Observable
final class FitnessDashboardStore {
    private let repository: DashboardRepository
    private let cache: DashboardCaching
    private let staleAfter: TimeInterval
    private var activeRefreshes: Set<FitnessDashboardSection> = []

    var snapshot: FitnessDataSnapshot
    var preferences: DashboardPreferences
    var selectedTab: FitnessDashboardTab = .summary
    var sectionStates: [FitnessDashboardSection: FitnessSectionState]
    var summaryPath: [DashboardRoute] = []
    var activityPath: [DashboardRoute] = []
    var workoutPath: [DashboardRoute] = []
    var healthPath: [DashboardRoute] = []
    var errorMessage: String?
    var automaticallyRefreshes = true

    init(repository: DashboardRepository, cache: DashboardCaching, staleAfter: TimeInterval = 300) {
        let cachedPreferences = cache.loadPreferences()
        let cachedSummary = cache.loadSummary()
        let cachedSnapshot = cachedSummary.map(FitnessDataSnapshot.fromLegacyDashboard)

        self.repository = repository
        self.cache = cache
        self.staleAfter = staleAfter
        preferences = cachedPreferences
        snapshot = cachedSnapshot ?? .empty(goals: cachedPreferences.goals)
        sectionStates = Self.initialSectionStates(for: cachedSnapshot)
        errorMessage = nil
    }

    func load() async {
        preferences = cache.loadPreferences()
        if let summary = cache.loadSummary() {
            snapshot.summary = summary
            snapshot.lastUpdated = max(snapshot.lastUpdated, summary.lastUpdated)
            setSection(.summary, phase: .loaded, lastUpdated: summary.lastUpdated, error: nil)
        } else if snapshot.summary.lastUpdated == .distantPast {
            snapshot = .empty(goals: preferences.goals)
            sectionStates = Self.initialSectionStates(for: nil)
        }

        hydrateCachedSections()
    }

    func refreshSummaryIfStale(now: Date = .now) async {
        guard automaticallyRefreshes else { return }
        guard now.timeIntervalSince(snapshot.summary.lastUpdated) > staleAfter else {
            return
        }
        await refreshSummary()
    }

    func loadSelectedTabIfNeeded() async {
        guard automaticallyRefreshes else { return }
        guard selectedTab.section != .summary else {
            return
        }

        await loadIfNeeded(selectedTab.section)
    }

    func loadIfNeeded(_ section: FitnessDashboardSection) async {
        guard automaticallyRefreshes else { return }
        guard section != .summary else {
            await refreshSummaryIfStale()
            return
        }

        if let state = sectionStates[section],
           state.isLoaded,
           Date.now.timeIntervalSince(state.lastUpdated) <= staleAfter {
            return
        }

        await refreshSection(section)
    }

    func refreshSummary(announcesResult: Bool = false) async {
        guard beginRefresh(.summary) else { return }
        defer { finishRefresh(.summary) }

        errorMessage = nil
        setSection(.summary, phase: .loading, error: nil)
        snapshot.summary.syncState = .refreshing

        do {
            preferences = cache.loadPreferences()
            snapshot = try await repository.refreshSummary(preserving: snapshot)
            snapshot.summary.syncState = .idle
            setSection(.summary, phase: .loaded, lastUpdated: snapshot.summary.lastUpdated, error: nil)
            announceIfRequested("Summary updated", when: announcesResult)
        } catch {
            guard !error.isCancellation else {
                snapshot.summary.syncState = .idle
                setSection(.summary, phase: .idle, lastUpdated: snapshot.summary.lastUpdated, error: nil)
                errorMessage = nil
                return
            }

            snapshot.summary.syncState = .failed
            let message = presentationMessage(for: error)
            errorMessage = message
            setSection(.summary, phase: .failed, lastUpdated: snapshot.summary.lastUpdated, error: message)
            announceIfRequested("Summary could not be updated. \(message)", when: announcesResult)
        }
    }

    func refreshSection(_ section: FitnessDashboardSection, announcesResult: Bool = false) async {
        guard section != .summary else {
            await refreshSummary(announcesResult: announcesResult)
            return
        }
        guard beginRefresh(section) else { return }
        defer { finishRefresh(section) }

        setSection(section, phase: .loading, error: nil)

        do {
            switch section {
            case .summary:
                break
            case .activity:
                snapshot = try await repository.refreshActivity(preserving: snapshot)
                setSection(.activity, phase: .loaded, lastUpdated: snapshot.activity.loadedAt ?? .now, error: nil)
            case .workouts:
                snapshot = try await repository.refreshWorkouts(preserving: snapshot)
                setSection(.workouts, phase: .loaded, lastUpdated: .now, error: nil)
            case .health:
                snapshot = try await repository.refreshHealth(preserving: snapshot)
                setSection(.health, phase: .loaded, lastUpdated: snapshot.health.loadedAt ?? .now, error: nil)
            }
            announceIfRequested("\(section.spokenTitle) updated", when: announcesResult)
        } catch {
            guard !error.isCancellation else {
                setSection(section, phase: .idle, error: nil)
                return
            }
            let message = presentationMessage(for: error)
            setSection(section, phase: .failed, error: message)
            announceIfRequested("\(section.spokenTitle) could not be updated. \(message)", when: announcesResult)
        }
    }

    func loadEarlierMetric(_ type: GoogleHealthDataType) async {
        guard let currentSeries = series(for: type),
              let before = currentSeries.rangeStart ?? currentSeries.points.first?.startDate else {
            return
        }

        let section = type.category == .activity ? FitnessDashboardSection.activity : .health
        guard beginRefresh(section) else { return }
        defer { finishRefresh(section) }

        setSection(section, phase: .loading, error: nil)

        do {
            snapshot = try await repository.loadEarlierMetric(type, preserving: snapshot, before: before)
            setSection(section, phase: .loaded, lastUpdated: .now, error: nil)
        } catch {
            guard !error.isCancellation else {
                setSection(section, phase: .idle, error: nil)
                return
            }
            setSection(section, phase: .failed, error: presentationMessage(for: error))
        }
    }

    func loadMetricChart(
        _ type: GoogleHealthDataType,
        range: MetricChartRange,
        force: Bool = false
    ) async {
        guard type.supportsDetailedChartRollups else {
            return
        }

        if !force, chartSeries(for: type, range: range) != nil {
            return
        }

        guard beginRefresh(.activity) else { return }
        defer { finishRefresh(.activity) }

        setSection(.activity, phase: .loading, error: nil)

        do {
            snapshot = try await repository.refreshMetricChart(
                type,
                range: range,
                preserving: snapshot,
                date: snapshot.summary.date
            )
            setSection(.activity, phase: .loaded, lastUpdated: .now, error: nil)
        } catch {
            guard !error.isCancellation else {
                setSection(.activity, phase: .idle, error: nil)
                return
            }
            setSection(.activity, phase: .failed, error: presentationMessage(for: error))
        }
    }

    func route(to route: DashboardRoute) {
        let targetTab = targetTab(for: route)
        selectedTab = targetTab

        switch targetTab {
        case .summary:
            summaryPath.append(route)
        case .activity:
            activityPath.append(route)
        case .workouts:
            workoutPath.append(route)
        case .health:
            healthPath.append(route)
        }
    }

    func series(for type: GoogleHealthDataType) -> NumericMetricSeries? {
        snapshot.activity.series(for: type)
            ?? snapshot.health.series(for: type)
    }

    func chartSeries(for type: GoogleHealthDataType, range: MetricChartRange) -> MetricChartSeries? {
        snapshot.activity.chartSeries(for: type, range: range)
    }

    func workout(id: String) -> WorkoutDetail? {
        snapshot.workouts.first { $0.id == id }
    }

    func workoutID(matching summary: WorkoutSummary) -> String? {
        snapshot.workouts.first {
            $0.startTime == summary.startTime && $0.type == summary.type
        }?.id
    }

    func sleepSession(id: String) -> SleepSession? {
        snapshot.health.sleepSessions.first { $0.id == id }
    }

    func sectionState(_ section: FitnessDashboardSection) -> FitnessSectionState {
        sectionStates[section] ?? .idle
    }

    func saveGoals(moveCalories: Int, activeMinutes: Int, steps: Int) {
        preferences.goals = ActivityGoals(
            moveCalories: moveCalories,
            activeMinutes: activeMinutes,
            steps: steps
        )
        cache.savePreferences(preferences)
        snapshot.summary.rings.move.goal = Double(moveCalories)
        snapshot.summary.rings.active.goal = Double(activeMinutes)
        snapshot.summary.rings.steps.goal = Double(steps)
        cache.saveFitnessData(snapshot)
    }

    func saveUnits(_ unit: DistanceUnit) {
        preferences.units.distanceUnit = unit
        cache.savePreferences(preferences)
    }

    func saveAppearance(_ appearance: AppearancePreference) {
        preferences.units.appearance = appearance
        cache.savePreferences(preferences)
    }

    func clearHealthDataForDisconnect() {
        repository.clearHealthData()
        snapshot = .empty(goals: preferences.goals)
        sectionStates = Self.initialSectionStates(for: nil)
        summaryPath = []
        activityPath = []
        workoutPath = []
        healthPath = []
        errorMessage = nil
    }

    private func beginRefresh(_ section: FitnessDashboardSection) -> Bool {
        guard !activeRefreshes.contains(section) else {
            return false
        }
        activeRefreshes.insert(section)
        return true
    }

    private func finishRefresh(_ section: FitnessDashboardSection) {
        activeRefreshes.remove(section)
    }

    private func hydrateCachedSections() {
        if let activity = cache.loadActivityData() {
            snapshot.activity = activity
            if let loadedAt = activity.loadedAt {
                setSection(.activity, phase: .loaded, lastUpdated: loadedAt, error: nil)
            }
        }

        if let workouts = cache.loadWorkouts() {
            snapshot.workouts = workouts.workouts
            snapshot.workoutsLoadedAt = workouts.loadedAt
            if let loadedAt = workouts.loadedAt {
                setSection(.workouts, phase: .loaded, lastUpdated: loadedAt, error: nil)
            }
        }

        if let health = cache.loadHealthData() {
            snapshot.health = health
            if let loadedAt = health.loadedAt {
                setSection(.health, phase: .loaded, lastUpdated: loadedAt, error: nil)
            }
        }

        snapshot.lastUpdated = [
            snapshot.summary.lastUpdated,
            snapshot.activity.loadedAt,
            snapshot.workoutsLoadedAt,
            snapshot.health.loadedAt
        ]
        .compactMap { $0 }
        .max() ?? snapshot.summary.lastUpdated
    }

    private func setSection(
        _ section: FitnessDashboardSection,
        phase: FitnessLoadingPhase,
        lastUpdated: Date? = nil,
        error: String?
    ) {
        let existing = sectionStates[section] ?? .idle
        sectionStates[section] = FitnessSectionState(
            phase: phase,
            lastUpdated: lastUpdated ?? existing.lastUpdated,
            errorMessage: error
        )
    }

    private func presentationMessage(for error: Error) -> String {
        if let urlError = error as? URLError {
            switch urlError.code {
            case .notConnectedToInternet, .networkConnectionLost:
                return "Check your internet connection, then try again."
            case .timedOut:
                return "Google Health took too long to respond. Please try again."
            default:
                break
            }
        }

        return "Google Health couldn’t complete the request. Please try again."
    }

    private func announceIfRequested(_ message: String, when requested: Bool) {
        guard requested else { return }
        UIAccessibility.post(notification: .announcement, argument: message)
    }

    private func targetTab(for route: DashboardRoute) -> FitnessDashboardTab {
        switch route.kind {
        case .workout:
            return .workouts
        case .sleep:
            return .health
        case .metric:
            guard let type = route.dataType else { return .summary }
            switch type.category {
            case .activity:
                return .activity
            case .workout:
                return .workouts
            case .heart, .sleep, .vitals, .cardioFitness, .body:
                return .health
            }
        }
    }

    private static func initialSectionStates(
        for snapshot: FitnessDataSnapshot?
    ) -> [FitnessDashboardSection: FitnessSectionState] {
        var states = Dictionary(
            uniqueKeysWithValues: FitnessDashboardSection.allCases.map { ($0, FitnessSectionState.idle) }
        )

        guard let snapshot else {
            return states
        }

        states[.summary] = FitnessSectionState(
            phase: .loaded,
            lastUpdated: snapshot.summary.lastUpdated,
            errorMessage: nil
        )

        if let loadedAt = snapshot.activity.loadedAt {
            states[.activity] = FitnessSectionState(phase: .loaded, lastUpdated: loadedAt, errorMessage: nil)
        }

        if let workoutsLoadedAt = snapshot.workoutsLoadedAt {
            states[.workouts] = FitnessSectionState(phase: .loaded, lastUpdated: workoutsLoadedAt, errorMessage: nil)
        }

        if let loadedAt = snapshot.health.loadedAt {
            states[.health] = FitnessSectionState(phase: .loaded, lastUpdated: loadedAt, errorMessage: nil)
        }

        return states
    }
}

private extension FitnessDashboardSection {
    var spokenTitle: String {
        switch self {
        case .summary:
            return "Summary"
        case .activity:
            return "Activity"
        case .workouts:
            return "Workouts"
        case .health:
            return "Health"
        }
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
