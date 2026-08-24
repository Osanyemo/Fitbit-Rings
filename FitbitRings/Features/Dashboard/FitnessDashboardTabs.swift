import SwiftUI

struct FitnessDashboardView: View {
    @Bindable var store: FitnessDashboardStore
    let accountEmail: String?
    let onSignOut: () -> Void

    var body: some View {
        TabView(selection: $store.selectedTab) {
            NavigationStack(path: $store.summaryPath) {
                SummaryView(
                    store: store,
                    accountEmail: accountEmail,
                    onSignOut: onSignOut
                )
                .navigationDestination(for: DashboardRoute.self) { route in
                    DashboardRouteDestination(route: route, store: store)
                }
            }
            .tabItem {
                Label(FitnessDashboardTab.summary.title, systemImage: FitnessDashboardTab.summary.symbolName)
            }
            .tag(FitnessDashboardTab.summary)

            NavigationStack(path: $store.activityPath) {
                ActivityTabView(store: store)
                    .navigationDestination(for: DashboardRoute.self) { route in
                        DashboardRouteDestination(route: route, store: store)
                    }
            }
            .tabItem {
                Label(FitnessDashboardTab.activity.title, systemImage: FitnessDashboardTab.activity.symbolName)
            }
            .tag(FitnessDashboardTab.activity)

            NavigationStack(path: $store.workoutPath) {
                WorkoutsTabView(store: store)
                    .navigationDestination(for: DashboardRoute.self) { route in
                        DashboardRouteDestination(route: route, store: store)
                    }
            }
            .tabItem {
                Label(FitnessDashboardTab.workouts.title, systemImage: FitnessDashboardTab.workouts.symbolName)
            }
            .tag(FitnessDashboardTab.workouts)

            NavigationStack(path: $store.healthPath) {
                HealthTabView(store: store)
                    .navigationDestination(for: DashboardRoute.self) { route in
                        DashboardRouteDestination(route: route, store: store)
                    }
            }
            .tabItem {
                Label(FitnessDashboardTab.health.title, systemImage: FitnessDashboardTab.health.symbolName)
            }
            .tag(FitnessDashboardTab.health)
        }
        .tint(.activeRing)
        .preferredColorScheme(store.preferences.units.appearance.preferredColorScheme)
        .task {
            await store.loadSelectedTabIfNeeded()
        }
        .onChange(of: store.selectedTab) { _, tab in
            Task {
                await store.loadIfNeeded(tab.section)
            }
        }
    }
}

struct SummaryHourlyPairSection: View {
    let snapshot: FitnessDataSnapshot
    let units: UnitPreferences
    let onSelectMetric: (GoogleHealthDataType) -> Void

    var body: some View {
        let stepsPoints = hourlySeries(for: .steps)?.points ?? []
        let distancePoints = hourlySeries(for: .distance)?.points ?? []
        let reservesChartSpace = stepsPoints.count > 1 || distancePoints.count > 1

        if snapshot.summary.activity.hasData(for: .steps)
            || snapshot.summary.activity.hasData(for: .distance) {
            DashboardAdaptiveGrid {
                if snapshot.summary.activity.hasData(for: .steps) {
                    DashboardMetricCard(
                        title: "Steps",
                        value: stepsValue,
                        unit: stepsUnit,
                        systemImage: GoogleHealthDataType.steps.symbolName,
                        accentColor: .stepsRing,
                        points: stepsPoints,
                        reservesChartSpace: reservesChartSpace,
                        isAvailable: true
                    ) {
                        onSelectMetric(.steps)
                    }
                }

                if snapshot.summary.activity.hasData(for: .distance) {
                    DashboardMetricCard(
                        title: "Distance",
                        value: distanceValue.value,
                        unit: distanceValue.unit,
                        systemImage: GoogleHealthDataType.distance.symbolName,
                        accentColor: .distanceAccent,
                        points: distancePoints,
                        reservesChartSpace: reservesChartSpace,
                        isAvailable: true
                    ) {
                        onSelectMetric(.distance)
                    }
                }
            }
        }
    }

    private var stepsValue: String {
        snapshot.summary.activity.hasData(for: .steps)
            ? DashboardFormatting.integer(Double(snapshot.summary.activity.steps))
            : "No data"
    }

    private var stepsUnit: String {
        snapshot.summary.activity.hasData(for: .steps) ? "steps" : ""
    }

    private var distanceValue: DashboardFormatting.MetricValue {
        guard snapshot.summary.activity.hasData(for: .distance) else {
            return DashboardFormatting.MetricValue(value: "No data", unit: "")
        }
        return DashboardFormatting.distanceParts(
            snapshot.summary.activity.distanceMeters,
            unit: units.distanceUnit
        )
    }

    private func hourlySeries(for type: GoogleHealthDataType) -> NumericMetricSeries? {
        snapshot.activity.hourlySeries.first { $0.type == type }
    }
}

private struct ActivityTabView: View {
    @Bindable var store: FitnessDashboardStore

    var body: some View {
        DashboardScrollView(
            title: "Activity",
            subtitle: DashboardFormatting.compactUpdate(store.snapshot.summary.lastUpdated),
            state: store.sectionState(.activity),
            onRefresh: {
                await store.refreshSection(.activity, announcesResult: true)
            }
        ) {
            VStack(alignment: .leading, spacing: 24) {
                switch contentState {
                case .initialLoading:
                    DashboardLoadingState(title: "Loading activity")
                case .failed(let message):
                    DashboardFailureState(message: message) {
                        Task { await store.refreshSection(.activity, announcesResult: true) }
                    }
                case .empty:
                    DashboardEmptyState(
                        title: "No activity data",
                        systemImage: "figure.run.circle",
                        message: "Activity appears here when Google Health has measurements to share."
                    )
                case .cachedRefreshing, .populated:
                    if store.snapshot.summary.activity.hasAnyData {
                        ActivityTodayFocusSection(
                            snapshot: store.snapshot.summary,
                            onSelectMetric: { type in
                                store.route(to: .metric(type))
                            }
                        )
                    }

                    if store.snapshot.activity.dailySeries.contains(where: { !$0.points.isEmpty }) {
                        DashboardSeriesSection(
                            title: "14-Day Trends",
                            series: store.snapshot.activity.dailySeries,
                            units: store.preferences.units,
                            onSelectMetric: { type in
                                store.route(to: .metric(type))
                            }
                        )
                    }

                    BucketedSeriesSection(series: store.snapshot.activity.bucketedSeries)
                }
            }
        }
        .task {
            await store.loadIfNeeded(.activity)
        }
    }

    private var hasActivityContent: Bool {
        store.snapshot.summary.activity.hasAnyData
            || store.snapshot.activity.dailySeries.contains(where: { !$0.points.isEmpty })
            || !store.snapshot.activity.bucketedSeries.isEmpty
    }

    private var contentState: DashboardContentState {
        DashboardContentState(
            section: store.sectionState(.activity),
            hasContent: hasActivityContent
        )
    }
}

private struct WorkoutsTabView: View {
    @Bindable var store: FitnessDashboardStore

    var body: some View {
        DashboardScrollView(
            title: "Workouts",
            subtitle: "Last 14 days",
            state: store.sectionState(.workouts),
            onRefresh: {
                await store.refreshSection(.workouts, announcesResult: true)
            }
        ) {
            VStack(alignment: .leading, spacing: 14) {
                switch contentState {
                case .initialLoading:
                    DashboardLoadingState(title: "Loading workouts")
                case .failed(let message):
                    DashboardFailureState(message: message) {
                        Task { await store.refreshSection(.workouts, announcesResult: true) }
                    }
                case .empty:
                    DashboardEmptyState(
                        title: "No workouts",
                        systemImage: "dumbbell",
                        message: "Workouts from the last 14 days appear here."
                    )
                case .cachedRefreshing, .populated:
                    ForEach(workoutGroups) { group in
                        VStack(alignment: .leading, spacing: 12) {
                            DashboardSectionTitle(title: LocalizedStringKey(group.title))

                            ForEach(group.workouts) { workout in
                                WorkoutRowCard(workout: workout, units: store.preferences.units) {
                                    store.workoutPath.append(.workout(workout.id))
                                }
                            }
                        }
                    }
                }
            }
        }
        .task {
            await store.loadIfNeeded(.workouts)
        }
    }

    private var contentState: DashboardContentState {
        DashboardContentState(
            section: store.sectionState(.workouts),
            hasContent: !store.snapshot.workouts.isEmpty
        )
    }

    private var workoutGroups: [WorkoutDayGroup] {
        let calendar = Calendar.current
        let groups = Dictionary(grouping: store.snapshot.workouts) {
            calendar.startOfDay(for: $0.startTime)
        }

        return groups
            .map { day, workouts in
                WorkoutDayGroup(
                    day: day,
                    title: DashboardFormatting.compactDayLabel(for: day),
                    workouts: workouts.sorted { $0.startTime > $1.startTime }
                )
            }
            .sorted { $0.day > $1.day }
    }
}

private struct WorkoutDayGroup: Identifiable {
    var id: Date { day }
    let day: Date
    let title: String
    let workouts: [WorkoutDetail]
}

private struct HealthTabView: View {
    @Bindable var store: FitnessDashboardStore

