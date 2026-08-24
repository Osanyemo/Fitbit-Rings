import SwiftUI

enum DashboardDesign {
    enum Spacing {
        static let compact: CGFloat = 8
        static let standard: CGFloat = 12
        static let section: CGFloat = 22
        static let screen: CGFloat = 20
    }

    enum Radius {
        static let card: CGFloat = 24
        static let compactCard: CGFloat = 18
    }

    static let minimumControlSize: CGFloat = 44
    static let minimumCardWidth: CGFloat = 156
}

enum DashboardContentState: Equatable {
    case initialLoading
    case cachedRefreshing
    case populated
    case empty
    case failed(String)

    init(section: FitnessSectionState, hasContent: Bool) {
        switch (section.phase, hasContent) {
        case (.loading, true):
            self = .cachedRefreshing
        case (.loading, false):
            self = .initialLoading
        case (.failed, false):
            self = .failed(section.errorMessage ?? String(localized: "Couldn’t load this data."))
        case (_, true):
            self = .populated
        case (.loaded, false):
            self = .empty
        case (.idle, false):
            self = .initialLoading
        }
    }
}

enum DashboardGridPolicy {
    static func usesSingleColumn(dynamicTypeSize: DynamicTypeSize, assistiveAccessEnabled: Bool) -> Bool {
        dynamicTypeSize.isAccessibilitySize || assistiveAccessEnabled
    }

    static func columns(
        dynamicTypeSize: DynamicTypeSize,
        assistiveAccessEnabled: Bool,
        spacing: CGFloat = DashboardDesign.Spacing.standard
    ) -> [GridItem] {
        if usesSingleColumn(
            dynamicTypeSize: dynamicTypeSize,
            assistiveAccessEnabled: assistiveAccessEnabled
        ) {
            return [GridItem(.flexible(), spacing: spacing, alignment: .topLeading)]
        }

        return [
            GridItem(
                .adaptive(
                    minimum: DashboardDesign.minimumCardWidth,
                    maximum: 260
                ),
                spacing: spacing,
                alignment: .topLeading
            )
        ]
    }
}

struct DashboardAdaptiveGrid<Content: View>: View {
    var spacing: CGFloat = DashboardDesign.Spacing.standard
    @ViewBuilder let content: Content

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    init(
        spacing: CGFloat = DashboardDesign.Spacing.standard,
        @ViewBuilder content: () -> Content
    ) {
        self.spacing = spacing
        self.content = content()
    }

    @ViewBuilder
    var body: some View {
        if #available(iOS 18.0, *) {
            DashboardAssistiveAdaptiveGrid(spacing: spacing) {
                content
            }
        } else {
            grid(assistiveAccessEnabled: false)
        }
    }

    private func grid(assistiveAccessEnabled: Bool) -> some View {
        LazyVGrid(
            columns: DashboardGridPolicy.columns(
                dynamicTypeSize: dynamicTypeSize,
                assistiveAccessEnabled: assistiveAccessEnabled,
                spacing: spacing
            ),
            alignment: .leading,
            spacing: spacing
        ) {
            content
        }
    }
}

@available(iOS 18.0, *)
private struct DashboardAssistiveAdaptiveGrid<Content: View>: View {
    let spacing: CGFloat
    @ViewBuilder let content: Content

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.accessibilityAssistiveAccessEnabled) private var assistiveAccessEnabled

    init(spacing: CGFloat, @ViewBuilder content: () -> Content) {
        self.spacing = spacing
        self.content = content()
    }

    var body: some View {
        LazyVGrid(
            columns: DashboardGridPolicy.columns(
                dynamicTypeSize: dynamicTypeSize,
                assistiveAccessEnabled: assistiveAccessEnabled,
                spacing: spacing
            ),
            alignment: .leading,
            spacing: spacing
        ) {
            content
        }
    }
}

struct DashboardSectionTitle: View {
    let title: LocalizedStringKey

    var body: some View {
        Text(title)
            .font(.title2.weight(.bold))
            .fixedSize(horizontal: false, vertical: true)
            .accessibilityAddTraits(.isHeader)
    }
}

