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

    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]

    var body: some View {
        let stepsPoints = hourlySeries(for: .steps)?.points ?? []
        let distancePoints = hourlySeries(for: .distance)?.points ?? []
        let reservesChartSpace = stepsPoints.count > 1 || distancePoints.count > 1

        LazyVGrid(columns: columns, spacing: 12) {
            DashboardMetricCard(
                title: "Steps",
                value: stepsValue,
                unit: stepsUnit,
                systemImage: GoogleHealthDataType.steps.symbolName,
                accentColor: .stepsRing,
                points: stepsPoints,
                reservesChartSpace: reservesChartSpace,
                isAvailable: snapshot.summary.activity.hasData(for: .steps)
            ) {
                onSelectMetric(.steps)
            }

            DashboardMetricCard(
                title: "Distance",
                value: distanceValue.value,
                unit: distanceValue.unit,
                systemImage: GoogleHealthDataType.distance.symbolName,
                accentColor: .distanceAccent,
                points: distancePoints,
                reservesChartSpace: reservesChartSpace,
                isAvailable: snapshot.summary.activity.hasData(for: .distance)
            ) {
                onSelectMetric(.distance)
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
                await store.refreshSection(.activity)
            }
        ) {
            VStack(alignment: .leading, spacing: 24) {
                if hasActivityContent {
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
                } else {
                    DashboardEmptyState(title: "No activity data", systemImage: "figure.run.circle")
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
}

private struct WorkoutsTabView: View {
    @Bindable var store: FitnessDashboardStore

    var body: some View {
        DashboardScrollView(
            title: "Workouts",
            subtitle: "Last 14 days",
            state: store.sectionState(.workouts),
            onRefresh: {
                await store.refreshSection(.workouts)
            }
        ) {
            VStack(alignment: .leading, spacing: 14) {
                if store.snapshot.workouts.isEmpty {
                    DashboardEmptyState(title: "No workouts", systemImage: "dumbbell")
                } else {
                    ForEach(store.snapshot.workouts) { workout in
                        WorkoutRowCard(workout: workout, units: store.preferences.units) {
                            store.workoutPath.append(.workout(workout.id))
                        }
                    }
                }
            }
        }
        .task {
            await store.loadIfNeeded(.workouts)
        }
    }
}

private struct HealthTabView: View {
    @Bindable var store: FitnessDashboardStore

    var body: some View {
        DashboardScrollView(
            title: "Health",
            subtitle: "Last 14 days",
            state: store.sectionState(.health),
            onRefresh: {
                await store.refreshSection(.health)
            }
        ) {
            VStack(alignment: .leading, spacing: 22) {
                if store.snapshot.health.isEmpty {
                    DashboardEmptyState(title: "No health data", systemImage: "heart.text.square")
                } else {
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
}

private struct HealthOverviewSection: View {
    let health: HealthDashboardData
    let units: UnitPreferences
    let onSelectMetric: (GoogleHealthDataType) -> Void
    let onSelectSleep: (String) -> Void

    private let columns = [
        GridItem(.flexible(), spacing: 12, alignment: .top),
        GridItem(.flexible(), spacing: 12, alignment: .top)
    ]

    @ViewBuilder
    var body: some View {
        let items = overviewItems
        if !items.isEmpty {
            VStack(alignment: .leading, spacing: 14) {
                Text("Overview")
                    .font(.title2.weight(.bold))

                if items.count == 1, let item = items.first {
                    Button {
                        select(item)
                    } label: {
                        HealthOverviewCard(item: item)
                    }
                    .buttonStyle(DashboardInteractiveCardButtonStyle())
                } else {
                    LazyVGrid(columns: columns, spacing: 12) {
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
                Image(systemName: item.systemImage)
                    .font(.headline.weight(.bold))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(item.accentColor)
                    .frame(width: 32, height: 32)
                    .background(item.accentColor.opacity(0.16), in: Circle())

                VStack(alignment: .leading, spacing: 3) {
                    Text(item.title)
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(.primary)
                        .lineLimit(2, reservesSpace: true)
                        .minimumScaleFactor(0.62)
                        .allowsTightening(true)

                    Text(item.subtitle)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .minimumScaleFactor(0.72)
                        .allowsTightening(true)
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

            HStack(alignment: .lastTextBaseline, spacing: 4) {
                Text(item.value)
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.48)
                    .allowsTightening(true)
                    .layoutPriority(1)

                if !item.unit.isEmpty {
                    Text(item.unit)
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.62)
                }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, minHeight: 156, alignment: .topLeading)
        .background(overviewBackground, in: RoundedRectangle(cornerRadius: DashboardCardRadius.tile, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: DashboardCardRadius.tile, style: .continuous)
                .stroke(item.accentColor.opacity(0.18), lineWidth: 1)
        }
        .accessibilityElement(children: .combine)
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

    var body: some View {
        let series = store.series(for: type)

        DashboardScrollView(
            title: type.displayName,
            subtitle: series?.rangeSubtitle ?? "Last 14 days",
            state: store.sectionState(type.category == .activity ? .activity : .health),
            showsNavigationBackButton: true,
            onRefresh: {
                await store.refreshSection(type.category == .activity ? .activity : .health)
            }
        ) {
            VStack(alignment: .leading, spacing: 22) {
                DashboardMetricCard(
                    title: "Latest",
                    value: latestValue(for: series),
                    unit: latestUnit(for: series),
                    subtitle: latestSubtitle(for: series),
                    systemImage: type.symbolName,
                    accentColor: type.accentColor,
                    points: latestCardPoints(fallback: series),
                    isAvailable: latestIsAvailable(fallback: series)
                )

                if let series, !series.points.isEmpty {
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

    private func latestValue(for series: NumericMetricSeries?) -> String {
        if let todayActivityValue {
            return todayActivityValue.value
        }

        guard let point = series?.latestPoint else {
            return "No data"
        }
        return DashboardFormatting.metricValue(point.value, type: type, units: store.preferences.units).value
    }

    private func latestUnit(for series: NumericMetricSeries?) -> String {
        if let todayActivityValue {
            return todayActivityValue.unit
        }

        guard let point = series?.latestPoint else {
            return ""
        }
        return DashboardFormatting.metricValue(point.value, type: type, units: store.preferences.units).unit
    }

    private func latestSubtitle(for series: NumericMetricSeries?) -> String? {
        if usesTodayActivityPresentation, todayActivityValue != nil {
            return "Recorded \(DashboardFormatting.compactDayLabel(for: store.snapshot.summary.date))"
        }

        return series?.latestPoint.map { "Recorded \($0.dashboardDateLabel(for: type))" }
    }

    private func latestCardPoints(fallback series: NumericMetricSeries?) -> [NumericMetricPoint] {
        guard usesTodayActivityPresentation else {
            return series?.points ?? []
        }

        return store.snapshot.activity.hourlySeries(for: type)?.points ?? []
    }

    private func latestIsAvailable(fallback series: NumericMetricSeries?) -> Bool {
        guard usesTodayActivityPresentation else {
            return series?.latestPoint != nil
        }

        return todayActivityValue != nil
    }

    private var todayActivityValue: DashboardFormatting.MetricValue? {
        let activity = store.snapshot.summary.activity
        switch type {
        case .steps where activity.hasData(for: .steps):
            return DashboardFormatting.MetricValue(
                value: DashboardFormatting.integer(Double(activity.steps)),
                unit: "steps"
            )
        case .distance where activity.hasData(for: .distance):
            return DashboardFormatting.distanceParts(
                activity.distanceMeters,
                unit: store.preferences.units.distanceUnit
            )
        default:
            return nil
        }
    }

    private var usesTodayActivityPresentation: Bool {
        type == .steps || type == .distance
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
                            .padding(14)
                            .background(.summarySurface, in: RoundedRectangle(cornerRadius: DashboardCardRadius.compact, style: .continuous))
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

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                DashboardLargeHeader(title: title, subtitle: subtitle, state: state)
                content
            }
            .padding(.horizontal, 20)
            .padding(.top, 22)
            .padding(.bottom, 34)
        }
        .scrollIndicators(.hidden)
        .background(Color.fitbitBackground.ignoresSafeArea())
        .overlay(alignment: .top) {
            DashboardScrollEdgeFade(color: .fitbitBackground, edge: .top)
        }
        .overlay(alignment: .bottom) {
            DashboardScrollEdgeFade(color: .fitbitBackground, edge: .bottom)
        }
        .refreshable {
            await refresh()
        }
        .navigationTitle(showsNavigationBackButton ? title : "")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(showsNavigationBackButton ? .visible : .hidden, for: .navigationBar)
    }

    private func refresh() async {
        guard let onRefresh else { return }
        await onRefresh()
    }
}

private struct DashboardLargeHeader: View {
    let title: String
    var subtitle: String?
    var state: FitnessSectionState?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text(title)
                    .font(.system(size: 38, weight: .bold, design: .rounded))
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)

                Spacer(minLength: 10)

                if state?.phase == .loading {
                    ProgressView()
                        .controlSize(.small)
                }
            }

            if let subtitle {
                Text(subtitle)
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .minimumScaleFactor(0.78)
                    .allowsTightening(true)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if let error = state?.errorMessage {
                Text(error)
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(Color(uiColor: .systemRed))
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 2)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct ActivityTodayFocusSection: View {
    let snapshot: DashboardSnapshot
    let onSelectMetric: (GoogleHealthDataType) -> Void

    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .center, spacing: 12) {
                Text("Today Focus")
                    .font(.title2.weight(.bold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)

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

            LazyVGrid(columns: columns, spacing: 12) {
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
        goalInsights.filter { $0.id != primaryInsight.id }
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
            .lineLimit(1)
            .minimumScaleFactor(0.76)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(.dashboardTintSurface, in: Capsule())
            .overlay {
                Capsule()
                    .stroke(.dashboardStroke, lineWidth: 1)
            }
    }
}

private struct DashboardActionIndicator: View {
    let accentColor: Color
    var size: CGFloat = 28

    var body: some View {
        Image(systemName: "chevron.right")
            .font(.system(size: max(11, size * 0.42), weight: .bold))
            .foregroundStyle(accentColor)
            .frame(width: size, height: size)
            .background(accentColor.opacity(0.13), in: Circle())
            .overlay {
                Circle()
                    .stroke(accentColor.opacity(0.20), lineWidth: 1)
            }
            .accessibilityHidden(true)
    }
}

private struct DashboardInteractiveCardButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.985 : 1)
            .opacity(configuration.isPressed ? 0.86 : 1)
            .animation(.smooth(duration: 0.16, extraBounce: 0), value: configuration.isPressed)
    }
}

private struct ActivityGoalTile: View {
    let insight: ActivityGoalInsight

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: insight.systemImage)
                    .font(.caption.weight(.bold))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(insight.accentColor)
                    .frame(width: 26, height: 26)
                    .background(insight.accentColor.opacity(0.15), in: Circle())

                Text(insight.title)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.62)
                    .allowsTightening(true)
                    .layoutPriority(1)

                Spacer(minLength: 4)

                DashboardActionIndicator(accentColor: insight.accentColor, size: 24)
            }

            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .lastTextBaseline, spacing: 3) {
                    Text(insight.value)
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(insight.isAvailable ? Color.primary : Color.secondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.48)
                        .allowsTightening(true)

                    if !insight.unit.isEmpty {
                        Text(insight.unit)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.62)
                    }
                }

                Text(insight.subtitle)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .minimumScaleFactor(0.72)
            }

            Spacer(minLength: 0)

            if insight.isAvailable {
                ProgressView(value: min(max(insight.progress, 0), 1))
                    .tint(insight.accentColor)
                    .accessibilityLabel("\(insight.title) \(insight.progressText)")
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, minHeight: 142, alignment: .topLeading)
        .background(tileBackground, in: RoundedRectangle(cornerRadius: DashboardCardRadius.tile, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: DashboardCardRadius.tile, style: .continuous)
                .stroke(tileBorder, lineWidth: 1)
        }
        .accessibilityElement(children: .combine)
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
                Image(systemName: systemImage)
                    .font(.headline.weight(.bold))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(accentColor)
                    .frame(width: 30, height: 30)
                    .background(accentColor.opacity(0.15), in: Circle())

                Text(title)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(.primary)
                    .lineLimit(2, reservesSpace: true)
                    .minimumScaleFactor(0.60)
                    .allowsTightening(true)
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
                    .minimumScaleFactor(0.72)
                    .allowsTightening(true)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)

            HStack(alignment: .lastTextBaseline, spacing: 4) {
                Text(isAvailable ? value : "No data")
                    .font(.system(size: 30, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(isAvailable ? Color.primary : Color.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.46)
                    .allowsTightening(true)
                    .layoutPriority(1)

                if isAvailable && !unit.isEmpty {
                    Text(unit)
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.64)
                }
            }

            if showsChart {
                MetricBarChart(points: points, color: accentColor)
                    .frame(height: 42)
            } else if reservesChartSpace {
                Color.clear
                    .frame(height: 42)
                    .accessibilityHidden(true)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, minHeight: showsChartSlot ? 190 : 142, alignment: .topLeading)
        .background(.summarySurface, in: RoundedRectangle(cornerRadius: DashboardCardRadius.tile, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: DashboardCardRadius.tile, style: .continuous)
                .stroke(cardBorder, lineWidth: 1)
        }
    }

    private var showsChartSlot: Bool {
        showsChart || reservesChartSpace
    }

    private var showsChart: Bool {
        points.count > 1
    }

    private var cardBorder: Color {
        onSelect == nil ? Color.dashboardStroke : accentColor.opacity(0.20)
    }
}

private struct DashboardSeriesSection: View {
    let title: String
    let series: [NumericMetricSeries]
    let units: UnitPreferences
    let onSelectMetric: (GoogleHealthDataType) -> Void

    private let columns = [
        GridItem(.flexible(), spacing: 14),
        GridItem(.flexible(), spacing: 14)
    ]

    @ViewBuilder
    var body: some View {
        let visibleSeries = series.filter { !$0.points.isEmpty }
        if !visibleSeries.isEmpty {
            VStack(alignment: .leading, spacing: 14) {
                Text(title)
                    .font(.title2.weight(.bold))

                LazyVGrid(columns: columns, spacing: 14) {
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

    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(title)
                .font(.title2.weight(.bold))

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
                LazyVGrid(columns: columns, spacing: 12) {
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
                Text("Intensity")
                    .font(.title2.weight(.bold))

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
                        .minimumScaleFactor(0.72)
                        .allowsTightening(true)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .layoutPriority(1)

                Spacer(minLength: 12)

                Text(totalText)
                    .font(.headline.weight(.bold).monospacedDigit())
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)
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
        .padding(16)
        .background(.summarySurface, in: RoundedRectangle(cornerRadius: DashboardCardRadius.tile, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: DashboardCardRadius.tile, style: .continuous)
                .stroke(.dashboardStroke, lineWidth: 1)
        }
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
            }
        }
        .padding(16)
        .background(.summarySurface, in: RoundedRectangle(cornerRadius: DashboardCardRadius.compact, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: DashboardCardRadius.compact, style: .continuous)
                .stroke(.dashboardStroke, lineWidth: 1)
        }
    }
}

private struct SleepSessionsSection: View {
    let sessions: [SleepSession]
    let onSelect: (SleepSession) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Sleep")
                .font(.title2.weight(.bold))

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
                Image(systemName: "moon.zzz.fill")
                    .font(.headline.weight(.bold))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(.sleepAccent)
                    .frame(width: 34, height: 34)
                    .background(Color.sleepAccent.opacity(0.16), in: Circle())

                VStack(alignment: .leading, spacing: 4) {
                    Text("Sleep")
                        .font(.headline.weight(.bold))
                        .lineLimit(1)

                    Text(sleepRange)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .minimumScaleFactor(0.70)
                        .allowsTightening(true)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .layoutPriority(1)

                Spacer(minLength: 30)
            }
            .frame(minHeight: 48, alignment: .topLeading)
            .overlay(alignment: .topTrailing) {
                DashboardActionIndicator(accentColor: .sleepAccent, size: 30)
            }

            HStack(alignment: .lastTextBaseline, spacing: 4) {
                Text(duration.value)
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.54)
                    .allowsTightening(true)
                    .layoutPriority(1)

                if !duration.unit.isEmpty {
                    Text(duration.unit)
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
            }

            if !session.displayStages.isEmpty {
                SleepStageStrip(stages: session.displayStages)
            }
        }
        .padding(15)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .background(.summarySurface, in: RoundedRectangle(cornerRadius: DashboardCardRadius.tile, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: DashboardCardRadius.tile, style: .continuous)
                .stroke(Color.sleepAccent.opacity(0.18), lineWidth: 1)
        }
        .accessibilityElement(children: .combine)
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
                                .lineLimit(1)
                                .minimumScaleFactor(0.72)

                            Text(stageDetail(for: stage))
                                .font(.caption2.weight(.medium))
                                .monospacedDigit()
                                .foregroundStyle(.tertiary)
                                .lineLimit(1)
                                .minimumScaleFactor(0.72)
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
            .map { "\($0.stage) \(DashboardFormatting.duration($0.durationSeconds))" }
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
            .accessibilityElement(children: .combine)
            .accessibilityHint("Opens workout details")
        } else {
            cardContent
                .accessibilityElement(children: .combine)
        }
    }

    private var cardContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "dumbbell.fill")
                    .font(.system(size: 18, weight: .bold))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(.activeRing)
                    .frame(width: 44, height: 44)
                    .background(.activeRing.opacity(0.15), in: Circle())

                VStack(alignment: .leading, spacing: 4) {
                    Text(workout.type)
                        .font(.headline.weight(.bold))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.72)
                        .allowsTightening(true)

                    Text(DashboardFormatting.compactDateTimeLabel(for: workout.startTime))
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .minimumScaleFactor(0.72)
                        .allowsTightening(true)
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
                HStack(alignment: .lastTextBaseline, spacing: 4) {
                    Text(duration.value)
                        .font(.system(size: 34, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .lineLimit(1)
                        .minimumScaleFactor(0.50)
                        .allowsTightening(true)
                        .layoutPriority(1)

                    if !duration.unit.isEmpty {
                        Text(duration.unit)
                            .font(.headline.weight(.semibold))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.64)
                    }
                }

                if !stats.isEmpty {
                    WorkoutStatsRow(stats: stats)
                }
            }
        }
        .padding(15)
        .frame(maxWidth: .infinity, minHeight: 148, alignment: .topLeading)
        .background(.summarySurface, in: RoundedRectangle(cornerRadius: DashboardCardRadius.tile, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: DashboardCardRadius.tile, style: .continuous)
                .stroke(cardBorder, lineWidth: 1)
        }
    }

    private var duration: DashboardFormatting.MetricValue {
        DashboardFormatting.durationParts(workout.durationSeconds)
    }

    private var stats: [WorkoutStat] {
        var stats: [WorkoutStat] = []

        if let steps = workout.metricsSummary.steps {
            stats.append(
                WorkoutStat(
                    id: "steps",
                    text: DashboardFormatting.integer(Double(steps)),
                    systemImage: "shoeprints.fill"
                )
            )
        }

        if let distance = workout.metricsSummary.distanceMeters {
            stats.append(
                WorkoutStat(
                    id: "distance",
                    text: DashboardFormatting.distance(distance, unit: units.distanceUnit),
                    systemImage: "map"
                )
            )
        }

        if let calories = workout.metricsSummary.caloriesKcal {
            stats.append(
                WorkoutStat(
                    id: "calories",
                    text: "\(DashboardFormatting.integer(calories)) kcal",
                    systemImage: "flame"
                )
            )
        }

        if let heartRate = workout.metricsSummary.averageHeartRate {
            stats.append(
                WorkoutStat(
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
}

private struct WorkoutStat: Identifiable {
    let id: String
    let text: String
    let systemImage: String
}

private struct WorkoutStatsRow: View {
    let stats: [WorkoutStat]

    private let wrappedColumns = [
        GridItem(.adaptive(minimum: 92), spacing: 12, alignment: .leading)
    ]

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .firstTextBaseline, spacing: 18) {
                ForEach(stats) { stat in
                    WorkoutStatLabel(stat: stat)
                        .fixedSize(horizontal: true, vertical: false)
                }
            }

            LazyVGrid(columns: wrappedColumns, alignment: .leading, spacing: 6) {
                ForEach(stats) { stat in
                    WorkoutStatLabel(stat: stat)
                }
            }
        }
        .font(.caption.weight(.semibold))
        .foregroundStyle(.secondary)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct WorkoutStatLabel: View {
    let stat: WorkoutStat

    var body: some View {
        Label(stat.text, systemImage: stat.systemImage)
            .lineLimit(1)
            .minimumScaleFactor(0.72)
            .allowsTightening(true)
    }
}

private struct DetailMetricGrid: View {
    let metrics: [DetailMetric]

    private let columns = [
        GridItem(.flexible(), spacing: 14),
        GridItem(.flexible(), spacing: 14)
    ]

    var body: some View {
        if !metrics.isEmpty {
            LazyVGrid(columns: columns, spacing: 14) {
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
            Text("Splits")
                .font(.title2.weight(.bold))

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
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.summarySurface, in: RoundedRectangle(cornerRadius: DashboardCardRadius.compact, style: .continuous))
            }
        }
    }
}

private struct MetricPointList: View {
    let series: NumericMetricSeries
    let units: UnitPreferences

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("History")
                .font(.title2.weight(.bold))

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
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.summarySurface, in: RoundedRectangle(cornerRadius: DashboardCardRadius.compact, style: .continuous))
    }

    private var dateText: some View {
        Text(dateLabel)
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(.primary)
            .minimumScaleFactor(0.72)
            .allowsTightening(true)
            .fixedSize(horizontal: false, vertical: true)
    }

    private var valueText: some View {
        Text(value)
            .font(.headline.monospacedDigit())
            .foregroundStyle(.secondary)
            .lineLimit(1)
            .minimumScaleFactor(0.72)
            .allowsTightening(true)
    }
}

