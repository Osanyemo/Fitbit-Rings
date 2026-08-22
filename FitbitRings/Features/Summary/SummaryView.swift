import SwiftUI

struct SummaryView: View {
    @Bindable var store: FitnessDashboardStore
    let accountEmail: String?
    let onSignOut: () -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var showingSettings = false

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
                ActivityTopBand(
                    snapshot: store.snapshot.summary,
                    onSettings: {
                        showingSettings = true
                    }
                )
                .padding(.horizontal, 20)
                .padding(.top, 18)

                VStack(alignment: .leading, spacing: 24) {
                    if let errorMessage = store.errorMessage {
                        SyncStatusBanner(errorMessage: errorMessage)
                    }

                    SummaryHourlyPairSection(
                        snapshot: store.snapshot,
                        units: store.preferences.units,
                        onSelectMetric: { type in
                            store.route(to: .metric(type))
                        }
                    )

                    if let latestWorkout = store.snapshot.summary.latestWorkout {
                        RecentWorkoutSection(
                            workout: latestWorkout,
                            units: store.preferences.units,
                            onSelect: {
                                if let workoutID = store.workoutID(matching: latestWorkout) {
                                    store.route(to: .workout(workoutID))
                                } else {
                                    store.selectedTab = .workouts
                                }
                            }
                        )
                    }

                    TodayGoalsSection(
                        snapshot: store.snapshot.summary,
                        units: store.preferences.units,
                        onMetricSelected: { type in
                            if type == .sleep,
                               let sleepID = store.snapshot.health.sleepSessions.first?.id {
                                store.route(to: .sleep(sleepID))
                            } else {
                                store.route(to: .metric(type))
                            }
                        }
                    )
                }
                .padding(.horizontal, 20)
                .padding(.top, 22)
                .padding(.bottom, 38)
            }
        }
        .scrollIndicators(.hidden)
        .background {
            Color.fitbitBackground
                .ignoresSafeArea()
        }
        .overlay(alignment: .top) {
            SummaryScrollEdgeFade(color: .fitbitBackground, edge: .top)
        }
        .overlay(alignment: .bottom) {
            SummaryScrollEdgeFade(color: .fitbitBackground, edge: .bottom)
        }
        .refreshable {
            await store.refreshSummary()
        }
        .animation(statusAnimation, value: store.errorMessage)
        .toolbar(.hidden, for: .navigationBar)
        .sheet(isPresented: $showingSettings) {
            SettingsView(
                store: store,
                accountEmail: accountEmail,
                onSignOut: onSignOut
            )
        }
    }

    private var statusAnimation: Animation? {
        reduceMotion ? nil : .smooth(duration: 0.22, extraBounce: 0)
    }
}

private struct SummaryScrollEdgeFade: View {
    enum Edge {
        case top
        case bottom
    }

    let color: Color
    let edge: Edge

    var body: some View {
        LinearGradient(
            stops: stops,
            startPoint: .top,
            endPoint: .bottom
        )
        .frame(height: 56)
        .frame(maxWidth: .infinity)
        .ignoresSafeArea(edges: ignoredSafeAreaEdges)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private var stops: [Gradient.Stop] {
        switch edge {
        case .top:
            return [
                Gradient.Stop(color: color, location: 0),
                Gradient.Stop(color: color.opacity(0.85), location: 0.28),
                Gradient.Stop(color: color.opacity(0), location: 1)
            ]
        case .bottom:
            return [
                Gradient.Stop(color: color.opacity(0), location: 0),
                Gradient.Stop(color: color.opacity(0.85), location: 0.72),
                Gradient.Stop(color: color, location: 1)
            ]
        }
    }

    private var ignoredSafeAreaEdges: SwiftUI.Edge.Set {
        edge == .top ? .top : .bottom
    }
}

private struct ActivityTopBand: View {
    let snapshot: DashboardSnapshot
    let onSettings: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            ActivityHeader(
                syncState: snapshot.syncState,
                lastUpdated: snapshot.lastUpdated,
                date: snapshot.date,
                onSettings: onSettings
            )

