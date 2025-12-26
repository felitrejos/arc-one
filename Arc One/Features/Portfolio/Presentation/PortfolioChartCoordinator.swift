import UIKit
import DGCharts

struct ChartDataPoint {
    let date: Date
    let equityUSD: Double
}

final class DayChartXAxisFormatter: AxisValueFormatter {
    
    private let fixedTimes: [Date]
    private let formatter: DateFormatter
    
    init(today: Date) {
        let calendar = Calendar.current
        let dayStart = calendar.startOfDay(for: today)
        
        // Fixed labels: 3:30pm, 5pm, 6:30pm, 8pm, 10pm
        let labelMinutes = [15*60+30, 17*60, 18*60+30, 20*60, 22*60] 
        self.fixedTimes = labelMinutes.compactMap {
            calendar.date(byAdding: .minute, value: $0, to: dayStart)
        }
        
        self.formatter = DateFormatter()
        self.formatter.dateFormat = "h:mm"
    }
    
    func stringForValue(_ value: Double, axis: AxisBase?) -> String {
        let minutesFromStart = value
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        
        guard let time = calendar.date(byAdding: .minute, value: Int(15*60 + 30 + minutesFromStart), to: today) else {
            return ""
        }
        
        return formatter.string(from: time)
    }
}

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

final class PortfolioChartCoordinator: NSObject, ChartViewDelegate {

    private var currentDataPoints: [ChartDataPoint] = []
    private var baselineEquity: Double = 0
    private var storedPercent: Double?
    
    private let dayStartMinutes: Double = 15 * 60 + 30
    private let dayEndMinutes: Double = 22 * 60
    private var dayTotalMinutes: Double { dayEndMinutes - dayStartMinutes }

    var onHeaderUpdate: ((Double, Double) -> Void)?
    private weak var chartView: LineChartView?

    func attach(to chartView: LineChartView) {
        self.chartView = chartView
        chartView.delegate = self
        setupChartAppearance(chartView)
    }
    
    func setDayChart(dataPoints: [ChartDataPoint], openEquity: Double, currentPercent: Double) {
        guard let chartView else { return }
        
        currentDataPoints = dataPoints
        baselineEquity = openEquity
        storedPercent = currentPercent
        
        configureDayXAxis(chartView: chartView)
        renderDayChart(on: chartView, dataPoints: dataPoints, openEquity: openEquity)
    }
    
    func setDayPlaceholder(currentEquity: Double, percent: Double) {
        guard let chartView else { return }
        
        storedPercent = percent
        baselineEquity = percent == -100 ? currentEquity : currentEquity / (1 + percent / 100.0)
        currentDataPoints = []
        
        configureDayXAxis(chartView: chartView)
        
        // Just configure axes with no data
        let right = chartView.rightAxis
        right.axisMinimum = -3.0
        right.axisMaximum = 3.0
        
        chartView.data = nil
        chartView.notifyDataSetChanged()
    }

    func setChartData(_ dataPoints: [ChartDataPoint], rangeType: ChartXAxisFormatter.RangeType) {
        guard let chartView, !dataPoints.isEmpty else { return }
        
        currentDataPoints = dataPoints
        baselineEquity = dataPoints.first?.equityUSD ?? 0
        storedPercent = nil

        configureStandardXAxis(chartView: chartView, dates: dataPoints.map { $0.date }, rangeType: rangeType)
        renderStandardChart(on: chartView, equities: dataPoints.map { $0.equityUSD })
    }
    
    func setPlaceholderChart(currentEquity: Double, percent: Double, rangeType: ChartXAxisFormatter.RangeType) {
        guard let chartView else { return }
        
        storedPercent = percent
        let dates = generateFixedDateRange(for: rangeType)
        let equities = Array(repeating: currentEquity, count: dates.count)
        
        currentDataPoints = zip(dates, equities).map { ChartDataPoint(date: $0, equityUSD: $1) }
        baselineEquity = currentEquity

        configureStandardXAxis(chartView: chartView, dates: dates, rangeType: rangeType)
        renderStandardChart(on: chartView, equities: equities, overridePositive: percent >= 0)
    }

    private func configureDayXAxis(chartView: LineChartView) {
        let xAxis = chartView.xAxis
        xAxis.valueFormatter = DayChartXAxisFormatter(today: Date())
        xAxis.avoidFirstLastClippingEnabled = true
        xAxis.axisMinimum = 0
        xAxis.axisMaximum = dayTotalMinutes  // 390 minutes (3:30pm to 10pm)
        xAxis.setLabelCount(5, force: true)
    }
    
    private func configureStandardXAxis(chartView: LineChartView, dates: [Date], rangeType: ChartXAxisFormatter.RangeType) {
        let xAxis = chartView.xAxis
        xAxis.valueFormatter = ChartXAxisFormatter(dates: dates, rangeType: rangeType)
        xAxis.avoidFirstLastClippingEnabled = true
        xAxis.resetCustomAxisMin()
        xAxis.resetCustomAxisMax()
        
        let labelCount: Int
        switch rangeType {
        case .day:   labelCount = 5
        case .week:  labelCount = 7
        case .month: labelCount = 5
        case .year:  labelCount = 6
        }
        xAxis.setLabelCount(labelCount, force: false)
    }