private struct MetricBarChart: View {
    let points: [NumericMetricPoint]
    let color: Color

    var body: some View {
        GeometryReader { geometry in
            let chartPoints = Array(points.suffix(24))
            let maxValue = max(chartPoints.map { max(0, $0.value) }.max() ?? 0, 1)
            let barWidth = barWidth(in: geometry.size.width, count: chartPoints.count)

            ZStack(alignment: .bottomLeading) {
                Path { path in
                    let baselineY = geometry.size.height - 0.5
                    let guideY = geometry.size.height * 0.42
                    path.move(to: CGPoint(x: 0, y: baselineY))
                    path.addLine(to: CGPoint(x: geometry.size.width, y: baselineY))
                    path.move(to: CGPoint(x: 0, y: guideY))
                    path.addLine(to: CGPoint(x: geometry.size.width, y: guideY))
                }
                .stroke(Color.dashboardStroke.opacity(0.42), style: StrokeStyle(lineWidth: 1, dash: [3, 4]))

                HStack(alignment: .bottom, spacing: barSpacing(in: geometry.size.width, count: chartPoints.count)) {
                    ForEach(chartPoints) { point in
                        let normalizedValue = max(0, point.value) / maxValue
                        RoundedRectangle(cornerRadius: min(5, barWidth / 2), style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [color.opacity(0.62), color.opacity(0.95)],
                                    startPoint: .bottom,
                                    endPoint: .top
                                )
                            )
                            .frame(
                                width: barWidth,
                                height: barHeight(
                                    normalizedValue: normalizedValue,
                                    value: point.value,
                                    maxHeight: geometry.size.height - 5
                                )
                            )
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
            }
        }
        .accessibilityHidden(true)
    }

    private func barWidth(in width: CGFloat, count: Int) -> CGFloat {
        guard count > 0 else { return 4 }
        let compactSpacing = CGFloat(max(count - 1, 0)) * preferredBarSpacing(for: count)
        let availableWidth = width - compactSpacing
        let preferredWidth = availableWidth / CGFloat(count)
        guard preferredWidth >= 4 else {
            return max(2, width / CGFloat(count * 2 - 1))
        }
        return min(12, preferredWidth)
    }

    private func barSpacing(in width: CGFloat, count: Int) -> CGFloat {
        guard count > 1 else { return 0 }
        let widthAfterBars = width - CGFloat(count) * barWidth(in: width, count: count)
        let availableSpacing = widthAfterBars / CGFloat(count - 1)
        return min(9, max(2, availableSpacing))
    }

    private func preferredBarSpacing(for count: Int) -> CGFloat {
        count > 16 ? 5 : 7
    }

    private func barHeight(normalizedValue: Double, value: Double, maxHeight: CGFloat) -> CGFloat {
        guard value > 0 else { return 2 }
        return max(4, maxHeight * CGFloat(normalizedValue))
    }
}

private struct DashboardEmptyState: View {
    let title: String
    let systemImage: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: systemImage)
                .font(.headline.weight(.bold))
                .foregroundStyle(.secondary)
                .frame(width: 28, height: 28)