    var body: some View {
        DashboardScrollView(
            title: "Health",
            subtitle: "Last 14 days",
            state: store.sectionState(.health),
            onRefresh: {
                await store.refreshSection(.health, announcesResult: true)
            }
        ) {
            VStack(alignment: .leading, spacing: 22) {
                switch contentState {
                case .initialLoading:
                    DashboardLoadingState(title: "Loading health data")
                case .failed(let message):
                    DashboardFailureState(message: message) {
                        Task { await store.refreshSection(.health, announcesResult: true) }
                    }
                case .empty:
                    DashboardEmptyState(
                        title: "No health data",
                        systemImage: "heart.text.square",
                        message: "Shared heart, sleep, vital, and body measurements appear here."
                    )
                case .cachedRefreshing, .populated:
                    HealthOverviewSection(
                        health: store.snapshot.health,
                        units: store.preferences.units,
                        onSelectMetric: { store.route(to: .metric($0)) },
                        onSelectSleep: { store.route(to: .sleep($0)) }
                    )

                    HealthMetricGroup(
                        title: "Heart",
                        series: store.snapshot.health.heartSeries,
                        units: store.preferences.units,
                        onSelectMetric: { store.route(to: .metric($0)) }
                    )

                    if !store.snapshot.health.sleepSessions.isEmpty {
                        SleepSessionsSection(
                            sessions: store.snapshot.health.sleepSessions,
                            onSelect: { store.route(to: .sleep($0.id)) }
                        )
                    }

                    HealthMetricGroup(
                        title: "Sleep Metrics",
                        series: store.snapshot.health.sleepMetricSeries,
                        units: store.preferences.units,
                        onSelectMetric: { store.route(to: .metric($0)) }
                    )

                    HealthMetricGroup(
                        title: "Vitals",
                        series: store.snapshot.health.vitalSeries,
                        units: store.preferences.units,
                        onSelectMetric: { store.route(to: .metric($0)) }
                    )

                    HealthMetricGroup(
                        title: "Cardio Fitness",
                        series: store.snapshot.health.cardioFitnessSeries,
                        units: store.preferences.units,
                        onSelectMetric: { store.route(to: .metric($0)) }
                    )

                    HealthMetricGroup(
                        title: "Body",
                        series: store.snapshot.health.bodySeries,
                        units: store.preferences.units,
                        onSelectMetric: { store.route(to: .metric($0)) }
                    )
                }
            }
        }
        .task {
            await store.loadIfNeeded(.health)
        }
    }

    private var contentState: DashboardContentState {
        DashboardContentState(
            section: store.sectionState(.health),
            hasContent: !store.snapshot.health.isEmpty
        )
    }
}

private struct HealthOverviewSection: View {
    let health: HealthDashboardData
    let units: UnitPreferences
    let onSelectMetric: (GoogleHealthDataType) -> Void
    let onSelectSleep: (String) -> Void

    @ViewBuilder
    var body: some View {
        let items = overviewItems
        if !items.isEmpty {
            VStack(alignment: .leading, spacing: 14) {
                DashboardSectionTitle(title: "Overview")

                if items.count == 1, let item = items.first {
                    Button {
                        select(item)
                    } label: {
                        HealthOverviewCard(item: item)
                    }
                    .buttonStyle(DashboardInteractiveCardButtonStyle())
                } else {
                    DashboardAdaptiveGrid {
                        ForEach(items) { item in
                            Button {
                                select(item)
                            } label: {
                                HealthOverviewCard(item: item)
                            }
                            .buttonStyle(DashboardInteractiveCardButtonStyle())
                        }
                    }
                }
            }
        }
    }

    private var overviewItems: [HealthOverviewItem] {
        [heartItem, sleepItem].compactMap { $0 }
    }

    private var heartItem: HealthOverviewItem? {
        let preferredTypes: [GoogleHealthDataType] = [
            .heartRate,
            .dailyRestingHeartRate,
            .heartRateVariability,
            .dailyHeartRateVariability
        ]
        let preferredSeries = preferredTypes
            .compactMap { health.series(for: $0) }
            .first { !$0.points.isEmpty }
        guard let series = preferredSeries ?? health.heartSeries.first(where: { !$0.points.isEmpty }),
              let latest = series.latestPoint else {
            return nil
        }

        let value = DashboardFormatting.metricValue(latest.value, type: series.type, units: units)
        return HealthOverviewItem(
            title: series.type.displayName,
            value: value.value,
            unit: value.unit,
            subtitle: "Measured \(latest.dashboardDateLabel(for: series.type))",
            systemImage: series.type.symbolName,
            accentColor: series.type.accentColor,
            destination: .metric(series.type)
        )
    }

    private var sleepItem: HealthOverviewItem? {
        guard let session = latestSleepSession else { return nil }

        let duration = DashboardFormatting.durationParts(session.summaryValue.durationSeconds)
        return HealthOverviewItem(
            title: "Sleep",
            value: duration.value,
            unit: duration.unit,
            subtitle: sleepRange(for: session),
            systemImage: "moon.zzz.fill",
            accentColor: .sleepAccent,
            destination: .sleep(session.id)
        )
    }

    private var latestSleepSession: SleepSession? {
        health.sleepSessions.max { sleepSortDate($0) < sleepSortDate($1) }
    }

    private func sleepSortDate(_ session: SleepSession) -> Date {
        session.endTime ?? session.startTime ?? .distantPast
    }

    private func sleepRange(for session: SleepSession) -> String {
        guard session.startTime != nil || session.endTime != nil else {
            return "Last sleep"
        }

        return DashboardFormatting.compactDateTimeRangeLabel(start: session.startTime, end: session.endTime) ?? "Last sleep"
    }

    private func select(_ item: HealthOverviewItem) {
        switch item.destination {
        case .metric(let type):
            onSelectMetric(type)
        case .sleep(let id):
            onSelectSleep(id)
        }
    }
}

private struct HealthOverviewItem: Identifiable {
    var id: String { destination.id }
    let title: String
    let value: String
    let unit: String
    let subtitle: String
    let systemImage: String
    let accentColor: Color
    let destination: HealthOverviewDestination
}

private enum HealthOverviewDestination {
    case metric(GoogleHealthDataType)
    case sleep(String)

    var id: String {
        switch self {
        case .metric(let type):
            return type.rawValue
        case .sleep(let id):
            return "sleep-\(id)"
        }
    }
}

private struct HealthOverviewCard: View {
    let item: HealthOverviewItem

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 8) {
                DashboardMetricBadge(systemImage: item.systemImage, accentColor: item.accentColor, size: 32)

                VStack(alignment: .leading, spacing: 3) {
                    Text(item.title)
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(.primary)
                        .fixedSize(horizontal: false, vertical: true)

                    Text(item.subtitle)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .layoutPriority(1)

                Spacer(minLength: 24)
            }
            .frame(minHeight: 48, alignment: .topLeading)
            .overlay(alignment: .topTrailing) {
                DashboardActionIndicator(accentColor: item.accentColor, size: 26)
            }

            Spacer(minLength: 0)

            DashboardCardValueRow(value: item.value, unit: item.unit, valueFontSize: 32)
        }
        .dashboardCard(
            background: overviewBackground,
            border: item.accentColor.opacity(0.18),
            padding: 14,
            minHeight: 156
        )
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(item.title)
        .accessibilityValue(
            "\(DashboardAccessibilityFormatting.metric(value: item.value, unit: item.unit)). \(item.subtitle)"
        )
    }

    private var overviewBackground: Color {
        item.accentColor.opacity(0.12)
    }
}

private struct DashboardRouteDestination: View {
    let route: DashboardRoute
    @Bindable var store: FitnessDashboardStore

    var body: some View {
        switch route.kind {
        case .metric:
            if let type = route.dataType {
                MetricDetailView(type: type, store: store)
            } else {
                DashboardEmptyState(title: "No data", systemImage: "chart.bar")
            }
        case .workout:
            if let workout = store.workout(id: route.identifier) {
                WorkoutDetailView(workout: workout, units: store.preferences.units)
            } else {
                DashboardEmptyState(title: "No workout", systemImage: "dumbbell")
            }
        case .sleep:
            if let sleep = store.sleepSession(id: route.identifier) {
                SleepDetailView(session: sleep)
            } else {
                DashboardEmptyState(title: "No sleep data", systemImage: "moon.zzz")
            }
        }
    }
}

private struct MetricDetailView: View {
    let type: GoogleHealthDataType
    @Bindable var store: FitnessDashboardStore
    @State private var selectedRange: MetricChartRange = .day

    var body: some View {
        let series = store.series(for: type)

        DashboardScrollView(
            title: type.displayName,
            subtitle: detailSubtitle(fallback: series),
            state: store.sectionState(type.category == .activity ? .activity : .health),
            showsNavigationBackButton: true,
            onRefresh: {
                if type.supportsDetailedChartRollups {
                    await store.loadMetricChart(type, range: selectedRange, force: true)
                } else {
                    await store.refreshSection(
                        type.category == .activity ? .activity : .health,
                        announcesResult: true
                    )
                }
            }
        ) {
            VStack(alignment: .leading, spacing: 22) {
                if type.supportsDetailedChartRollups {
                    MetricRangeChartSection(
                        type: type,
                        selectedRange: $selectedRange,
                        series: store.chartSeries(for: type, range: selectedRange),
                        isLoading: store.sectionState(.activity).phase == .loading,
                        units: store.preferences.units
                    )
                    .task(id: "\(type.rawValue)-\(selectedRange.rawValue)") {
                        await store.loadMetricChart(type, range: selectedRange)
                    }

                    if let series, !series.points.isEmpty {
                        MetricPointList(series: series, units: store.preferences.units)
                    }
                } else {
                    if let series, !series.points.isEmpty {
                        MetricTrendChartSection(
                            series: series,
                            units: store.preferences.units
                        )

                        MetricPointList(series: series, units: store.preferences.units)
                    } else {
                        DashboardEmptyState(title: "No data", systemImage: type.symbolName)
                    }

                    Button {
                        Task {
                            await store.loadEarlierMetric(type)
                        }
                    } label: {
                        Label("Load Earlier", systemImage: "clock.arrow.circlepath")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.large)
                    .disabled(series?.points.isEmpty != false)
                }
            }
        }
    }

