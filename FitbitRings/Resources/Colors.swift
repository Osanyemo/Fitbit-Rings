import SwiftUI

extension ShapeStyle where Self == Color {
    static var moveRing: Color { Color(red: 1.00, green: 0.17, blue: 0.10) }
    static var activeRing: Color { Color(red: 0.42, green: 0.96, blue: 0.08) }
    static var stepsRing: Color { Color(red: 0.06, green: 0.82, blue: 0.90) }
    static var calorieAccent: Color { Color(red: 0.76, green: 0.34, blue: 0.98) }
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
    static var dashboardStroke: Color { Color(uiColor: .separator).opacity(0.24) }
    static var dashboardTintSurface: Color { Color(uiColor: .systemFill).opacity(0.40) }
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
