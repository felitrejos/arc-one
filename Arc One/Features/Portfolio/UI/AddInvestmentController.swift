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
    private var selectedMarketIndex: Int = 0
    
    private let portfolioService = PortfolioService()
    private let marketDataService = MarketDataService()
    
    private var currentMarket: MarketInfo {
        MarketDataService.availableMarkets[selectedMarketIndex]
    }
    
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
        
        // Set default placeholder
        setTickerPlaceholder()
    }
    
    private func setTickerPlaceholder() {
        tickerLogo.image = UIImage(named: "nasdaq-logo")
        tickerName.text = "Select a stock to invest"
        tickerName.textColor = .secondaryLabel
    }
    
    private func setupMenus() {
        // Market menu 
        let marketActions = MarketDataService.availableMarkets.enumerated().map { index, market in
            return UIAction(title: market.displayName, state: index == selectedMarketIndex ? .on : .off) { [weak self] _ in
                self?.selectMarket(index)
            }
        }
        marketButton.menu = UIMenu(children: marketActions)
        marketButton.showsMenuAsPrimaryAction = true
        marketButton.setTitle(currentMarket.displayName, for: .normal)
        
        // Ticker menu
        updateTickerMenu()
    }
    
    private func selectMarket(_ index: Int) {
        selectedMarketIndex = index
        marketButton.setTitle(currentMarket.displayName, for: .normal)
        
        // Reset ticker when market changes
        selectedTicker = nil
        tickerButton.setTitle("Select Ticker", for: .normal)
        setTickerPlaceholder()
        
        updateTickerMenu()
        setupMenus() // Refresh to update checkmark
    }
    
    private func updateTickerMenu() {
        let tickerActions = currentMarket.tickers.map { ticker in
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
        tickerName.textColor = .label  // Reset from placeholder color
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
        if let market = prefilledMarket,
           let index = MarketDataService.availableMarkets.firstIndex(where: { $0.id == market }) {
            selectedMarketIndex = index
            marketButton.setTitle(currentMarket.displayName, for: .normal)
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
                    market: currentMarket.id,
                    quantity: quantity,
                    avgBuyPrice: price
                )
                navigationController?.popToRootViewController(animated: true)
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