    private func detailSubtitle(fallback series: NumericMetricSeries?) -> String {
        if type.supportsDetailedChartRollups,
           let chartSeries = store.chartSeries(for: type, range: selectedRange) {
            return chartSeries.rangeSubtitle
        }

        return series?.rangeSubtitle ?? "Last 14 days"
    }
}

private struct MetricRangeChartSection: View {
    let type: GoogleHealthDataType
    @Binding var selectedRange: MetricChartRange
    let series: MetricChartSeries?
    let isLoading: Bool
    let units: UnitPreferences

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Picker("Range", selection: $selectedRange) {
                ForEach(MetricChartRange.allCases) { range in
                    Text(range.shortTitle)
                        .tag(range)
                        .accessibilityLabel(range.title)
                }
            }
            .pickerStyle(.segmented)
            .accessibilityLabel("Chart range")

            if let series {
                if series.points.isEmpty {
                    DashboardEmptyState(title: "No \(selectedRange.title.lowercased()) data", systemImage: type.symbolName)
                } else {
                    chartCard(series)
                }
            } else if isLoading {
                loadingCard
            } else {
                DashboardEmptyState(title: "No \(selectedRange.title.lowercased()) data", systemImage: type.symbolName)
            }
        }
    }

    private func chartCard(_ series: MetricChartSeries) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(summaryTitle)
                .font(.caption.weight(.bold))
                .foregroundStyle(.secondary)
                .tracking(1.1)

            DashboardCardValueRow(
                value: summaryValue(for: series).value,
                unit: summaryValue(for: series).unit,
                valueFontSize: 34,
                unitFont: .title3.weight(.semibold),
                valueColor: type.accentColor,
                unitColor: type.accentColor
            )

            Text(series.rangeSubtitle)
                .font(.headline.weight(.semibold))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            MetricTimeChart(
                points: series.points,
                color: type.accentColor,
                range: series.range,
                rangeStart: series.rangeStart,
                rangeEnd: series.rangeEnd,
                mode: .full,
                style: .bar,
                title: "\(type.displayName), \(selectedRange.title)",
                rangeDescription: series.rangeSubtitle,
                axisLabel: { value in
                    DashboardFormatting.metricValue(value, type: type, units: units).value
                },
                accessibilityValue: { value in
                    DashboardFormatting.accessibilityMetricValue(value, type: type, units: units)
                }
            )
            .frame(height: 300)
        }
        .dashboardCard(
            border: type.accentColor.opacity(0.18),
            padding: 16
        )
    }

    private var loadingCard: some View {
        HStack(spacing: 12) {
            ProgressView()
                .controlSize(.small)
            Text("Loading \(selectedRange.title.lowercased())")
                .font(.headline.weight(.semibold))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .dashboardCard(
            border: .dashboardStroke,
            radius: DashboardCardRadius.compact,
            padding: 16
        )
    }

    private var summaryTitle: String {
        selectedRange == .day ? "TOTAL" : "DAILY AVERAGE"
    }

    private func summaryValue(for series: MetricChartSeries) -> DashboardFormatting.MetricValue {
        let value = selectedRange == .day
            ? series.totalValue
            : series.averageDailyValue ?? series.totalValue
        return DashboardFormatting.metricValue(value, type: type, units: units)
    }
}

private struct MetricTrendChartSection: View {
    let series: NumericMetricSeries
    let units: UnitPreferences

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("RECENT TREND")
                .font(.caption.weight(.bold))
                .foregroundStyle(.secondary)
                .tracking(1.1)

            if let latest = series.latestPoint {
                let value = DashboardFormatting.metricValue(latest.value, type: series.type, units: units)
                DashboardCardValueRow(
                    value: value.value,
                    unit: value.unit,
                    valueFontSize: 32,
                    unitFont: .title3.weight(.semibold),
                    valueColor: series.type.accentColor,
                    unitColor: series.type.accentColor
                )
            }

            Text(series.rangeSubtitle)
                .font(.headline.weight(.semibold))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            MetricTimeChart(
                points: series.points,
                color: series.type.accentColor,
                range: nil,
                rangeStart: series.rangeStart,
                rangeEnd: series.rangeEnd,
                mode: .full,
                style: .line,
                title: "\(series.type.displayName) history",
                rangeDescription: series.rangeSubtitle,
                axisLabel: { value in
                    DashboardFormatting.metricValue(value, type: series.type, units: units).value
                },
                accessibilityValue: { value in
                    DashboardFormatting.accessibilityMetricValue(value, type: series.type, units: units)
                }
            )
            .frame(height: 260)
        }
        .dashboardCard(
            border: series.type.accentColor.opacity(0.18),
            padding: 16
        )
    }
}

private struct WorkoutDetailView: View {
    let workout: WorkoutDetail
    let units: UnitPreferences

    var body: some View {
        DashboardScrollView(
            title: workout.type,
            subtitle: DashboardFormatting.compactDateTimeLabel(for: workout.startTime),
            showsNavigationBackButton: true
        ) {
            VStack(alignment: .leading, spacing: 22) {
                WorkoutRowCard(workout: workout, units: units, onSelect: nil)

                DetailMetricGrid(metrics: workout.detailMetrics(units: units))

                if !workout.zoneMinutes.isEmpty {
                    BucketList(title: "Heart Zones", buckets: workout.zoneMinutes)
                }

                if !workout.splits.isEmpty {
                    WorkoutSplitsSection(splits: workout.splits, units: units)
                }
            }
        }
    }
}

private struct SleepDetailView: View {
    let session: SleepSession

    var body: some View {
        DashboardScrollView(
            title: "Sleep",
            subtitle: sleepRange,
            showsNavigationBackButton: true
        ) {
            VStack(alignment: .leading, spacing: 22) {
                DashboardMetricCard(
                    title: "Duration",
                    value: DashboardFormatting.durationParts(session.summaryValue.durationSeconds).value,
                    unit: DashboardFormatting.durationParts(session.summaryValue.durationSeconds).unit,
                    subtitle: sleepRange,
                    systemImage: "moon.zzz.fill",
                    accentColor: .sleepAccent,
                    points: [],
                    isAvailable: session.durationSeconds != nil || session.startTime != nil || session.endTime != nil
                )

                if session.displayStages.isEmpty {
                    DashboardEmptyState(title: "No stage breakdown", systemImage: "bed.double")
                } else {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Stages")
                            .font(.title2.weight(.bold))
                        ForEach(session.displayStages) { stage in
                            HStack {
                                Text(stage.stage)
                                    .font(.headline)
                                Spacer()
                                Text(DashboardFormatting.duration(stage.durationSeconds))
                                    .font(.headline.monospacedDigit())
                                    .foregroundStyle(.secondary)
                            }
                            .dashboardCard(
                                radius: DashboardCardRadius.compact,
                                padding: 14
                            )
                        }
                    }
                }
            }
        }
    }

    private var sleepRange: String {
        return DashboardFormatting.compactDateTimeRangeLabel(start: session.startTime, end: session.endTime) ?? "Sleep session"
    }
}

private struct DashboardScrollView<Content: View>: View {
    let title: String
    var subtitle: String?
    var state: FitnessSectionState?
    var showsNavigationBackButton: Bool
    let onRefresh: (() async -> Void)?
    @ViewBuilder var content: Content

    init(
        title: String,
        subtitle: String? = nil,
        state: FitnessSectionState? = nil,
        showsNavigationBackButton: Bool = false,
        onRefresh: (() async -> Void)? = nil,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.subtitle = subtitle
        self.state = state
        self.showsNavigationBackButton = showsNavigationBackButton
        self.onRefresh = onRefresh
        self.content = content()
    }

    @ViewBuilder
    var body: some View {
        if let onRefresh {
            scrollContent
                .refreshable {
                    await onRefresh()
                }
        } else {
            scrollContent
        }
    }

    private var scrollContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                DashboardContextHeader(
                    subtitle: subtitle,
                    state: state,
                    onRetry: onRefresh
                )
                content
            }
            .padding(.horizontal, 20)
            .padding(.top, 22)
            .padding(.bottom, 34)
        }
        .scrollIndicators(.hidden)
        .background(Color.fitbitBackground.ignoresSafeArea())
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(showsNavigationBackButton ? .inline : .large)
    }
}

private struct DashboardContextHeader: View {
    var subtitle: String?
    var state: FitnessSectionState?
    var onRetry: (() async -> Void)?

