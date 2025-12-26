import UIKit
import DGCharts
import FirebaseFirestore

@MainActor
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
    private var holdingDTOs: [HoldingDTO] = []
    private var marketQuotes: [String: MarketQuote] = [:]

    private let chartCoordinator = PortfolioChartCoordinator()
    private let tableDS = PortfolioTableDataSource()

    private let portfolioService = PortfolioService()
    private var holdingsListener: ListenerRegistration?
    private let marketCoordinator = PortfolioMarketCoordinator(market: MarketDataService())
    private let snapshotService = PortfolioSnapshotService()
    private let intradayService = IntradayPointService()

    private var refreshTimer: Timer?
    private var lastMarketDailyPercent: Double = 0
    private var lastMarketEquityUSD: Double = 0
    
    /// Cached intraday points for 1D chart
    private var intradayPoints: [ChartDataPoint] = []

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Portfolio"

        styleHeader()
        updateHeader()
        setupSegmentedControl()
        setupMetricMenu()
        setupTable()
        setupChartCoordinator()

        startHoldingsListener()
        chartCoordinator.setDayPlaceholder(currentEquity: 0, percent: 0)
        
        // Cleanup old intraday points on launch
        Task { try? await intradayService.cleanupOldPoints() }
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

    private func updateHeader() {
        amountLabel.text = headerVM.amountText
        changeLabel.text = headerVM.changeText
        changeLabel.textColor = headerVM.changeColor
    }
    
    private func styleHeader() {
        amountLabel.font = .systemFont(ofSize: amountLabel.font.pointSize, weight: .bold)
        changeLabel.font = .systemFont(ofSize: changeLabel.font.pointSize, weight: .bold)
    }

    private func setupSegmentedControl() {
        rangeSegment.removeAllSegments()
        ["1D", "1W", "1M", "1Y"].enumerated().forEach { idx, title in
            rangeSegment.insertSegment(withTitle: title, at: idx, animated: false)
        }
        rangeSegment.selectedSegmentIndex = 0
        selectedRange = .day
        updateSegmentedControlFont()
        configureRefreshTimer()
    }

    private func updateSegmentedControlFont() {
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

    private func setupMetricMenu() {
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

    private func setupTable() {
        tableView.register(
            UINib(nibName: "InvestmentCell", bundle: nil),
            forCellReuseIdentifier: "investmentCustomCell"
        )
        tableView.dataSource = tableDS
        tableView.delegate = tableDS

        tableDS.holdings = holdings
        tableDS.performanceMode = performanceMode

        tableDS.onAddTapped = { [weak self] in self?.presentAddInvestment() }
        tableDS.onHoldingTapped = { [weak self] index in self?.showInvestmentDetail(at: index) }

        tableView.reloadData()
    }

    private func startHoldingsListener() {
        holdingsListener?.remove()
        guard FirebaseManager.uid != nil else { return }

        holdingsListener = portfolioService.listenHoldings { [weak self] dtos in
            guard let self else { return }

            Task { @MainActor in
                self.holdingDTOs = dtos

                // 1) Compute prices + table % (daily/sinceBuy)
                let (holdingVMs, dailyPercent, equityUSD, quotes) = await self.computeHoldings(from: dtos)
                self.lastMarketDailyPercent = dailyPercent
                self.lastMarketEquityUSD = equityUSD
                self.marketQuotes = quotes

                self.holdings = holdingVMs
                self.tableDS.holdings = holdingVMs
                self.tableView.reloadData()

                // 2) Save today's snapshot (builds history over time)
                await self.saveTodaySnapshotIfNeeded()
                
                // 3) Load persisted intraday points for 1D chart
                await self.loadIntradayPoints()

                // 4) Refresh header/chart according to selected segment
                await self.refreshHeaderAndChartForSelectedRange()
            }
        }
    }
    
    /// Compute holdings with market data, returning fallback if API fails
    private func computeHoldings(from dtos: [HoldingDTO]) async -> (vms: [HoldingViewModel], dailyPercent: Double, equityUSD: Double, quotes: [String: MarketQuote]) {
        do {
            let result = try await marketCoordinator.compute(dtos: dtos)
            return (result.holdingVMs, result.totalDailyPercent, result.totalEquityUSD, result.quotes)
        } catch {
            print("[Portfolio] Market data fetch failed: \(error)")
            let fallback = dtos.map {
                HoldingViewModel(name: $0.ticker.uppercased(), valueUSD: $0.quantity * $0.avgBuyPrice,
                                 sinceBuyChangePercent: 0, dailyChangePercent: 0, icon: nil)
            }
            return (fallback, 0, fallback.reduce(0) { $0 + $1.valueUSD }, [:])
        }
    }

    /// Save today's snapshot using current equity from quotes
    private func saveTodaySnapshotIfNeeded() async {
        guard lastMarketEquityUSD > 0 else { return }
        
        let today = PortfolioSnapshotService.utcDayStart(for: Date())
        let dayId = PortfolioSnapshotService.dayId(for: today)
        let snap = PortfolioSnapshot(dayId: dayId, dayStartUTC: today, equityUSD: lastMarketEquityUSD)
        
        do {
            try await snapshotService.upsert(snapshot: snap)
            print("[Portfolio] Saved snapshot: \(dayId) = $\(String(format: "%.2f", lastMarketEquityUSD))")
        } catch {
            print("[Portfolio] Failed to save snapshot: \(error)")
        }
    }
    
    /// Load persisted intraday points from Firestore
    private func loadIntradayPoints() async {
        do {
            let points = try await intradayService.fetchTodayPoints()
            intradayPoints = points.map { ChartDataPoint(date: $0.timestamp, equityUSD: $0.equityUSD) }
            print("[Portfolio] Loaded \(intradayPoints.count) intraday points")
        } catch {
            print("[Portfolio] Failed to load intraday points: \(error)")
            intradayPoints = []
        }
    }
    
    /// Save a new intraday point
    private func saveIntradayPoint(equity: Double) async {
        let point = IntradayPoint(timestamp: Date(), equityUSD: equity)
        do {
            try await intradayService.save(point: point)
            print("[Portfolio] Saved intraday point: \(Date()) = $\(String(format: "%.2f", equity))")
        } catch {
            print("[Portfolio] Failed to save intraday point: \(error)")
        }
    }

    private func refreshHeaderAndChartForSelectedRange() async {
        // For 1D, show daily change with accumulated points
        if selectedRange == .day {
            headerVM = PortfolioHeaderViewModel(amountUSD: lastMarketEquityUSD, changePercent: lastMarketDailyPercent)
            updateHeader()
            
            // Calculate open equity from daily percent
            let openEquity = lastMarketDailyPercent == -100 
                ? lastMarketEquityUSD 
                : lastMarketEquityUSD / (1 + lastMarketDailyPercent / 100.0)
            
            // Add current point if not already in the list
            if shouldAddNewIntradayPoint() {
                let newPoint = ChartDataPoint(date: Date(), equityUSD: lastMarketEquityUSD)
                intradayPoints.append(newPoint)
                await saveIntradayPoint(equity: lastMarketEquityUSD)
            }
            
            if intradayPoints.isEmpty {
                chartCoordinator.setDayPlaceholder(currentEquity: lastMarketEquityUSD, percent: lastMarketDailyPercent)
            } else {
                chartCoordinator.setDayChart(dataPoints: intradayPoints, openEquity: openEquity, currentPercent: lastMarketDailyPercent)
            }
            return
        }
        
        let (rangeType, days): (ChartXAxisFormatter.RangeType, Int) = {
            switch selectedRange {
            case .day:   return (.day, 1)
            case .week:  return (.week, 7)
            case .month: return (.month, 30)
            case .year:  return (.year, 365)
            }
        }()
        
        // For 1W/1M/1Y, fetch snapshots
        do {
            let snaps = try await snapshotService.fetchSnapshots(lastNDays: days)
            
            guard snaps.count > 1 else {
                let equity = snaps.first?.equityUSD ?? lastMarketEquityUSD
                headerVM = PortfolioHeaderViewModel(amountUSD: equity, changePercent: 0)
                updateHeader()
                chartCoordinator.setPlaceholderChart(currentEquity: equity, percent: 0, rangeType: rangeType)
                return
            }
            
            let dataPoints = snaps.map { ChartDataPoint(date: $0.dayStartUTC, equityUSD: $0.equityUSD) }
            let firstEquity = dataPoints.first?.equityUSD ?? 0
            let lastEquity = dataPoints.last?.equityUSD ?? lastMarketEquityUSD
            let pct = firstEquity == 0 ? 0 : ((lastEquity - firstEquity) / firstEquity) * 100.0

            headerVM = PortfolioHeaderViewModel(amountUSD: lastEquity, changePercent: pct)
            updateHeader()
            chartCoordinator.setChartData(dataPoints, rangeType: rangeType)
        } catch {
            print("[Portfolio] Failed to fetch snapshots: \(error)")
            headerVM = PortfolioHeaderViewModel(amountUSD: lastMarketEquityUSD, changePercent: 0)
            updateHeader()
            chartCoordinator.setPlaceholderChart(currentEquity: lastMarketEquityUSD, percent: 0, rangeType: rangeType)
        }
    }
    
    /// Check if we should add a new intraday point (avoid duplicates within 30 seconds)
    private func shouldAddNewIntradayPoint() -> Bool {
        guard lastMarketEquityUSD > 0 else { return false }
        guard let lastPoint = intradayPoints.last else { return true }
        
        let timeSinceLastPoint = Date().timeIntervalSince(lastPoint.date)
        return timeSinceLastPoint >= 25  // At least 25 seconds since last point
    }

    private func configureRefreshTimer() {
        refreshTimer?.invalidate()
        refreshTimer = nil

        guard selectedRange == .day else { return }

        refreshTimer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            guard let self else { return }
            Task { await self.refreshMarketData() }
        }
    }
    
    /// Refetch market data and update UI
    private func refreshMarketData() async {
        guard !holdingDTOs.isEmpty else { return }
        
        let (holdingVMs, dailyPercent, equityUSD, quotes) = await computeHoldings(from: holdingDTOs)
        lastMarketDailyPercent = dailyPercent
        lastMarketEquityUSD = equityUSD
        marketQuotes = quotes
        
        holdings = holdingVMs
        tableDS.holdings = holdingVMs
        tableView.reloadData()
        
        // For 1D: add new point and refresh chart
        if selectedRange == .day {
            headerVM = PortfolioHeaderViewModel(amountUSD: lastMarketEquityUSD, changePercent: lastMarketDailyPercent)
            updateHeader()
            
            let openEquity = lastMarketDailyPercent == -100 
                ? lastMarketEquityUSD 
                : lastMarketEquityUSD / (1 + lastMarketDailyPercent / 100.0)
            
            // Add new point
            if shouldAddNewIntradayPoint() {
                let newPoint = ChartDataPoint(date: Date(), equityUSD: lastMarketEquityUSD)
                intradayPoints.append(newPoint)
                await saveIntradayPoint(equity: lastMarketEquityUSD)
            }
            
            chartCoordinator.setDayChart(dataPoints: intradayPoints, openEquity: openEquity, currentPercent: lastMarketDailyPercent)
        } else {
            await refreshHeaderAndChartForSelectedRange()
        }
    }

    private func presentAddInvestment() {
        performSegue(withIdentifier: "showAddInvestment", sender: nil)
    }

    private func showInvestmentDetail(at index: Int) {
        guard index < holdingDTOs.count else { return }
        let dto = holdingDTOs[index]
        let vm = holdings[index]
        
        let ticker = dto.ticker.uppercased()
        let quote = marketQuotes[ticker]
        let currentPrice = quote?.currentPrice ?? dto.avgBuyPrice
        let prevClose = quote?.previousClose ?? currentPrice
        let dailyPct = prevClose == 0 ? 0 : ((currentPrice - prevClose) / prevClose) * 100
        let sinceBuyPct = vm.sinceBuyChangePercent
        
        let totalInvested = dto.avgBuyPrice * dto.quantity
        let currentValue = currentPrice * dto.quantity
        
        let detailVM = InvestmentDetailViewModel(
            id: dto.id,
            ticker: ticker,
            market: dto.market,
            image: vm.icon,
            currentPriceText: Formatters.currency.string(from: currentPrice as NSNumber) ?? "$0.00",
            dailyChangeText: Formatters.percentText(dailyPct),
            dailyChangePositive: dailyPct >= 0,
            sinceBuyText: Formatters.percentText(sinceBuyPct),
            sinceBuyPositive: sinceBuyPct >= 0,
            buyPositionText: Formatters.currency.string(from: dto.avgBuyPrice as NSNumber) ?? "$0.00",
            quantityText: String(format: "%.4f", dto.quantity),
            totalInvestedText: Formatters.currency.string(from: totalInvested as NSNumber) ?? "$0.00",
            currentValueText: Formatters.currency.string(from: currentValue as NSNumber) ?? "$0.00"
        )
        
        performSegue(withIdentifier: "showInvestmentDetail", sender: detailVM)
    }

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "showInvestmentDetail",
           let detailVC = segue.destination as? InvestmentDetailController,
           let detailVM = sender as? InvestmentDetailViewModel {
            detailVC.viewModel = detailVM
        }
    }

    private func setupChartCoordinator() {
        chartCoordinator.attach(to: chartView)

        // Update header when user hovers/taps on chart points
        chartCoordinator.onHeaderUpdate = { [weak self] equity, percent in
            guard let self else { return }
            self.headerVM = PortfolioHeaderViewModel(amountUSD: equity, changePercent: percent)
            self.updateHeader()
        }
    }
}
