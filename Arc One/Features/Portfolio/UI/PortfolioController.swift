import UIKit
import DGCharts
import FirebaseFirestore

final class PortfolioController: UIViewController {

    @IBOutlet private weak var amountLabel: UILabel!
    @IBOutlet private weak var changeLabel: UILabel!
    @IBOutlet private weak var rangeSegment: UISegmentedControl!
    @IBOutlet private weak var chartView: LineChartView!
    @IBOutlet private weak var tableView: UITableView!
    @IBOutlet private weak var metricButton: UIButton!

    private enum Range: Int { case day = 0, week = 1, month = 2, year = 3 }

    private var selectedRange: Range = .day
    private var performanceMode: PerformanceMode = .sinceBuy

    private var headerVM = PortfolioHeaderViewModel(amountUSD: 0, changePercent: 0)
    private var holdings: [HoldingViewModel] = []

    private let chartCoordinator = PortfolioChartCoordinator()
    private let tableDS = PortfolioTableDataSource()

    private let portfolioService = PortfolioService()
    private var holdingsListener: ListenerRegistration?

    private let marketService = MarketDataService()
    private lazy var marketCoordinator = PortfolioMarketCoordinator(market: marketService)
    private let snapshotService = PortfolioSnapshotService()

    private var refreshTimer: Timer?
    private var lastMarketDailyPercent: Double = 0
    private var lastMarketEquityUSD: Double = 0

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Portfolio"

        setupHeader()
        setupSegmentedControl()
        setupMetricMenu()
        setupTable()
        setupChartCoordinator()

        startHoldingsListener()
        chartCoordinator.setPlaceholderChart(currentEquity: 0, percent: 0, rangeType: .day)
    }

    deinit {
        refreshTimer?.invalidate()
        holdingsListener?.remove()
    }

    @IBAction private func rangeChanged(_ sender: UISegmentedControl) {
        updateSegmentedControlFont()
        selectedRange = Range(rawValue: sender.selectedSegmentIndex) ?? .day

        Task { await refreshHeaderAndChartForSelectedRange() }
        configureRefreshTimer()
    }
}

private extension PortfolioController {

    func setupHeader() {
        amountLabel.text = headerVM.amountText
        amountLabel.font = .systemFont(ofSize: amountLabel.font.pointSize, weight: .bold)

        changeLabel.text = headerVM.changeText
        changeLabel.textColor = headerVM.changeColor
        changeLabel.font = .systemFont(ofSize: changeLabel.font.pointSize, weight: .bold)
    }

    func setupSegmentedControl() {
        rangeSegment.removeAllSegments()
        ["1D", "1W", "1M", "1Y"].enumerated().forEach { idx, title in
            rangeSegment.insertSegment(withTitle: title, at: idx, animated: false)
        }
        rangeSegment.selectedSegmentIndex = 0
        selectedRange = .day
        updateSegmentedControlFont()
        configureRefreshTimer()
    }

    func updateSegmentedControlFont() {
        let normal: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 13, weight: .regular),
            .foregroundColor: UIColor.secondaryLabel
        ]
        let selected: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 13, weight: .bold),
            .foregroundColor: UIColor.label
        ]
        rangeSegment.setTitleTextAttributes(normal, for: .normal)
        rangeSegment.setTitleTextAttributes(selected, for: .selected)
    }
}

private extension PortfolioController {

    func setupMetricMenu() {
        let actions = PerformanceMode.allCases.map { mode in
            UIAction(title: mode.rawValue, state: (mode == performanceMode) ? .on : .off) { [weak self] _ in
                guard let self else { return }
                self.performanceMode = mode
                self.setupMetricMenu()

                self.tableDS.performanceMode = mode
                self.tableView.reloadData()
            }
        }

        metricButton.menu = UIMenu(children: actions)
        metricButton.showsMenuAsPrimaryAction = true
        metricButton.contentHorizontalAlignment = .trailing
        metricButton.tintColor = .secondaryLabel
        metricButton.setTitleColor(.secondaryLabel, for: .normal)

        let chevron = UIImage(
            systemName: "chevron.down",
            withConfiguration: UIImage.SymbolConfiguration(pointSize: 12, weight: .semibold)
        )

        var config = UIButton.Configuration.plain()
        config.image = chevron
        config.imagePlacement = .trailing
        config.imagePadding = 6
        config.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0)

