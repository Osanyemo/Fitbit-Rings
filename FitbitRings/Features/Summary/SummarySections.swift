import SwiftUI

struct ActivitySummarySection: View {
    let summary: ActivitySummary
    let units: UnitPreferences

    var body: some View {
        SummarySection(title: "Activity") {
            MetricGrid(items: [
                MetricItem(title: "Steps", value: DashboardFormatting.integer(Double(summary.steps))),
                MetricItem(title: "Distance", value: DashboardFormatting.distance(summary.distanceMeters, unit: units.distanceUnit)),
                MetricItem(title: "Active calories", value: "\(DashboardFormatting.integer(summary.activeCalories)) kcal"),
                MetricItem(title: "Total calories", value: "\(DashboardFormatting.integer(summary.totalCalories)) kcal")
            ])
        }
    }
}

struct LatestWorkoutCard: View {
    let workout: WorkoutSummary?
    let units: UnitPreferences

    var body: some View {
        SummarySection(title: "Latest Workout") {
            if let workout {
                VStack(spacing: 12) {
                    InfoRow(title: "Type", value: workout.type)
                    InfoRow(title: "Start", value: workout.startTime.formatted(date: .abbreviated, time: .shortened))
                    InfoRow(title: "Duration", value: DashboardFormatting.duration(workout.durationSeconds))
                    if let distance = workout.distanceMeters {
                        InfoRow(title: "Distance", value: DashboardFormatting.distance(distance, unit: units.distanceUnit))
                    }
                    if let calories = workout.calories {
                        InfoRow(title: "Calories", value: "\(DashboardFormatting.integer(calories)) kcal")
                    }
                }
            } else {
                EmptySummaryText("No recent workout found")
            }
        }
    }
}

struct HeartSummarySection: View {
    let summary: HeartSummary

    var body: some View {
        SummarySection(title: "Heart") {
            MetricGrid(items: [
                MetricItem(title: "Latest", value: summary.mostRecentHeartRate.map { "\($0) bpm" } ?? "--"),
                MetricItem(title: "Resting", value: summary.restingHeartRate.map { "\($0) bpm" } ?? "--")
            ])

            if let measuredAt = summary.measuredAt {
                Text("Measured \(measuredAt.formatted(date: .omitted, time: .shortened))")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top, 4)
            }
        }
    }
}

struct SleepSummarySection: View {
    let summary: SleepSummary?

    var body: some View {
        SummarySection(title: "Sleep") {
            if let summary {
                VStack(spacing: 12) {
                    InfoRow(title: "Duration", value: DashboardFormatting.duration(summary.durationSeconds))
                    InfoRow(title: "Start", value: DashboardFormatting.time(summary.startTime))
                    InfoRow(title: "End", value: DashboardFormatting.time(summary.endTime))
                }
            } else {
                EmptySummaryText("No sleep session found")
            }
        }
    }
}

struct SummarySection<Content: View>: View {
    let title: String
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(title)
                .font(.title3.weight(.bold))
            content
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(.summarySurface, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

struct MetricItem: Identifiable {
    var id: String { title }
    var title: String
    var value: String
}

struct MetricGrid: View {
    let items: [MetricItem]

    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]

    var body: some View {
        LazyVGrid(columns: columns, spacing: 14) {
            ForEach(items) { item in
                VStack(alignment: .leading, spacing: 4) {
                    Text(item.title)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Text(item.value)
                        .font(.headline.monospacedDigit())
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }
}

struct InfoRow: View {
    let title: String
    let value: String

    var body: some View {
        HStack {
            Text(title)
                .foregroundStyle(.secondary)
            Spacer(minLength: 12)
            Text(value)
                .fontWeight(.semibold)
                .multilineTextAlignment(.trailing)
        }
        .font(.subheadline)
    }
}

struct EmptySummaryText: View {
    let message: String

    init(_ message: String) {
        self.message = message
    }

    var body: some View {
        Text(message)
            .font(.subheadline.weight(.medium))
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}
