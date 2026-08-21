import SwiftUI

struct ActivityRingsView: View {
    let rings: RingSet
    private let lineWidth: CGFloat = 22

    var body: some View {
        ZStack {
            ring(metric: rings.steps, color: .stepsRing, inset: 0)
            ring(metric: rings.active, color: .activeRing, inset: 34)
            ring(metric: rings.move, color: .moveRing, inset: 68)

            VStack(spacing: 4) {
                Text(DashboardFormatting.integer(rings.steps.value))
                    .font(.system(.largeTitle, design: .rounded, weight: .bold))
                    .monospacedDigit()
                    .contentTransition(.numericText())
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
                Text("steps")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
                Text(DashboardFormatting.percent(rings.steps.progress))
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.stepsRing)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 4)
                    .background(.stepsRing.opacity(0.12), in: Capsule())
                    .accessibilityHidden(true)
            }
            .padding(.horizontal, 28)
        }
        .aspectRatio(1, contentMode: .fit)
        .frame(maxWidth: 320)
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 2)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            "Move \(Int(rings.move.value)) of \(Int(rings.move.goal)) calories, Active \(Int(rings.active.value)) of \(Int(rings.active.goal)) minutes, Steps \(Int(rings.steps.value)) of \(Int(rings.steps.goal))"
        )
    }

    private func ring(metric: RingMetric, color: Color, inset: CGFloat) -> some View {
        ZStack {
            RingShape(progress: 1)
                .stroke(color.opacity(0.14), style: stroke)
            RingShape(progress: metric.cappedProgress)
                .stroke(
                    AngularGradient(
                        colors: [color.opacity(0.68), color],
                        center: .center,
                        startAngle: .degrees(-90),
                        endAngle: .degrees(270)
                    ),
                    style: stroke
                )
                .shadow(color: color.opacity(0.20), radius: 7, x: 0, y: 3)
        }
        .padding(inset + lineWidth / 2)
        .animation(.snappy(duration: 0.55), value: metric.cappedProgress)
    }

    private var stroke: StrokeStyle {
        StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round)
    }
}

struct RingShape: Shape {
    var progress: Double

    var animatableData: Double {
        get { progress }
        set { progress = newValue }
    }

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let size = min(rect.width, rect.height)
        let radius = size / 2
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let startAngle = Angle.degrees(-92)
        let endAngle = Angle.degrees(-92 + 360 * progress)

        path.addArc(
            center: center,
            radius: radius,
            startAngle: startAngle,
            endAngle: endAngle,
            clockwise: false
        )
        return path
    }
}
