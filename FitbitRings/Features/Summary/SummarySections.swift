import SwiftUI

struct TodayGoalsSection: View {
    let snapshot: DashboardSnapshot
    let units: UnitPreferences
    var onMetricSelected: (GoogleHealthDataType) -> Void = { _ in }
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isExpanded = true

    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            DashboardSectionHeader(title: "Summary") {
                Button {
                    withAnimation(sectionAnimation) {
                        isExpanded.toggle()
                    }
                } label: {
                    Text(isExpanded ? "Collapse" : "Expand")
                        .font(.headline.weight(.semibold))
                }
                .buttonStyle(DashboardPillButtonStyle())
                .accessibilityLabel(isExpanded ? "Collapse summary" : "Expand summary")
            }

            if isExpanded {
                LazyVGrid(columns: columns, spacing: 12) {
                    ForEach(goalCards) { card in
                        Button {
                            onMetricSelected(card.dataType)
                        } label: {
                            FitnessGoalCard(card: card)
                        }
                        .buttonStyle(SummaryInteractiveCardButtonStyle())
                        .accessibilityHint("Opens details")
                    }
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }

    private var goalCards: [FitnessGoalCardModel] {
        let distance = DashboardFormatting.distanceParts(snapshot.activity.distanceMeters, unit: units.distanceUnit)
        let summaryDayLabel = DashboardFormatting.compactDayLabel(for: snapshot.date)
        var cards: [FitnessGoalCardModel] = [
            FitnessGoalCardModel(
                title: "Steps",
                value: valueText(
                    type: .steps,
                    value: DashboardFormatting.integer(Double(snapshot.activity.steps))
                ),
                subtitle: summaryDayLabel,
                progress: progressValue(type: .steps, progress: snapshot.rings.steps.progress),
                systemImage: "shoeprints.fill",
                accentColor: .stepsRing,
                dataType: .steps,
                isAvailable: snapshot.activity.hasData(for: .steps)
            ),
            FitnessGoalCardModel(
                title: "Exercise Minutes",
                value: valueText(
                    type: .activeMinutes,
                    value: DashboardFormatting.integer(snapshot.rings.active.value)
                ),
                unit: unitText(type: .activeMinutes, unit: "m"),
                subtitle: summaryDayLabel,
                progress: progressValue(type: .activeMinutes, progress: snapshot.rings.active.progress),
                systemImage: "figure.run",
                accentColor: .activeRing,
                dataType: .activeMinutes,
                isHighlighted: snapshot.rings.active.progress >= 1,
                isAvailable: snapshot.activity.hasData(for: .activeMinutes)
            ),
            FitnessGoalCardModel(
                title: "Active Calories",
                value: valueText(
                    type: .activeEnergyBurned,
                    value: DashboardFormatting.integer(snapshot.activity.activeCalories)
                ),
                unit: unitText(type: .activeEnergyBurned, unit: "kcal"),
                subtitle: summaryDayLabel,
                progress: progressValue(type: .activeEnergyBurned, progress: snapshot.rings.move.progress),
                systemImage: "flame.fill",
                accentColor: .moveRing,
                dataType: .activeEnergyBurned,
                isHighlighted: snapshot.rings.move.progress >= 1,
                isAvailable: snapshot.activity.hasData(for: .activeEnergyBurned)
            ),
            FitnessGoalCardModel(
                title: "Distance",
                value: valueText(type: .distance, value: distance.value),
                unit: unitText(type: .distance, unit: distance.unit),
                subtitle: summaryDayLabel,
                systemImage: "map.fill",
                accentColor: .distanceAccent,
                dataType: .distance,
                isAvailable: snapshot.activity.hasData(for: .distance)
            ),
            FitnessGoalCardModel(
                title: "Total Calories",
                value: valueText(
                    type: .totalCalories,
                    value: DashboardFormatting.integer(snapshot.activity.totalCalories)
                ),
                unit: unitText(type: .totalCalories, unit: "kcal"),
                subtitle: summaryDayLabel,
                systemImage: "flame.circle.fill",
                accentColor: .calorieAccent,
                dataType: .totalCalories,
                isAvailable: snapshot.activity.hasData(for: .totalCalories)
            )
        ]

        cards.append(
            FitnessGoalCardModel(
                title: "Heart Rate",
                value: snapshot.heart.mostRecentHeartRate.map(String.init) ?? "No data",
                unit: snapshot.heart.mostRecentHeartRate == nil ? "" : "bpm",
                subtitle: snapshot.heart.measuredAt.map { "Measured \(DashboardFormatting.compactDateTimeLabel(for: $0))" },
                systemImage: "heart.fill",
                accentColor: .heartAccent,
                dataType: .heartRate,
                isAvailable: snapshot.heart.mostRecentHeartRate != nil
            )
        )

        cards.append(
            FitnessGoalCardModel(
                title: "Resting Heart",
                value: snapshot.heart.restingHeartRate.map(String.init) ?? "No data",
                unit: snapshot.heart.restingHeartRate == nil ? "" : "bpm",
                subtitle: summaryDayLabel,
                systemImage: "heart.circle.fill",
                accentColor: .heartAccent,
                dataType: .dailyRestingHeartRate,
                isAvailable: snapshot.heart.restingHeartRate != nil
            )
        )

        let sleepDuration = snapshot.sleep.map { DashboardFormatting.durationParts($0.durationSeconds) }
        cards.append(
            FitnessGoalCardModel(
                title: "Sleep",
                value: sleepDuration?.value ?? "No data",
                unit: sleepDuration?.unit ?? "",
                subtitle: snapshot.sleep.flatMap { sleepRange(for: $0) },
                systemImage: "moon.zzz.fill",
                accentColor: .sleepAccent,
                dataType: .sleep,
                isAvailable: snapshot.sleep != nil
            )
        )

        return cards
    }

    private func valueText(type: GoogleHealthDataType, value: String) -> String {
        snapshot.activity.hasData(for: type) ? value : "No data"
    }

    private func unitText(type: GoogleHealthDataType, unit: String) -> String {
        snapshot.activity.hasData(for: type) ? unit : ""
    }

    private func progressValue(type: GoogleHealthDataType, progress: Double) -> Double? {
        snapshot.activity.hasData(for: type) ? progress : nil
    }

    private func sleepRange(for sleep: SleepSummary) -> String? {
        guard sleep.startTime != nil || sleep.endTime != nil else {
            return nil
        }

        return DashboardFormatting.compactDateTimeRangeLabel(start: sleep.startTime, end: sleep.endTime)
    }

    private var sectionAnimation: Animation? {
        reduceMotion ? nil : .smooth(duration: 0.26, extraBounce: 0)
    }
}

struct RecentWorkoutSection: View {
    let workout: WorkoutSummary
    let units: UnitPreferences
    var onSelect: (() -> Void)? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            DashboardSectionHeader(title: "Recent Workout")