    @ViewBuilder
    var body: some View {
        if subtitle != nil || state?.phase == .loading || state?.errorMessage != nil {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .firstTextBaseline, spacing: 10) {
                    if let subtitle {
                        Text(subtitle)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Spacer(minLength: 0)

                    if state?.phase == .loading {
                        Label {
                            Text("Refreshing")
                                .font(.caption.weight(.semibold))
                        } icon: {
                            ProgressView()
                                .controlSize(.mini)
                        }
                        .foregroundStyle(.secondary)
                        .accessibilityLabel("Refreshing data")
                    }
                }

                if let error = state?.errorMessage,
                   state?.lastUpdated != .distantPast {
                    VStack(alignment: .leading, spacing: 8) {
                        Label("Couldn’t refresh", systemImage: "exclamationmark.triangle.fill")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.red)

                        Text(error)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)

                        if let onRetry {
                            Button("Try Again") {
                                Task { await onRetry() }
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.regular)
                        }
                    }
                    .dashboardCard(
                        background: .dashboardErrorSurface,
                        border: .dashboardErrorStroke,
                        radius: DashboardDesign.Radius.compactCard,
                        padding: 14
                    )
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

private struct ActivityTodayFocusSection: View {
    let snapshot: DashboardSnapshot
    let onSelectMetric: (GoogleHealthDataType) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                DashboardSectionTitle(title: "Today Focus")

                Spacer(minLength: 0)

                ActivityStatusPill(text: goalStatusText)
            }

            DashboardMetricCard(
                title: primaryTitle,
                value: primaryInsight.primaryValue,
                unit: primaryInsight.primaryUnit,
                subtitle: primarySubtitle,
                systemImage: primaryInsight.systemImage,
                accentColor: primaryInsight.accentColor,
                isAvailable: primaryInsight.isAvailable
            ) {
                onSelectMetric(primaryInsight.dataType)
            }

            DashboardAdaptiveGrid {
                ForEach(supportingGoalInsights) { insight in
                    Button {
                        onSelectMetric(insight.dataType)
                    } label: {
                        ActivityGoalTile(insight: insight)
                    }
                    .buttonStyle(DashboardInteractiveCardButtonStyle())
                }
            }
        }
    }

    private var primaryTitle: String {
        guard primaryInsight.isAvailable else {
            return "Waiting for Activity"
        }

        return allAvailableGoalsComplete ? "Goals Complete" : "Next Goal"
    }

    private var primarySubtitle: String {
        allAvailableGoalsComplete
            ? "Steps, exercise, and move are complete"
            : primaryInsight.primarySubtitle
    }

    private var allAvailableGoalsComplete: Bool {
        let availableGoals = goalInsights.filter(\.isAvailable)
        return !availableGoals.isEmpty && availableGoals.allSatisfy(\.isComplete)
    }

    private var primaryInsight: ActivityGoalInsight {
        ActivityGoalPriority.primaryInsight(from: goalInsights)
            ?? goalInsights[0]
    }

    private var supportingGoalInsights: [ActivityGoalInsight] {
        goalInsights.filter { $0.id != primaryInsight.id && $0.isAvailable }
    }

    private var goalStatusText: String {
        let availableGoals = goalInsights.filter(\.isAvailable)
        guard !availableGoals.isEmpty else {
            return "No data"
        }

        let completeCount = availableGoals.filter(\.isComplete).count
        return "\(completeCount)/\(availableGoals.count) complete"
    }

    private var goalInsights: [ActivityGoalInsight] {
        [
            ActivityGoalInsight(
                title: "Steps",
                metric: snapshot.rings.steps,
                displayUnit: "steps",
                dataType: .steps,
                systemImage: "shoeprints.fill",
                accentColor: .stepsRing,
                isAvailable: snapshot.activity.hasData(for: .steps)
            ),
            ActivityGoalInsight(
                title: "Exercise",
                metric: snapshot.rings.active,
                displayUnit: "min",
                dataType: .activeMinutes,
                systemImage: "figure.run",
                accentColor: .activeRing,
                isAvailable: snapshot.activity.hasData(for: .activeMinutes)
            ),
            ActivityGoalInsight(
                title: "Move",
                metric: snapshot.rings.move,
                displayUnit: "kcal",
                dataType: .activeEnergyBurned,
                systemImage: "flame.fill",
                accentColor: .moveRing,
                isAvailable: snapshot.activity.hasData(for: .activeEnergyBurned)
            )
        ]
    }
}

struct ActivityGoalInsight: Identifiable {
    var id: GoogleHealthDataType { dataType }

    let title: String
    let value: String
    let unit: String
    let primaryValue: String
    let primaryUnit: String
    let subtitle: String
    let primarySubtitle: String
    let progressText: String
    let progress: Double
    let dataType: GoogleHealthDataType
    let systemImage: String
    let accentColor: Color
    let isAvailable: Bool
    let isComplete: Bool

    init(
        title: String,
        metric: RingMetric,
        displayUnit: String,
        dataType: GoogleHealthDataType,
        systemImage: String,
        accentColor: Color,
        isAvailable: Bool
    ) {
        self.title = title
        self.dataType = dataType
        self.systemImage = systemImage
        self.accentColor = accentColor
        self.isAvailable = isAvailable
        progress = metric.progress
        isComplete = isAvailable && metric.progress >= 1

        let logged = DashboardFormatting.integer(metric.value)
        let goal = DashboardFormatting.integer(metric.goal)
        let remaining = DashboardFormatting.integer(max(0, metric.goal - metric.value))
        progressText = DashboardFormatting.percent(metric.progress)

        if !isAvailable {
            value = "No data"
            unit = ""
            primaryValue = "No data"
            primaryUnit = ""
            subtitle = "Not available today"
            primarySubtitle = "\(title) has not synced yet"
        } else if isComplete {
            value = "Complete"
            unit = ""
            primaryValue = "Complete"
            primaryUnit = ""
            subtitle = "\(logged) of \(goal) \(displayUnit)"
            primarySubtitle = "\(title) is \(progressText) complete"
        } else {
            value = remaining
            unit = "\(displayUnit) left"
            primaryValue = remaining
            primaryUnit = "\(displayUnit) left"
            subtitle = "\(logged) of \(goal) \(displayUnit)"
            primarySubtitle = "\(title) is \(progressText) complete"
        }
    }
}

enum ActivityGoalPriority {
    static func primaryInsight(from insights: [ActivityGoalInsight]) -> ActivityGoalInsight? {
        insights.first { $0.isAvailable && !$0.isComplete }
            ?? insights.first { $0.isAvailable }
            ?? insights.first
    }
}

private struct ActivityStatusPill: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.caption.weight(.bold).monospacedDigit())
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(.dashboardTintSurface, in: Capsule())
            .overlay {
                Capsule()
                    .stroke(.dashboardStroke, lineWidth: 1)
            }
    }
}

private struct ActivityGoalTile: View {
    let insight: ActivityGoalInsight

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                DashboardMetricBadge(systemImage: insight.systemImage, accentColor: insight.accentColor, size: 26)

                Text(insight.title)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .layoutPriority(1)

                Spacer(minLength: 4)

                DashboardActionIndicator(accentColor: insight.accentColor, size: 24)
            }

            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .lastTextBaseline, spacing: 3) {
                    Text(insight.value)
                        .font(.title3.bold().monospacedDigit())
                        .monospacedDigit()
                        .foregroundStyle(insight.isAvailable ? Color.primary : Color.secondary)
                        .fixedSize(horizontal: false, vertical: true)

                    if !insight.unit.isEmpty {
                        Text(insight.unit)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                Text(insight.subtitle)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)

            if insight.isAvailable {
                ProgressView(value: min(max(insight.progress, 0), 1))
                    .tint(insight.accentColor)
                    .accessibilityLabel("\(insight.title) \(insight.progressText)")
            }
        }
        .dashboardCard(
            background: tileBackground,
            border: tileBorder,
            padding: 14,
            minHeight: 142
        )
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(insight.title)
        .accessibilityValue("\(insight.primaryValue) \(DashboardAccessibilityFormatting.expandedUnit(insight.primaryUnit, value: insight.primaryValue)). \(insight.subtitle)")
    }

    private var tileBackground: Color {
        insight.isComplete ? insight.accentColor.opacity(0.16) : Color.summarySurface
    }

    private var tileBorder: Color {
        insight.accentColor.opacity(insight.isComplete ? 0.24 : 0.18)
    }
}

struct DashboardMetricCard: View {
    let title: String
    let value: String
    let unit: String
    var subtitle: String?
    let systemImage: String
    let accentColor: Color
    var points: [NumericMetricPoint] = []
    var chartSeries: MetricChartSeries?
    var chartStyle: MetricChartStyle = .bar
    var reservesChartSpace = false
    var isAvailable = true
    var onSelect: (() -> Void)?

    var body: some View {
        if let onSelect {
            Button(action: onSelect) {
                cardContent
            }
            .buttonStyle(DashboardInteractiveCardButtonStyle())
            .accessibilityElement(children: .combine)
            .accessibilityHint("Opens details")
        } else {
            cardContent
                .accessibilityElement(children: .combine)
        }
    }

    private var cardContent: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 7) {
                DashboardMetricBadge(systemImage: systemImage, accentColor: accentColor, size: 30)

                Text(title)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)
                    .layoutPriority(1)

                Spacer(minLength: onSelect == nil ? 0 : 24)
            }
            .frame(minHeight: 34, alignment: .topLeading)
            .overlay(alignment: .topTrailing) {
                if onSelect != nil {
                    DashboardActionIndicator(accentColor: accentColor, size: 26)
                }
            }

            if let subtitle {
                Text(subtitle)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)

            DashboardCardValueRow(
                value: isAvailable ? value : "No data",
                unit: isAvailable ? unit : "",
                valueFontSize: 30,
                valueColor: isAvailable ? .primary : .secondary
            )

            if showsChart {
                MetricTimeChart(
                    points: chartPoints,
                    color: accentColor,
                    range: chartSeries?.range,
                    rangeStart: chartSeries?.rangeStart,
                    rangeEnd: chartSeries?.rangeEnd,
                    mode: .compact,
                    style: chartStyle
                )
                    .frame(height: 42)
            } else if reservesChartSpace {
                Color.clear
                    .frame(height: 42)
                    .accessibilityHidden(true)
            }
        }
        .dashboardCard(
            border: cardBorder,
            padding: 14,
            minHeight: showsChartSlot ? 190 : 142
        )
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(title)
        .accessibilityValue(cardAccessibilityValue)
    }

    private var showsChartSlot: Bool {
        showsChart || reservesChartSpace
    }

    private var showsChart: Bool {
        chartPoints.count > 1
    }

    private var cardBorder: Color {
        onSelect == nil ? Color.dashboardStroke : accentColor.opacity(0.20)
    }

    private var chartPoints: [NumericMetricPoint] {
        chartSeries?.points ?? points
    }

    private var cardAccessibilityValue: String {
        let metricDescription: String
        if unit == "m", ["elevation", "height", "altitude"].contains(where: title.lowercased().contains) {
            metricDescription = "\(value) \(value == "1" ? "meter" : "meters")"
        } else {
            metricDescription = DashboardAccessibilityFormatting.metric(
                value: isAvailable ? value : String(localized: "No data"),
                unit: isAvailable ? unit : ""
            )
        }

        var parts = [
            metricDescription
        ]
        if let subtitle {
            parts.append(subtitle)
        }
        return parts.joined(separator: ". ")
    }
}