    private func renderDayChart(on chartView: LineChartView, dataPoints: [ChartDataPoint], openEquity: Double) {
        guard openEquity != 0, !dataPoints.isEmpty else {
            chartView.data = nil
            return
        }
        
        let calendar = Calendar.current
        
        var entries: [ChartDataEntry] = []
        
        for point in dataPoints {
            let components = calendar.dateComponents([.hour, .minute], from: point.date)
            let pointMinutes = Double(components.hour ?? 0) * 60 + Double(components.minute ?? 0)
            let xValue = pointMinutes - dayStartMinutes
            
            guard xValue >= 0, xValue <= dayTotalMinutes else { continue }
            
            let percentFromOpen = ((point.equityUSD - openEquity) / openEquity) * 100.0
            entries.append(ChartDataEntry(x: xValue, y: percentFromOpen))
        }
        
        guard !entries.isEmpty else {
            chartView.data = nil
            return
        }
        
        let maxPercent = entries.map { abs($0.y) }.max() ?? 0
        let yRange = max(maxPercent * 1.3, 3.0)
        
        let right = chartView.rightAxis
        right.axisMinimum = -yRange
        right.axisMaximum = yRange
        
        let isPositive = (entries.last?.y ?? 0) >= 0
        applyChartData(on: chartView, entries: entries, isPositive: isPositive)
    }
    
    private func renderStandardChart(on chartView: LineChartView, equities: [Double], overridePositive: Bool? = nil) {
        guard let first = equities.first, first != 0 else {
            let entries = equities.indices.map { ChartDataEntry(x: Double($0), y: 0) }
            applyChartData(on: chartView, entries: entries, isPositive: true)
            return
        }

        let percentSeries = equities.map { (($0 - first) / first) * 100.0 }
        let entries = percentSeries.enumerated().map { ChartDataEntry(x: Double($0.offset), y: $0.element) }
        let isPositive = overridePositive ?? ((percentSeries.last ?? 0) >= 0)
        
        chartView.rightAxis.resetCustomAxisMin()
        chartView.rightAxis.resetCustomAxisMax()
        
        applyChartData(on: chartView, entries: entries, isPositive: isPositive)
    }
    
    private func generateFixedDateRange(for rangeType: ChartXAxisFormatter.RangeType) -> [Date] {
        let calendar = Calendar.current
        let now = Date()
        let today = calendar.startOfDay(for: now)
        
        switch rangeType {
        case .day:
            return []
            
        case .week:
            return (0..<7).reversed().compactMap { calendar.date(byAdding: .day, value: -$0, to: today) }
            
        case .month:
            return (0..<30).reversed().compactMap { calendar.date(byAdding: .day, value: -$0, to: today) }
            
        case .year:
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
        right.drawGridLinesEnabled = false
        right.drawAxisLineEnabled = false
        right.drawLabelsEnabled = true
        right.labelTextColor = .secondaryLabel
        right.labelFont = .systemFont(ofSize: 11)
        right.valueFormatter = PercentAxisFormatter()
        
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
        set.mode = .linear  // Straight lines to connect gaps
        set.lineWidth = 2.5
        set.drawCirclesEnabled = false
        set.drawValuesEnabled = false
        set.drawFilledEnabled = false
        set.setColor(isPositive ? .systemGreen : .systemRed)

        set.highlightEnabled = true
        set.highlightColor = .tertiaryLabel
        set.highlightLineWidth = 1
        set.drawHorizontalHighlightIndicatorEnabled = false

        chartView.data = LineChartData(dataSet: set)
        chartView.animate(xAxisDuration: 0.2)
    }

    func chartValueSelected(_ chartView: ChartViewBase, entry: ChartDataEntry, highlight: Highlight) {
        let equity: Double
        let pct: Double
        
        if let point = currentDataPoints.first(where: { point in
            let calendar = Calendar.current
            let components = calendar.dateComponents([.hour, .minute], from: point.date)
            let pointMinutes = Double(components.hour ?? 0) * 60 + Double(components.minute ?? 0)
            return abs((pointMinutes - dayStartMinutes) - entry.x) < 1
        }) {
            equity = point.equityUSD
            pct = baselineEquity == 0 ? 0 : ((equity - baselineEquity) / baselineEquity) * 100.0
        } else {
            let index = Int(round(entry.x))
            guard index >= 0, index < currentDataPoints.count else { return }
            equity = currentDataPoints[index].equityUSD
            pct = storedPercent ?? (baselineEquity == 0 ? 0 : ((equity - baselineEquity) / baselineEquity) * 100.0)
        }
        
        onHeaderUpdate?(equity, pct)
    }

    func chartValueNothingSelected(_ chartView: ChartViewBase) {
        guard let last = currentDataPoints.last else { return }
        let pct = storedPercent ?? (baselineEquity == 0 ? 0 : ((last.equityUSD - baselineEquity) / baselineEquity) * 100.0)
        onHeaderUpdate?(last.equityUSD, pct)
    }
}

private final class PercentAxisFormatter: AxisValueFormatter {
    func stringForValue(_ value: Double, axis: AxisBase?) -> String {
        String(format: "%.1f%%", value)
    }
}