        config.attributedTitle = AttributedString(
            performanceMode.rawValue,
            attributes: AttributeContainer([
                .font: UIFont.systemFont(ofSize: 17, weight: .semibold),
                .foregroundColor: UIColor.secondaryLabel
            ])
        )

        metricButton.configuration = config
    }
}

private extension PortfolioController {

    func setupTable() {
        tableView.register(
            UINib(nibName: "InvestmentCell", bundle: nil),
            forCellReuseIdentifier: "investmentCustomCell"
        )
        tableView.dataSource = tableDS
        tableView.delegate = tableDS

        tableDS.holdings = holdings
        tableDS.performanceMode = performanceMode

        tableDS.onAddTapped = { [weak self] in self?.presentAddInvestment() }
        tableDS.onHoldingTapped = { _ in }

        tableView.reloadData()
    }
}

private extension PortfolioController {

    func startHoldingsListener() {
        holdingsListener?.remove()
        guard FirebaseManager.uid != nil else { return }

        holdingsListener = portfolioService.listenHoldings { [weak self] dtos in
            guard let self else { return }

            Task {
                // 1) Compute prices + table % (daily/sinceBuy)
                let (holdingVMs, dailyPercent, equityUSD) = await self.computeHoldings(from: dtos)
                self.lastMarketDailyPercent = dailyPercent
                self.lastMarketEquityUSD = equityUSD

                await MainActor.run {
                    self.holdings = holdingVMs
                    self.tableDS.holdings = holdingVMs
                    self.tableView.reloadData()
                }

                // 2) Save today's snapshot (builds history over time)
                await self.saveTodaySnapshotIfNeeded()

                // 3) Refresh header/chart according to selected segment
                await self.refreshHeaderAndChartForSelectedRange()
            }
        }
    }
    
    /// Compute holdings with market data, returning fallback if API fails
    private func computeHoldings(from dtos: [HoldingDTO]) async -> (vms: [HoldingViewModel], dailyPercent: Double, equityUSD: Double) {
        do {
            let result = try await marketCoordinator.compute(dtos: dtos)
            return (result.holdingVMs, result.totalDailyPercent, result.totalEquityUSD)
        } catch {
            print("[Portfolio] Market data fetch failed: \(error)")
            let fallback = dtos.map {
                HoldingViewModel(name: $0.ticker.uppercased(), valueUSD: $0.quantity * $0.avgBuyPrice,
                                 sinceBuyChangePercent: 0, dailyChangePercent: 0, icon: nil)
            }
            return (fallback, 0, fallback.reduce(0) { $0 + $1.valueUSD })
        }
    }
}

private extension PortfolioController {

    /// Save today's snapshot using current equity from quotes
    func saveTodaySnapshotIfNeeded() async {
        guard lastMarketEquityUSD > 0 else { return }
        
        let today = PortfolioHistoryBuilder.utcDayStart(for: Date())
        let dayId = PortfolioHistoryBuilder.dayId(for: today)
        let snap = PortfolioSnapshot(dayId: dayId, dayStartUTC: today, equityUSD: lastMarketEquityUSD)
        
        do {
            try await snapshotService.upsert(snapshot: snap)
            print("[Portfolio] Saved snapshot: \(dayId) = $\(String(format: "%.2f", lastMarketEquityUSD))")
        } catch {
            print("[Portfolio] Failed to save snapshot: \(error)")
        }
    }