            Button {
                onSelect?()
            } label: {
                VStack(alignment: .leading, spacing: 14) {
                    HStack(alignment: .center, spacing: 12) {
                        MetricBadge(systemImage: "dumbbell.fill", accentColor: .activeRing, size: 44)

                        VStack(alignment: .leading, spacing: 4) {
                            Text(workout.type)
                                .font(.title3.weight(.bold))
                                .lineLimit(1)
                                .minimumScaleFactor(0.76)

                            Text(DashboardFormatting.compactDateTimeLabel(for: workout.startTime))
                                .font(.headline.weight(.semibold))
                                .foregroundStyle(.secondary)
                                .minimumScaleFactor(0.74)
                                .allowsTightening(true)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)

                        if onSelect != nil {
                            SummaryActionIndicator(accentColor: .activeRing, size: 30)
                        }
                    }

                    HStack(alignment: .top, spacing: 12) {
                        ForEach(workoutMetrics) { metric in
                            WorkoutMetricView(metric: metric)
                        }
                    }
                }
                .padding(15)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.summarySurface, in: RoundedRectangle(cornerRadius: DashboardCardRadius.tile, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: DashboardCardRadius.tile, style: .continuous)
                        .stroke(workoutBorder, lineWidth: 1)
                }
                .accessibilityElement(children: .combine)
            }
            .buttonStyle(SummaryInteractiveCardButtonStyle())
            .disabled(onSelect == nil)
            .accessibilityHint(onSelect == nil ? "" : "Opens workout details")
        }
    }

    private var workoutMetrics: [WorkoutMetricModel] {
        var metrics = [
            WorkoutMetricModel(
                title: "Duration",
                value: DashboardFormatting.durationParts(workout.durationSeconds),
                systemImage: "stopwatch"
            )
        ]

        if let distance = workout.distanceMeters {
            metrics.append(
                WorkoutMetricModel(
                    title: "Distance",
                    value: DashboardFormatting.distanceParts(distance, unit: units.distanceUnit),
                    systemImage: "map"
                )
            )
        }

        if let calories = workout.calories {
            metrics.append(
                WorkoutMetricModel(
                    title: "Calories Burned",
                    value: DashboardFormatting.MetricValue(
                        value: DashboardFormatting.integer(calories),
                        unit: "kcal"
                    ),
                    systemImage: "bolt.fill"
                )
            )
        }

        return metrics
    }

    private var workoutBorder: Color {
        onSelect == nil ? Color.dashboardStroke : Color.activeRing.opacity(0.18)
    }
}

