import Accessibility
import Charts
import SwiftUI

struct MetricTimeChart: View {
    enum Mode {
        case compact
        case full
    }

    let points: [NumericMetricPoint]
    let color: Color
    var range: MetricChartRange?
    var rangeStart: Date?
    var rangeEnd: Date?
    var mode: Mode
    var style: MetricChartStyle
    var title = String(localized: "Metric history")
    var rangeDescription = String(localized: "Recorded values over time")
    var axisLabel: (Double) -> String = { value in
        DashboardFormatting.decimal(value, maximumFractionDigits: abs(value) >= 10 ? 0 : 1)
    }
    var accessibilityValue: (Double) -> String = { value in
        DashboardFormatting.decimal(value, maximumFractionDigits: abs(value) >= 10 ? 0 : 1)
    }

    @Environment(\.calendar) private var calendar
    @State private var selectedDate: Date?

    @ViewBuilder
    var body: some View {
        if mode == .compact {
            chart
                .chartXAxis(.hidden)
                .chartYAxis(.hidden)
                .accessibilityHidden(true)
                .allowsHitTesting(false)
        } else {
            chart
                .chartXAxis {
                    AxisMarks(values: .automatic(desiredCount: xAxisMarkCount)) { value in
                        AxisGridLine(stroke: StrokeStyle(lineWidth: 1, dash: [3, 4]))
                            .foregroundStyle(Color.dashboardStroke.opacity(0.6))
                        AxisTick()
                        AxisValueLabel {
                            if let date = value.as(Date.self) {
                                Text(xAxisLabel(for: date))
                            }
                        }
                    }
                }
                .chartYAxis {
                    AxisMarks(position: .trailing, values: .automatic(desiredCount: 3)) { value in
                        AxisGridLine(stroke: StrokeStyle(lineWidth: 1, dash: [3, 4]))
                            .foregroundStyle(Color.dashboardStroke.opacity(0.6))
                        AxisTick()
                        AxisValueLabel {
                            if let number = value.as(Double.self) {
                                Text(axisLabel(number))
                            }
                        }
                    }
                }
                .chartXSelection(value: $selectedDate)
                .accessibilityChartDescriptor(
                    MetricChartAccessibilityDescriptor(
                        title: title,
                        summary: rangeDescription,
                        points: visiblePoints,
                        valueDescription: accessibilityValue
                    )
                )
                .accessibilityLabel(title)
                .accessibilityHint("Swipe up or down to explore the chart, or drag across it to select a value.")
        }
    }

    private var chart: some View {
        Chart {
            ForEach(visiblePoints) { point in
                if style == .bar {
                    BarMark(
                        x: .value("Date", point.startDate),
                        y: .value("Value", point.value)
                    )
                    .foregroundStyle(color.gradient)
                    .cornerRadius(4)
                } else {
                    LineMark(
                        x: .value("Date", point.startDate),
                        y: .value("Value", point.value)
                    )
                    .foregroundStyle(color)
                    .lineStyle(StrokeStyle(lineWidth: mode == .full ? 3 : 2, lineCap: .round, lineJoin: .round))

                    PointMark(
                        x: .value("Date", point.startDate),
                        y: .value("Value", point.value)
                    )
                    .foregroundStyle(color)
                    .symbolSize(mode == .full ? 34 : 12)
                }
            }

            if mode == .full, let selectedPoint {
                RuleMark(x: .value("Selected date", selectedPoint.startDate))
                    .foregroundStyle(Color.primary.opacity(0.65))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))
                    .annotation(position: .top, alignment: .leading, spacing: 6) {
                        selectedValueLabel(for: selectedPoint)
                    }
            }
        }
        .chartXScale(domain: chartDomain)
        .chartYScale(domain: valueDomain)
    }

    private func selectedValueLabel(for point: NumericMetricPoint) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(accessibilityValue(point.value))
                .font(.caption.weight(.bold).monospacedDigit())
            Text(xAxisLabel(for: point.startDate))
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .accessibilityElement(children: .combine)
    }

    private var visiblePoints: [NumericMetricPoint] {
        mode == .compact ? Array(points.suffix(24)) : points
    }

    private var selectedPoint: NumericMetricPoint? {
        guard let selectedDate else { return nil }
        return visiblePoints.min {
            abs($0.startDate.timeIntervalSince(selectedDate)) < abs($1.startDate.timeIntervalSince(selectedDate))
        }
    }

    private var chartDomain: ClosedRange<Date> {
        let start = rangeStart ?? visiblePoints.first?.startDate ?? .now
        let candidateEnd = rangeEnd
            ?? visiblePoints.last?.endDate
            ?? visiblePoints.last?.startDate
            ?? start.addingTimeInterval(1)
        let end = candidateEnd > start ? candidateEnd : start.addingTimeInterval(1)
        return start...end
    }

    private var valueDomain: ClosedRange<Double> {
        guard let minimum = visiblePoints.map(\.value).min(),
              let maximum = visiblePoints.map(\.value).max() else {
            return 0...1
        }

        if style == .bar {
            return 0...max(maximum, 1)
        }

        guard maximum > minimum else {
            return (minimum - 1)...(maximum + 1)
        }

        let padding = (maximum - minimum) * 0.12
        return (minimum - padding)...(maximum + padding)
    }

    private var xAxisMarkCount: Int {
        switch range {
        case .day:
            return 4
        case .week:
            return 7
        case .month:
            return 5
        case .year:
            return 6
        case nil:
            return 4
        }
    }

    private func xAxisLabel(for date: Date) -> String {
        switch range {
        case .day:
            return date.formatted(.dateTime.hour().minute())
        case .week:
            return date.formatted(.dateTime.weekday(.abbreviated))
        case .month:
            return date.formatted(.dateTime.day())
        case .year:
            return date.formatted(.dateTime.month(.abbreviated))
        case nil:
            return DashboardFormatting.compactDayLabel(for: date, calendar: calendar)
        }
    }
}

struct MetricChartAccessibilityDescriptor: AXChartDescriptorRepresentable {
    let title: String
    let summary: String
    let points: [NumericMetricPoint]
    let valueDescription: (Double) -> String

    func makeChartDescriptor() -> AXChartDescriptor {
        let categories = points.map { point in
            point.startDate.formatted(
                .dateTime.year().month(.wide).day().hour().minute()
            )
        }
        let values = points.map(\.value)
        let lowerBound = values.min() ?? 0
        let upperBound = values.max() ?? 1
        let resolvedRange = upperBound > lowerBound
            ? lowerBound...upperBound
            : (lowerBound - 1)...(upperBound + 1)

        let xAxis = AXCategoricalDataAxisDescriptor(
            title: String(localized: "Date and time"),
            categoryOrder: categories
        )
        let yAxis = AXNumericDataAxisDescriptor(
            title: String(localized: "Value"),
            range: resolvedRange,
            gridlinePositions: [],
            valueDescriptionProvider: valueDescription
        )
        let dataPoints = zip(categories, points).map { category, point in
            AXDataPoint(
                x: category,
                y: point.value,
                label: "\(category), \(valueDescription(point.value))"
            )
        }
        let dataSeries = AXDataSeriesDescriptor(
            name: title,
            isContinuous: true,
            dataPoints: dataPoints
        )

        return AXChartDescriptor(
            title: title,
            summary: summary,
            xAxis: xAxis,
            yAxis: yAxis,
            series: [dataSeries]
        )
    }
}
