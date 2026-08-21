import SwiftUI

extension ShapeStyle where Self == Color {
    static var moveRing: Color { Color(red: 0.97, green: 0.33, blue: 0.27) }
    static var activeRing: Color { Color(red: 0.00, green: 0.68, blue: 0.78) }
    static var stepsRing: Color { Color(red: 0.61, green: 0.84, blue: 0.22) }
    static var fitbitBackground: Color { Color(uiColor: .systemGroupedBackground) }
    static var summarySurface: Color { Color(uiColor: .secondarySystemGroupedBackground) }
}
