import Foundation

enum DashboardFormatting {
    struct MetricValue: Equatable {
        var value: String
        var unit: String
    }

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
        let parts = distanceParts(meters, unit: unit)
        return "\(parts.value) \(parts.unit)"
    }

    static func distanceParts(_ meters: Double, unit: DistanceUnit) -> MetricValue {
        switch unit {
        case .kilometers:
            return MetricValue(value: String(format: "%.2f", meters / 1_000), unit: "km")
        case .miles:
            return MetricValue(value: String(format: "%.2f", meters / 1_609.344), unit: "mi")
        }
    }

    static func duration(_ seconds: TimeInterval) -> String {
        let parts = durationParts(seconds)
        return parts.unit.isEmpty ? parts.value : "\(parts.value)\(parts.unit)"
    }

    static func durationParts(_ seconds: TimeInterval) -> MetricValue {
        let totalMinutes = Int(seconds / 60)
        let hours = totalMinutes / 60
        let minutes = totalMinutes % 60

        if hours > 0 {
            return MetricValue(value: "\(hours)h \(minutes)m", unit: "")
        }

        return MetricValue(value: "\(minutes)", unit: "m")
    }

    static func percent(_ progress: Double) -> String {
        guard progress.isFinite else { return "0%" }

        let roundedPercent = Int((max(0, progress) * 100).rounded())
        return "\(roundedPercent)%"
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

    static func compactUpdate(_ date: Date, relativeTo now: Date = .now) -> String {
        let age = compactUpdateAge(date, relativeTo: now)
        return age == "Not synced" ? age : "Updated \(age)"
    }

    static func compactUpdateAge(_ date: Date, relativeTo now: Date = .now) -> String {
        guard date > .distantPast else { return "Not synced" }

        let elapsed = max(0, now.timeIntervalSince(date))

        if elapsed < 60 {
            return "just now"
        }

        if elapsed < 3_600 {
            return "\(Int(elapsed / 60))m ago"
        }

        if elapsed < 86_400 {
            return "\(Int(elapsed / 3_600))h ago"
        }

        if elapsed < 604_800 {
            return "\(Int(elapsed / 86_400))d ago"
        }

        return date.formatted(date: .abbreviated, time: .omitted)
    }
}