private struct DashboardSeriesSection: View {
    let title: String
    let series: [NumericMetricSeries]
    let units: UnitPreferences
    let onSelectMetric: (GoogleHealthDataType) -> Void

    @ViewBuilder
    var body: some View {
        let visibleSeries = series.filter { !$0.points.isEmpty }
        if !visibleSeries.isEmpty {
            VStack(alignment: .leading, spacing: 14) {
                DashboardSectionTitle(title: LocalizedStringKey(title))

                DashboardAdaptiveGrid(spacing: 14) {
                    ForEach(visibleSeries) { item in
                        let latest = item.latestPoint
                        let metricValue = latest.map {
                            DashboardFormatting.metricValue($0.value, type: item.type, units: units)
                        }
                        DashboardMetricCard(
                            title: item.title,
                            value: metricValue?.value ?? "No data",
                            unit: metricValue?.unit ?? "",
                            systemImage: item.type.symbolName,
                            accentColor: item.type.accentColor,
                            points: item.points,
                            reservesChartSpace: true,
                            isAvailable: latest != nil
                        ) {
                            onSelectMetric(item.type)
                        }
                    }
                }
            }
        }
    }
}

private struct HealthMetricGroup: View {
    let title: String
    let series: [NumericMetricSeries]
    let units: UnitPreferences
    let onSelectMetric: (GoogleHealthDataType) -> Void

    @ViewBuilder
    var body: some View {
        let visibleSeries = series.filter { !$0.points.isEmpty }
        if !visibleSeries.isEmpty {
            HealthSeriesSection(
                title: title,
                series: visibleSeries,
                units: units,
                onSelectMetric: onSelectMetric
            )
        }
    }
}

private struct HealthSeriesSection: View {
    let title: String
    let series: [NumericMetricSeries]
    let units: UnitPreferences
    let onSelectMetric: (GoogleHealthDataType) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            DashboardSectionTitle(title: LocalizedStringKey(title))

            if series.count == 1 {
                ForEach(series) { item in
                    HealthSeriesCard(
                        series: item,
                        units: units,
                        reservesChartSpace: false,
                        onSelectMetric: onSelectMetric
                    )
                }
            } else {
                let reservesChartSpace = series.contains { $0.points.count > 1 }
                DashboardAdaptiveGrid {
                    ForEach(series) { item in
                        HealthSeriesCard(
                            series: item,
                            units: units,
                            reservesChartSpace: reservesChartSpace,
                            onSelectMetric: onSelectMetric
                        )
                    }
                }
            }
        }
    }
}

private struct HealthSeriesCard: View {
    let series: NumericMetricSeries
    let units: UnitPreferences
    let reservesChartSpace: Bool
    let onSelectMetric: (GoogleHealthDataType) -> Void

    var body: some View {
        DashboardMetricCard(
            title: series.title,
            value: latestValue.value,
            unit: latestValue.unit,
            subtitle: subtitle,
            systemImage: series.type.symbolName,
            accentColor: series.type.accentColor,
            points: chartPoints,
            chartStyle: .line,
            reservesChartSpace: reservesChartSpace,
            isAvailable: series.latestPoint != nil
        ) {
            onSelectMetric(series.type)
        }
    }

    private var latestValue: DashboardFormatting.MetricValue {
        guard let latest = series.latestPoint else {
            return DashboardFormatting.MetricValue(value: "No data", unit: "")
        }
        return DashboardFormatting.metricValue(latest.value, type: series.type, units: units)
    }

    private var subtitle: String? {
        guard let latest = series.latestPoint else {
            return nil
        }

        if series.points.count <= 1 {
            return "Measured \(latest.dashboardDateLabel(for: series.type))"
        }

        return nil
    }

    private var chartPoints: [NumericMetricPoint] {
        series.points.count > 1 ? series.points : []
    }
}

private struct BucketedSeriesSection: View {
    let series: [BucketedMetricSeries]

    var body: some View {
        if !series.isEmpty {
            VStack(alignment: .leading, spacing: 14) {
                DashboardSectionTitle(title: "Intensity")

                ForEach(series) { item in
                    BucketDistributionCard(series: item)
                }
            }
        }
    }
}

private struct BucketDistributionCard: View {
    let series: BucketedMetricSeries

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(series.displayTitle)
                        .font(.headline.weight(.bold))

                    Text(series.rangeSubtitle)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .layoutPriority(1)

                Spacer(minLength: 12)

                Text(totalText)
                    .font(.headline.weight(.bold).monospacedDigit())
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            ForEach(series.displayBuckets) { bucket in
                VStack(alignment: .leading, spacing: 7) {
                    HStack {
                        Text(bucket.label)
                            .font(.subheadline.weight(.semibold))
                        Spacer()
                        Text("\(DashboardFormatting.integer(bucket.value)) \(bucket.unit)")
                            .font(.subheadline.weight(.bold).monospacedDigit())
                            .foregroundStyle(.secondary)
                    }

                    ProgressView(value: progress(for: bucket))
                        .tint(series.type.accentColor)
                }
            }
        }
        .dashboardCard(
            border: .dashboardStroke,
            padding: 16
        )
    }

    private var total: Double {
        series.displayBuckets.reduce(0) { $0 + $1.value }
    }

    private var unit: String {
        series.displayBuckets.first?.unit ?? ""
    }

    private var totalText: String {
        let value = DashboardFormatting.integer(total)
        return unit.isEmpty ? value : "\(value) \(unit)"
    }

    private func progress(for bucket: MetricBucket) -> Double {
        guard total > 0 else { return 0 }
        return min(max(bucket.value / total, 0), 1)
    }
}

private struct BucketList: View {
    let title: String
    let buckets: [MetricBucket]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.headline.weight(.bold))
            ForEach(Array(buckets.enumerated()), id: \.offset) { _, bucket in
                HStack {
                    Text(bucket.label)
                    Spacer()
                    Text("\(DashboardFormatting.integer(bucket.value)) \(bucket.unit)")
                        .font(.headline.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
                .font(.subheadline.weight(.semibold))
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(bucket.label)
                .accessibilityValue(
                    DashboardAccessibilityFormatting.metric(
                        value: DashboardFormatting.integer(bucket.value),
                        unit: bucket.unit
                    )
                )
            }
        }
        .dashboardCard(
            border: .dashboardStroke,
            radius: DashboardCardRadius.compact,
            padding: 16
        )
    }
}

private struct SleepSessionsSection: View {
    let sessions: [SleepSession]
    let onSelect: (SleepSession) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            DashboardSectionTitle(title: "Sleep")

            if sessions.isEmpty {
                DashboardEmptyState(title: "No sleep data", systemImage: "moon.zzz")
            } else {
                ForEach(sessions) { session in
                    Button {
                        onSelect(session)
                    } label: {
                        HealthSleepSessionCard(session: session)
                    }
                    .buttonStyle(DashboardInteractiveCardButtonStyle())
                }
            }
        }
    }
}

private struct HealthSleepSessionCard: View {
    let session: SleepSession

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 8) {
                DashboardMetricBadge(systemImage: "moon.zzz.fill", accentColor: .sleepAccent, size: 34)

                VStack(alignment: .leading, spacing: 4) {
                    Text("Sleep")
                        .font(.headline.weight(.bold))
                        .fixedSize(horizontal: false, vertical: true)

                    Text(sleepRange)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .layoutPriority(1)

                Spacer(minLength: 30)
            }
            .frame(minHeight: 48, alignment: .topLeading)
            .overlay(alignment: .topTrailing) {
                DashboardActionIndicator(accentColor: .sleepAccent, size: 30)
            }

            DashboardCardValueRow(value: duration.value, unit: duration.unit, valueFontSize: 34)

            if !session.displayStages.isEmpty {
                SleepStageStrip(stages: session.displayStages)
            }
        }
        .dashboardCard(
            border: Color.sleepAccent.opacity(0.18),
            padding: 15
        )
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Sleep")
        .accessibilityValue(
            "\(DashboardAccessibilityFormatting.duration(session.summaryValue.durationSeconds)). \(sleepRange). \(stageAccessibilityValue)"
        )
        .accessibilityHint("Opens sleep details")
    }

    private var duration: DashboardFormatting.MetricValue {
        DashboardFormatting.durationParts(session.summaryValue.durationSeconds)
    }

    private var sleepRange: String {
        guard session.startTime != nil || session.endTime != nil else {
            return "Sleep session"
        }

        return DashboardFormatting.compactDateTimeRangeLabel(start: session.startTime, end: session.endTime) ?? "Sleep session"
    }

    private var stageAccessibilityValue: String {
        guard !session.displayStages.isEmpty else { return "No stage breakdown" }
        let total = max(session.displayStages.reduce(0) { $0 + $1.durationSeconds }, 1)
        return session.displayStages.map {
            "\($0.stage), \(DashboardAccessibilityFormatting.duration($0.durationSeconds)), \(DashboardFormatting.percent($0.durationSeconds / total))"
        }.joined(separator: ". ")
    }
}

