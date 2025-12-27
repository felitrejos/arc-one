import UIKit
import DGCharts

struct ChartDataPoint {
    let date: Date
    let equityUSD: Double
}

final class DayChartXAxisFormatter: AxisValueFormatter {
    
    private let formatter: DateFormatter
    
    init() {
        self.formatter = DateFormatter()
        self.formatter.dateFormat = "h:mm"
    }
    
    func stringForValue(_ value: Double, axis: AxisBase?) -> String {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        guard let time = calendar.date(byAdding: .minute, value: Int(15*60 + 30 + value), to: today) else {
            return ""
        }
        return formatter.string(from: time)
    }
}

final class ChartXAxisFormatter: AxisValueFormatter {
    
    enum RangeType { case week, month, year }
    
    private let dates: [Date]
    private let formatter: DateFormatter
    
    init(dates: [Date], rangeType: RangeType) {
        self.dates = dates
        self.formatter = DateFormatter()
        
        switch rangeType {
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
        guard let chartView, !dataPoints.isEmpty else { return }
        guard let firstEquity = dataPoints.first?.equityUSD, firstEquity != 0 else { return }
        
        currentDataPoints = dataPoints
        baselineEquity = firstEquity  // Use first point as baseline
        storedPercent = currentPercent
        
        let calendar = Calendar.current
        var entries: [ChartDataEntry] = []
        
        for point in dataPoints {
            let components = calendar.dateComponents([.hour, .minute], from: point.date)
            let pointMinutes = Double(components.hour ?? 0) * 60 + Double(components.minute ?? 0)
            let xValue = pointMinutes - dayStartMinutes
            
            guard xValue >= 0, xValue <= dayTotalMinutes else { continue }
            
            // Calculate percent from first point
            let percentFromFirst = ((point.equityUSD - firstEquity) / firstEquity) * 100.0
            entries.append(ChartDataEntry(x: xValue, y: percentFromFirst))
        }
        
        guard !entries.isEmpty else { return }
        
        // Calculate the actual percent range for Y-axis
        let lastPercent = entries.last?.y ?? 0
        setupDayAxes(chartView, currentPercent: lastPercent)
        applyChartData(chartView, entries: entries, isPositive: currentPercent >= 0)
    }
    
    func setDayPlaceholder(percent: Double) {
        guard let chartView else { return }
        
        currentDataPoints = []
        storedPercent = percent
        
        setupDayAxes(chartView, currentPercent: percent)
        chartView.data = nil
    }
    
    func setEmptyChart(message: String) {
        guard let chartView else { return }
        
        currentDataPoints = []
        storedPercent = 0
        
        setupDayAxes(chartView, currentPercent: 0)
        chartView.noDataText = message
        chartView.data = nil
    }
    
    private func setupDayAxes(_ chartView: LineChartView, currentPercent: Double) {
        let xAxis = chartView.xAxis
        xAxis.valueFormatter = DayChartXAxisFormatter()
        xAxis.axisMinimum = 0
        xAxis.axisMaximum = dayTotalMinutes
        xAxis.setLabelCount(5, force: true)
        
        let absPercent = abs(currentPercent)
        let range = max(absPercent + 2.0, 3.0)
        
        let right = chartView.rightAxis
        right.axisMinimum = -range
        right.axisMaximum = range
        right.removeAllLimitLines()
        
        let zeroLine = ChartLimitLine(limit: 0)
        zeroLine.lineWidth = 1.5
        zeroLine.lineColor = .systemGray3
        zeroLine.lineDashLengths = [6, 4]
        right.addLimitLine(zeroLine)
    }
    
    func setChartData(_ dataPoints: [ChartDataPoint], rangeType: ChartXAxisFormatter.RangeType) {
        guard let chartView, !dataPoints.isEmpty else { return }
        guard let first = dataPoints.first?.equityUSD, first != 0 else { return }
        
        currentDataPoints = dataPoints
        baselineEquity = first
        storedPercent = nil

        setupStandardXAxis(chartView, dates: dataPoints.map { $0.date }, rangeType: rangeType)
        
        let percentSeries = dataPoints.map { (($0.equityUSD - first) / first) * 100.0 }
        let entries = percentSeries.enumerated().map { ChartDataEntry(x: Double($0.offset), y: $0.element) }
        
        chartView.rightAxis.resetCustomAxisMin()
        chartView.rightAxis.resetCustomAxisMax()
        
        applyChartData(chartView, entries: entries, isPositive: (percentSeries.last ?? 0) >= 0)
    }
    
    private func setupStandardXAxis(_ chartView: LineChartView, dates: [Date], rangeType: ChartXAxisFormatter.RangeType) {
        let xAxis = chartView.xAxis
        xAxis.valueFormatter = ChartXAxisFormatter(dates: dates, rangeType: rangeType)
        xAxis.resetCustomAxisMin()
        xAxis.resetCustomAxisMax()
        
        switch rangeType {
        case .week:  xAxis.setLabelCount(7, force: false)
        case .month: xAxis.setLabelCount(5, force: false)
        case .year:  xAxis.setLabelCount(6, force: false)
        }
    }
    
    private func setupChartAppearance(_ chartView: LineChartView) {
        chartView.backgroundColor = .systemBackground
        chartView.layer.cornerRadius = 14
        chartView.layer.masksToBounds = true
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
        right.drawLabelsEnabled = false  
        right.labelTextColor = .secondaryLabel
        right.labelFont = .systemFont(ofSize: 11)
        right.valueFormatter = PercentAxisFormatter()

        let xAxis = chartView.xAxis
        xAxis.drawGridLinesEnabled = false
        xAxis.drawAxisLineEnabled = false
        xAxis.labelPosition = .bottom
        xAxis.labelTextColor = .secondaryLabel
        xAxis.labelFont = .systemFont(ofSize: 11)
        xAxis.avoidFirstLastClippingEnabled = true
    }

    private func applyChartData(_ chartView: LineChartView, entries: [ChartDataEntry], isPositive: Bool) {
        let set = LineChartDataSet(entries: entries, label: "")
        set.mode = .linear
        set.lineWidth = 4.0
        set.drawCirclesEnabled = false
        set.drawValuesEnabled = false
        set.drawFilledEnabled = false
        set.setColor(.systemGreen) 
        set.highlightEnabled = true
        set.highlightColor = .tertiaryLabel
        set.highlightLineWidth = 1
        set.drawHorizontalHighlightIndicatorEnabled = false

        chartView.data = LineChartData(dataSet: set)
        chartView.animate(xAxisDuration: 0.2)
    }

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

private final class PercentAxisFormatter: AxisValueFormatter {
    func stringForValue(_ value: Double, axis: AxisBase?) -> String {
        String(format: "%.1f%%", value)
    }
}
