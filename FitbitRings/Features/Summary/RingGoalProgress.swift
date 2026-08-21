import SwiftUI

struct RingGoalProgress: View {
    let rings: RingSet

    var body: some View {
        VStack(spacing: 10) {
            ProgressRow(metric: rings.move, color: .moveRing, systemImage: "flame.fill")
            ProgressRow(metric: rings.active, color: .activeRing, systemImage: "bolt.heart.fill")
            ProgressRow(metric: rings.steps, color: .stepsRing, systemImage: "figure.walk")
        }
    }
}

private struct ProgressRow: View {
    let metric: RingMetric
    let color: Color
    let systemImage: String
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                Image(systemName: systemImage)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(color)
                    .frame(width: 20)

                Text(metric.title)
                    .font(.subheadline.weight(.bold))

                Spacer(minLength: 8)

                Text(valueText)
                    .font(.subheadline.weight(.semibold).monospacedDigit())
                    .foregroundStyle(.secondary)
                    .contentTransition(.numericText())
                    .animation(valueAnimation, value: valueText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.76)

                Text(DashboardFormatting.percent(metric.progress))
                    .font(.caption.weight(.bold).monospacedDigit())
                    .foregroundStyle(color)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(color.opacity(0.12), in: Capsule())
            }

            DashboardProgressTrack(progress: metric.cappedProgress, accentColor: color, height: 10)
        }
        .padding(12)
        .dashboardSurface(level: .raised, accentColor: color, isHighlighted: metric.progress >= 1)
        .accessibilityElement(children: .combine)
    }

    private var valueText: String {
        let value = DashboardFormatting.integer(metric.value)
        let goal = DashboardFormatting.integer(metric.goal)
        if metric.unit.isEmpty {
            return "\(value) / \(goal)"
        }
        return "\(value) / \(goal) \(metric.unit)"
    }

    private var valueAnimation: Animation? {
        reduceMotion ? nil : .smooth(duration: 0.28, extraBounce: 0)
    }
}