struct DashboardLoadingState: View {
    let title: LocalizedStringKey

    var body: some View {
        HStack(spacing: DashboardDesign.Spacing.standard) {
            ProgressView()
                .controlSize(.regular)
                .accessibilityHidden(true)

            Text(title)
                .font(.headline)
                .fixedSize(horizontal: false, vertical: true)
        }
        .foregroundStyle(.secondary)
        .frame(maxWidth: .infinity, alignment: .leading)
        .dashboardCard(
            border: .dashboardStroke,
            radius: DashboardDesign.Radius.compactCard,
            padding: 16
        )
        .accessibilityElement(children: .combine)
    }
}

struct DashboardFailureState: View {
    let message: String
    let onRetry: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: DashboardDesign.Spacing.standard) {
            Label {
                Text("Couldn’t load this data")
                    .font(.headline.weight(.semibold))
            } icon: {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.red)
            }

            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            Button("Try Again", action: onRetry)
                .buttonStyle(.bordered)
                .controlSize(.large)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .dashboardCard(
            background: .dashboardErrorSurface,
            border: .dashboardErrorStroke,
            radius: DashboardDesign.Radius.compactCard,
            padding: 16
        )
        .accessibilityElement(children: .contain)
    }
}

enum DashboardAccessibilityFormatting {
    static func metric(value: String, unit: String) -> String {
        guard !unit.isEmpty else {
            return expandedCompactDuration(value) ?? value
        }
        return "\(value) \(expandedUnit(unit, value: value))"
    }

    static func expandedUnit(_ unit: String, value: String) -> String {
        let singular = normalizedNumericValue(value) == 1

        switch unit.lowercased() {
        case "m", "min":
            return singular ? String(localized: "minute") : String(localized: "minutes")
        case "h", "hr":
            return singular ? String(localized: "hour") : String(localized: "hours")
        case "km":
            return singular ? String(localized: "kilometer") : String(localized: "kilometers")
        case "mi":
            return singular ? String(localized: "mile") : String(localized: "miles")
        case "kcal":
            return singular ? String(localized: "kilocalorie") : String(localized: "kilocalories")
        case "bpm":
            return String(localized: "beats per minute")
        case "ms":
            return singular ? String(localized: "millisecond") : String(localized: "milliseconds")
        case "brpm":
            return String(localized: "breaths per minute")
        case "deg":
            return String(localized: "degrees")
        case "ml/kg/min":
            return String(localized: "milliliters per kilogram per minute")
        case "mg/dl":
            return String(localized: "milligrams per deciliter")
        case "/km":
            return String(localized: "per kilometer")
        case "m/s":
            return String(localized: "meters per second")
        default:
            return unit
        }
    }

    static func duration(_ seconds: TimeInterval) -> String {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = seconds >= 3_600 ? [.hour, .minute] : [.minute]
        formatter.unitsStyle = .full
        formatter.maximumUnitCount = 2
        formatter.zeroFormattingBehavior = .dropAll
        return formatter.string(from: max(0, seconds)) ?? String(localized: "Zero minutes")
    }

    private static func normalizedNumericValue(_ value: String) -> Double? {
        NumberFormatter.localizedNumber(from: value)?.doubleValue
    }

    private static func expandedCompactDuration(_ value: String) -> String? {
        let components = value.split(separator: " ")
        guard components.contains(where: { $0.hasSuffix("h") || $0.hasSuffix("m") }) else {
            return nil
        }

        return components.compactMap { component -> String? in
            if component.hasSuffix("h"), let hours = Int(component.dropLast()) {
                return "\(hours) \(hours == 1 ? "hour" : "hours")"
            }
            if component.hasSuffix("m"), let minutes = Int(component.dropLast()) {
                return "\(minutes) \(minutes == 1 ? "minute" : "minutes")"
            }
            return nil
        }.joined(separator: ", ")
    }
}

private extension NumberFormatter {
    static func localizedNumber(from value: String) -> NSNumber? {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        return formatter.number(from: value)
    }
}
