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
                switch contentState {
                case .initialLoading:
                    DashboardLoadingState(title: "Loading your summary")
                        .padding(.horizontal, 20)
                        .padding(.top, 12)
                case .failed(let message):
                    DashboardFailureState(message: message) {
                        Task { await store.refreshSummary(announcesResult: true) }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 12)
                case .empty:
                    DashboardEmptyState(
                        title: "No summary data yet",
                        systemImage: "circle.grid.cross",
                        message: "Pull to refresh after Google Health has activity to share."
                    )
                    .padding(.horizontal, 20)
                    .padding(.top, 12)
                case .cachedRefreshing, .populated:
                    summaryContent
                }
            }
        }
        .scrollIndicators(.hidden)
        .background {
            Color.fitbitBackground
                .ignoresSafeArea()
        }
        .refreshable {
            await store.refreshSummary(announcesResult: true)
        }
        .animation(statusAnimation, value: store.errorMessage)
        .navigationTitle("Summary")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showingSettings = true
                } label: {
                    Label("Settings", systemImage: "gearshape.fill")
                }
                .frame(minWidth: DashboardDesign.minimumControlSize, minHeight: DashboardDesign.minimumControlSize)
            }
        }
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

    @ViewBuilder
    private var summaryContent: some View {
        if store.snapshot.summary.activity.hasAnyData {
            ActivityTopBand(snapshot: store.snapshot.summary)
                .padding(.horizontal, 20)
                .padding(.top, 8)
        }

        VStack(alignment: .leading, spacing: 24) {
            if let errorMessage = store.errorMessage {
                SyncStatusBanner(errorMessage: errorMessage)
            }

            SummaryHourlyPairSection(
                snapshot: store.snapshot,
                units: store.preferences.units,
                onSelectMetric: { store.route(to: .metric($0)) }
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

    private var contentState: DashboardContentState {
        DashboardContentState(
            section: store.sectionState(.summary),
            hasContent: store.snapshot.summary.activity.hasAnyData
                || store.snapshot.summary.latestWorkout != nil
                || store.snapshot.summary.heart.mostRecentHeartRate != nil
                || store.snapshot.summary.heart.restingHeartRate != nil
                || store.snapshot.summary.sleep != nil
        )
    }
}

private struct ActivityTopBand: View {
    let snapshot: DashboardSnapshot

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            ActivityStatusHeader(
                syncState: snapshot.syncState,
                lastUpdated: snapshot.lastUpdated,
                date: snapshot.date
            )

            ActivityHeroPanel(rings: snapshot.rings)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .dashboardCard(
            background: .activityHeaderSurface,
            border: .dashboardStroke,
            padding: 18
        )
    }
}

private struct ActivityStatusHeader: View {
    let syncState: SyncState
    let lastUpdated: Date
    let date: Date

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
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
            .minimumScaleFactor(0.78)
            .allowsTightening(true)
            .fixedSize(horizontal: false, vertical: true)
    }

    private var headerSubtitle: String {
        DashboardFormatting.compactDayLabel(for: date)
    }
}

private struct ActivityHeroPanel: View {
    let rings: RingSet
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    @ViewBuilder
    var body: some View {
        if dynamicTypeSize.isAccessibilitySize {
            verticalLayout
        } else {
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .center, spacing: 16) {
                    ActivityRingStats(rings: rings)
                        .frame(minWidth: DashboardDesign.minimumCardWidth, alignment: .leading)

                    ActivityRingsView(
                        rings: rings,
                        showsCenterSummary: false,
                        showsRingBadges: true
                    )
                    .frame(maxWidth: 190)
                }

                verticalLayout
            }
        }
    }

    private var verticalLayout: some View {
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
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct ActivityRingStats: View {
    let rings: RingSet

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            heroMetric(title: "Steps", metric: rings.steps, unit: "steps", color: .stepsRing)
            heroMetric(title: "Exercise", metric: rings.active, unit: "min", color: .activeRing)
            heroMetric(title: "Move", metric: rings.move, unit: "kcal", color: .moveRing)
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
                    .fixedSize(horizontal: false, vertical: true)

                HStack(alignment: .lastTextBaseline, spacing: 3) {
                    Text(DashboardFormatting.integer(metric.value))
                        .font(.title2.bold().monospacedDigit())
                        .monospacedDigit()
                        .foregroundStyle(.primary)
                        .fixedSize(horizontal: false, vertical: true)

                    Text(unit)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .layoutPriority(1)

            Spacer(minLength: 0)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(title)
        .accessibilityValue(
            "\(DashboardAccessibilityFormatting.metric(value: DashboardFormatting.integer(metric.value), unit: unit)), goal \(DashboardAccessibilityFormatting.metric(value: DashboardFormatting.integer(metric.goal), unit: unit)), \(DashboardFormatting.percent(metric.progress))"
        )
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
        .dashboardCard(
            background: background,
            border: border,
            radius: DashboardCardRadius.compact,
            padding: 14
        )
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
                calories: 242,
                averageHeartRate: 122,
                steps: 4_210
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
