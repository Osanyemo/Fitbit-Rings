import SwiftUI

struct ActivityRingsView: View {
    let rings: RingSet
    var showsCenterSummary = true
    var showsRingBadges = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        GeometryReader { geometry in
            let size = min(geometry.size.width, geometry.size.height)
            let lineWidth = ringLineWidth(for: size)
            let ringSpacing = lineWidth * 1.55

            ZStack {
                ring(
                    metric: rings.steps,
                    color: .stepsRing,
                    inset: 0,
                    lineWidth: lineWidth,
                    size: size,
                    systemImage: "arrow.up"
                )
                ring(
                    metric: rings.active,
                    color: .activeRing,
                    inset: ringSpacing,
                    lineWidth: lineWidth,
                    size: size,
                    systemImage: "chevron.right.2"
                )
                ring(
                    metric: rings.move,
                    color: .moveRing,
                    inset: ringSpacing * 2,
                    lineWidth: lineWidth,
                    size: size,
                    systemImage: "arrow.right"
                )

                if showsCenterSummary {
                    centerSummary
                }
            }
            .frame(width: size, height: size)
            .position(x: geometry.size.width / 2, y: geometry.size.height / 2)
        }
        .aspectRatio(1, contentMode: .fit)
        .frame(maxWidth: 320)
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 2)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            "Steps \(Int(rings.steps.value)) of \(Int(rings.steps.goal)), Exercise \(Int(rings.active.value)) of \(Int(rings.active.goal)) minutes, Move \(Int(rings.move.value)) of \(Int(rings.move.goal)) calories"
        )
    }

    private var centerSummary: some View {
        VStack(spacing: 4) {
            Text(DashboardFormatting.integer(rings.steps.value))
                .font(.system(.largeTitle, design: .rounded, weight: .bold))
                .monospacedDigit()
                .contentTransition(.numericText())
                .animation(progressAnimation, value: rings.steps.value)
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

    private func ring(
        metric: RingMetric,
        color: Color,
        inset: CGFloat,
        lineWidth: CGFloat,
        size: CGFloat,
        systemImage: String
    ) -> some View {
        let progress = metric.cappedProgress
        let ringPadding = inset + lineWidth / 2
        let headPosition = ActivityRingGeometry.endpoint(
            center: CGPoint(x: size / 2, y: size / 2),
            radius: ActivityRingGeometry.radius(size: size, inset: inset, lineWidth: lineWidth),
            progress: progress
        )

        return ZStack {
            RingShape(progress: 1)
                .stroke(Color.black.opacity(0.20), style: stroke(lineWidth: lineWidth + 3))
                .shadow(color: Color.black.opacity(0.12), radius: 1, x: 0, y: 1)
                .padding(ringPadding)
            RingShape(progress: 1)
                .stroke(color.opacity(0.13), style: stroke(lineWidth: lineWidth))
                .padding(ringPadding)
            RingShape(progress: 1)
                .stroke(trackHighlight, style: stroke(lineWidth: lineWidth * 0.58))
                .blendMode(.screen)
                .padding(ringPadding)
            RingShape(progress: progress)
                .stroke(
                    AngularGradient(
                        colors: [
                            color.opacity(0.72),
                            color,
                            color.opacity(0.92)
                        ],
                        center: .center,
                        startAngle: ActivityRingGeometry.startAngle,
                        endAngle: .degrees(ActivityRingGeometry.startAngle.degrees + 360)
                    ),
                    style: stroke(lineWidth: lineWidth)
                )
                .shadow(color: color.opacity(0.34), radius: lineWidth * 0.34, x: 0, y: lineWidth * 0.12)
                .shadow(color: color.opacity(0.18), radius: lineWidth * 0.16, x: 0, y: 0)
                .padding(ringPadding)

            if showsRingBadges, ActivityRingGeometry.showsProgressHead(for: progress) {
                ringHead(systemImage: systemImage, color: color, lineWidth: lineWidth)
                    .position(headPosition)
                    .transition(.scale(scale: 0.74).combined(with: .opacity))
            }
        }
        .frame(width: size, height: size)
        .drawingGroup(opaque: false, colorMode: .linear)
        .animation(progressAnimation, value: progress)
    }

    private var trackHighlight: LinearGradient {
        LinearGradient(
            colors: [
                Color.white.opacity(0.18),
                Color.white.opacity(0.02),
                Color.black.opacity(0.18)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private func ringHead(systemImage: String, color: Color, lineWidth: CGFloat) -> some View {
        ZStack {
            Circle()
                .fill(color)
            Circle()
                .fill(headHighlight)
                .blendMode(.screen)
            Image(systemName: systemImage)
                .font(.system(size: lineWidth * 0.58, weight: .black, design: .rounded))
                .symbolRenderingMode(.monochrome)
                .foregroundStyle(Color.black.opacity(0.82))
        }
        .frame(width: lineWidth * 1.42, height: lineWidth * 1.42)
        .overlay {
            Circle()
                .stroke(Color.white.opacity(0.28), lineWidth: 1)
        }
        .shadow(color: color.opacity(0.38), radius: lineWidth * 0.28, x: 0, y: lineWidth * 0.11)
        .shadow(color: Color.black.opacity(0.24), radius: lineWidth * 0.12, x: 0, y: lineWidth * 0.08)
        .accessibilityHidden(true)
    }

    private var headHighlight: LinearGradient {
        LinearGradient(
            colors: [
                Color.white.opacity(0.38),
                Color.white.opacity(0.06),
                Color.black.opacity(0.16)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private func ringLineWidth(for size: CGFloat) -> CGFloat {
        min(22, max(16, size * 0.105))
    }

    private func stroke(lineWidth: CGFloat) -> StrokeStyle {
        StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round)
    }

    private var progressAnimation: Animation? {
        reduceMotion ? nil : .smooth(duration: 0.52, extraBounce: 0)
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
        let startAngle = ActivityRingGeometry.startAngle
        let endAngle = ActivityRingGeometry.endpointAngle(for: progress)

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

enum ActivityRingGeometry {
    static let startAngle = Angle.degrees(-90)
    static let minimumVisibleProgress = 0.018

    static func clampedProgress(_ progress: Double) -> Double {
        guard progress.isFinite else { return 0 }
        return min(max(progress, 0), 1)
    }

    static func renderedProgress(for progress: Double) -> Double {
        let clamped = clampedProgress(progress)
        guard clamped > 0 else { return 0 }
        return max(clamped, minimumVisibleProgress)
    }

    static func showsProgressHead(for progress: Double) -> Bool {
        clampedProgress(progress) > 0
    }

    static func endpointAngle(for progress: Double) -> Angle {
        .degrees(startAngle.degrees + 360 * renderedProgress(for: progress))
    }

    static func radius(size: CGFloat, inset: CGFloat, lineWidth: CGFloat) -> CGFloat {
        max(0, size / 2 - inset - lineWidth / 2)
    }

    static func endpoint(center: CGPoint, radius: CGFloat, progress: Double) -> CGPoint {
        let angle = endpointAngle(for: progress).radians
        return CGPoint(
            x: center.x + radius * CGFloat(cos(angle)),
            y: center.y + radius * CGFloat(sin(angle))
        )
    }
}
