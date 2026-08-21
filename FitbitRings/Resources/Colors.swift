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
    static var dashboardSurfaceRaised: Color {
        adaptiveColor(
            light: UIColor(red: 1.00, green: 1.00, blue: 1.00, alpha: 1),
            dark: UIColor(red: 0.13, green: 0.13, blue: 0.14, alpha: 1)
        )
    }
    static var dashboardSurfaceProminent: Color {
        adaptiveColor(
            light: UIColor(red: 0.98, green: 0.99, blue: 1.00, alpha: 1),
            dark: UIColor(red: 0.16, green: 0.16, blue: 0.17, alpha: 1)
        )
    }
    static var dashboardSurfaceInset: Color {
        adaptiveColor(
            light: UIColor(red: 0.91, green: 0.93, blue: 0.96, alpha: 1),
            dark: UIColor(red: 0.08, green: 0.08, blue: 0.09, alpha: 1)
        )
    }
    static var dashboardStroke: Color { Color(uiColor: .separator).opacity(0.24) }
    static var dashboardElevatedStroke: Color { Color(uiColor: .separator).opacity(0.16) }
    static var dashboardInnerHighlight: Color {
        adaptiveColor(
            light: UIColor.white.withAlphaComponent(0.70),
            dark: UIColor.white.withAlphaComponent(0.08)
        )
    }
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

enum DashboardSurfaceLevel {
    case base
    case raised
    case prominent
    case inset
}

struct DashboardBackground: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ZStack {
            Color.fitbitBackground
            LinearGradient(
                colors: [
                    .stepsRing.opacity(colorScheme == .dark ? 0.13 : 0.07),
                    .activeRing.opacity(colorScheme == .dark ? 0.08 : 0.04),
                    .clear,
                    .moveRing.opacity(colorScheme == .dark ? 0.08 : 0.04)
                ],
                startPoint: .topTrailing,
                endPoint: .bottomLeading
            )
            LinearGradient(
                colors: [
                    Color.dashboardInnerHighlight.opacity(colorScheme == .dark ? 0.42 : 0.72),
                    .clear
                ],
                startPoint: .top,
                endPoint: .center
            )
        }
        .ignoresSafeArea()
    }
}

private struct DashboardSurfaceModifier: ViewModifier {
    let level: DashboardSurfaceLevel
    let accentColor: Color?
    let isHighlighted: Bool
    let cornerRadius: CGFloat

    @Environment(\.colorScheme) private var colorScheme

    func body(content: Content) -> some View {
        content
            .background {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(surfaceColor)

                if let accentColor {
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [
                                    accentColor.opacity(isHighlighted ? 0.22 : 0.11),
                                    accentColor.opacity(isHighlighted ? 0.09 : 0.03),
                                    .clear
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                }
            }
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(
                        LinearGradient(
                            colors: [
                                Color.dashboardInnerHighlight.opacity(innerHighlightOpacity),
                                borderColor,
                                accentColor?.opacity(isHighlighted ? 0.28 : 0.12) ?? borderColor
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: level == .inset ? 0.8 : 1
                    )
            }
            .shadow(
                color: Color.black.opacity(shadowOpacity),
                radius: shadowRadius,
                x: 0,
                y: shadowY
            )
    }

    private var surfaceColor: Color {
        switch level {
        case .base:
            return .summarySurface
        case .raised:
            return .dashboardSurfaceRaised
        case .prominent:
            return .dashboardSurfaceProminent
        case .inset:
            return .dashboardSurfaceInset
        }
    }

    private var borderColor: Color {
        switch level {
        case .inset:
            return .dashboardStroke.opacity(0.60)
        default:
            return .dashboardElevatedStroke
        }
    }

    private var innerHighlightOpacity: Double {
        switch level {
        case .prominent:
            return colorScheme == .dark ? 0.54 : 0.88
        case .raised:
            return colorScheme == .dark ? 0.38 : 0.70
        default:
            return colorScheme == .dark ? 0.18 : 0.40
        }
    }

    private var shadowOpacity: Double {
        switch level {
        case .prominent:
            return colorScheme == .dark ? 0.46 : 0.13
        case .raised:
            return colorScheme == .dark ? 0.30 : 0.08
        case .base:
            return colorScheme == .dark ? 0.18 : 0.04
        case .inset:
            return 0
        }
    }

    private var shadowRadius: CGFloat {
        switch level {
        case .prominent:
            return 18
        case .raised:
            return 10
        case .base:
            return 5
        case .inset:
            return 0
        }
    }

    private var shadowY: CGFloat {
        switch level {
        case .prominent:
            return 10
        case .raised:
            return 5
        case .base:
            return 2
        case .inset:
            return 0
        }
    }
}

extension View {
    func dashboardSurface(
        level: DashboardSurfaceLevel = .raised,
        accentColor: Color? = nil,
        isHighlighted: Bool = false,
        cornerRadius: CGFloat = 8
    ) -> some View {
        modifier(
            DashboardSurfaceModifier(
                level: level,
                accentColor: accentColor,
                isHighlighted: isHighlighted,
                cornerRadius: cornerRadius
            )
        )
    }
}

struct DashboardPressButtonStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.985 : 1)
            .opacity(configuration.isPressed ? 0.82 : 1)
            .animation(pressAnimation, value: configuration.isPressed)
    }

    private var pressAnimation: Animation? {
        reduceMotion ? nil : .smooth(duration: 0.14, extraBounce: 0)
    }
}

struct DashboardProgressTrack: View {
    let progress: Double
    let accentColor: Color
    var height: CGFloat = 10

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        GeometryReader { geometry in
            let normalizedProgress = min(max(progress, 0), 1)
            let width = normalizedProgress > 0
                ? max(height, geometry.size.width * normalizedProgress)
                : 0

            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.dashboardSurfaceInset)
                    .overlay {
                        Capsule()
                            .stroke(Color.dashboardInnerHighlight.opacity(0.22), lineWidth: 1)
                    }

                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [
                                accentColor.opacity(0.68),
                                accentColor,
                                Color.white.opacity(0.52)
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: width)
                    .shadow(color: accentColor.opacity(0.24), radius: 6, x: 0, y: 2)
                    .animation(progressAnimation, value: normalizedProgress)
            }
        }
        .frame(height: height)
    }

    private var progressAnimation: Animation? {
        reduceMotion ? nil : .smooth(duration: 0.36, extraBounce: 0)
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