private extension SleepSession {
    var displayStages: [SleepStageSummary] {
        let positiveStages = stages.filter { $0.durationSeconds > 0 }
        guard positiveStages.count > 1 else { return [] }

        var orderedKeys: [String] = []
        var labels: [String: String] = [:]
        var totals: [String: TimeInterval] = [:]

        for stage in positiveStages {
            let key = stage.stage.lowercased()
            if totals[key] == nil {
                orderedKeys.append(key)
            }
            labels[key] = stage.stage
            totals[key, default: 0] += stage.durationSeconds
        }

        let aggregatedStages = orderedKeys.compactMap { key -> SleepStageSummary? in
            guard let duration = totals[key], let label = labels[key] else {
                return nil
            }
            return SleepStageSummary(stage: label, durationSeconds: duration)
        }

        guard aggregatedStages.count > 1 else { return [] }
        return aggregatedStages
    }
}

private struct SleepStageStrip: View {
    let stages: [SleepStageSummary]

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            GeometryReader { geometry in
                HStack(spacing: 3) {
                    ForEach(indexedStages, id: \.offset) { indexedStage in
                        let stage = indexedStage.element
                        Capsule()
                            .fill(color(for: stage.stage).opacity(0.9))
                            .frame(width: segmentWidth(for: stage, totalWidth: geometry.size.width))
                    }
                }
            }
            .frame(height: 8)

            LazyVGrid(columns: legendColumns, alignment: .leading, spacing: 7) {
                ForEach(indexedStages, id: \.offset) { indexedStage in
                    let stage = indexedStage.element
                    HStack(alignment: .top, spacing: 6) {
                        Circle()
                            .fill(color(for: stage.stage))
                            .frame(width: 6, height: 6)
                            .padding(.top, 4)

                        VStack(alignment: .leading, spacing: 1) {
                            Text(stage.stage)
                                .fixedSize(horizontal: false, vertical: true)

                            Text(stageDetail(for: stage))
                                .font(.caption2.weight(.medium))
                                .monospacedDigit()
                                .foregroundStyle(.tertiary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
            }
            .font(.caption.weight(.semibold))
            .foregroundStyle(.secondary)
        }
        .accessibilityLabel(stageAccessibilityText)
    }

    private var totalDuration: TimeInterval {
        max(stages.reduce(0) { $0 + $1.durationSeconds }, 1)
    }

    private var indexedStages: [(offset: Int, element: SleepStageSummary)] {
        Array(stages.enumerated())
    }

    private var legendColumns: [GridItem] {
        [
            GridItem(.adaptive(minimum: 82), spacing: 8, alignment: .leading)
        ]
    }

    private func segmentWidth(for stage: SleepStageSummary, totalWidth: CGFloat) -> CGFloat {
        max(6, totalWidth * CGFloat(stage.durationSeconds / totalDuration))
    }

    private func stageDetail(for stage: SleepStageSummary) -> String {
        "\(DashboardFormatting.duration(stage.durationSeconds)) | \(DashboardFormatting.percent(stage.durationSeconds / totalDuration))"
    }

    private func color(for stage: String) -> Color {
        let normalizedStage = stage.lowercased()
        if normalizedStage.contains("deep") {
            return Color(uiColor: .systemIndigo)
        }
        if normalizedStage.contains("rem") {
            return Color(uiColor: .systemPurple)
        }
        if normalizedStage.contains("awake") || normalizedStage.contains("wake") {
            return Color(uiColor: .systemTeal)
        }
        return .sleepAccent
    }

    private var stageAccessibilityText: String {
        stages
            .map {
                "\($0.stage), \(DashboardFormatting.duration($0.durationSeconds)), \(DashboardFormatting.percent($0.durationSeconds / totalDuration))"
            }
            .joined(separator: ", ")
    }
}

private struct WorkoutRowCard: View {
    let workout: WorkoutDetail
    let units: UnitPreferences
    let onSelect: (() -> Void)?

    var body: some View {
        if let onSelect {
            Button(action: onSelect) {
                cardContent
            }
            .buttonStyle(DashboardInteractiveCardButtonStyle())
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(workout.type)
            .accessibilityValue(workoutAccessibilityValue)
            .accessibilityHint("Opens workout details")
        } else {
            cardContent
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(workout.type)
                .accessibilityValue(workoutAccessibilityValue)
        }
    }

    private var cardContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top, spacing: 12) {
                DashboardMetricBadge(systemImage: "dumbbell.fill", accentColor: .activeRing, size: 44)

                VStack(alignment: .leading, spacing: 4) {
                    Text(workout.type)
                        .font(.headline.weight(.bold))
                        .foregroundStyle(.primary)
                        .fixedSize(horizontal: false, vertical: true)

                    Text(DashboardFormatting.compactDateTimeLabel(for: workout.startTime))
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .layoutPriority(1)

                Spacer(minLength: onSelect == nil ? 0 : 32)
            }
            .frame(minHeight: 48, alignment: .topLeading)
            .overlay(alignment: .topTrailing) {
                if onSelect != nil {
                    DashboardActionIndicator(accentColor: .activeRing, size: 30)
                }
            }

            VStack(alignment: .leading, spacing: 6) {
                DashboardCardValueRow(value: duration.value, unit: duration.unit, valueFontSize: 34)

                if !stats.isEmpty {
                    DashboardCardStatRow(stats: stats)
                }
            }
        }
        .dashboardCard(
            border: cardBorder,
            padding: 15,
            minHeight: 148
        )
    }

    private var duration: DashboardFormatting.MetricValue {
        DashboardFormatting.durationParts(workout.durationSeconds)
    }

    private var stats: [DashboardCardStat] {
        var stats: [DashboardCardStat] = []

        if let steps = workout.metricsSummary.steps {
            stats.append(
                DashboardCardStat(
                    id: "steps",
                    text: DashboardFormatting.integer(Double(steps)),
                    systemImage: "shoeprints.fill"
                )
            )
        }

        if let distance = workout.metricsSummary.distanceMeters {
            stats.append(
                DashboardCardStat(
                    id: "distance",
                    text: DashboardFormatting.distance(distance, unit: units.distanceUnit),
                    systemImage: "map"
                )
            )
        }

        if let calories = workout.metricsSummary.caloriesKcal {
            stats.append(
                DashboardCardStat(
                    id: "calories",
                    text: "\(DashboardFormatting.integer(calories)) kcal",
                    systemImage: "flame"
                )
            )
        }

        if let heartRate = workout.metricsSummary.averageHeartRate {
            stats.append(
                DashboardCardStat(
                    id: "average-heart-rate",
                    text: "\(DashboardFormatting.integer(heartRate)) bpm",
                    systemImage: "heart.fill"
                )
            )
        }

        return stats
    }

    private var cardBorder: Color {
        onSelect == nil ? Color.dashboardStroke : Color.activeRing.opacity(0.20)
    }

    private var workoutAccessibilityValue: String {
        let date = DashboardFormatting.compactDateTimeLabel(for: workout.startTime)
        let statsDescription = stats.map(\.text).joined(separator: ", ")
        return [
            date,
            DashboardAccessibilityFormatting.duration(workout.durationSeconds),
            statsDescription
        ]
        .filter { !$0.isEmpty }
        .joined(separator: ". ")
    }
}

private struct DetailMetricGrid: View {
    let metrics: [DetailMetric]

    var body: some View {
        if !metrics.isEmpty {
            DashboardAdaptiveGrid(spacing: 14) {
                ForEach(metrics) { metric in
                    DashboardMetricCard(
                        title: metric.title,
                        value: metric.value,
                        unit: metric.unit,
                        systemImage: metric.systemImage,
                        accentColor: metric.color,
                        isAvailable: true
                    )
                }
            }
        }
    }
}

private struct DetailMetric: Identifiable {
    var id: String { title }
    let title: String
    let value: String
    let unit: String
    let systemImage: String
    let color: Color
}

private struct WorkoutSplitsSection: View {
    let splits: [WorkoutSplit]
    let units: UnitPreferences

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            DashboardSectionTitle(title: "Splits")

            ForEach(splits) { split in
                VStack(alignment: .leading, spacing: 10) {
                    Text(split.label)
                        .font(.headline.weight(.bold))

                    HStack(spacing: 14) {
                        if let distance = split.distanceMeters {
                            Text(DashboardFormatting.distance(distance, unit: units.distanceUnit))
                        }
                        if let duration = split.durationSeconds {
                            Text(DashboardFormatting.duration(duration))
                        }
                        if let heartRate = split.heartRateAverage {
                            Text("\(DashboardFormatting.integer(heartRate)) bpm")
                        }
                    }
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
                }
                .dashboardCard(
                    radius: DashboardCardRadius.compact,
                    padding: 14,
                    alignment: .leading
                )
                .accessibilityElement(children: .combine)
            }
        }
    }
}

private struct MetricPointList: View {
    let series: NumericMetricSeries
    let units: UnitPreferences

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            DashboardSectionTitle(title: "History")

            ForEach(series.points.sorted { $0.startDate > $1.startDate }) { point in
                let value = DashboardFormatting.metricValue(point.value, type: series.type, units: units)
                MetricPointRow(
                    dateLabel: point.dashboardDateLabel(for: series.type),
                    value: value.unit.isEmpty ? value.value : "\(value.value) \(value.unit)"
                )
            }
        }
    }
}

private struct MetricPointRow: View {
    let dateLabel: String
    let value: String

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                dateText

                Spacer(minLength: 12)

