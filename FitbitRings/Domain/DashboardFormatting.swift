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

    static func decimal(
        _ value: Double,
        minimumFractionDigits: Int = 0,
        maximumFractionDigits: Int,
        locale: Locale = .current
    ) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.locale = locale
        formatter.minimumFractionDigits = minimumFractionDigits
        formatter.maximumFractionDigits = maximumFractionDigits
        return formatter.string(from: NSNumber(value: value)) ?? "\(value)"
    }

    static func distance(_ meters: Double, unit: DistanceUnit) -> String {
        let parts = distanceParts(meters, unit: unit)
        return "\(parts.value) \(parts.unit)"
    }

    static func distanceParts(_ meters: Double, unit: DistanceUnit) -> MetricValue {
        switch unit {
        case .kilometers:
            return MetricValue(
                value: decimal(meters / 1_000, minimumFractionDigits: 2, maximumFractionDigits: 2),
                unit: "km"
            )
        case .miles:
            return MetricValue(
                value: decimal(meters / 1_609.344, minimumFractionDigits: 2, maximumFractionDigits: 2),
                unit: "mi"
            )
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
        return max(0, progress).formatted(.percent.precision(.fractionLength(0)))
    }

    static func time(_ date: Date?) -> String {
        guard let date else { return "--" }
        return compactTime(date, calendar: .current)
    }

    static func compactDayLabel(
        for date: Date,
        relativeTo now: Date = .now,
        calendar: Calendar = .current
    ) -> String {
        if calendar.isDate(date, inSameDayAs: now) {
            return "Today"
        }

        if let yesterday = calendar.date(byAdding: .day, value: -1, to: calendar.startOfDay(for: now)),
           calendar.isDate(date, inSameDayAs: yesterday) {
            return "Yesterday"
        }

        return compactCalendarDate(date, relativeTo: now, calendar: calendar)
    }

    static func compactDateTimeLabel(
        for date: Date,
        relativeTo now: Date = .now,
        calendar: Calendar = .current
    ) -> String {
        "\(compactDayLabel(for: date, relativeTo: now, calendar: calendar)), \(compactTime(date, calendar: calendar))"
    }

    static func compactRangeLabel(
        start: Date,
        end: Date,
        relativeTo now: Date = .now,
        calendar: Calendar = .current,
        treatsEndAsExclusive: Bool = false
    ) -> String {
        let displayEnd = rangeDisplayEnd(
            start: start,
            end: end,
            calendar: calendar,
            treatsEndAsExclusive: treatsEndAsExclusive
        )

        if calendar.isDate(start, inSameDayAs: displayEnd) {
            return compactDayLabel(for: start, relativeTo: now, calendar: calendar)
        }

        return [
            compactDayLabel(for: start, relativeTo: now, calendar: calendar),
            compactDayLabel(for: displayEnd, relativeTo: now, calendar: calendar)
        ].joined(separator: " - ")
    }

    static func compactRangeLabel(
        start: Date?,
        end: Date?,
        relativeTo now: Date = .now,
        calendar: Calendar = .current,
        treatsEndAsExclusive: Bool = false
    ) -> String? {
        switch (start, end) {
        case let (start?, end?):
            return compactRangeLabel(
                start: start,
                end: end,
                relativeTo: now,
                calendar: calendar,
                treatsEndAsExclusive: treatsEndAsExclusive
            )
        case let (start?, nil):
            return compactDayLabel(for: start, relativeTo: now, calendar: calendar)
        case let (nil, end?):
            return compactDayLabel(for: end, relativeTo: now, calendar: calendar)
        case (nil, nil):
            return nil
        }
    }

    static func compactDateTimeRangeLabel(
        start: Date?,
        end: Date?,
        relativeTo now: Date = .now,
        calendar: Calendar = .current
    ) -> String? {
        guard start != nil || end != nil else {
            return nil
        }

        switch (start, end) {
        case let (start?, end?):
            let startTime = compactTime(start, calendar: calendar)
            let endTime = compactTime(end, calendar: calendar)

            if calendar.isDate(start, inSameDayAs: end) {
                let day = compactDayLabel(for: start, relativeTo: now, calendar: calendar)
                return "\(day), \(startTime) - \(endTime)"
            }

            return "\(compactDateTimeLabel(for: start, relativeTo: now, calendar: calendar)) - \(compactDateTimeLabel(for: end, relativeTo: now, calendar: calendar))"
        case let (start?, nil):
            return "Starts \(compactDateTimeLabel(for: start, relativeTo: now, calendar: calendar))"
        case let (nil, end?):
            return "Ends \(compactDateTimeLabel(for: end, relativeTo: now, calendar: calendar))"
        case (nil, nil):
            return nil
        }
    }

    static func relativeUpdate(_ date: Date) -> String {
        guard date > .distantPast else { return "Not synced yet" }
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return "Updated \(formatter.localizedString(for: date, relativeTo: .now))"
    }

    static func compactUpdate(
        _ date: Date,
        relativeTo now: Date = .now,
        calendar: Calendar = .current
    ) -> String {
        let age = compactUpdateAge(date, relativeTo: now, calendar: calendar)
        return age == "Not synced" ? age : "Updated \(age)"
    }

    static func compactUpdateAge(
        _ date: Date,
        relativeTo now: Date = .now,
        calendar: Calendar = .current
    ) -> String {
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

        return compactCalendarDate(date, relativeTo: now, calendar: calendar)
    }

    private static func compactCalendarDate(
        _ date: Date,
        relativeTo now: Date,
        calendar: Calendar
    ) -> String {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.timeZone = calendar.timeZone
        formatter.locale = .current
        formatter.setLocalizedDateFormatFromTemplate(
            calendar.isDate(date, equalTo: now, toGranularity: .year)
                ? "MMMd"
                : "MMMdy"
        )
        return formatter.string(from: date)
    }

    private static func compactTime(_ date: Date, calendar: Calendar) -> String {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.timeZone = calendar.timeZone
        formatter.locale = .current
        formatter.timeStyle = .short
        formatter.dateStyle = .none
        return formatter.string(from: date)
    }

    private static func rangeDisplayEnd(
        start: Date,
        end: Date,
        calendar: Calendar,
        treatsEndAsExclusive: Bool
    ) -> Date {
        guard treatsEndAsExclusive,
              end > start,
              end == calendar.startOfDay(for: end),
              let adjustedEnd = calendar.date(byAdding: .second, value: -1, to: end) else {
            return end
        }

        return adjustedEnd
    }
}
