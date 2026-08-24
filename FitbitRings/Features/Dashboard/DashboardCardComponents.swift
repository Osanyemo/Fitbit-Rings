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
    @ScaledMetric(relativeTo: .body) private var scale: CGFloat = 1

    var body: some View {
        Image(systemName: systemImage)
            .font(.system(size: size * 0.42 * min(scale, 1.35), weight: .bold))
            .symbolRenderingMode(.hierarchical)
            .foregroundStyle(accentColor)
            .frame(width: size * min(scale, 1.25), height: size * min(scale, 1.25))
            .background(accentColor.opacity(0.15), in: Circle())
            .accessibilityHidden(true)
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
            .modifier(DashboardPressedEffect(isPressed: configuration.isPressed))
    }
}

private struct DashboardPressedEffect: ViewModifier {
    let isPressed: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @ViewBuilder
    func body(content: Content) -> some View {
        if #available(iOS 26.4, *) {
            content.modifier(
                DashboardModernPressedEffect(
                    isPressed: isPressed,
                    reduceMotion: reduceMotion
                )
            )
        } else {
            pressed(content: content, avoidsMotion: reduceMotion)
        }
    }

    private func pressed(content: Content, avoidsMotion: Bool) -> some View {
        content
            .scaleEffect(isPressed && !avoidsMotion ? 0.985 : 1)
            .opacity(isPressed ? 0.86 : 1)
            .animation(
                avoidsMotion
                    ? .easeOut(duration: 0.08)
                    : .smooth(duration: 0.16, extraBounce: 0),
                value: isPressed
            )
    }
}

@available(iOS 26.4, *)
private struct DashboardModernPressedEffect: ViewModifier {
    let isPressed: Bool
    let reduceMotion: Bool
    @Environment(\.accessibilityPrefersCrossFadeTransitions) private var prefersCrossFade

    func body(content: Content) -> some View {
        content
            .scaleEffect(isPressed && !reduceMotion && !prefersCrossFade ? 0.985 : 1)
            .opacity(isPressed ? 0.86 : 1)
            .animation(
                reduceMotion || prefersCrossFade
                    ? .easeOut(duration: 0.08)
                    : .smooth(duration: 0.16, extraBounce: 0),
                value: isPressed
            )
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
    @ScaledMetric(relativeTo: .title2) private var scaledValueFontSize: CGFloat = 30

    init(
        value: String,
        unit: String,
        valueFontSize: CGFloat = 30,
        unitFont: Font = .headline.weight(.semibold),
        valueColor: Color = .primary,
        unitColor: Color = .secondary,
        animatesValue: Bool = false
    ) {
        self.value = value
        self.unit = unit
        self.valueFontSize = valueFontSize
        self.unitFont = unitFont
        self.valueColor = valueColor
        self.unitColor = unitColor
        self.animatesValue = animatesValue
        _scaledValueFontSize = ScaledMetric(wrappedValue: valueFontSize, relativeTo: .title2)
    }

    var body: some View {
        HStack(alignment: .lastTextBaseline, spacing: 4) {
            Text(value)
                .font(.system(size: scaledValueFontSize, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(valueColor)
                .contentTransition(.numericText())
                .animation(valueAnimation, value: value)
                .lineLimit(1)
                .minimumScaleFactor(0.72)
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
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(DashboardAccessibilityFormatting.metric(value: value, unit: unit))
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
    var message: String?

    init(title: String, systemImage: String, message: String? = nil) {
        self.title = title
        self.systemImage = systemImage
        self.message = message
    }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: systemImage)
                .font(.headline.weight(.bold))
                .foregroundStyle(.secondary)
                .frame(width: 32, height: 32)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)

                if let message {
                    Text(message)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .dashboardCard(
            border: .dashboardStroke,
            radius: DashboardCardRadius.compact,
            padding: 16
        )
        .accessibilityElement(children: .combine)
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
