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

    private var performanceMode: PerformanceMode = .sinceBuy

    private var headerVM = PortfolioHeaderViewModel(amountEUR: 0, changePercent: 0)
    private var holdings: [HoldingViewModel] = []

    private let chartCoordinator = PortfolioChartCoordinator()
    private let tableDS = PortfolioTableDataSource()

    private let portfolioService = PortfolioService()
    private var holdingsListener: ListenerRegistration?

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Portfolio"

        setupHeader()
        setupSegmentedControl()
        setupMetricMenu()

        setupTable()
        startHoldingsListener()

        setupChartCoordinator()
        chartCoordinator.setEquitySeries([0, 0, 0, 0, 0])
    }

    deinit {
        holdingsListener?.remove()
    }

    @IBAction private func rangeChanged(_ sender: UISegmentedControl) {
        updateSegmentedControlFont()

        // En el futuro: aquí cargas la serie histórica real según el rango.
        // Por ahora no cambiamos nada, porque el chart se alimenta de setEquitySeries(...)
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
        ["1D", "1W", "1M", "1Y"].enumerated().forEach { index, title in
            rangeSegment.insertSegment(withTitle: title, at: index, animated: false)
        }
        rangeSegment.selectedSegmentIndex = 0
        updateSegmentedControlFont()
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
        config.title = performanceMode.rawValue
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

        tableDS.onAddTapped = { [weak self] in
            self?.presentAddInvestment()
        }

        tableDS.onHoldingTapped = { vm in
            // Future: push detail controller
            _ = vm
        }

        tableView.reloadData()
    }

    func startHoldingsListener() {
        holdingsListener?.remove()

        guard FirebaseManager.uid != nil else { return }

        holdingsListener = portfolioService.listenHoldings { [weak self] dtos in
            guard let self else { return }

            let vms: [HoldingViewModel] = dtos.map { dto in
                HoldingViewModel(
                    name: dto.ticker,
                    valueEUR: dto.quantity * dto.avgBuyPrice, // placeholder until market prices
                    sinceBuyChangePercent: 0,
                    dailyChangePercent: 0,
                    icon: UIImage(systemName: "cpu")
                )
            }

            self.holdings = vms
            self.tableDS.holdings = vms
            self.tableView.reloadData()

            let total = vms.reduce(0) { $0 + $1.valueEUR }
            self.headerVM = PortfolioHeaderViewModel(amountEUR: total, changePercent: 0)
            self.setupHeader()

            let series = self.makeSimpleSeries(from: total)
            self.chartCoordinator.setEquitySeries(series)
        }
    }

    func makeSimpleSeries(from total: Double) -> [Double] {
        let t = max(total, 0)
        return [t * 0.98, t * 0.985, t * 0.99, t * 0.995, t]
    }

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
            tf.placeholder = "Avg buy price (e.g. 120.30)"
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

        chartCoordinator.onHeaderUpdate = { [weak self] equity, percent in
            self?.setHeader(equity: equity, percent: percent)
        }
    }

    func setHeader(equity: Double, percent: Double) {
        let f = NumberFormatter()
        f.numberStyle = .currency
        f.currencyCode = "EUR"
        amountLabel.text = f.string(from: equity as NSNumber) ?? "\(equity) €"
        amountLabel.font = .systemFont(ofSize: amountLabel.font.pointSize, weight: .bold)

        let sign = percent >= 0 ? "▲" : "▼"
        changeLabel.text = "\(sign) \(String(format: "%.2f", abs(percent)))%"
        changeLabel.textColor = percent >= 0 ? .systemGreen : .systemRed
        changeLabel.font = .systemFont(ofSize: changeLabel.font.pointSize, weight: .bold)
    }
}
