import Foundation

enum DashboardFormatting {
    static let integer: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 0
        return formatter
    }()

    static func integer(_ value: Double) -> String {
        integer.string(from: NSNumber(value: value.rounded())) ?? "\(Int(value.rounded()))"
    }

    static func distance(_ meters: Double, unit: DistanceUnit) -> String {
        switch unit {
        case .kilometers:
            return String(format: "%.2f km", meters / 1_000)
        case .miles:
            return String(format: "%.2f mi", meters / 1_609.344)
        }
    }

    static func duration(_ seconds: TimeInterval) -> String {
        let totalMinutes = Int(seconds / 60)
        let hours = totalMinutes / 60
        let minutes = totalMinutes % 60

        if hours > 0 {
            return "\(hours)h \(minutes)m"
        }

        return "\(minutes)m"
    }

    static func time(_ date: Date?) -> String {
        guard let date else { return "--" }
        return date.formatted(date: .omitted, time: .shortened)
    }

    static func relativeUpdate(_ date: Date) -> String {
        guard date > .distantPast else { return "Not synced yet" }
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return "Updated \(formatter.localizedString(for: date, relativeTo: .now))"
    }
}