            ActivityHeroPanel(rings: snapshot.rings)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .background(Color.activityHeaderSurface, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(.dashboardStroke, lineWidth: 1)
        }
    }
}

private struct ActivityHeader: View {
    let syncState: SyncState
    let lastUpdated: Date
    let date: Date
    let onSettings: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .center, spacing: 14) {
                Text("Summary")
                    .font(.system(size: 36, weight: .bold, design: .rounded))
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)

                Spacer(minLength: 10)

                Button(action: onSettings) {
                    Image(systemName: "gearshape.fill")
                        .font(.system(size: 16, weight: .bold))
                        .frame(width: 36, height: 36)
                        .background(.dashboardTintSurface, in: Circle())
                        .overlay {
                            Circle()
                                .stroke(.dashboardStroke, lineWidth: 1)
                        }
                }
                .buttonStyle(.plain)
                .foregroundStyle(.primary)
                .accessibilityLabel("Settings")
            }

            ViewThatFits(in: .horizontal) {
                HStack(alignment: .center, spacing: 10) {
                    subtitleText
                    Spacer(minLength: 8)
                    SyncPill(syncState: syncState, lastUpdated: lastUpdated)
                }

                VStack(alignment: .leading, spacing: 8) {
                    subtitleText
                        .frame(maxWidth: .infinity, alignment: .leading)
                    SyncPill(syncState: syncState, lastUpdated: lastUpdated)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var subtitleText: some View {
        Text(headerSubtitle)
            .font(.headline.weight(.bold))
            .foregroundStyle(.secondary)
            .lineLimit(2)
            .minimumScaleFactor(0.78)
    }

    private var headerSubtitle: String {
        date.formatted(date: .abbreviated, time: .omitted)
    }
}

private struct ActivityHeroPanel: View {
    let rings: RingSet

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .center, spacing: 12) {
                ActivityRingStats(rings: rings)
                    .frame(width: 124, alignment: .leading)

                Spacer(minLength: 0)

                ActivityRingsView(
                    rings: rings,
                    showsCenterSummary: false,
                    showsRingBadges: true
                )
                .frame(width: 176)
            }

            VStack(alignment: .leading, spacing: 16) {
                ActivityRingsView(
                    rings: rings,
                    showsCenterSummary: false,
                    showsRingBadges: true
                )
                .frame(maxWidth: 204)
                .frame(maxWidth: .infinity)

                ActivityRingStats(rings: rings)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct ActivityRingStats: View {
    let rings: RingSet

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            heroMetric(title: "Move", metric: rings.move, unit: "kcal", color: .moveRing)
            heroMetric(title: "Exercise", metric: rings.active, unit: "min", color: .activeRing)
            heroMetric(title: "Steps", metric: rings.steps, unit: "steps", color: .stepsRing)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func heroMetric(
        title: String,
        metric: RingMetric,
        unit: String,
        color: Color
    ) -> some View {
        HStack(alignment: .center, spacing: 8) {
            RoundedRectangle(cornerRadius: 3, style: .continuous)
                .fill(color)
                .frame(width: 4, height: 34)

            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(color)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)

                HStack(alignment: .lastTextBaseline, spacing: 3) {
                    Text(DashboardFormatting.integer(metric.value))
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.48)
                        .allowsTightening(true)

                    Text(unit)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.65)
                        .allowsTightening(true)
                }
            }
            .layoutPriority(1)

            Spacer(minLength: 0)
        }
        .accessibilityElement(children: .combine)
    }
}

