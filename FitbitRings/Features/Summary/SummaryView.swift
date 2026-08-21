import SwiftUI

struct SummaryView: View {
    @Bindable var viewModel: SummaryViewModel
    let accountEmail: String?
    let onSignOut: () -> Void
    @State private var showingSettings = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 18) {
                    dashboardHeader
                    SyncStatusBanner(
                        syncState: viewModel.snapshot.syncState,
                        errorMessage: viewModel.errorMessage
                    )

                    dashboardHero

                    ActivitySummarySection(
                        summary: viewModel.snapshot.activity,
                        units: viewModel.preferences.units
                    )
                    LatestWorkoutCard(
                        workout: viewModel.snapshot.latestWorkout,
                        units: viewModel.preferences.units
                    )
                    HeartSummarySection(summary: viewModel.snapshot.heart)
                    SleepSummarySection(summary: viewModel.snapshot.sleep)
                }
                .padding(.horizontal, 20)
                .padding(.top, 12)
                .padding(.bottom, 32)
            }
            .background {
                Color.fitbitBackground
                    .ignoresSafeArea()
            }
            .refreshable {
                await viewModel.refresh()
            }
            .navigationTitle("Fitbit Rings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingSettings = true
                    } label: {
                        Image(systemName: "gearshape")
                    }
                    .accessibilityLabel("Settings")
                }
            }
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

    private var dashboardHeader: some View {
        HStack(alignment: .center, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Today")
                    .font(.system(.largeTitle, design: .rounded, weight: .bold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)

                Text(Date.now.formatted(date: .complete, time: .omitted))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            SyncPill(syncState: viewModel.snapshot.syncState, lastUpdated: viewModel.snapshot.lastUpdated)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var dashboardHero: some View {
        VStack(spacing: 18) {
            ActivityRingsView(rings: viewModel.snapshot.rings)
            RingGoalProgress(rings: viewModel.snapshot.rings)
        }
        .padding(18)
        .background(.summarySurface, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(.dashboardStroke, lineWidth: 1)
        }
        .shadow(color: Color.black.opacity(0.06), radius: 16, x: 0, y: 8)
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
