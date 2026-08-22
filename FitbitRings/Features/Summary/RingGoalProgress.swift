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
                    .animation(progressAnimation, value: valueText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.76)

                Text(DashboardFormatting.percent(metric.progress))
                    .font(.caption.weight(.bold).monospacedDigit())
                    .foregroundStyle(color)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(color.opacity(0.12), in: Capsule())
            }

            ProgressView(value: metric.cappedProgress)
                .tint(color)
                .scaleEffect(x: 1, y: 1.25, anchor: .center)
                .animation(progressAnimation, value: metric.cappedProgress)
        }
        .padding(12)
        .background(.dashboardMetricSurface, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(color.opacity(0.10), lineWidth: 1)
        }
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

    private var progressAnimation: Animation? {
        reduceMotion ? nil : .smooth(duration: 0.34, extraBounce: 0)
    }
}