                valueText
                    .fixedSize(horizontal: true, vertical: false)
            }

            VStack(alignment: .leading, spacing: 6) {
                dateText
                valueText
            }
        }
        .dashboardCard(
            radius: DashboardCardRadius.compact,
            padding: 14,
            alignment: .leading
        )
    }

    private var dateText: some View {
        Text(dateLabel)
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(.primary)
            .fixedSize(horizontal: false, vertical: true)
    }

    private var valueText: some View {
        Text(value)
            .font(.headline.monospacedDigit())
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
    }
}

private extension NumericMetricSeries {
    var rangeSubtitle: String {
        guard let start = rangeStart, let end = rangeEnd else {
            return "Last 14 days"
        }
        return DashboardFormatting.compactRangeLabel(start: start, end: end, treatsEndAsExclusive: true)
    }
}

private extension BucketedMetricSeries {
    var rangeSubtitle: String {
        guard let start = rangeStart, let end = rangeEnd else {
            return "Last 14 days"
        }
        return DashboardFormatting.compactRangeLabel(start: start, end: end, treatsEndAsExclusive: true)
    }
}

private extension NumericMetricPoint {
    func dashboardDateLabel(for type: GoogleHealthDataType, calendar: Calendar = .current) -> String {
        switch type.recordKind {
        case .sample:
            return DashboardFormatting.compactDateTimeLabel(for: startDate, calendar: calendar)
        case .session:
            return DashboardFormatting.compactDateTimeRangeLabel(
                start: startDate,
                end: endDate,
                calendar: calendar
            ) ?? DashboardFormatting.compactDateTimeLabel(for: startDate, calendar: calendar)
        case .daily:
            return DashboardFormatting.compactDayLabel(for: startDate, calendar: calendar)
        case .interval:
            guard let endDate, !calendar.isDate(startDate, inSameDayAs: endDate) else {
                return DashboardFormatting.compactDayLabel(for: startDate, calendar: calendar)
            }

            return DashboardFormatting.compactRangeLabel(
                start: startDate,
                end: endDate,
                calendar: calendar,
                treatsEndAsExclusive: true
            )
        }
    }
}

private extension GoogleHealthDataType {
    var accentColor: Color {
        switch category {
        case .activity:
            switch self {
            case .steps:
                return .stepsRing
            case .activeMinutes, .activeZoneMinutes:
                return .activeRing
            case .activeEnergyBurned, .totalCalories:
                return .moveRing
            default:
                return .distanceAccent
            }
        case .workout:
            return .activeRing
        case .heart:
            return .heartAccent
        case .sleep:
            return .sleepAccent
        case .vitals:
            return Color(uiColor: .systemTeal)
        case .cardioFitness:
            return Color(uiColor: .systemMint)
        case .body:
            return Color(uiColor: .systemOrange)
        }
    }
}

extension DashboardFormatting {
    static func metricValue(
        _ value: Double,
        type: GoogleHealthDataType,
        units: UnitPreferences
    ) -> DashboardFormatting.MetricValue {
        switch type {
        case .distance:
            return distanceParts(value, unit: units.distanceUnit)
        case .height, .altitude:
            return DashboardFormatting.MetricValue(value: decimal(value, maximumFractionDigits: 2), unit: "m")
        case .weight:
            return DashboardFormatting.MetricValue(value: decimal(value, maximumFractionDigits: 1), unit: "kg")
        case .bodyFat, .oxygenSaturation, .dailyOxygenSaturation:
            return DashboardFormatting.MetricValue(value: decimal(value, maximumFractionDigits: 1), unit: "%")
        case .heartRate, .dailyRestingHeartRate:
            return DashboardFormatting.MetricValue(value: integer(value), unit: "bpm")
        case .heartRateVariability, .dailyHeartRateVariability:
            return DashboardFormatting.MetricValue(value: integer(value), unit: "ms")
        case .activeMinutes, .activeZoneMinutes, .timeInHeartRateZone, .sedentaryPeriod:
            return DashboardFormatting.MetricValue(value: integer(value), unit: "min")
        case .activeEnergyBurned, .totalCalories, .caloriesInHeartRateZone:
            return DashboardFormatting.MetricValue(value: integer(value), unit: "kcal")
        case .steps:
            return DashboardFormatting.MetricValue(value: integer(value), unit: "steps")
        case .floors:
            return DashboardFormatting.MetricValue(value: integer(value), unit: "floors")
        case .respiratoryRateSleepSummary, .dailyRespiratoryRate:
            return DashboardFormatting.MetricValue(value: decimal(value, maximumFractionDigits: 1), unit: "brpm")
        case .dailySleepTemperatureDerivations, .coreBodyTemperature:
            return DashboardFormatting.MetricValue(value: decimal(value, maximumFractionDigits: 1), unit: "deg")
        case .vo2Max, .dailyVo2Max, .runVo2Max:
            return DashboardFormatting.MetricValue(value: decimal(value, maximumFractionDigits: 1), unit: "ml/kg/min")
        case .bloodGlucose:
            return DashboardFormatting.MetricValue(value: integer(value), unit: "mg/dL")
        case .activityLevel, .swimLengthsData:
            return DashboardFormatting.MetricValue(value: integer(value), unit: type.unit)
        case .exercise, .dailyHeartRateZones, .sleep:
            return DashboardFormatting.MetricValue(value: integer(value), unit: type.unit)
        }
    }

    static func accessibilityMetricValue(
        _ value: Double,
        type: GoogleHealthDataType,
        units: UnitPreferences
    ) -> String {
        let formatted = metricValue(value, type: type, units: units)
        let expandedUnit: String

        switch type {
        case .height, .altitude:
            expandedUnit = value == 1 ? "meter" : "meters"
        case .weight:
            expandedUnit = value == 1 ? "kilogram" : "kilograms"
        case .bodyFat, .oxygenSaturation, .dailyOxygenSaturation:
            expandedUnit = "percent"
        case .activeMinutes, .activeZoneMinutes, .timeInHeartRateZone, .sedentaryPeriod:
            expandedUnit = value == 1 ? "minute" : "minutes"
        default:
            expandedUnit = DashboardAccessibilityFormatting.expandedUnit(
                formatted.unit,
                value: formatted.value
            )
        }

        return expandedUnit.isEmpty
            ? formatted.value
            : "\(formatted.value) \(expandedUnit)"
    }
}

private extension WorkoutDetail {
    func detailMetrics(units: UnitPreferences) -> [DetailMetric] {
        var metrics: [DetailMetric] = []

        if let steps = metricsSummary.steps {
            metrics.append(
                DetailMetric(title: "Steps", value: DashboardFormatting.integer(Double(steps)), unit: "", systemImage: "shoeprints.fill", color: .stepsRing)
            )
        }

        metrics.append(
            DetailMetric(
                title: "Duration",
                value: DashboardFormatting.durationParts(durationSeconds).value,
                unit: DashboardFormatting.durationParts(durationSeconds).unit,
                systemImage: "stopwatch",
                color: .activeRing
            )
        )

        if let distanceMeters = metricsSummary.distanceMeters {
            let value = DashboardFormatting.distanceParts(distanceMeters, unit: units.distanceUnit)
            metrics.append(
                DetailMetric(title: "Distance", value: value.value, unit: value.unit, systemImage: "map", color: .distanceAccent)
            )
        }

        if let calories = metricsSummary.caloriesKcal {
            metrics.append(
                DetailMetric(title: "Calories Burned", value: DashboardFormatting.integer(calories), unit: "kcal", systemImage: "flame", color: .moveRing)
            )
        }

        if let elevation = metricsSummary.elevationGainMeters {
            metrics.append(
                DetailMetric(title: "Elevation", value: DashboardFormatting.decimal(elevation, maximumFractionDigits: 0), unit: "m", systemImage: "mountain.2", color: .distanceAccent)
            )
        }

        if let heart = metricsSummary.averageHeartRate {
            metrics.append(
                DetailMetric(title: "Avg Heart", value: DashboardFormatting.integer(heart), unit: "bpm", systemImage: "heart.fill", color: .heartAccent)
            )
        }

        if let heart = metricsSummary.maxHeartRate {
            metrics.append(
                DetailMetric(title: "Max Heart", value: DashboardFormatting.integer(heart), unit: "bpm", systemImage: "heart.circle.fill", color: .heartAccent)
            )
        }

        if let pace = metricsSummary.averagePaceSecondsPerKilometer {
            metrics.append(
                DetailMetric(title: "Pace", value: DashboardFormatting.duration(pace), unit: "/km", systemImage: "speedometer", color: .activeRing)
            )
        }

        if let speed = metricsSummary.averageSpeedMetersPerSecond {
            metrics.append(
                DetailMetric(title: "Speed", value: DashboardFormatting.decimal(speed, maximumFractionDigits: 1), unit: "m/s", systemImage: "gauge", color: .activeRing)
            )
        }

        return metrics
    }
}

#if DEBUG
#Preview("Tabs Populated") {
    FitnessDashboardView(
        store: .preview(snapshot: .previewPopulatedFitness),
        accountEmail: "osanyemosadebe@example.com",
        onSignOut: {}
    )
}

#Preview("Tabs Sparse") {
    FitnessDashboardView(
        store: .preview(snapshot: .empty()),
        accountEmail: "osanyemosadebe@example.com",
        onSignOut: {}
    )
}

#Preview("Activity Loading Large Type") {
    FitnessDashboardView(
        store: .previewActivityLoading(),
        accountEmail: "osanyemosadebe@example.com",
        onSignOut: {}
    )
    .environment(\.dynamicTypeSize, .accessibility2)
}

#Preview("Failed Section") {
    FitnessDashboardView(
        store: .previewFailedHealth(),
        accountEmail: "osanyemosadebe@example.com",
        onSignOut: {}
    )
}

