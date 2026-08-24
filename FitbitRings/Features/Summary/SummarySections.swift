import SwiftUI

struct TodayGoalsSection: View {
    let snapshot: DashboardSnapshot
    let units: UnitPreferences
    var onMetricSelected: (GoogleHealthDataType) -> Void = { _ in }
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isExpanded = true

    @ViewBuilder
    var body: some View {
        if !goalCards.isEmpty {
            VStack(alignment: .leading, spacing: 14) {
            DashboardSectionHeader(title: "Today’s Metrics") {
                Button {
                    withAnimation(sectionAnimation) {
                        isExpanded.toggle()
                    }
                } label: {
                    Label(
                        isExpanded ? "Collapse" : "Expand",
                        systemImage: isExpanded ? "chevron.up" : "chevron.down"
                    )
                    .font(.subheadline.weight(.semibold))
                    .frame(minHeight: DashboardDesign.minimumControlSize)
                }
                .buttonStyle(DashboardPillButtonStyle())
                .accessibilityLabel(isExpanded ? "Collapse summary" : "Expand summary")
            }

            if isExpanded {
                DashboardAdaptiveGrid {
                    ForEach(goalCards) { card in
                        Button {
                            onMetricSelected(card.dataType)
                        } label: {
                            FitnessGoalCard(card: card)
                        }
                        .buttonStyle(DashboardInteractiveCardButtonStyle())
                        .accessibilityHint("Opens details")
                    }
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        }
    }

    private var goalCards: [FitnessGoalCardModel] {
        var cards: [FitnessGoalCardModel] = []

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

        return cards.filter(\.isAvailable)
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
                        DashboardMetricBadge(systemImage: "dumbbell.fill", accentColor: .activeRing, size: 44)

                        VStack(alignment: .leading, spacing: 4) {
                            Text(workout.type)
                                .font(.title3.weight(.bold))
                                .fixedSize(horizontal: false, vertical: true)

                            Text(DashboardFormatting.compactDateTimeLabel(for: workout.startTime))
                                .font(.headline.weight(.semibold))
                                .foregroundStyle(.secondary)
                                .minimumScaleFactor(0.74)
                                .allowsTightening(true)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)

                        if onSelect != nil {
                            DashboardActionIndicator(accentColor: .activeRing, size: 30)
                        }
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        DashboardCardValueRow(
                            value: duration.value,
                            unit: duration.unit,
                            valueFontSize: 34
                        )

                        if !workoutStats.isEmpty {
                            DashboardCardStatRow(stats: workoutStats)
                        }
                    }
                }
                .dashboardCard(border: workoutBorder, padding: 15)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(workout.type)
                .accessibilityValue(workoutAccessibilityValue)
            }
            .buttonStyle(DashboardInteractiveCardButtonStyle())
            .disabled(onSelect == nil)
            .accessibilityHint(onSelect == nil ? "" : "Opens workout details")
        }
    }

    private var duration: DashboardFormatting.MetricValue {
        DashboardFormatting.durationParts(workout.durationSeconds)
    }

    private var workoutStats: [DashboardCardStat] {
        var stats: [DashboardCardStat] = []

        if let steps = workout.steps {
            stats.append(
                DashboardCardStat(
                    id: "steps",
                    text: DashboardFormatting.integer(Double(steps)),
                    systemImage: "shoeprints.fill"
                )
            )
        }

        if let distance = workout.distanceMeters {
            stats.append(
                DashboardCardStat(
                    id: "distance",
                    text: DashboardFormatting.distance(distance, unit: units.distanceUnit),
                    systemImage: "map"
                )
            )
        }

        if let calories = workout.calories {
            stats.append(
                DashboardCardStat(
                    id: "calories",
                    text: "\(DashboardFormatting.integer(calories)) kcal",
                    systemImage: "flame"
                )
            )
        }

        if let heartRate = workout.averageHeartRate {
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

    private var workoutBorder: Color {
        onSelect == nil ? Color.dashboardStroke : Color.activeRing.opacity(0.18)
    }

    private var workoutAccessibilityValue: String {
        let statsDescription = workoutStats.map(\.text).joined(separator: ", ")
        return [
            DashboardFormatting.compactDateTimeLabel(for: workout.startTime),
            DashboardAccessibilityFormatting.duration(workout.durationSeconds),
            statsDescription
        ]
        .filter { !$0.isEmpty }
        .joined(separator: ". ")
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
                .font(.title2.weight(.bold))
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)

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
                DashboardMetricBadge(systemImage: card.systemImage, accentColor: card.accentColor, size: 34)

                VStack(alignment: .leading, spacing: 3) {
                    Text(card.title)
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(.primary)
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
                DashboardActionIndicator(accentColor: card.accentColor, size: 28)
            }

            Spacer(minLength: 4)

            VStack(alignment: .leading, spacing: 8) {
                DashboardCardValueRow(
                    value: card.value,
                    unit: card.isAvailable ? card.unit : "",
                    valueFontSize: 31,
                    animatesValue: true
                )

                if let progress = card.progress {
                    FitnessProgressBar(progress: progress, accentColor: card.accentColor)
                }
            }
        }
        .dashboardCard(
            background: cardBackground,
            border: cardBorder,
            padding: 15,
            minHeight: 154
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel(card.title)
        .accessibilityValue(
            DashboardAccessibilityFormatting.metric(
                value: card.value,
                unit: card.isAvailable ? card.unit : ""
            )
        )
    }

    private var cardBackground: Color {
        card.isHighlighted ? card.accentColor.opacity(0.16) : Color.summarySurface
    }

    private var cardBorder: Color {
        card.accentColor.opacity(card.isHighlighted ? 0.28 : 0.18)
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
