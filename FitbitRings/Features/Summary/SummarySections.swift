import SwiftUI

struct ActivitySummarySection: View {
    let summary: ActivitySummary
    let units: UnitPreferences

    var body: some View {
        SummarySection(title: "Activity", systemImage: "figure.walk", accentColor: .stepsRing) {
            MetricGrid(items: [
                MetricItem(
                    title: "Steps",
                    value: DashboardFormatting.integer(Double(summary.steps)),
                    systemImage: "figure.walk",
                    accentColor: .stepsRing
                ),
                MetricItem(
                    title: "Distance",
                    value: DashboardFormatting.distance(summary.distanceMeters, unit: units.distanceUnit),
                    systemImage: "map.fill",
                    accentColor: .activeRing
                ),
                MetricItem(
                    title: "Active calories",
                    value: "\(DashboardFormatting.integer(summary.activeCalories)) kcal",
                    systemImage: "flame.fill",
                    accentColor: .moveRing
                ),
                MetricItem(
                    title: "Total calories",
                    value: "\(DashboardFormatting.integer(summary.totalCalories)) kcal",
                    systemImage: "speedometer",
                    accentColor: Color(uiColor: .systemOrange)
                )
            ])
        }
    }
}

struct LatestWorkoutCard: View {
    let workout: WorkoutSummary?
    let units: UnitPreferences

    var body: some View {
        SummarySection(title: "Latest Workout", systemImage: "figure.run", accentColor: .activeRing) {
            if let workout {
                VStack(spacing: 11) {
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
                EmptySummaryText("No recent workout found", systemImage: "figure.walk.circle")
            }
        }
    }
}

struct HeartSummarySection: View {
    let summary: HeartSummary

    var body: some View {
        SummarySection(title: "Heart", systemImage: "heart.fill", accentColor: Color(uiColor: .systemPink)) {
            MetricGrid(items: [
                MetricItem(
                    title: "Latest",
                    value: summary.mostRecentHeartRate.map { "\($0) bpm" } ?? "--",
                    systemImage: "waveform.path.ecg",
                    accentColor: Color(uiColor: .systemPink)
                ),
                MetricItem(
                    title: "Resting",
                    value: summary.restingHeartRate.map { "\($0) bpm" } ?? "--",
                    systemImage: "heart.circle.fill",
                    accentColor: Color(uiColor: .systemRed)
                )
            ])

            if let measuredAt = summary.measuredAt {
                HStack(spacing: 6) {
                    Image(systemName: "clock")
                    Text("Measured \(measuredAt.formatted(date: .omitted, time: .shortened))")
                }
                    .font(.footnote.weight(.medium))
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
        SummarySection(title: "Sleep", systemImage: "moon.zzz.fill", accentColor: Color(uiColor: .systemIndigo)) {
            if let summary {
                VStack(spacing: 11) {
                    InfoRow(title: "Duration", value: DashboardFormatting.duration(summary.durationSeconds))
                    InfoRow(title: "Start", value: DashboardFormatting.time(summary.startTime))
                    InfoRow(title: "End", value: DashboardFormatting.time(summary.endTime))
                }
            } else {
                EmptySummaryText("No sleep session found", systemImage: "bed.double.circle")
            }
        }
    }
}

struct SummarySection<Content: View>: View {
    let title: String
    let systemImage: String
    let accentColor: Color
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 10) {
                Image(systemName: systemImage)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(accentColor)
                    .frame(width: 28, height: 28)
                    .background(accentColor.opacity(0.12), in: RoundedRectangle(cornerRadius: 8, style: .continuous))

                Text(title)
                    .font(.headline.weight(.bold))

                Spacer(minLength: 0)
            }

            content
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(.summarySurface, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(.dashboardStroke, lineWidth: 1)
        }
        .shadow(color: Color.black.opacity(0.035), radius: 12, x: 0, y: 6)
    }
}

struct MetricItem: Identifiable {
    var id: String { title }
    var title: String
    var value: String
    var systemImage: String
    var accentColor: Color
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
                VStack(alignment: .leading, spacing: 7) {
                    HStack(spacing: 6) {
                        Image(systemName: item.systemImage)
                            .font(.caption.weight(.bold))
                            .foregroundStyle(item.accentColor)
                            .frame(width: 16)

                        Text(item.title)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.78)
                    }

                    Text(item.value)
                        .font(.title3.weight(.bold).monospacedDigit())
                        .lineLimit(1)
                        .minimumScaleFactor(0.68)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityElement(children: .combine)
            }
        }
    }
}

struct InfoRow: View {
    let title: String
    let value: String

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .foregroundStyle(.secondary)
            Spacer(minLength: 12)
            Text(value)
                .fontWeight(.semibold)
                .multilineTextAlignment(.trailing)
                .fixedSize(horizontal: false, vertical: true)
        }
        .font(.subheadline.weight(.medium))
    }
}

struct EmptySummaryText: View {
    let message: String
    let systemImage: String

    init(_ message: String, systemImage: String = "tray") {
        self.message = message
        self.systemImage = systemImage
    }

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: systemImage)
                .font(.headline)
                .foregroundStyle(.secondary)
                .frame(width: 26)

            Text(message)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(.dashboardTintSurface, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}
