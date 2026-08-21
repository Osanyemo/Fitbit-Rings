import SwiftUI

struct RingGoalProgress: View {
    let rings: RingSet

    var body: some View {
        VStack(spacing: 12) {
            ProgressRow(metric: rings.move, color: .moveRing)
            ProgressRow(metric: rings.active, color: .activeRing)
            ProgressRow(metric: rings.steps, color: .stepsRing)
        }
    }
}

private struct ProgressRow: View {
    let metric: RingMetric
    let color: Color

    var body: some View {
        HStack {
            Circle()
                .fill(color)
                .frame(width: 10, height: 10)
            Text(metric.title)
                .font(.headline)
            Spacer()
            Text(valueText)
                .font(.headline.monospacedDigit())
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 2)
    }

    private var valueText: String {
        let value = DashboardFormatting.integer(metric.value)
        let goal = DashboardFormatting.integer(metric.goal)
        if metric.unit.isEmpty {
            return "\(value) / \(goal)"
        }
        return "\(value) / \(goal) \(metric.unit)"
    }
}
