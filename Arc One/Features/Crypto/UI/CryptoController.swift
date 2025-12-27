import UIKit
import DGCharts
import FirebaseFirestore

@MainActor
final class CryptoController: UIViewController {

    @IBOutlet private weak var amountLabel: UILabel!
    @IBOutlet private weak var changeLabel: UILabel!
    @IBOutlet private weak var rangeSegment: UISegmentedControl!
    @IBOutlet private weak var chartView: LineChartView!
    @IBOutlet private weak var tableView: UITableView!
    @IBOutlet private weak var metricButton: UIButton!

    private enum Range: Int { case day = 0, week = 1, month = 2, year = 3 }

    private var selectedRange: Range = .day
    private var performanceMode: CryptoPerformanceMode = .sinceBuy

    private var holdings: [CryptoHoldingViewModel] = []
    private var holdingDTOs: [CryptoHoldingDTO] = []
    private var marketQuotes: [String: CryptoQuote] = [:]

    private let chartCoordinator = CryptoChartCoordinator()
    private let tableDS = CryptoTableDataSource()

    private let cryptoService = CryptoService()
    private var holdingsListener: ListenerRegistration?
    private let marketCoordinator = CryptoMarketCoordinator()
    private let snapshotService = CryptoSnapshotService()
    private let intradayService = CryptoIntradayService()

    private var refreshTimer: Timer?
    private var lastMarketDailyPercent: Double = 0
    private var lastMarketEquityUSD: Double = 0
    private var intradayPoints: [CryptoChartDataPoint] = []
    private var previousHoldingsCount: Int = -1

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Crypto"

        styleHeader()
        updateHeader()
        setupSegmentedControl()
        setupMetricMenu()
        setupTable()
        setupChartCoordinator()

        startHoldingsListener()
        chartCoordinator.setDayPlaceholder(percent: 0)
        
