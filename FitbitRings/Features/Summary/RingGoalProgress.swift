import SwiftUI

struct RingGoalProgress: View {
    let rings: RingSet

    var body: some View {
        VStack(spacing: 10) {
            ProgressRow(metric: rings.steps, color: .stepsRing, systemImage: "figure.walk")
            ProgressRow(metric: rings.active, color: .activeRing, systemImage: "bolt.heart.fill")
            ProgressRow(metric: rings.move, color: .moveRing, systemImage: "flame.fill")
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
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 10) {
                    titleLabel
                    Spacer(minLength: 8)
                    valueLabel
                    percentLabel
                }

                VStack(alignment: .leading, spacing: 8) {
                    titleLabel
                    valueLabel
                    percentLabel
                }
            }

            ProgressView(value: metric.cappedProgress)
                .tint(color)
                .scaleEffect(x: 1, y: 1.25, anchor: .center)
                .animation(progressAnimation, value: metric.cappedProgress)
        }
        .dashboardCard(
            background: .dashboardMetricSurface,
            border: color.opacity(0.10),
            radius: DashboardCardRadius.compact,
            padding: 12
        )
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(metric.title)
        .accessibilityValue(
            "\(DashboardAccessibilityFormatting.metric(value: DashboardFormatting.integer(metric.value), unit: metric.unit)), goal \(DashboardAccessibilityFormatting.metric(value: DashboardFormatting.integer(metric.goal), unit: metric.unit)), \(DashboardFormatting.percent(metric.progress))"
        )
    }

    private var titleLabel: some View {
        Label(metric.title, systemImage: systemImage)
            .font(.subheadline.weight(.bold))
            .foregroundStyle(color)
            .fixedSize(horizontal: false, vertical: true)
    }

    private var valueLabel: some View {
        Text(valueText)
            .font(.subheadline.weight(.semibold).monospacedDigit())
            .foregroundStyle(.secondary)
            .contentTransition(.numericText())
            .animation(progressAnimation, value: valueText)
            .fixedSize(horizontal: false, vertical: true)
    }

    private var percentLabel: some View {
        Text(DashboardFormatting.percent(metric.progress))
            .font(.caption.weight(.bold).monospacedDigit())
            .foregroundStyle(color)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(color.opacity(0.12), in: Capsule())
    }

    private var valueText: String {
        let value = DashboardFormatting.integer(metric.value)
        let goal = DashboardFormatting.integer(metric.goal)
        if metric.unit.isEmpty {
            return "\(value) / \(goal)"
        }
        return "\(value) / \(goal) \(metric.unit)"
    }

    private var progressAnimation: Animation? {
        reduceMotion ? nil : .smooth(duration: 0.34, extraBounce: 0)
    }
}
