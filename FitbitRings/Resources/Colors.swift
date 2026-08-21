import SwiftUI

extension ShapeStyle where Self == Color {
    static var moveRing: Color { Color(red: 0.97, green: 0.33, blue: 0.27) }
    static var activeRing: Color { Color(red: 0.00, green: 0.68, blue: 0.78) }
    static var stepsRing: Color { Color(red: 0.61, green: 0.84, blue: 0.22) }
    static var fitbitBackground: Color { Color(uiColor: .systemGroupedBackground) }
    static var summarySurface: Color { Color(uiColor: .secondarySystemGroupedBackground) }
    static var dashboardMetricSurface: Color { Color(uiColor: .tertiarySystemGroupedBackground) }
    static var dashboardStroke: Color { Color(uiColor: .separator).opacity(0.18) }
    static var dashboardTintSurface: Color { Color(uiColor: .systemFill).opacity(0.32) }
    static var dashboardErrorSurface: Color { Color(uiColor: .systemRed).opacity(0.12) }
    static var dashboardErrorStroke: Color { Color(uiColor: .systemRed).opacity(0.22) }
    static var dashboardSyncSurface: Color { Color(uiColor: .systemBlue).opacity(0.10) }
    static var dashboardSyncStroke: Color { Color(uiColor: .systemBlue).opacity(0.18) }
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