private struct DashboardSectionHeader<Trailing: View>: View {
    let title: String
    @ViewBuilder var trailing: Trailing

    init(title: String, @ViewBuilder trailing: () -> Trailing) {
        self.title = title
        self.trailing = trailing()
    }

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            Text(title)
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .lineLimit(1)
                .minimumScaleFactor(0.72)

            Spacer(minLength: 0)

            trailing
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private extension DashboardSectionHeader where Trailing == EmptyView {
    init(title: String) {
        self.title = title
        self.trailing = EmptyView()
    }
}

private struct FitnessGoalCardModel: Identifiable {
    var id: String { title }
    let title: String
    let value: String
    var unit = ""
    var subtitle: String?
    var progress: Double?
    let systemImage: String
    let accentColor: Color
    let dataType: GoogleHealthDataType
    var isHighlighted = false
    var isAvailable = true
}

private struct FitnessGoalCard: View {
    let card: FitnessGoalCardModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 8) {
                MetricBadge(systemImage: card.systemImage, accentColor: card.accentColor, size: 34)

                VStack(alignment: .leading, spacing: 3) {
                    Text(card.title)
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(.primary)
                        .lineLimit(2)
                        .minimumScaleFactor(0.70)
                        .allowsTightening(true)
                        .fixedSize(horizontal: false, vertical: true)

                    if let subtitle = card.subtitle {
                        Text(subtitle)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                            .minimumScaleFactor(0.74)
                            .allowsTightening(true)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .layoutPriority(1)

                Spacer(minLength: 28)
            }
            .frame(minHeight: 46, alignment: .topLeading)
            .overlay(alignment: .topTrailing) {
                SummaryActionIndicator(accentColor: card.accentColor, size: 28)
            }

            Spacer(minLength: 4)

            VStack(alignment: .leading, spacing: 8) {
                MetricValueText(value: card.value, unit: card.isAvailable ? card.unit : "")

                if let progress = card.progress {
                    FitnessProgressBar(progress: progress, accentColor: card.accentColor)
                }
            }
        }
        .padding(15)
        .frame(maxWidth: .infinity, minHeight: 154, alignment: .topLeading)
        .background(cardBackground, in: RoundedRectangle(cornerRadius: DashboardCardRadius.tile, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: DashboardCardRadius.tile, style: .continuous)
                .stroke(cardBorder, lineWidth: 1)
        }
        .accessibilityElement(children: .combine)
    }

