import UIKit

@MainActor
class CryptoDetailController: UIViewController {
    
    @IBOutlet weak var tickerStack: UIStackView!
    @IBOutlet weak var investmentStack: UIStackView!
    
    @IBOutlet weak var investmentImage: UIImageView!
    @IBOutlet weak var investmentName: UILabel!
    @IBOutlet weak var investmentSymbol: UILabel!
    
    @IBOutlet weak var currentPrice: UILabel!
    @IBOutlet weak var dailyChange: UILabel!
    @IBOutlet weak var sinceBuy: UILabel!
    
    @IBOutlet weak var buyPosition: UILabel!
    @IBOutlet weak var quantity: UILabel!
    @IBOutlet weak var totalInvested: UILabel!
    @IBOutlet weak var currentValue: UILabel!
    
    var viewModel: CryptoDetailViewModel?
    
    private let cryptoService = CryptoService()
    private let marketService = CryptoMarketService()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        populateUI()
    }
    
    private func populateUI() {
        guard let vm = viewModel else { return }
        tickerStack.layer.cornerRadius = 12
        investmentStack.layer.cornerRadius = 12
        
        investmentImage.layer.cornerRadius = 8
        investmentImage.clipsToBounds = true
        investmentImage.contentMode = .scaleAspectFit
        
        investmentImage.image = vm.image
        investmentName.text = vm.name
        investmentSymbol.text = vm.symbol
        
        currentPrice.text = vm.currentPriceText
        
        dailyChange.text = vm.dailyChangeText
        dailyChange.textColor = vm.dailyChangePositive ? .systemGreen : .systemRed
        
        sinceBuy.text = vm.sinceBuyText
        sinceBuy.textColor = vm.sinceBuyPositive ? .systemGreen : .systemRed
        
        buyPosition.text = vm.buyPositionText
        quantity.text = vm.quantityText
        totalInvested.text = vm.totalInvestedText
        currentValue.text = vm.currentValueText
        
        // Load image async if not loaded
        if vm.image == nil {
            Task {
                if let profile = try? await marketService.fetchProfile(coinId: vm.coinId),
                   let url = profile.logoURL {
                    investmentImage.image = await ImageLoader.shared.load(url)
                }
            }
        }
    }
    
    @IBAction func deleteCryptoTapped(_ sender: UIButton) {
        let alert = UIAlertController(
            title: "Delete Crypto",
            message: "Are you sure you want to delete \(viewModel?.symbol ?? "this crypto")? This action cannot be undone.",
            preferredStyle: .alert
        )
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "Delete", style: .destructive) { [weak self] _ in
            self?.deleteCrypto()
        })
        
        present(alert, animated: true)
    }
    
    private func deleteCrypto() {
        guard let id = viewModel?.id else { return }
        
        Task {
            do {
                try await cryptoService.deleteHolding(id: id)
                navigationController?.popViewController(animated: true)
            } catch {
                let errorAlert = UIAlertController(
                    title: "Error",
                    message: "Failed to delete crypto. Please try again.",
                    preferredStyle: .alert
                )
                errorAlert.addAction(UIAlertAction(title: "OK", style: .default))
                present(errorAlert, animated: true)
            }
        }
    }
    
    @IBAction func addCryptoTapped(_ sender: UIButton) {
        performSegue(withIdentifier: "showAddCrypto", sender: nil)
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "showAddCrypto",
           let addVC = segue.destination as? AddCryptoController {
            addVC.prefilledCoinId = viewModel?.coinId
            addVC.prefilledSymbol = viewModel?.symbol
        }
    }
}
