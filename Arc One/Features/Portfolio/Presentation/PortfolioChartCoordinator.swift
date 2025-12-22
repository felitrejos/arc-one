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
        case day      // Show hours: "9AM", "12PM", "3PM"
        case week     // Show days: "Mon", "Tue", "Wed"
        case month    // Show dates: "Dec 1", "Dec 8", "Dec 15"
        case year     // Show months: "Jan", "Feb", "Mar"
    }
    
    private let dates: [Date]
    private let formatter: DateFormatter
    
    init(dates: [Date], rangeType: RangeType) {
        self.dates = dates
        self.formatter = DateFormatter()
        
        switch rangeType {
        case .day:
            formatter.dateFormat = "ha"  // "9AM", "3PM"
        case .week:
            formatter.dateFormat = "EEE" // "Mon", "Tue"
        case .month:
            formatter.dateFormat = "MMM d" // "Dec 1"
        case .year:
            formatter.dateFormat = "MMM" // "Jan", "Feb"
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
    private var currentRangeType: ChartXAxisFormatter.RangeType = .day
    
    /// Stored percent for placeholder charts (so hover doesn't show 0%)
    private var storedPercent: Double?
    private var isPlaceholder: Bool = false

    /// Called when user hovers/taps on chart. Provides (equity, percentChange).
    var onHeaderUpdate: ((Double, Double) -> Void)?

    private weak var chartView: LineChartView?

    func attach(to chartView: LineChartView) {
        self.chartView = chartView
        chartView.delegate = self
        setupChartAppearance(chartView)
    }

    /// Set chart with real data points
    func setChartData(_ dataPoints: [ChartDataPoint], rangeType: ChartXAxisFormatter.RangeType) {
        guard let chartView else { return }
        
        currentRangeType = rangeType
        currentDataPoints = dataPoints
        baselineEquity = dataPoints.first?.equityUSD ?? 0
        isPlaceholder = false
        storedPercent = nil

        configureXAxis(chartView: chartView, dates: dataPoints.map { $0.date }, rangeType: rangeType)
        renderChart(on: chartView, equities: dataPoints.map { $0.equityUSD })
    }
    
    /// Set chart with placeholder data (flat line) but proper X-axis labels
    /// - Parameters:
    ///   - currentEquity: The current portfolio value
    ///   - percent: The real percent change to display when hovering
    ///   - rangeType: The time range for X-axis formatting
    func setPlaceholderChart(currentEquity: Double, percent: Double, rangeType: ChartXAxisFormatter.RangeType) {
        guard let chartView else { return }
        
        currentRangeType = rangeType
        isPlaceholder = true
        storedPercent = percent
        
        let dates = generateDateRange(for: rangeType)
        let equities = Array(repeating: currentEquity, count: dates.count)
        
        currentDataPoints = zip(dates, equities).map { ChartDataPoint(date: $0, equityUSD: $1) }
        baselineEquity = currentEquity

        configureXAxis(chartView: chartView, dates: dates, rangeType: rangeType)
        renderChart(on: chartView, equities: equities, overridePositive: percent >= 0)
    }
    
    /// Set chart for 1D view showing daily change (open → current)
    func setDayChart(currentEquity: Double, percent: Double) {
        guard let chartView else { return }
        
        currentRangeType = .day
        isPlaceholder = false
        storedPercent = percent
        
        let calendar = Calendar.current
        let now = Date()
        let currentHour = calendar.component(.hour, from: now)
        
        // Market hours: 9AM - 10PM local time
        // If outside market hours, show full day (9AM-10PM)
        // If during market hours, show 9AM to current hour
        let isMarketOpen = currentHour >= 9 && currentHour < 22
        let endHour = isMarketOpen ? currentHour : 22
        
        let today = calendar.startOfDay(for: now)
        var dates: [Date] = []
        for hour in stride(from: 9, through: endHour, by: 1) {
            if let date = calendar.date(bySettingHour: hour, minute: 0, second: 0, of: today) {
                dates.append(date)
            }
        }
        
        guard dates.count >= 2 else {
            setPlaceholderChart(currentEquity: currentEquity, percent: percent, rangeType: .day)
            return
        }
        
        // Calculate open value: open = current / (1 + percent/100)
        let openEquity = percent == -100 ? currentEquity : currentEquity / (1 + percent / 100.0)
        
        // Create smooth progression from open to current
        var equities: [Double] = []
        for i in 0..<dates.count {
            let progress = Double(i) / Double(dates.count - 1)
            equities.append(openEquity + (currentEquity - openEquity) * progress)
        }
        
        currentDataPoints = zip(dates, equities).map { ChartDataPoint(date: $0, equityUSD: $1) }
        baselineEquity = openEquity

        configureXAxis(chartView: chartView, dates: dates, rangeType: .day)
        renderChart(on: chartView, equities: equities)
    }

    // MARK: - Private Helpers
    
    private func configureXAxis(chartView: LineChartView, dates: [Date], rangeType: ChartXAxisFormatter.RangeType) {
        let xAxis = chartView.xAxis
        xAxis.valueFormatter = ChartXAxisFormatter(dates: dates, rangeType: rangeType)
        xAxis.avoidFirstLastClippingEnabled = true
        
        // Use appropriate label count based on data points available
        let labelCount: Int
        switch rangeType {
        case .day:   labelCount = min(5, dates.count)
        case .week:  labelCount = min(7, dates.count)
        case .month: labelCount = min(5, dates.count)
        case .year:  labelCount = min(6, dates.count)
        }
        xAxis.setLabelCount(labelCount, force: false)
    }
    
    private func renderChart(on chartView: LineChartView, equities: [Double], overridePositive: Bool? = nil) {
        guard let first = equities.first, first != 0 else {
            let entries = equities.indices.map { ChartDataEntry(x: Double($0), y: 0) }
            applyChartData(on: chartView, entries: entries, isPositive: overridePositive ?? true)
            return
        }

        let percentSeries = equities.map { (($0 - first) / first) * 100.0 }
        let entries = percentSeries.enumerated().map { ChartDataEntry(x: Double($0.offset), y: $0.element) }
        let isPositive = overridePositive ?? ((percentSeries.last ?? 0) >= 0)
        
        applyChartData(on: chartView, entries: entries, isPositive: isPositive)
    }
    
    /// Generate date range for placeholder charts
    private func generateDateRange(for rangeType: ChartXAxisFormatter.RangeType) -> [Date] {
        let calendar = Calendar.current
        let now = Date()
        
        switch rangeType {
        case .day:
            // Market hours: 9AM to 9PM (13 hours, every hour)
            var dates: [Date] = []
            let today = calendar.startOfDay(for: now)
            for hour in stride(from: 9, through: 21, by: 1) {
                if let date = calendar.date(bySettingHour: hour, minute: 0, second: 0, of: today) {
                    dates.append(date)
                }
            }
            return dates
            
        case .week:
            // Last 7 days
            return (0..<7).reversed().compactMap { calendar.date(byAdding: .day, value: -$0, to: now) }
            
        case .month:
            // Last 30 days
            return (0..<30).reversed().compactMap { calendar.date(byAdding: .day, value: -$0, to: now) }
            
        case .year:
            // Last 12 months (first day of each month)
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

        let right = chartView.rightAxis
        right.enabled = true
        right.drawGridLinesEnabled = true
        right.drawAxisLineEnabled = false
        right.labelTextColor = .secondaryLabel
        right.labelFont = .systemFont(ofSize: 11)
        right.valueFormatter = DefaultAxisValueFormatter { value, _ in
            String(format: "%.1f%%", value)
        }

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
        set.lineWidth = 3
        set.drawCirclesEnabled = false
        set.drawValuesEnabled = false

        let lineColor: UIColor = isPositive ? .systemGreen : .systemRed
        set.setColor(lineColor)

        set.drawFilledEnabled = true
        let gradient = CGGradient(
            colorsSpace: CGColorSpaceCreateDeviceRGB(),
            colors: [lineColor.withAlphaComponent(0.25).cgColor, lineColor.withAlphaComponent(0.0).cgColor] as CFArray,
            locations: [0.0, 1.0]
        )!
        set.fill = LinearGradientFill(gradient: gradient, angle: 90)

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
        
        // For placeholder charts, use the stored real percent
        let pct: Double
        if isPlaceholder, let stored = storedPercent {
            pct = stored
        } else {
            pct = baselineEquity == 0 ? 0 : ((equity - baselineEquity) / baselineEquity) * 100.0
        }
        
        onHeaderUpdate?(equity, pct)
    }

    func chartValueNothingSelected(_ chartView: ChartViewBase) {
        guard let last = currentDataPoints.last else { return }
        
        // For placeholder charts, use the stored real percent
        let pct: Double
        if isPlaceholder, let stored = storedPercent {
            pct = stored
        } else {
            pct = baselineEquity == 0 ? 0 : ((last.equityUSD - baselineEquity) / baselineEquity) * 100.0
        }
        
        onHeaderUpdate?(last.equityUSD, pct)
    }
}
