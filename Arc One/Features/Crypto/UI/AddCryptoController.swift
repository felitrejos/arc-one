import UIKit

@MainActor
class AddCryptoController: UIViewController {
    
    @IBOutlet weak var coinStack: UIStackView!
    @IBOutlet weak var coinButton: UIButton!
    
    @IBOutlet weak var coinLogo: UIImageView!
    @IBOutlet weak var coinName: UILabel!
    
    @IBOutlet weak var priceInput: UITextField!
    @IBOutlet weak var quantityInput: UITextField!
    
    @IBOutlet weak var addCryptoButton: UIButton!
    
    // Prefill properties
    var prefilledCoinId: String?
    var prefilledSymbol: String?
    
    // Selected values
    private var selectedCoinId: String?
    private var selectedSymbol: String?
    
    private let cryptoService = CryptoService()
    private let marketService = CryptoMarketService()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupCoinMenu()
        applyPrefill()
    }
    
    private func setupUI() {
        coinStack.layer.cornerRadius = 12
        
        priceInput.applyAuthStyle()
        quantityInput.applyAuthStyle()
        priceInput.keyboardType = .decimalPad
        quantityInput.keyboardType = .decimalPad

        coinButton.layer.cornerRadius = 12
        addCryptoButton.layer.cornerRadius = 14
        
        coinLogo.layer.cornerRadius = 8
        coinLogo.clipsToBounds = true
        coinLogo.contentMode = .scaleAspectFit
        
        setCoinPlaceholder()
    }
    
    private func setCoinPlaceholder() {
        coinLogo.image = UIImage(named: "crypto-logo")
        coinName.text = "Select a coin to invest"
        coinName.textColor = .secondaryLabel
    }
    
    private func setupCoinMenu() {
        let coinActions = CryptoMarketService.availableCoins.map { coin in
            UIAction(title: "\(coin.symbol) - \(coin.name)") { [weak self] _ in
                self?.selectCoin(id: coin.id, symbol: coin.symbol, name: coin.name)
            }
        }
        coinButton.menu = UIMenu(children: coinActions)
        coinButton.showsMenuAsPrimaryAction = true
    }
    
    private func selectCoin(id: String, symbol: String, name: String) {
        selectedCoinId = id
        selectedSymbol = symbol
        coinButton.setTitle(symbol, for: .normal)
        coinName.text = name
        coinName.textColor = .label
        coinLogo.image = nil
        
        // Load logo async
        Task {
            if let profile = try? await marketService.fetchProfile(coinId: id),
               let url = profile.logoURL {
                coinLogo.image = await ImageLoader.shared.load(url)
            }
        }
    }
    
    private func applyPrefill() {
        if let coinId = prefilledCoinId, let symbol = prefilledSymbol {
            // Find coin name from hardcoded list
            let name = CryptoMarketService.availableCoins.first { $0.id == coinId }?.name ?? symbol
            selectCoin(id: coinId, symbol: symbol, name: name)
        }
    }
    
    @IBAction func addCryptoTapped(_ sender: UIButton) {
        guard validateInputs() else { return }
        
        guard let coinId = selectedCoinId,
              let symbol = selectedSymbol,
              let priceText = priceInput.text,
              let quantityText = quantityInput.text,
              let price = Double(priceText),
              let quantity = Double(quantityText) else { return }
        
        addCryptoButton.isEnabled = false
        
        Task {
            do {
                try await cryptoService.addHolding(
                    coinId: coinId,
                    symbol: symbol,
                    quantity: quantity,
                    avgBuyPrice: price
                )
                navigationController?.popToRootViewController(animated: true)
            } catch {
                addCryptoButton.isEnabled = true
                showError("Failed to add crypto. Please try again.")
            }
        }
    }
    
    private func validateInputs() -> Bool {
        guard selectedCoinId != nil else {
            showError("Please select a coin.")
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