private struct SyncPill: View {
    let syncState: SyncState
    let lastUpdated: Date
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        HStack(spacing: 6) {
            icon
                .frame(width: 14, height: 14)
            Text(title)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
        .font(.caption.weight(.bold))
        .foregroundStyle(foregroundStyle)
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(backgroundStyle, in: Capsule())
        .overlay {
            Capsule()
                .stroke(borderStyle, lineWidth: 1)
        }
        .animation(syncAnimation, value: syncState)
        .accessibilityLabel(accessibilityText)
    }

    @ViewBuilder
    private var icon: some View {
        switch syncState {
        case .refreshing:
            ProgressView()
                .controlSize(.mini)
        case .failed:
            Image(systemName: "exclamationmark.triangle.fill")
        case .idle:
            Image(systemName: lastUpdated > .distantPast ? "checkmark.circle.fill" : "circle.dashed")
        }
    }

    private var title: String {
        switch syncState {
        case .refreshing:
            return lastUpdated > .distantPast
                ? "Updating - \(DashboardFormatting.compactUpdateAge(lastUpdated))"
                : "Updating"
        case .failed:
            return lastUpdated > .distantPast
                ? "Issue - \(DashboardFormatting.compactUpdateAge(lastUpdated))"
                : "Issue"
        case .idle:
            return DashboardFormatting.compactUpdate(lastUpdated)
        }
    }

    private var accessibilityText: String {
        switch syncState {
        case .refreshing:
            return "Refreshing dashboard. \(DashboardFormatting.relativeUpdate(lastUpdated))"
        case .failed:
            return "Dashboard refresh failed. \(DashboardFormatting.relativeUpdate(lastUpdated))"
        case .idle:
            return DashboardFormatting.relativeUpdate(lastUpdated)
        }
    }

    private var foregroundStyle: Color {
        switch syncState {
        case .failed:
            return Color(uiColor: .systemRed)
        case .refreshing:
            return Color(uiColor: .systemBlue)
        case .idle:
            return Color(uiColor: .secondaryLabel)
        }
    }

    private var backgroundStyle: Color {
        switch syncState {
        case .failed:
            return .dashboardErrorSurface
        case .refreshing:
            return .dashboardSyncSurface
        case .idle:
            return .dashboardTintSurface
        }
    }

    private var borderStyle: Color {
        switch syncState {
        case .failed:
            return .dashboardErrorStroke
        case .refreshing:
            return .dashboardSyncStroke
        case .idle:
            return .dashboardStroke
        }
    }

    private var syncAnimation: Animation? {
        reduceMotion ? nil : .smooth(duration: 0.18, extraBounce: 0)
    }
}

private struct SyncStatusBanner: View {
    let errorMessage: String

    var body: some View {
        statusContent(
            systemImage: "exclamationmark.triangle.fill",
            title: "Could not refresh",
            message: errorMessage,
            foregroundColor: Color(uiColor: .systemRed),
            background: .dashboardErrorSurface,
            border: .dashboardErrorStroke
        )
    }

    private func statusContent(
        systemImage: String,
        title: String,
        message: String,
        foregroundColor: Color,
        background: Color,
        border: Color
    ) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: systemImage)
                .font(.headline)
                .foregroundStyle(foregroundColor)
                .frame(width: 22)

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(.primary)
                Text(message)
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(background, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(border, lineWidth: 1)
        }
        .transition(.opacity.combined(with: .move(edge: .top)))
    }
}

#if DEBUG
#Preview("Dashboard") {
    SummaryView(
        store: .preview(snapshot: .previewPopulated),
        accountEmail: "osanyemosadebe@example.com",
        onSignOut: {}
    )
}

#Preview("Refreshing") {
    SummaryView(
        store: .preview(snapshot: .previewRefreshing),
        accountEmail: "osanyemosadebe@example.com",
        onSignOut: {}
    )
}

#Preview("Failed") {
    SummaryView(
        store: .preview(
            snapshot: .previewFailed,
            errorMessage: "Google Health did not return today's activity yet."
        ),
        accountEmail: "osanyemosadebe@example.com",
        onSignOut: {}
    )
}

