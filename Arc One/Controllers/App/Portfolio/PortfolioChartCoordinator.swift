import UIKit
import DGCharts

final class PortfolioChartCoordinator: NSObject, ChartViewDelegate {

    enum ChartRange { case day, week, month, year }

    private var currentEquitySeries: [Double] = []
    private var baselineEquity: Double = 0

    var onHeaderUpdate: ((Double, Double) -> Void)?

    private weak var chartView: LineChartView?

    func attach(to chartView: LineChartView) {
        self.chartView = chartView
        chartView.delegate = self
        setupChartAppearance(chartView)
    }

    func setEquitySeries(_ equity: [Double]) {
        guard let chartView else { return }

        currentEquitySeries = equity
        baselineEquity = equity.first ?? 0

        setChartAsPercentChange(on: chartView, equitySeries: equity)

        if let last = equity.last {
            let pct = baselineEquity == 0 ? 0 : ((last - baselineEquity) / baselineEquity) * 100.0
            onHeaderUpdate?(last, pct)
        }
    }

    private func setupChartAppearance(_ chartView: LineChartView) {
        chartView.chartDescription.enabled = false
        chartView.legend.enabled = false

        chartView.dragEnabled = true
        chartView.pinchZoomEnabled = false
        chartView.doubleTapToZoomEnabled = false

        chartView.leftAxis.enabled = false

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
        xAxis.setLabelCount(4, force: false)

        chartView.drawGridBackgroundEnabled = false
        chartView.highlightPerTapEnabled = true
        chartView.highlightPerDragEnabled = true
    }

    private func setChartAsPercentChange(on chartView: LineChartView, equitySeries: [Double]) {
        guard let first = equitySeries.first, first != 0 else {
            let entries = (0..<max(equitySeries.count, 5)).map { ChartDataEntry(x: Double($0), y: 0) }
            applyChartData(on: chartView, entries: entries, isPositive: true)
            return
        }

        let percentSeries = equitySeries.map { (($0 - first) / first) * 100.0 }
        let entries = percentSeries.enumerated().map { ChartDataEntry(x: Double($0.offset), y: $0.element) }

        let isPositive = (percentSeries.last ?? 0) >= 0
        applyChartData(on: chartView, entries: entries, isPositive: isPositive)
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
        let top = lineColor.withAlphaComponent(0.25).cgColor
        let bottom = lineColor.withAlphaComponent(0.0).cgColor

        let gradient = CGGradient(
            colorsSpace: CGColorSpaceCreateDeviceRGB(),
            colors: [top, bottom] as CFArray,
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

    func chartValueSelected(_ chartView: ChartViewBase, entry: ChartDataEntry, highlight: Highlight) {
        let index = Int(round(entry.x))
        guard index >= 0, index < currentEquitySeries.count else { return }

        let equity = currentEquitySeries[index]
        let pct = baselineEquity == 0 ? 0 : ((equity - baselineEquity) / baselineEquity) * 100.0
        onHeaderUpdate?(equity, pct)
    }

    func chartValueNothingSelected(_ chartView: ChartViewBase) {
        guard let last = currentEquitySeries.last else { return }
        let pct = baselineEquity == 0 ? 0 : ((last - baselineEquity) / baselineEquity) * 100.0
        onHeaderUpdate?(last, pct)
    }
}
