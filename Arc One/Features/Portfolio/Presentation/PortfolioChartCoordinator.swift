import UIKit
import DGCharts

/// Data point for the chart: timestamp + equity value
struct ChartDataPoint {
    let date: Date
    let equityUSD: Double
}

/// X-axis formatter that displays appropriate labels based on the chart range
final class ChartXAxisFormatter: AxisValueFormatter {
    
    enum RangeType {
        case day, week, month, year
    }
    
    private let dates: [Date]
    private let formatter: DateFormatter
    
    init(dates: [Date], rangeType: RangeType) {
        self.dates = dates
        self.formatter = DateFormatter()
        
        switch rangeType {
        case .day:   formatter.dateFormat = "ha"
        case .week:  formatter.dateFormat = "EEE"
        case .month: formatter.dateFormat = "MMM d"
        case .year:  formatter.dateFormat = "MMM"
        }
    }
    
    func stringForValue(_ value: Double, axis: AxisBase?) -> String {
        let index = Int(round(value))
        guard index >= 0, index < dates.count else { return "" }
        return formatter.string(from: dates[index])
    }
}

// MARK: - Chart Coordinator

final class PortfolioChartCoordinator: NSObject, ChartViewDelegate {

    private var currentDataPoints: [ChartDataPoint] = []
    private var baselineEquity: Double = 0
    private var storedPercent: Double?

    var onHeaderUpdate: ((Double, Double) -> Void)?
    private weak var chartView: LineChartView?

    func attach(to chartView: LineChartView) {
        self.chartView = chartView
        chartView.delegate = self
        setupChartAppearance(chartView)
    }

    /// Set chart with real data points
    func setChartData(_ dataPoints: [ChartDataPoint], rangeType: ChartXAxisFormatter.RangeType) {
        guard let chartView, !dataPoints.isEmpty else { return }
        
        currentDataPoints = dataPoints
        baselineEquity = dataPoints.first?.equityUSD ?? 0
        storedPercent = nil

        configureXAxis(chartView: chartView, dates: dataPoints.map { $0.date }, rangeType: rangeType)
        renderChart(on: chartView, equities: dataPoints.map { $0.equityUSD })
    }
    
    /// Set placeholder (flat line) chart
    func setPlaceholderChart(currentEquity: Double, percent: Double, rangeType: ChartXAxisFormatter.RangeType) {
        guard let chartView else { return }
        
        storedPercent = percent
        let dates = generateFixedDateRange(for: rangeType)
        let equities = Array(repeating: currentEquity, count: dates.count)
        
        currentDataPoints = zip(dates, equities).map { ChartDataPoint(date: $0, equityUSD: $1) }
        baselineEquity = currentEquity

        configureXAxis(chartView: chartView, dates: dates, rangeType: rangeType)
        renderChart(on: chartView, equities: equities, overridePositive: percent >= 0)
    }
    
    /// Set 1D chart showing open → current progression
    func setDayChart(currentEquity: Double, percent: Double) {
        guard let chartView else { return }
        
        storedPercent = percent
        let dates = generateFixedDateRange(for: .day)
        
        // open = current / (1 + percent/100)
        let openEquity = percent == -100 ? currentEquity : currentEquity / (1 + percent / 100.0)
        
        // Smooth progression from open to current
        let equities = dates.indices.map { i -> Double in
            let progress = Double(i) / Double(max(dates.count - 1, 1))
            return openEquity + (currentEquity - openEquity) * progress
        }
        
        currentDataPoints = zip(dates, equities).map { ChartDataPoint(date: $0, equityUSD: $1) }
        baselineEquity = openEquity

        configureXAxis(chartView: chartView, dates: dates, rangeType: .day)
        renderChart(on: chartView, equities: equities)
    }

    // MARK: - Private
    
    private func configureXAxis(chartView: LineChartView, dates: [Date], rangeType: ChartXAxisFormatter.RangeType) {
        let xAxis = chartView.xAxis
        xAxis.valueFormatter = ChartXAxisFormatter(dates: dates, rangeType: rangeType)
        xAxis.avoidFirstLastClippingEnabled = true
        
        let labelCount: Int
        switch rangeType {
        case .day:   labelCount = 5
        case .week:  labelCount = 7
        case .month: labelCount = 5
        case .year:  labelCount = 6
        }
        xAxis.setLabelCount(labelCount, force: false)
    }
    