        Task { await processYesterdayData() }
    }

    deinit {
        refreshTimer?.invalidate()
        holdingsListener?.remove()
    }
    
    private func processYesterdayData() async {
        do {
            guard let lastPoint = try await intradayService.fetchYesterdayLastPoint() else {
                return
            }
            
            let snapshot = CryptoSnapshot(date: lastPoint.timestamp, equityUSD: lastPoint.equityUSD)
            try await snapshotService.save(snapshot: snapshot)
            print("[Crypto] Created snapshot from yesterday: \(snapshot.dayId) = $\(String(format: "%.2f", lastPoint.equityUSD))")
            
            try await intradayService.deleteAll()
        } catch {
            print("[Crypto] Failed to process yesterday data: \(error)")
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
        let actions = CryptoPerformanceMode.allCases.map { mode in
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
        tableView.register(UINib(nibName: "CryptoCell", bundle: nil), forCellReuseIdentifier: "cryptoCustomCell")
        tableView.dataSource = tableDS
        tableView.delegate = tableDS

        tableDS.holdings = holdings
        tableDS.performanceMode = performanceMode
        tableDS.onAddTapped = { [weak self] in self?.presentAddCrypto() }
        tableDS.onHoldingTapped = { [weak self] index in self?.showCryptoDetail(at: index) }

        tableView.reloadData()
    }

    private func startHoldingsListener() {
        holdingsListener?.remove()
        guard FirebaseManager.uid != nil else { return }

        holdingsListener = cryptoService.listenHoldings { [weak self] dtos in
            guard let self else { return }

            Task { @MainActor in
                let portfolioChanged = self.previousHoldingsCount != -1 && self.previousHoldingsCount != dtos.count
                self.previousHoldingsCount = dtos.count
                
                if portfolioChanged {
                    self.intradayPoints = []
                    try? await self.intradayService.deleteAll()
                }
                
                self.holdingDTOs = dtos

                let result = await self.computeHoldings(from: dtos)
                self.lastMarketDailyPercent = result.dailyPercent
                self.lastMarketEquityUSD = result.equityUSD
                self.marketQuotes = result.quotes

                self.holdings = result.vms
                self.tableDS.holdings = result.vms
                self.tableView.reloadData()
                
                if !portfolioChanged {
                    await self.loadIntradayPoints()
                }
                await self.refreshHeaderAndChartForSelectedRange()
            }
        }
    }
    
    private func computeHoldings(from dtos: [CryptoHoldingDTO]) async -> (vms: [CryptoHoldingViewModel], dailyPercent: Double, equityUSD: Double, quotes: [String: CryptoQuote]) {
        do {
            let result = try await marketCoordinator.compute(dtos: dtos)
            return (result.holdingVMs, result.totalDailyPercent, result.totalEquityUSD, result.quotes)
        } catch {
            print("[Crypto] Market data fetch failed: \(error)")
            let fallback = dtos.map {
                CryptoHoldingViewModel(coinId: $0.coinId, symbol: $0.symbol, name: $0.symbol,
                                       valueUSD: $0.quantity * $0.avgBuyPrice,
                                       sinceBuyChangePercent: 0, dailyChangePercent: 0, icon: nil)
            }
            return (fallback, 0, fallback.reduce(0) { $0 + $1.valueUSD }, [:])
        }
    }
    
    private func loadIntradayPoints() async {
        do {
            let points = try await intradayService.fetchTodayPoints()
            intradayPoints = points.map { CryptoChartDataPoint(date: $0.timestamp, equityUSD: $0.equityUSD) }
        } catch {
            intradayPoints = []
        }
    }
    
    private func saveIntradayPoint(equity: Double) async {
        let point = CryptoIntradayPoint(timestamp: Date(), equityUSD: equity)
        try? await intradayService.save(point: point)
    }

    private func refreshHeaderAndChartForSelectedRange() async {
        if selectedRange == .day {
            updateHeader(amount: lastMarketEquityUSD, percent: lastMarketDailyPercent)
            
            let openEquity = lastMarketDailyPercent == -100 
                ? lastMarketEquityUSD 
                : lastMarketEquityUSD / (1 + lastMarketDailyPercent / 100.0)
            
            if shouldAddNewIntradayPoint() {
                let newPoint = CryptoChartDataPoint(date: Date(), equityUSD: lastMarketEquityUSD)
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
        
        let (rangeType, days): (CryptoChartXAxisFormatter.RangeType, Int) = {
            switch selectedRange {
            case .day:   return (.day, 1)
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
            
            let dataPoints = snaps.map { CryptoChartDataPoint(date: $0.date, equityUSD: $0.equityUSD) }
            let firstEquity = dataPoints.first?.equityUSD ?? 0
            let lastEquity = dataPoints.last?.equityUSD ?? lastMarketEquityUSD
            let pct = firstEquity == 0 ? 0 : ((lastEquity - firstEquity) / firstEquity) * 100.0

            updateHeader(amount: lastEquity, percent: pct)
            chartCoordinator.setChartData(dataPoints, rangeType: rangeType)
        } catch {
            updateHeader(amount: lastMarketEquityUSD, percent: 0)
            chartCoordinator.setEmptyChart(message: "No data yet")
        }
    }
    
    private func shouldAddNewIntradayPoint() -> Bool {
        guard lastMarketEquityUSD > 0 else { return false }
        guard let lastPoint = intradayPoints.last else { return true }
        return Date().timeIntervalSince(lastPoint.date) >= 25
    }

    private func configureRefreshTimer() {
        refreshTimer?.invalidate()
        refreshTimer = nil

        guard selectedRange == .day else { return }

        refreshTimer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            guard let self else { return }
            Task { await self.refreshMarketData() }
        }
    }
    
    private func refreshMarketData() async {
        guard !holdingDTOs.isEmpty else { return }
        
        let result = await computeHoldings(from: holdingDTOs)
        lastMarketDailyPercent = result.dailyPercent
        lastMarketEquityUSD = result.equityUSD
        marketQuotes = result.quotes
        
        holdings = result.vms
        tableDS.holdings = result.vms
        tableView.reloadData()
        
        if selectedRange == .day {
            updateHeader(amount: lastMarketEquityUSD, percent: lastMarketDailyPercent)
            
            let openEquity = lastMarketDailyPercent == -100 
                ? lastMarketEquityUSD 
                : lastMarketEquityUSD / (1 + lastMarketDailyPercent / 100.0)
            
            if shouldAddNewIntradayPoint() {
                let newPoint = CryptoChartDataPoint(date: Date(), equityUSD: lastMarketEquityUSD)
                intradayPoints.append(newPoint)
                await saveIntradayPoint(equity: lastMarketEquityUSD)
            }
            
            chartCoordinator.setDayChart(dataPoints: intradayPoints, openEquity: openEquity, currentPercent: lastMarketDailyPercent)
        } else {
            await refreshHeaderAndChartForSelectedRange()
        }
    }

    private func presentAddCrypto() {
        performSegue(withIdentifier: "showAddCrypto", sender: nil)
    }

    private func showCryptoDetail(at index: Int) {
        guard index < holdingDTOs.count else { return }
        let dto = holdingDTOs[index]
        let vm = holdings[index]
        
        let quote = marketQuotes[dto.coinId]
        let currentPrice = quote?.currentPrice ?? dto.avgBuyPrice
        let previousClose = quote?.previousClose ?? dto.avgBuyPrice
        let dailyPct = previousClose == 0 ? 0 : ((currentPrice - previousClose) / previousClose) * 100
        let sinceBuyPct = vm.sinceBuyChangePercent
        
        let totalInvested = dto.avgBuyPrice * dto.quantity
        let currentValue = currentPrice * dto.quantity
        
        let detailVM = CryptoDetailViewModel(
            id: dto.id,
            coinId: dto.coinId,
            symbol: dto.symbol,
            name: vm.name,
            image: vm.icon,
            currentPriceText: Formatters.currency.string(from: currentPrice as NSNumber) ?? "$0.00",
            dailyChangeText: Formatters.percentText(dailyPct),
            dailyChangePositive: dailyPct >= 0,
            sinceBuyText: Formatters.percentText(sinceBuyPct),
            sinceBuyPositive: sinceBuyPct >= 0,
            buyPositionText: Formatters.currency.string(from: dto.avgBuyPrice as NSNumber) ?? "$0.00",
            quantityText: String(format: "%.6f", dto.quantity),
            totalInvestedText: Formatters.currency.string(from: totalInvested as NSNumber) ?? "$0.00",
            currentValueText: Formatters.currency.string(from: currentValue as NSNumber) ?? "$0.00"
        )
        
        performSegue(withIdentifier: "showCryptoDetail", sender: detailVM)
    }

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "showCryptoDetail",
           let detailVC = segue.destination as? CryptoDetailController,
           let detailVM = sender as? CryptoDetailViewModel {
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
