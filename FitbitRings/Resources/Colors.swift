import SwiftUI

enum DashboardCardRadius {
    static let tile: CGFloat = DashboardDesign.Radius.card
    static let compact: CGFloat = DashboardDesign.Radius.compactCard
}

extension ShapeStyle where Self == Color {
    static var moveRing: Color {
        accessibleAccent(
            light: UIColor(red: 0.76, green: 0.10, blue: 0.07, alpha: 1),
            dark: UIColor(red: 1.00, green: 0.25, blue: 0.18, alpha: 1),
            highContrastLight: UIColor(red: 0.62, green: 0.04, blue: 0.02, alpha: 1),
            highContrastDark: UIColor(red: 1.00, green: 0.38, blue: 0.30, alpha: 1)
        )
    }
    static var activeRing: Color {
        accessibleAccent(
            light: UIColor(red: 0.10, green: 0.45, blue: 0.04, alpha: 1),
            dark: UIColor(red: 0.44, green: 0.94, blue: 0.16, alpha: 1),
            highContrastLight: UIColor(red: 0.05, green: 0.34, blue: 0.01, alpha: 1),
            highContrastDark: UIColor(red: 0.58, green: 1.00, blue: 0.28, alpha: 1)
        )
    }
    static var stepsRing: Color {
        accessibleAccent(
            light: UIColor(red: 0.00, green: 0.42, blue: 0.52, alpha: 1),
            dark: UIColor(red: 0.14, green: 0.84, blue: 0.92, alpha: 1),
            highContrastLight: UIColor(red: 0.00, green: 0.31, blue: 0.39, alpha: 1),
            highContrastDark: UIColor(red: 0.32, green: 0.94, blue: 1.00, alpha: 1)
        )
    }
    static var calorieAccent: Color {
        accessibleAccent(
            light: UIColor(red: 0.50, green: 0.15, blue: 0.72, alpha: 1),
            dark: UIColor(red: 0.78, green: 0.47, blue: 0.96, alpha: 1),
            highContrastLight: UIColor(red: 0.38, green: 0.08, blue: 0.58, alpha: 1),
            highContrastDark: UIColor(red: 0.88, green: 0.62, blue: 1.00, alpha: 1)
        )
    }
    static var distanceAccent: Color { Color(uiColor: .systemBlue) }
    static var sleepAccent: Color { Color(uiColor: .systemIndigo) }
    static var heartAccent: Color { Color(uiColor: .systemPink) }
    static var fitbitBackground: Color {
        adaptiveColor(
            light: .systemGroupedBackground,
            dark: .black
        )
    }
    static var activityHeaderSurface: Color {
        adaptiveColor(
            light: .systemGroupedBackground,
            dark: UIColor(red: 0.11, green: 0.11, blue: 0.12, alpha: 1)
        )
    }
    static var summarySurface: Color {
        adaptiveColor(
            light: .secondarySystemGroupedBackground,
            dark: UIColor(red: 0.12, green: 0.12, blue: 0.13, alpha: 1)
        )
    }
    static var dashboardMetricSurface: Color {
        adaptiveColor(
            light: .tertiarySystemGroupedBackground,
            dark: UIColor(red: 0.15, green: 0.15, blue: 0.16, alpha: 1)
        )
    }
    static var dashboardStroke: Color { Color(uiColor: .separator).opacity(0.38) }
    static var dashboardTintSurface: Color { Color(uiColor: .systemFill).opacity(0.52) }
    static var dashboardErrorSurface: Color { Color(uiColor: .systemRed).opacity(0.12) }
    static var dashboardErrorStroke: Color { Color(uiColor: .systemRed).opacity(0.22) }
    static var dashboardSyncSurface: Color { Color(uiColor: .systemBlue).opacity(0.10) }
    static var dashboardSyncStroke: Color { Color(uiColor: .systemBlue).opacity(0.18) }

    private static func adaptiveColor(light: UIColor, dark: UIColor) -> Color {
        Color(
            uiColor: UIColor { traits in
                traits.userInterfaceStyle == .dark ? dark : light
            }
        )
    }

    private static func accessibleAccent(
        light: UIColor,
        dark: UIColor,
        highContrastLight: UIColor,
        highContrastDark: UIColor
    ) -> Color {
        Color(
            uiColor: UIColor { traits in
                switch (traits.userInterfaceStyle, traits.accessibilityContrast) {
                case (.dark, .high):
                    return highContrastDark
                case (.dark, _):
                    return dark
                case (_, .high):
                    return highContrastLight
                default:
                    return light
                }
            }
        )
    }
}

extension AppearancePreference {
    var preferredColorScheme: ColorScheme? {
        switch self {
        case .system:
            return nil
        case .light:
            return .light
        case .dark:
            return .dark
        }
    }
}
