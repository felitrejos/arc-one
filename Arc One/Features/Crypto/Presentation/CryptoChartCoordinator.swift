import UIKit
import DGCharts

struct CryptoChartDataPoint {
    let date: Date
    let equityUSD: Double
}

final class CryptoChartXAxisFormatter: AxisValueFormatter {
    
    enum RangeType { case day, week, month, year }
    
    private let dates: [Date]
    private let formatter: DateFormatter
    
    init(dates: [Date], rangeType: RangeType) {
        self.dates = dates
        self.formatter = DateFormatter()
        
        switch rangeType {
        case .day:   formatter.dateFormat = "h:mm a"
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

final class CryptoChartCoordinator: NSObject, ChartViewDelegate {

    private var currentDataPoints: [CryptoChartDataPoint] = []
    private var baselineEquity: Double = 0
    private var storedPercent: Double?

    var onHeaderUpdate: ((Double, Double) -> Void)?
    private weak var chartView: LineChartView?

    func attach(to chartView: LineChartView) {
        self.chartView = chartView
        chartView.delegate = self
        setupChartAppearance(chartView)
    }
    
    func setDayChart(dataPoints: [CryptoChartDataPoint], openEquity: Double, currentPercent: Double) {
        guard let chartView, openEquity != 0, !dataPoints.isEmpty else { return }
        
        currentDataPoints = dataPoints
        baselineEquity = openEquity
        storedPercent = currentPercent
        
        let entries = dataPoints.enumerated().map { index, point -> ChartDataEntry in
            let percentFromOpen = ((point.equityUSD - openEquity) / openEquity) * 100.0
            return ChartDataEntry(x: Double(index), y: percentFromOpen)
        }
        
        guard !entries.isEmpty else { return }
        
        setupXAxis(chartView, dates: dataPoints.map { $0.date }, rangeType: .day)
        setupYAxis(chartView, currentPercent: currentPercent)
        applyChartData(chartView, entries: entries, isPositive: currentPercent >= 0)
    }
    
    func setDayPlaceholder(percent: Double) {
        guard let chartView else { return }
        
        currentDataPoints = []
        storedPercent = percent
        
        setupYAxis(chartView, currentPercent: percent)
        chartView.data = nil
    }
    
    func setEmptyChart(message: String) {
        guard let chartView else { return }
        
        currentDataPoints = []
        storedPercent = 0
        
        setupYAxis(chartView, currentPercent: 0)
        chartView.noDataText = message
        chartView.data = nil
    }
    
    func setChartData(_ dataPoints: [CryptoChartDataPoint], rangeType: CryptoChartXAxisFormatter.RangeType) {
        guard let chartView, !dataPoints.isEmpty else { return }
        guard let first = dataPoints.first?.equityUSD, first != 0 else { return }
        
        currentDataPoints = dataPoints
        baselineEquity = first
        storedPercent = nil

        setupXAxis(chartView, dates: dataPoints.map { $0.date }, rangeType: rangeType)
        
        let percentSeries = dataPoints.map { (($0.equityUSD - first) / first) * 100.0 }
        let entries = percentSeries.enumerated().map { ChartDataEntry(x: Double($0.offset), y: $0.element) }
        
        chartView.rightAxis.resetCustomAxisMin()
        chartView.rightAxis.resetCustomAxisMax()
        
        applyChartData(chartView, entries: entries, isPositive: (percentSeries.last ?? 0) >= 0)
    }
    
    private func setupXAxis(_ chartView: LineChartView, dates: [Date], rangeType: CryptoChartXAxisFormatter.RangeType) {
        let xAxis = chartView.xAxis
        xAxis.valueFormatter = CryptoChartXAxisFormatter(dates: dates, rangeType: rangeType)
        xAxis.resetCustomAxisMin()
        xAxis.resetCustomAxisMax()
        
        switch rangeType {
        case .day:   xAxis.setLabelCount(5, force: false)
        case .week:  xAxis.setLabelCount(7, force: false)
        case .month: xAxis.setLabelCount(5, force: false)
        case .year:  xAxis.setLabelCount(6, force: false)
        }
    }
    
    private func setupYAxis(_ chartView: LineChartView, currentPercent: Double) {
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
        set.lineWidth = 2.5
        set.drawCirclesEnabled = false
        set.drawValuesEnabled = false
        set.drawFilledEnabled = false
        set.setColor(.systemPurple) 
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
