import UIKit

final class AnalyticsController: UIViewController {
    
    @IBOutlet weak var headerStack: UIStackView!
    @IBOutlet weak var networthAmount: UILabel!
    @IBOutlet weak var totalChangePercent: UILabel!
    
    @IBOutlet weak var portfolioStack: UIStackView!
    @IBOutlet weak var cryptoStack: UIStackView!
    @IBOutlet weak var holdingsStack: UIStackView!
    
    @IBOutlet weak var totalStocksAmount: UILabel!
    @IBOutlet weak var totalStocksPercentage: UILabel!
    
    @IBOutlet weak var totalCryptoAmount: UILabel!
    @IBOutlet weak var totalCryptoPercentage: UILabel!
    
    @IBOutlet weak var holdingBreakdownTable: UITableView!
    
    private let analyticsService = AnalyticsService()
    private let tableDS = AnalyticsTableDataSource()
    private var hasAppearedOnce = false
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.title = "Analytics"
        
        setupUI()
        setupTable()
        
        // Hide content initially
        view.alpha = 0
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        loadData()
    }
    
    private func setupUI() {
        headerStack.layer.cornerRadius = 14
        headerStack.layer.masksToBounds = true
        portfolioStack.layer.cornerRadius = 14
        portfolioStack.layer.masksToBounds = true
        cryptoStack.layer.cornerRadius = 14
        cryptoStack.layer.masksToBounds = true
        holdingsStack.layer.cornerRadius = 14
        holdingsStack.layer.masksToBounds = true
    }
    
    private func setupTable() {
        holdingBreakdownTable.register(
            UINib(nibName: "HoldingBreakdownCell", bundle: nil),
            forCellReuseIdentifier: "holdingBreakdownCell"
        )
        holdingBreakdownTable.dataSource = tableDS
    }
    
    private func loadData() {
        Task {
            do {
                let data = try await analyticsService.fetchAnalytics()
                await MainActor.run {
                    updateUI(with: data)
                    fadeInIfNeeded()
                }
            } catch {
                print("Analytics error: \(error)")
                fadeInIfNeeded()
            }
        }
    }
    
    private func fadeInIfNeeded() {
        guard !hasAppearedOnce else { return }
        hasAppearedOnce = true
        UIView.animate(withDuration: 0.3) {
            self.view.alpha = 1
        }
    }
    
    private func updateUI(with data: AnalyticsData) {
        // Total net worth
        networthAmount.text = Formatters.currency.string(from: data.totalPortfolioValue as NSNumber)
        totalChangePercent.text = Formatters.percentText(data.totalChangePercent)
        totalChangePercent.textColor = Formatters.changeColor(data.totalChangePercent)
        
        // Stocks card
        totalStocksAmount.text = Formatters.currency.string(from: data.stocksValue as NSNumber)
        totalStocksPercentage.text = String(format: "%.0f%%", data.stocksPercent)
        
        // Crypto card
        totalCryptoAmount.text = Formatters.currency.string(from: data.cryptoValue as NSNumber)
        totalCryptoPercentage.text = String(format: "%.0f%%", data.cryptoPercent)
        
        // Holdings table
        tableDS.holdings = data.topHoldings
        holdingBreakdownTable.reloadData()
    }
}