    func refreshHeaderAndChartForSelectedRange() async {
        let rangeType: ChartXAxisFormatter.RangeType
        let days: Int
        
        switch selectedRange {
        case .day:   rangeType = .day;   days = 1
        case .week:  rangeType = .week;  days = 7
        case .month: rangeType = .month; days = 30
        case .year:  rangeType = .year;  days = 365
        }
        
        // For 1D, show daily change
        if selectedRange == .day {
            await MainActor.run {
                headerVM = PortfolioHeaderViewModel(amountUSD: lastMarketEquityUSD, changePercent: lastMarketDailyPercent)
                setupHeader()
                chartCoordinator.setDayChart(currentEquity: lastMarketEquityUSD, percent: lastMarketDailyPercent)
            }
            return
        }
        
        // For 1W/1M/1Y, fetch snapshots
        do {
            let snaps = try await snapshotService.fetchSnapshots(lastNDays: days)
            
            if snaps.count <= 1 {
                let equity = snaps.first?.equityUSD ?? lastMarketEquityUSD
                await MainActor.run {
                    headerVM = PortfolioHeaderViewModel(amountUSD: equity, changePercent: 0)
                    setupHeader()
                    chartCoordinator.setPlaceholderChart(currentEquity: equity, percent: 0, rangeType: rangeType)
                }
                return
            }
            
            let dataPoints = snaps.map { ChartDataPoint(date: $0.dayStartUTC, equityUSD: $0.equityUSD) }
            let firstEquity = dataPoints.first?.equityUSD ?? 0
            let lastEquity = dataPoints.last?.equityUSD ?? lastMarketEquityUSD
            let pct = firstEquity == 0 ? 0 : ((lastEquity - firstEquity) / firstEquity) * 100.0

            await MainActor.run {
                headerVM = PortfolioHeaderViewModel(amountUSD: lastEquity, changePercent: pct)
                setupHeader()
                chartCoordinator.setChartData(dataPoints, rangeType: rangeType)
            }
        } catch {
            print("[Portfolio] Failed to fetch snapshots: \(error)")
            await MainActor.run {
                headerVM = PortfolioHeaderViewModel(amountUSD: lastMarketEquityUSD, changePercent: 0)
                setupHeader()
                chartCoordinator.setPlaceholderChart(currentEquity: lastMarketEquityUSD, percent: 0, rangeType: rangeType)
            }
        }
    }
}

private extension PortfolioController {

    func configureRefreshTimer() {
        refreshTimer?.invalidate()
        refreshTimer = nil

        guard selectedRange == .day else { return }

        refreshTimer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            guard let self else { return }
            Task { await self.refreshHeaderAndChartForSelectedRange() }
        }
    }
}

private extension PortfolioController {

    func presentAddInvestment() {
        let alert = UIAlertController(title: "Add investment", message: nil, preferredStyle: .alert)

        alert.addTextField { tf in
            tf.placeholder = "Ticker (e.g. NVDA)"
            tf.autocapitalizationType = .allCharacters
        }
        alert.addTextField { tf in
            tf.placeholder = "Quantity (e.g. 2.5)"
            tf.keyboardType = .decimalPad
        }
        alert.addTextField { tf in
            tf.placeholder = "Avg buy price (USD) (e.g. 120.30)"
            tf.keyboardType = .decimalPad
        }

        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "Add", style: .default) { [weak self] _ in
            guard let self else { return }

            let ticker = alert.textFields?[0].text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            let qtyStr = alert.textFields?[1].text ?? ""
            let avgStr = alert.textFields?[2].text ?? ""

            let qty = Double(qtyStr.replacingOccurrences(of: ",", with: ".")) ?? 0
            let avg = Double(avgStr.replacingOccurrences(of: ",", with: ".")) ?? 0

            guard !ticker.isEmpty, qty > 0, avg > 0 else { return }

            Task { [weak self] in
                guard let self else { return }
                try? await self.portfolioService.addHolding(ticker: ticker, quantity: qty, avgBuyPrice: avg)
            }
        })

        present(alert, animated: true)
    }
}

private extension PortfolioController {

    func setupChartCoordinator() {
        chartCoordinator.attach(to: chartView)

        // Update header when user hovers/taps on chart points
        chartCoordinator.onHeaderUpdate = { [weak self] equity, percent in
            guard let self else { return }
            self.headerVM = PortfolioHeaderViewModel(amountUSD: equity, changePercent: percent)
            self.setupHeader()
        }
    }
}
