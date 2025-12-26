//
//  AddInvestmentController.swift
//  Arc One
//
//  Created by Felipe Trejos on 25/12/25.
//

import UIKit

@MainActor
class AddInvestmentController: UIViewController {
    
    @IBOutlet weak var marketStack: UIStackView!
    @IBOutlet weak var tickerStack: UIStackView!
    
    @IBOutlet weak var marketButton: UIButton!
    @IBOutlet weak var tickerButton: UIButton!
    
    @IBOutlet weak var tickerLogo: UIImageView!
    @IBOutlet weak var tickerName: UILabel!
    
    @IBOutlet weak var priceInput: UITextField!
    @IBOutlet weak var quantityInput: UITextField!
    
    @IBOutlet weak var addInvestmentButton: UIButton!
    
    // Prefill properties
    var prefilledTicker: String?
    var prefilledMarket: String?
    
    // Selected values
    private var selectedTicker: String?
    private var selectedMarket: String = "US"
    
    private let portfolioService = PortfolioService()
    private let marketDataService = MarketDataService()
    
    // Available Markets & Tickers 
    private let markets = ["US"]
    
    private let tickersByMarket: [String: [String]] = [
        "US": ["AAPL", "MSFT", "GOOGL", "AMZN", "NVDA", "META", "TSLA", "NFLX", "AMD", "INTC", "PYPL", "ADBE", "CSCO", "QCOM", "AVGO", "CRM", "ORCL", "IBM", "DIS", "V", "MA", "JPM", "BAC", "WMT", "KO"]
    ]
    
    private let marketDisplayNames: [String: String] = [
        "US": "US Stocks"
    ]
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupMenus()
        applyPrefill()
    }
    
    private func setupUI() {
        marketStack.layer.cornerRadius = 12
        tickerStack.layer.cornerRadius = 12
        
        priceInput.applyAuthStyle()
        quantityInput.applyAuthStyle()
        priceInput.keyboardType = .decimalPad
        quantityInput.keyboardType = .decimalPad

        marketButton.layer.cornerRadius = 12
        tickerButton.layer.cornerRadius = 12
        addInvestmentButton.layer.cornerRadius = 14
        
        tickerLogo.layer.cornerRadius = 8
        tickerLogo.clipsToBounds = true
        tickerLogo.contentMode = .scaleAspectFit
    }
    
    private func setupMenus() {
        // Market menu 
        let marketActions = markets.map { market in
            let displayName = marketDisplayNames[market] ?? market
            return UIAction(title: displayName, state: market == selectedMarket ? .on : .off) { [weak self] _ in
                self?.selectMarket(market)
            }
        }
        marketButton.menu = UIMenu(children: marketActions)
        marketButton.showsMenuAsPrimaryAction = true
        marketButton.setTitle(marketDisplayNames[selectedMarket] ?? selectedMarket, for: .normal)
        
        // Ticker menu
        updateTickerMenu()
    }
    
    private func selectMarket(_ market: String) {
        selectedMarket = market
        marketButton.setTitle(marketDisplayNames[market] ?? market, for: .normal)
        
        // Reset ticker when market changes
        selectedTicker = nil
        tickerButton.setTitle("Select Ticker", for: .normal)
        tickerLogo.image = nil
        tickerName.text = nil
        
        updateTickerMenu()
        setupMenus() // Refresh to update checkmark
    }
    
    private func updateTickerMenu() {
        let tickers = tickersByMarket[selectedMarket] ?? []
        
        let tickerActions = tickers.map { ticker in
            UIAction(title: ticker) { [weak self] _ in
                self?.selectTicker(ticker)
            }
        }
        tickerButton.menu = UIMenu(children: tickerActions)
        tickerButton.showsMenuAsPrimaryAction = true
    }
    
    private func selectTicker(_ ticker: String) {
        selectedTicker = ticker
        tickerButton.setTitle(ticker, for: .normal)
        tickerName.text = "Loading..."
        tickerLogo.image = nil
        
        Task {
            let profile = try? await marketDataService.fetchProfile(ticker: ticker)
            tickerName.text = profile?.name ?? ticker
            
            if let url = profile?.logoURL {
                tickerLogo.image = await ImageLoader.shared.load(url)
            }
        }
    }
    
    private func applyPrefill() {
        if let market = prefilledMarket, markets.contains(market) {
            selectedMarket = market
            marketButton.setTitle(marketDisplayNames[market] ?? market, for: .normal)
            updateTickerMenu()
        }
        
        if let ticker = prefilledTicker {
            selectTicker(ticker)
        }
    }
    
    @IBAction func addInvestmentTapped(_ sender: UIButton) {
        guard validateInputs() else { return }
        
        guard let ticker = selectedTicker,
              let priceText = priceInput.text,
              let quantityText = quantityInput.text,
              let price = Double(priceText),
              let quantity = Double(quantityText) else { return }
        
        addInvestmentButton.isEnabled = false
        
        Task {
            do {
                try await portfolioService.addHolding(
                    ticker: ticker,
                    market: selectedMarket,
                    quantity: quantity,
                    avgBuyPrice: price
                )
                navigationController?.popViewController(animated: true)
            } catch {
                addInvestmentButton.isEnabled = true
                showError("Failed to add investment. Please try again.")
            }
        }
    }
    
    private func validateInputs() -> Bool {
        guard selectedTicker != nil else {
            showError("Please select a ticker.")
            return false
        }
        
        guard let priceText = priceInput.text, let price = Double(priceText), price > 0 else {
            showError("Please enter a valid price.")
            return false
        }
        
        guard let quantityText = quantityInput.text, let quantity = Double(quantityText), quantity > 0 else {
            showError("Please enter a valid quantity.")
            return false
        }
        
        return true
    }
    
    private func showError(_ message: String) {
        let alert = UIAlertController(title: "Error", message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
}