    private func renderChart(on chartView: LineChartView, equities: [Double], overridePositive: Bool? = nil) {
        guard let first = equities.first, first != 0 else {
            let entries = equities.indices.map { ChartDataEntry(x: Double($0), y: 0) }
            applyChartData(on: chartView, entries: entries, isPositive: true)
            return
        }

        let percentSeries = equities.map { (($0 - first) / first) * 100.0 }
        let entries = percentSeries.enumerated().map { ChartDataEntry(x: Double($0.offset), y: $0.element) }
        let isPositive = overridePositive ?? ((percentSeries.last ?? 0) >= 0)
        
        applyChartData(on: chartView, entries: entries, isPositive: isPositive)
    }
    
    /// Fixed date ranges for each period
    private func generateFixedDateRange(for rangeType: ChartXAxisFormatter.RangeType) -> [Date] {
        let calendar = Calendar.current
        let now = Date()
        let today = calendar.startOfDay(for: now)
        
        switch rangeType {
        case .day:
            // Fixed: 9AM to 10PM (every hour)
            return (9...22).compactMap { calendar.date(bySettingHour: $0, minute: 0, second: 0, of: today) }
            
        case .week:
            // Fixed: past 7 days
            return (0..<7).reversed().compactMap { calendar.date(byAdding: .day, value: -$0, to: today) }
            
        case .month:
            // Fixed: past 30 days
            return (0..<30).reversed().compactMap { calendar.date(byAdding: .day, value: -$0, to: today) }
            
        case .year:
            // Fixed: past 12 months
            return (0..<12).reversed().compactMap { calendar.date(byAdding: .month, value: -$0, to: now) }
        }
    }

    private func setupChartAppearance(_ chartView: LineChartView) {
        chartView.chartDescription.enabled = false
        chartView.legend.enabled = false
        chartView.dragEnabled = true
        chartView.pinchZoomEnabled = false
        chartView.doubleTapToZoomEnabled = false
        chartView.leftAxis.enabled = false
        chartView.drawGridBackgroundEnabled = false
        chartView.highlightPerTapEnabled = true
        chartView.highlightPerDragEnabled = true

        // Right axis: only show 0% reference line
        let right = chartView.rightAxis
        right.enabled = true
        right.drawGridLinesEnabled = false
        right.drawAxisLineEnabled = false
        right.drawLabelsEnabled = false
        
        // Add single limit line at 0%
        let zeroLine = ChartLimitLine(limit: 0)
        zeroLine.lineWidth = 1.5
        zeroLine.lineColor = .systemGray3
        zeroLine.lineDashLengths = [6, 4]
        right.removeAllLimitLines()
        right.addLimitLine(zeroLine)

        let xAxis = chartView.xAxis
        xAxis.drawGridLinesEnabled = false
        xAxis.drawAxisLineEnabled = false
        xAxis.labelPosition = .bottom
        xAxis.labelTextColor = .secondaryLabel
        xAxis.labelFont = .systemFont(ofSize: 11)
    }

    private func applyChartData(on chartView: LineChartView, entries: [ChartDataEntry], isPositive: Bool) {
        let set = LineChartDataSet(entries: entries, label: "")
        set.mode = .cubicBezier
        set.lineWidth = 2.5
        set.drawCirclesEnabled = false
        set.drawValuesEnabled = false
        set.drawFilledEnabled = false  // No gradient fill
        set.setColor(isPositive ? .systemGreen : .systemRed)

        set.highlightEnabled = true
        set.highlightColor = .tertiaryLabel
        set.highlightLineWidth = 1
        set.drawHorizontalHighlightIndicatorEnabled = false

        chartView.data = LineChartData(dataSet: set)
        chartView.animate(xAxisDuration: 0.2)
    }

    // MARK: - ChartViewDelegate

    func chartValueSelected(_ chartView: ChartViewBase, entry: ChartDataEntry, highlight: Highlight) {
        let index = Int(round(entry.x))
        guard index >= 0, index < currentDataPoints.count else { return }

        let equity = currentDataPoints[index].equityUSD
        let pct = storedPercent ?? (baselineEquity == 0 ? 0 : ((equity - baselineEquity) / baselineEquity) * 100.0)
        onHeaderUpdate?(equity, pct)
    }

    func chartValueNothingSelected(_ chartView: ChartViewBase) {
        guard let last = currentDataPoints.last else { return }
        let pct = storedPercent ?? (baselineEquity == 0 ? 0 : ((last.equityUSD - baselineEquity) / baselineEquity) * 100.0)
        onHeaderUpdate?(last.equityUSD, pct)
    }
}
