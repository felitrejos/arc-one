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
    @IBOutlet weak var investmentsStack: UIStackView!
    
    private enum Range: Int { case day = 0, week = 1, month = 2, year = 3 }

    private var selectedRange: Range = .day
    private var performanceMode: PerformanceMode = .sinceBuy

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
    private var intradayPoints: [ChartDataPoint] = []
    private var previousHoldingsCount: Int = -1  // -1 = not yet initialized

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Portfolio"

        investmentsStack.layer.cornerRadius = 14
        styleHeader()
        updateHeader()
        setupSegmentedControl()
        setupMetricMenu()
        setupTable()
        setupChartCoordinator()

        startHoldingsListener()
        chartCoordinator.setDayPlaceholder(percent: 0)
        
        // On launch: check if we need to create a snapshot from yesterday's data
        Task { await processYesterdayData() }
    }

    deinit {
        refreshTimer?.invalidate()
        holdingsListener?.remove()
    }
    
    private func processYesterdayData() async {
        do {
            // Get last intraday point from yesterday
            guard let lastPoint = try await intradayService.fetchYesterdayLastPoint() else {
                return // No old data, nothing to do
            }
            
            // Create snapshot for that day
            let snapshot = PortfolioSnapshot(date: lastPoint.timestamp, equityUSD: lastPoint.equityUSD)
            try await snapshotService.save(snapshot: snapshot)
            print("[Portfolio] Created snapshot from yesterday: \(snapshot.dayId) = $\(String(format: "%.2f", lastPoint.equityUSD))")
            
            // Delete all old intraday points 
            try await intradayService.deleteAll()
        } catch {
            print("[Portfolio] Failed to process yesterday data: \(error)")
        }
    }

    @IBAction private func rangeChanged(_ sender: UISegmentedControl) {
        updateSegmentedControlFont()
        selectedRange = Range(rawValue: sender.selectedSegmentIndex) ?? .day

        Task { await refreshHeaderAndChartForSelectedRange() }
        configureRefreshTimer()
    }

    private func updateHeader(amount: Double = 0, percent: Double = 0) {
        amountLabel.text = Formatters.currency.string(from: amount as NSNumber) ?? "$0"
        changeLabel.text = Formatters.percentText(percent)
        changeLabel.textColor = Formatters.changeColor(percent)
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
        tableView.register(UINib(nibName: "InvestmentCell", bundle: nil), forCellReuseIdentifier: "investmentCustomCell")
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
                // Detect portfolio change (holdings added/removed)
                let portfolioChanged = self.previousHoldingsCount != -1 && self.previousHoldingsCount != dtos.count
                self.previousHoldingsCount = dtos.count
                
                // Clear intraday if portfolio changed
                if portfolioChanged {
                    self.intradayPoints = []
                    try? await self.intradayService.deleteAll()
                    print("[Portfolio] Portfolio changed, cleared intraday data")
                }
                
                self.holdingDTOs = dtos

                let (holdingVMs, dailyPercent, equityUSD, quotes) = await self.computeHoldings(from: dtos)
                self.lastMarketDailyPercent = dailyPercent
                self.lastMarketEquityUSD = equityUSD
                self.marketQuotes = quotes

                self.holdings = holdingVMs
                self.tableDS.holdings = holdingVMs
                self.tableView.reloadData()
                
                if !portfolioChanged {
                    await self.loadIntradayPoints()
                }
                await self.refreshHeaderAndChartForSelectedRange()
            }
        }
    }
    
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
    
    private func loadIntradayPoints() async {
        do {
            let points = try await intradayService.fetchTodayPoints()
            intradayPoints = points.map { ChartDataPoint(date: $0.timestamp, equityUSD: $0.equityUSD) }
        } catch {
            print("[Portfolio] Failed to load intraday points: \(error)")
            intradayPoints = []
        }
    }
    
    private func saveIntradayPoint(equity: Double) async {
        let point = IntradayPoint(timestamp: Date(), equityUSD: equity)
        do {
            try await intradayService.save(point: point)
        } catch {
            print("[Portfolio] Failed to save intraday point: \(error)")
        }
    }

    private func refreshHeaderAndChartForSelectedRange() async {
        if selectedRange == .day {
            updateHeader(amount: lastMarketEquityUSD, percent: lastMarketDailyPercent)
            
            // Check if market is open
            guard isMarketOpen() else {
                chartCoordinator.setEmptyChart(message: "Market Closed")
                return
            }
            
            let openEquity = lastMarketDailyPercent == -100 
                ? lastMarketEquityUSD 
                : lastMarketEquityUSD / (1 + lastMarketDailyPercent / 100.0)
            
            if shouldAddNewIntradayPoint() {
                let newPoint = ChartDataPoint(date: Date(), equityUSD: lastMarketEquityUSD)
                intradayPoints.append(newPoint)
                await saveIntradayPoint(equity: lastMarketEquityUSD)
            }
            
            if intradayPoints.isEmpty {
                chartCoordinator.setDayPlaceholder(percent: lastMarketDailyPercent)
            } else {
                chartCoordinator.setDayChart(dataPoints: intradayPoints, openEquity: openEquity, currentPercent: lastMarketDailyPercent)
            }
            return
        }
        
        let (rangeType, days): (ChartXAxisFormatter.RangeType, Int) = {
            switch selectedRange {
            case .day:   return (.week, 1) // Won't reach here
            case .week:  return (.week, 7)
            case .month: return (.month, 30)
            case .year:  return (.year, 365)
            }
        }()
        
        do {
            let snaps = try await snapshotService.fetchSnapshots(lastNDays: days)
            
            guard snaps.count > 1 else {
                let equity = snaps.first?.equityUSD ?? lastMarketEquityUSD
                updateHeader(amount: equity, percent: 0)
                chartCoordinator.setEmptyChart(message: "No data yet")
                return
            }
            
            let dataPoints = snaps.map { ChartDataPoint(date: $0.date, equityUSD: $0.equityUSD) }
            let firstEquity = dataPoints.first?.equityUSD ?? 0
            let lastEquity = dataPoints.last?.equityUSD ?? lastMarketEquityUSD
            let pct = firstEquity == 0 ? 0 : ((lastEquity - firstEquity) / firstEquity) * 100.0

            updateHeader(amount: lastEquity, percent: pct)
            chartCoordinator.setChartData(dataPoints, rangeType: rangeType)
        } catch {
            print("[Portfolio] Failed to fetch snapshots: \(error)")
            updateHeader(amount: lastMarketEquityUSD, percent: 0)
            chartCoordinator.setEmptyChart(message: "No data yet")
        }
    }
    
    private func shouldAddNewIntradayPoint() -> Bool {
        guard lastMarketEquityUSD > 0 else { return false }
        guard isMarketOpen() else { return false }
        guard let lastPoint = intradayPoints.last else { return true }
        return Date().timeIntervalSince(lastPoint.date) >= 25
    }
    
    private func isMarketOpen() -> Bool {
        let calendar = Calendar.current
        let now = Date()
        
        // Check if it's a weekend (Saturday = 7, Sunday = 1)
        let weekday = calendar.component(.weekday, from: now)
        if weekday == 1 || weekday == 7 {
            return false
        }
        
        let components = calendar.dateComponents([.hour, .minute], from: now)
        let currentMinutes = (components.hour ?? 0) * 60 + (components.minute ?? 0)
        
        let marketOpen = 15 * 60 + 30   // 3:30pm = 930 minutes
        let marketClose = 22 * 60       // 10:00pm = 1320 minutes
        
        return currentMinutes >= marketOpen && currentMinutes <= marketClose
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
    
    private func refreshMarketData() async {
        guard !holdingDTOs.isEmpty else { return }
        
        let (holdingVMs, dailyPercent, equityUSD, quotes) = await computeHoldings(from: holdingDTOs)
        lastMarketDailyPercent = dailyPercent
        lastMarketEquityUSD = equityUSD
        marketQuotes = quotes
        
        holdings = holdingVMs
        tableDS.holdings = holdingVMs
        tableView.reloadData()
        
        if selectedRange == .day {
            updateHeader(amount: lastMarketEquityUSD, percent: lastMarketDailyPercent)
            
            let openEquity = lastMarketDailyPercent == -100 
                ? lastMarketEquityUSD 
                : lastMarketEquityUSD / (1 + lastMarketDailyPercent / 100.0)
            
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
        chartCoordinator.onHeaderUpdate = { [weak self] equity, percent in
            guard let self else { return }
            self.updateHeader(amount: equity, percent: percent)
        }
    }
}
