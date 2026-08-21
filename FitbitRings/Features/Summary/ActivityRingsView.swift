import SwiftUI

struct ActivityRingsView: View {
    let rings: RingSet

    var body: some View {
        ZStack {
            RingShape(progress: rings.steps.cappedProgress)
                .stroke(.stepsRing.opacity(0.18), style: stroke(width: 22))
            RingShape(progress: rings.steps.cappedProgress)
                .stroke(.stepsRing, style: stroke(width: 22))

            RingShape(progress: rings.active.cappedProgress)
                .stroke(.activeRing.opacity(0.18), style: stroke(width: 22))
                .padding(34)
            RingShape(progress: rings.active.cappedProgress)
                .stroke(.activeRing, style: stroke(width: 22))
                .padding(34)

            RingShape(progress: rings.move.cappedProgress)
                .stroke(.moveRing.opacity(0.18), style: stroke(width: 22))
                .padding(68)
            RingShape(progress: rings.move.cappedProgress)
                .stroke(.moveRing, style: stroke(width: 22))
                .padding(68)

            VStack(spacing: 6) {
                Text("\(DashboardFormatting.integer(rings.steps.value))")
                    .font(.system(size: 38, weight: .bold, design: .rounded))
                Text("steps")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
        .aspectRatio(1, contentMode: .fit)
        .padding(.horizontal, 18)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            "Move \(Int(rings.move.value)) of \(Int(rings.move.goal)) calories, Active \(Int(rings.active.value)) of \(Int(rings.active.goal)) minutes, Steps \(Int(rings.steps.value)) of \(Int(rings.steps.goal))"
        )
    }

    private func stroke(width: CGFloat) -> StrokeStyle {
        StrokeStyle(lineWidth: width, lineCap: .round, lineJoin: .round)
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