            Text(title)
                .font(.headline.weight(.semibold))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(.summarySurface, in: RoundedRectangle(cornerRadius: DashboardCardRadius.compact, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: DashboardCardRadius.compact, style: .continuous)
                .stroke(.dashboardStroke, lineWidth: 1)
        }
    }
}

private struct DashboardScrollEdgeFade: View {
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

private extension DashboardFormatting {
    static func metricValue(
        _ value: Double,
        type: GoogleHealthDataType,
        units: UnitPreferences
    ) -> DashboardFormatting.MetricValue {
        switch type {
        case .distance:
            return distanceParts(value, unit: units.distanceUnit)
        case .height, .altitude:
            return DashboardFormatting.MetricValue(value: String(format: "%.2f", value), unit: "m")
        case .weight:
            return DashboardFormatting.MetricValue(value: String(format: "%.1f", value), unit: "kg")
        case .bodyFat, .oxygenSaturation, .dailyOxygenSaturation:
            return DashboardFormatting.MetricValue(value: String(format: "%.1f", value), unit: "%")
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
            return DashboardFormatting.MetricValue(value: String(format: "%.1f", value), unit: "brpm")
        case .dailySleepTemperatureDerivations, .coreBodyTemperature:
            return DashboardFormatting.MetricValue(value: String(format: "%.1f", value), unit: "deg")
        case .vo2Max, .dailyVo2Max, .runVo2Max:
            return DashboardFormatting.MetricValue(value: String(format: "%.1f", value), unit: "ml/kg/min")
        case .bloodGlucose:
            return DashboardFormatting.MetricValue(value: integer(value), unit: "mg/dL")
        case .activityLevel, .swimLengthsData:
            return DashboardFormatting.MetricValue(value: integer(value), unit: type.unit)
        case .exercise, .dailyHeartRateZones, .sleep:
            return DashboardFormatting.MetricValue(value: integer(value), unit: type.unit)
        }
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
                DetailMetric(title: "Elevation", value: String(format: "%.0f", elevation), unit: "m", systemImage: "mountain.2", color: .distanceAccent)
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
                DetailMetric(title: "Speed", value: String(format: "%.1f", speed), unit: "m/s", systemImage: "gauge", color: .activeRing)
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

@MainActor
private extension FitnessDashboardStore {
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

private extension FitnessDataSnapshot {
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
                averageHeartRate: 122
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