#Preview("AX5 Dark Increased Contrast") {
    FitnessDashboardView(
        store: .preview(snapshot: .previewPopulatedFitness),
        accountEmail: "a-very-long-accessible-account-identifier@example.com",
        onSignOut: {}
    )
    .preferredColorScheme(.dark)
    .environment(\.dynamicTypeSize, .accessibility5)
}

#Preview("RTL Light") {
    FitnessDashboardView(
        store: .preview(snapshot: .previewPopulatedFitness),
        accountEmail: "osanyemosadebe@example.com",
        onSignOut: {}
    )
    .preferredColorScheme(.light)
    .environment(\.layoutDirection, .rightToLeft)
}

#Preview("Motion-Safe Static State") {
    FitnessDashboardView(
        store: .preview(snapshot: .previewPopulatedFitness),
        accountEmail: "osanyemosadebe@example.com",
        onSignOut: {}
    )
    .transaction { transaction in
        transaction.animation = nil
    }
}

#Preview("Landscape", traits: .landscapeLeft) {
    FitnessDashboardView(
        store: .preview(snapshot: .previewPopulatedFitness),
        accountEmail: "osanyemosadebe@example.com",
        onSignOut: {}
    )
}

@MainActor
extension FitnessDashboardStore {
    static func preview(snapshot: FitnessDataSnapshot) -> FitnessDashboardStore {
        let cache = DashboardPreviewCache(snapshot: snapshot, preferences: .defaults)
        let repository = DashboardRepository(
            googleHealthClient: DashboardPreviewClient(snapshot: snapshot),
            cache: cache
        )
        let store = FitnessDashboardStore(repository: repository, cache: cache)
        store.snapshot = snapshot
        return store
    }

    static func previewActivityLoading() -> FitnessDashboardStore {
        let store = preview(snapshot: .previewPopulatedFitness)
        store.selectedTab = .activity
        store.sectionStates[.activity] = FitnessSectionState(
            phase: .loading,
            lastUpdated: .distantPast,
            errorMessage: nil
        )
        return store
    }

    static func previewInitialActivityLoading() -> FitnessDashboardStore {
        let store = preview(snapshot: .empty())
        store.selectedTab = .activity
        store.sectionStates[.activity] = FitnessSectionState(
            phase: .loading,
            lastUpdated: .distantPast,
            errorMessage: nil
        )
        return store
    }

    static func previewFailedHealth() -> FitnessDashboardStore {
        let store = preview(snapshot: .previewPopulatedFitness)
        store.selectedTab = .health
        store.sectionStates[.health] = FitnessSectionState(
            phase: .failed,
            lastUpdated: Date.now.addingTimeInterval(-3_600),
            errorMessage: "Google Health did not return this section."
        )
        return store
    }
}

extension FitnessDataSnapshot {
    static var previewPopulatedFitness: FitnessDataSnapshot {
        let summary = DashboardSnapshot(
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

        let days: [Date] = (0..<14).map { offset in
            Date.now.addingTimeInterval(TimeInterval((-13 + offset) * 86_400))
        }
        let stepPoints: [NumericMetricPoint] = days.enumerated().map { index, date in
            NumericMetricPoint(
                id: "steps-\(index)",
                startDate: date,
                value: Double(6_400 + index * 220),
                unit: "steps"
            )
        }
        let distancePoints: [NumericMetricPoint] = days.enumerated().map { index, date in
            NumericMetricPoint(
                id: "distance-\(index)",
                startDate: date,
                value: Double(4_800 + index * 130),
                unit: "m"
            )
        }
        let hourly: [NumericMetricPoint] = (0..<12).map { hour in
            NumericMetricPoint(
                id: "hour-\(hour)",
                startDate: Date.now.addingTimeInterval(TimeInterval(-hour * 3_600)),
                value: Double((hour + 1) * 80),
                unit: "steps"
            )
        }
        let steps = NumericMetricSeries(
            type: .steps,
            points: stepPoints,
            rangeStart: days.first,
            rangeEnd: days.last
        )
        let distance = NumericMetricSeries(
            type: .distance,
            points: distancePoints,
            rangeStart: days.first,
            rangeEnd: days.last
        )
        let workout = WorkoutDetail(
            id: "preview-workout",
            type: "Outdoor Walk",
            startTime: Date.now.addingTimeInterval(-7_200),
            endTime: Date.now.addingTimeInterval(-4_860),
            activeDurationSeconds: 2_340,
            metricsSummary: WorkoutMetricsSummary(
                caloriesKcal: 242,
                distanceMeters: 3_120,
                steps: 4_210,
                elevationGainMeters: 42,
                averageHeartRate: 122,
                maxHeartRate: 148,
                averageSpeedMetersPerSecond: nil,
                averagePaceSecondsPerKilometer: 750
            ),
            splits: [],
            zoneMinutes: [
                MetricBucket(label: "Fat Burn", value: 18, unit: "min"),
                MetricBucket(label: "Cardio", value: 9, unit: "min")
            ]
        )
        let heart = NumericMetricSeries(
            type: .heartRate,
            points: days.enumerated().map { index, date in
                NumericMetricPoint(id: "heart-\(index)", startDate: date, value: Double(70 + (index % 5)), unit: "bpm")
            },
            rangeStart: days.first,
            rangeEnd: days.last
        )
        let sleepSession = SleepSession(
            id: "preview-sleep",
            startTime: Date.now.addingTimeInterval(-34_200),
            endTime: Date.now.addingTimeInterval(-6_300),
            durationSeconds: 27_900,
            stages: [
                SleepStageSummary(stage: "Deep", durationSeconds: 5_100),
                SleepStageSummary(stage: "Light", durationSeconds: 14_400),
                SleepStageSummary(stage: "REM", durationSeconds: 6_000),
                SleepStageSummary(stage: "Awake", durationSeconds: 2_400)
            ]
        )

        return FitnessDataSnapshot(
            summary: summary,
            activity: ActivityDashboardData(
                dailySeries: [steps, distance],
                hourlySeries: [
                    NumericMetricSeries(type: .steps, points: hourly),
                    NumericMetricSeries(
                        type: .distance,
                        points: hourly.map {
                            NumericMetricPoint(id: "distance-\($0.id)", startDate: $0.startDate, value: $0.value * 0.75, unit: "m")
                        }
                    )
                ],
                bucketedSeries: [
                    BucketedMetricSeries(
                        type: .activeMinutes,
                        title: "Activity Intensity",
                        buckets: [
                            MetricBucket(label: "Light", value: 22, unit: "min"),
                            MetricBucket(label: "Moderate", value: 11, unit: "min"),
                            MetricBucket(label: "Vigorous", value: 4, unit: "min")
                        ],
                        rangeStart: days.first,
                        rangeEnd: days.last
                    )
                ],
                loadedAt: .now
            ),
            workouts: [workout],
            health: HealthDashboardData(
                heartSeries: [heart],
                sleepMetricSeries: [],
                vitalSeries: [
                    NumericMetricSeries(
                        type: .dailyRespiratoryRate,
                        points: days.enumerated().map { index, date in
                            NumericMetricPoint(id: "resp-\(index)", startDate: date, value: 15 + Double(index % 3), unit: "brpm")
                        },
                        rangeStart: days.first,
                        rangeEnd: days.last
                    )
                ],
                cardioFitnessSeries: [
                    NumericMetricSeries(
                        type: .dailyVo2Max,
                        points: days.enumerated().map { index, date in
                            NumericMetricPoint(id: "vo2-\(index)", startDate: date, value: 42 + Double(index % 2), unit: "ml/kg/min")
                        },
                        rangeStart: days.first,
                        rangeEnd: days.last
                    )
                ],
                bodySeries: [
                    NumericMetricSeries(
                        type: .weight,
                        points: [
                            NumericMetricPoint(id: "weight", startDate: Date.now.addingTimeInterval(-86_400), value: 78.4, unit: "kg")
                        ],
                        rangeStart: days.first,
                        rangeEnd: days.last
                    )
                ],
                sleepSessions: [sleepSession],
                loadedAt: .now
            )
        )
    }
}

@MainActor
private final class DashboardPreviewCache: DashboardCaching {
    private var snapshot: FitnessDataSnapshot?
    private var preferences: DashboardPreferences

    init(snapshot: FitnessDataSnapshot?, preferences: DashboardPreferences) {
        self.snapshot = snapshot
        self.preferences = preferences
    }

    func loadDashboard() -> DashboardSnapshot? {
        snapshot?.summary
    }

    func saveDashboard(_ snapshot: DashboardSnapshot) {
        self.snapshot?.summary = snapshot
    }

    func loadFitnessData() -> FitnessDataSnapshot? {
        snapshot
    }

    func saveFitnessData(_ snapshot: FitnessDataSnapshot) {
        self.snapshot = snapshot
    }

    func clearHealthData() {
        snapshot = nil
    }

    func loadPreferences() -> DashboardPreferences {
        preferences
    }

    func savePreferences(_ preferences: DashboardPreferences) {
        self.preferences = preferences
    }
}

private struct DashboardPreviewClient: GoogleHealthServing {
    let snapshot: FitnessDataSnapshot

    func fetchDashboard(goals: ActivityGoals, date: Date) async throws -> DashboardSnapshot {
        snapshot.summary
    }

    func fetchActivityData(date: Date) async throws -> ActivityDashboardData {
        snapshot.activity
    }

    func fetchWorkoutData(date: Date) async throws -> [WorkoutDetail] {
        snapshot.workouts
    }

    func fetchHealthData(date: Date) async throws -> HealthDashboardData {
        snapshot.health
    }
}
#endif