#Preview("Empty") {
    SummaryView(
        store: .preview(snapshot: .previewEmpty),
        accountEmail: "osanyemosadebe@example.com",
        onSignOut: {}
    )
}

@MainActor
private extension FitnessDashboardStore {
    static func preview(
        snapshot: DashboardSnapshot,
        preferences: DashboardPreferences = .defaults,
        errorMessage: String? = nil
    ) -> FitnessDashboardStore {
        let cache = PreviewDashboardCache(snapshot: snapshot, preferences: preferences)
        let repository = DashboardRepository(
            googleHealthClient: PreviewGoogleHealthClient(snapshot: snapshot),
            cache: cache
        )
        let store = FitnessDashboardStore(repository: repository, cache: cache)
        store.snapshot = FitnessDataSnapshot.fromLegacyDashboard(snapshot)
        store.preferences = preferences
        store.errorMessage = errorMessage
        return store
    }
}

private extension DashboardSnapshot {
    static var previewPopulated: DashboardSnapshot {
        DashboardSnapshot(
            date: .now,
            rings: RingSet(
                move: RingMetric(title: "Move", value: 428, goal: 500, unit: "kcal"),
                active: RingMetric(title: "Active", value: 37, goal: 30, unit: "min"),
                steps: RingMetric(title: "Steps", value: 8_942, goal: 10_000, unit: "")
            ),
            activity: ActivitySummary(
                steps: 8_942,
                distanceMeters: 6_840,
                activeCalories: 428,
                totalCalories: 2_163,
                providedMetrics: [.steps, .distance, .activeEnergyBurned, .activeMinutes, .totalCalories]
            ),
            latestWorkout: WorkoutSummary(
                type: "Outdoor Walk",
                startTime: Date.now.addingTimeInterval(-7_200),
                durationSeconds: 2_340,
                distanceMeters: 3_120,
                calories: 242
            ),
            heart: HeartSummary(
                mostRecentHeartRate: 86,
                restingHeartRate: 58,
                measuredAt: Date.now.addingTimeInterval(-1_200)
            ),
            sleep: SleepSummary(
                durationSeconds: 27_900,
                startTime: Date.now.addingTimeInterval(-34_200),
                endTime: Date.now.addingTimeInterval(-6_300)
            ),
            lastUpdated: Date.now.addingTimeInterval(-185),
            syncState: .idle
        )
    }

    static var previewRefreshing: DashboardSnapshot {
        var snapshot = previewPopulated
        snapshot.syncState = .refreshing
        snapshot.lastUpdated = Date.now.addingTimeInterval(-900)
        return snapshot
    }

    static var previewFailed: DashboardSnapshot {
        var snapshot = previewPopulated
        snapshot.syncState = .failed
        snapshot.lastUpdated = Date.now.addingTimeInterval(-3_600)
        return snapshot
    }

    static var previewEmpty: DashboardSnapshot {
        .empty()
    }
}

@MainActor
private final class PreviewDashboardCache: DashboardCaching {
    private var snapshot: DashboardSnapshot?
    private var preferences: DashboardPreferences

    init(snapshot: DashboardSnapshot?, preferences: DashboardPreferences) {
        self.snapshot = snapshot
        self.preferences = preferences
    }

    func loadDashboard() -> DashboardSnapshot? {
        snapshot
    }

    func saveDashboard(_ snapshot: DashboardSnapshot) {
        self.snapshot = snapshot
    }

    func loadPreferences() -> DashboardPreferences {
        preferences
    }

    func savePreferences(_ preferences: DashboardPreferences) {
        self.preferences = preferences
    }
}

private struct PreviewGoogleHealthClient: GoogleHealthServing {
    let snapshot: DashboardSnapshot

    func fetchDashboard(goals: ActivityGoals, date: Date) async throws -> DashboardSnapshot {
        snapshot
    }
}
#endif
