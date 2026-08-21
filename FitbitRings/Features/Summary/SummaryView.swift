import SwiftUI

struct SummaryView: View {
    @Bindable var viewModel: SummaryViewModel
    let accountEmail: String?
    let onSignOut: () -> Void
    @State private var showingSettings = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    ActivityTopBand(
                        snapshot: viewModel.snapshot,
                        onSettings: {
                            showingSettings = true
                        }
                    )

                    VStack(alignment: .leading, spacing: 30) {
                        SyncStatusBanner(
                            syncState: viewModel.snapshot.syncState,
                            errorMessage: viewModel.errorMessage
                        )

                        TodayGoalsSection(
                            snapshot: viewModel.snapshot,
                            units: viewModel.preferences.units
                        )

                        if let latestWorkout = viewModel.snapshot.latestWorkout {
                            RecentWorkoutSection(
                                workout: latestWorkout,
                                units: viewModel.preferences.units
                            )
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 26)
                    .padding(.bottom, 38)
                }
            }
            .scrollIndicators(.hidden)
            .background {
                Color.fitbitBackground
                    .ignoresSafeArea()
            }
            .refreshable {
                await viewModel.refresh()
            }
            .toolbar(.hidden, for: .navigationBar)
            .sheet(isPresented: $showingSettings) {
                SettingsView(
                    viewModel: viewModel,
                    accountEmail: accountEmail,
                    onSignOut: onSignOut
                )
            }
        }
        .preferredColorScheme(viewModel.preferences.units.appearance.preferredColorScheme)
    }
}

private struct ActivityTopBand: View {
    let snapshot: DashboardSnapshot
    let onSettings: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 26) {
            ActivityHeader(
                syncState: snapshot.syncState,
                lastUpdated: snapshot.lastUpdated,
                onSettings: onSettings
            )

            ActivityHeroPanel(rings: snapshot.rings)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 20)
        .padding(.top, 54)
        .padding(.bottom, 30)
        .background(Color.activityHeaderSurface)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(.dashboardStroke)
                .frame(height: 1)
        }
    }
}

private struct ActivityHeader: View {
    let syncState: SyncState
    let lastUpdated: Date
    let onSettings: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Activity")
                    .font(.system(size: 38, weight: .bold, design: .rounded))
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)

                Text("Today")
                    .font(.title3.weight(.bold))
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            VStack(alignment: .trailing, spacing: 10) {
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

                SyncPill(syncState: syncState, lastUpdated: lastUpdated)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct ActivityHeroPanel: View {
    let rings: RingSet

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .center, spacing: 14) {
                ActivityRingStats(rings: rings)
                    .frame(width: 116, alignment: .leading)

                Spacer(minLength: 0)

                ActivityRingsView(
                    rings: rings,
                    showsCenterSummary: false,
                    showsRingBadges: true
                )
                .frame(width: 208)
            }

            VStack(alignment: .leading, spacing: 20) {
                ActivityRingsView(
                    rings: rings,
                    showsCenterSummary: false,
                    showsRingBadges: true
                )
                .frame(maxWidth: 250)
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
        ViewThatFits(in: .horizontal) {
            VStack(alignment: .leading, spacing: 22) {
                heroMetric(title: "Move", metric: rings.move, unit: "kcal", color: .moveRing)
                heroMetric(title: "Exercise", metric: rings.active, unit: "min", color: .activeRing)
                heroMetric(title: "Steps", metric: rings.steps, unit: "steps", color: .stepsRing)
            }

            HStack(alignment: .top, spacing: 22) {
                heroMetric(title: "Move", metric: rings.move, unit: "kcal", color: .moveRing)
                heroMetric(title: "Exercise", metric: rings.active, unit: "min", color: .activeRing)
                heroMetric(title: "Steps", metric: rings.steps, unit: "steps", color: .stepsRing)
            }
        }
    }

    private func heroMetric(
        title: String,
        metric: RingMetric,
        unit: String,
        color: Color
    ) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.title3.weight(.bold))
                .foregroundStyle(color)
                .lineLimit(1)
                .minimumScaleFactor(0.72)

            Text(DashboardFormatting.integer(metric.value))
                .font(.system(size: 30, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.45)
                .allowsTightening(true)

            Text(unit)
                .font(.headline.weight(.semibold))
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .accessibilityElement(children: .combine)
    }
}

private struct SyncPill: View {
    let syncState: SyncState
    let lastUpdated: Date

    var body: some View {
        HStack(spacing: 6) {
            icon
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
}

private struct SyncStatusBanner: View {
    let syncState: SyncState
    let errorMessage: String?

    var body: some View {
        if let errorMessage {
            statusContent(
                systemImage: "exclamationmark.triangle.fill",
                title: "Could not refresh",
                message: errorMessage,
                foregroundColor: Color(uiColor: .systemRed),
                background: .dashboardErrorSurface,
                border: .dashboardErrorStroke
            )
        } else if syncState == .refreshing {
            statusContent(
                systemImage: "arrow.triangle.2.circlepath",
                title: "Refreshing data",
                message: "Showing the latest cached dashboard while Google Health updates.",
                foregroundColor: Color(uiColor: .systemBlue),
                background: .dashboardSyncSurface,
                border: .dashboardSyncStroke
            )
        }
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
    }
}

#if DEBUG
#Preview("Dashboard") {
    SummaryView(
        viewModel: .preview(snapshot: .previewPopulated),
        accountEmail: "osanyemosadebe@example.com",
        onSignOut: {}
    )
}

#Preview("Refreshing") {
    SummaryView(
        viewModel: .preview(snapshot: .previewRefreshing),
        accountEmail: "osanyemosadebe@example.com",
        onSignOut: {}
    )
}

#Preview("Failed") {
    SummaryView(
        viewModel: .preview(
            snapshot: .previewFailed,
            errorMessage: "Google Health did not return today's activity yet."
        ),
        accountEmail: "osanyemosadebe@example.com",
        onSignOut: {}
    )
}

#Preview("Empty") {
    SummaryView(
        viewModel: .preview(snapshot: .previewEmpty),
        accountEmail: "osanyemosadebe@example.com",
        onSignOut: {}
    )
}

@MainActor
private extension SummaryViewModel {
    static func preview(
        snapshot: DashboardSnapshot,
        preferences: DashboardPreferences = .defaults,
        errorMessage: String? = nil
    ) -> SummaryViewModel {
        let cache = PreviewDashboardCache(snapshot: snapshot, preferences: preferences)
        let repository = DashboardRepository(
            googleHealthClient: PreviewGoogleHealthClient(snapshot: snapshot),
            cache: cache
        )
        let viewModel = SummaryViewModel(repository: repository, cache: cache)
        viewModel.snapshot = snapshot
        viewModel.preferences = preferences
        viewModel.errorMessage = errorMessage
        return viewModel
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
                totalCalories: 2_163
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
