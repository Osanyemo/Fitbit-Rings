import SwiftUI

struct DashboardCardStat: Identifiable, Hashable {
    let id: String
    let text: String
    let systemImage: String
}

struct DashboardMetricBadge: View {
    let systemImage: String
    let accentColor: Color
    var size: CGFloat = 34

    var body: some View {
        Image(systemName: systemImage)
            .font(.system(size: size * 0.42, weight: .bold))
            .symbolRenderingMode(.hierarchical)
            .foregroundStyle(accentColor)
            .frame(width: size, height: size)
            .background(accentColor.opacity(0.15), in: Circle())
    }
}

struct DashboardActionIndicator: View {
    let accentColor: Color
    var size: CGFloat = 28

    var body: some View {
        Image(systemName: "chevron.right")
            .font(.system(size: max(11, size * 0.42), weight: .bold))
            .foregroundStyle(accentColor)
            .frame(width: size, height: size)
            .background(accentColor.opacity(0.13), in: Circle())
            .overlay {
                Circle()
                    .stroke(accentColor.opacity(0.20), lineWidth: 1)
            }
            .accessibilityHidden(true)
    }
}

struct DashboardInteractiveCardButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.985 : 1)
            .opacity(configuration.isPressed ? 0.86 : 1)
            .animation(.smooth(duration: 0.16, extraBounce: 0), value: configuration.isPressed)
    }
}

struct DashboardCardValueRow: View {
    let value: String
    let unit: String
    var valueFontSize: CGFloat = 30
    var unitFont: Font = .headline.weight(.semibold)
    var valueColor: Color = .primary
    var unitColor: Color = .secondary
    var animatesValue = false

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        HStack(alignment: .lastTextBaseline, spacing: 4) {
            Text(value)
                .font(.system(size: valueFontSize, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(valueColor)
                .contentTransition(.numericText())
                .animation(valueAnimation, value: value)
                .lineLimit(1)
                .minimumScaleFactor(0.46)
                .allowsTightening(true)
                .layoutPriority(1)

            if !unit.isEmpty {
                Text(unit)
                    .font(unitFont)
                    .foregroundStyle(unitColor)
                    .lineLimit(1)
                    .minimumScaleFactor(0.62)
                    .allowsTightening(true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var valueAnimation: Animation? {
        guard animatesValue, !reduceMotion else { return nil }
        return .smooth(duration: 0.24, extraBounce: 0)
    }
}

struct DashboardCardStatRow: View {
    let stats: [DashboardCardStat]
    var minimumColumnWidth: CGFloat = 92

    private var wrappedColumns: [GridItem] {
        [
            GridItem(
                .adaptive(minimum: minimumColumnWidth),
                spacing: 12,
                alignment: .leading
            )
        ]
    }

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .firstTextBaseline, spacing: 18) {
                ForEach(stats) { stat in
                    DashboardCardStatLabel(stat: stat)
                        .fixedSize(horizontal: true, vertical: false)
                }
            }

            LazyVGrid(columns: wrappedColumns, alignment: .leading, spacing: 6) {
                ForEach(stats) { stat in
                    DashboardCardStatLabel(stat: stat)
                }
            }
        }
        .font(.caption.weight(.semibold))
        .foregroundStyle(.secondary)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct DashboardEmptyState: View {
    let title: String
    let systemImage: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: systemImage)
                .font(.headline.weight(.bold))
                .foregroundStyle(.secondary)
                .frame(width: 28, height: 28)

            Text(title)
                .font(.headline.weight(.semibold))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .dashboardCard(
            border: .dashboardStroke,
            radius: DashboardCardRadius.compact,
            padding: 16
        )
    }
}

private struct DashboardCardStatLabel: View {
    let stat: DashboardCardStat

    var body: some View {
        Label(stat.text, systemImage: stat.systemImage)
            .lineLimit(1)
            .minimumScaleFactor(0.72)
            .allowsTightening(true)
    }
}

private struct DashboardCardChrome: ViewModifier {
    let background: Color
    let border: Color
    let radius: CGFloat
    let padding: CGFloat
    let minHeight: CGFloat?
    let alignment: Alignment

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .frame(maxWidth: .infinity, minHeight: minHeight, alignment: alignment)
            .background(background, in: RoundedRectangle(cornerRadius: radius, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .stroke(border, lineWidth: 1)
            }
    }
}

extension View {
    func dashboardCard(
        background: Color = .summarySurface,
        border: Color = .dashboardStroke,
        radius: CGFloat = DashboardCardRadius.tile,
        padding: CGFloat = 14,
        minHeight: CGFloat? = nil,
        alignment: Alignment = .topLeading
    ) -> some View {
        modifier(
            DashboardCardChrome(
                background: background,
                border: border,
                radius: radius,
                padding: padding,
                minHeight: minHeight,
                alignment: alignment
            )
        )
    }
}