    private var cardBackground: Color {
        card.isHighlighted ? card.accentColor.opacity(0.16) : Color.summarySurface
    }

    private var cardBorder: Color {
        card.accentColor.opacity(card.isHighlighted ? 0.28 : 0.18)
    }
}

private struct MetricBadge: View {
    let systemImage: String
    let accentColor: Color
    var size: CGFloat = 50

    var body: some View {
        Image(systemName: systemImage)
            .font(.system(size: size * 0.42, weight: .bold))
            .symbolRenderingMode(.hierarchical)
            .foregroundStyle(accentColor)
            .frame(width: size, height: size)
            .background(accentColor.opacity(0.15), in: Circle())
    }
}

private struct MetricValueText: View {
    let value: String
    let unit: String
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        HStack(alignment: .lastTextBaseline, spacing: 3) {
            Text(value)
                .font(.system(size: 31, weight: .bold, design: .rounded))
                .monospacedDigit()
                .contentTransition(.numericText())
                .animation(valueAnimation, value: value)
                .lineLimit(1)
                .minimumScaleFactor(0.45)
                .allowsTightening(true)
                .layoutPriority(1)

            if !unit.isEmpty {
                Text(unit)
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.55)
                    .allowsTightening(true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var valueAnimation: Animation? {
        reduceMotion ? nil : .smooth(duration: 0.24, extraBounce: 0)
    }
}

private struct FitnessProgressBar: View {
    let progress: Double
    let accentColor: Color
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        GeometryReader { geometry in
            let normalizedProgress = min(max(progress, 0), 1)
            let width = normalizedProgress > 0
                ? max(10, geometry.size.width * normalizedProgress)
                : 0

            ZStack(alignment: .leading) {
                Capsule()
                    .fill(accentColor.opacity(0.24))

                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [accentColor.opacity(0.82), accentColor],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: width)
                    .animation(progressAnimation, value: normalizedProgress)
            }
        }
        .frame(height: 9)
    }

    private var progressAnimation: Animation? {
        reduceMotion ? nil : .smooth(duration: 0.38, extraBounce: 0)
    }
}

private struct WorkoutMetricModel: Identifiable {
    var id: String { title }
    let title: String
    let value: DashboardFormatting.MetricValue
    let systemImage: String
}

private struct WorkoutMetricView: View {
    let metric: WorkoutMetricModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack(spacing: 6) {
                Image(systemName: metric.systemImage)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.tertiary)
                    .frame(width: 15)

                Text(metric.title)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.76)
            }

            HStack(alignment: .lastTextBaseline, spacing: 3) {
                Text(metric.value.value)
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .contentTransition(.numericText())
                    .animation(valueAnimation, value: metric.value.value)
                    .lineLimit(1)
                    .minimumScaleFactor(0.58)
                    .allowsTightening(true)

                if !metric.value.unit.isEmpty {
                    Text(metric.value.unit)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                        .allowsTightening(true)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityLabel("\(metric.title) \(metric.value.value) \(metric.value.unit)")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var valueAnimation: Animation? {
        reduceMotion ? nil : .smooth(duration: 0.24, extraBounce: 0)
    }
}

private struct SummaryActionIndicator: View {
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

private struct SummaryInteractiveCardButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.985 : 1)
            .opacity(configuration.isPressed ? 0.86 : 1)
            .animation(.smooth(duration: 0.16, extraBounce: 0), value: configuration.isPressed)
    }
}

private struct DashboardPillButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(.primary)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(.dashboardTintSurface, in: Capsule())
            .overlay {
                Capsule()
                    .stroke(.dashboardStroke, lineWidth: 1)
            }
            .opacity(configuration.isPressed ? 0.72 : 1)
    }
}
