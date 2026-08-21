import SwiftUI

struct TodayGoalsSection: View {
    let snapshot: DashboardSnapshot
    let units: UnitPreferences
    @State private var isExpanded = true

    private let columns = [
        GridItem(.flexible(), spacing: 14),
        GridItem(.flexible(), spacing: 14)
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            DashboardSectionHeader(title: "Today's Goals") {
                Button {
                    withAnimation(.snappy(duration: 0.28)) {
                        isExpanded.toggle()
                    }
                } label: {
                    Text(isExpanded ? "Collapse" : "Expand")
                        .font(.headline.weight(.semibold))
                }
                .buttonStyle(DashboardPillButtonStyle())
                .accessibilityLabel(isExpanded ? "Collapse today's goals" : "Expand today's goals")
            }

            if isExpanded {
                LazyVGrid(columns: columns, spacing: 14) {
                    ForEach(goalCards) { card in
                        FitnessGoalCard(card: card)
                    }
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }

    private var goalCards: [FitnessGoalCardModel] {
        let distance = DashboardFormatting.distanceParts(snapshot.activity.distanceMeters, unit: units.distanceUnit)
        var cards: [FitnessGoalCardModel] = [
            FitnessGoalCardModel(
                title: "Exercise Minutes",
                value: DashboardFormatting.integer(snapshot.rings.active.value),
                unit: "m",
                percent: DashboardFormatting.percent(snapshot.rings.active.progress),
                progress: snapshot.rings.active.progress,
                systemImage: "figure.run",
                accentColor: .activeRing,
                isHighlighted: snapshot.rings.active.progress >= 1
            ),
            FitnessGoalCardModel(
                title: "Calories",
                value: DashboardFormatting.integer(snapshot.activity.totalCalories),
                unit: "kcal",
                systemImage: "fork.knife",
                accentColor: .calorieAccent
            ),
            FitnessGoalCardModel(
                title: "Steps",
                value: DashboardFormatting.integer(Double(snapshot.activity.steps)),
                percent: DashboardFormatting.percent(snapshot.rings.steps.progress),
                progress: snapshot.rings.steps.progress,
                systemImage: "shoeprints.fill",
                accentColor: .stepsRing
            ),
            FitnessGoalCardModel(
                title: "Distance",
                value: distance.value,
                unit: distance.unit,
                systemImage: "map.fill",
                accentColor: .distanceAccent
            ),
            FitnessGoalCardModel(
                title: "Active Calories",
                value: DashboardFormatting.integer(snapshot.activity.activeCalories),
                unit: "kcal",
                percent: DashboardFormatting.percent(snapshot.rings.move.progress),
                progress: snapshot.rings.move.progress,
                systemImage: "flame.fill",
                accentColor: .moveRing
            )
        ]

        if let latestHeartRate = snapshot.heart.mostRecentHeartRate {
            cards.append(
                FitnessGoalCardModel(
                    title: "Heart Rate",
                    value: "\(latestHeartRate)",
                    unit: "bpm",
                    subtitle: snapshot.heart.measuredAt.map { "Measured \(DashboardFormatting.time($0))" },
                    systemImage: "heart.fill",
                    accentColor: .heartAccent
                )
            )
        }

        if let restingHeartRate = snapshot.heart.restingHeartRate {
            cards.append(
                FitnessGoalCardModel(
                    title: "Resting Heart",
                    value: "\(restingHeartRate)",
                    unit: "bpm",
                    systemImage: "heart.circle.fill",
                    accentColor: .heartAccent
                )
            )
        }

        if let sleep = snapshot.sleep {
            let sleepDuration = DashboardFormatting.durationParts(sleep.durationSeconds)
            cards.append(
                FitnessGoalCardModel(
                    title: "Sleep",
                    value: sleepDuration.value,
                    unit: sleepDuration.unit,
                    subtitle: sleepRange(for: sleep),
                    systemImage: "moon.zzz.fill",
                    accentColor: .sleepAccent
                )
            )
        }

        return cards
    }

    private func sleepRange(for sleep: SleepSummary) -> String? {
        guard sleep.startTime != nil || sleep.endTime != nil else {
            return nil
        }

        return "\(DashboardFormatting.time(sleep.startTime)) - \(DashboardFormatting.time(sleep.endTime))"
    }
}

struct RecentWorkoutSection: View {
    let workout: WorkoutSummary
    let units: UnitPreferences

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            DashboardSectionHeader(title: "Recent Workout")

            VStack(alignment: .leading, spacing: 18) {
                HStack(alignment: .top, spacing: 14) {
                    MetricBadge(systemImage: "dumbbell.fill", accentColor: .activeRing, size: 50)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(workout.type)
                            .font(.title3.weight(.bold))
                            .lineLimit(1)
                            .minimumScaleFactor(0.76)

                        Text(workout.startTime.formatted(date: .abbreviated, time: .omitted))
                            .font(.headline.weight(.semibold))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    Image(systemName: "chevron.right")
                        .font(.title3.weight(.bold))
                        .foregroundStyle(.tertiary)
                        .padding(.top, 8)
                }

                HStack(spacing: 12) {
                    ForEach(workoutMetrics) { metric in
                        WorkoutMetricView(metric: metric)
                    }
                }
            }
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.summarySurface, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            .accessibilityElement(children: .combine)
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
                    title: "Calories",
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
                .font(.system(size: 30, weight: .bold, design: .rounded))
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
    var percent: String?
    var progress: Double?
    let systemImage: String
    let accentColor: Color
    var isHighlighted = false
}

private struct FitnessGoalCard: View {
    let card: FitnessGoalCardModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 10) {
                MetricBadge(systemImage: card.systemImage, accentColor: card.accentColor)

                Spacer(minLength: 0)

                MetricValueText(value: card.value, unit: card.unit)
            }
            .frame(height: 46)

            VStack(alignment: .leading, spacing: 5) {
                Text(card.title)
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .lineLimit(2)
                    .minimumScaleFactor(0.68)
                    .fixedSize(horizontal: false, vertical: true)

                if let subtitle = card.subtitle {
                    Text(subtitle)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                        .minimumScaleFactor(0.78)
                }
            }

            Spacer(minLength: 0)

            if let percent = card.percent, let progress = card.progress {
                VStack(alignment: .leading, spacing: 8) {
                    Text(percent)
                        .font(.headline.weight(.bold).monospacedDigit())
                        .foregroundStyle(card.accentColor)

                    FitnessProgressBar(progress: progress, accentColor: card.accentColor)
                }
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, minHeight: 174, alignment: .topLeading)
        .background(cardBackground, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .accessibilityElement(children: .combine)
    }

    private var cardBackground: Color {
        card.isHighlighted ? card.accentColor.opacity(0.20) : Color.summarySurface
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

    var body: some View {
        HStack(alignment: .lastTextBaseline, spacing: 3) {
            Text(value)
                .font(.system(size: 31, weight: .bold, design: .rounded))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.58)

            if !unit.isEmpty {
                Text(unit)
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
        }
        .frame(maxWidth: 110, alignment: .trailing)
    }
}

private struct FitnessProgressBar: View {
    let progress: Double
    let accentColor: Color

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
            }
        }
        .frame(height: 9)
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

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            Image(systemName: metric.systemImage)
                .font(.headline.weight(.bold))
                .foregroundStyle(.tertiary)
                .frame(height: 20)

            MetricValueText(value: metric.value.value, unit: metric.value.unit)
                .frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityLabel("\(metric.title) \(metric.value.value) \(metric.value.unit)")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
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
