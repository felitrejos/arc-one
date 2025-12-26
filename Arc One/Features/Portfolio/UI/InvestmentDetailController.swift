//
//  InvestmentDetailController.swift
//  Arc One
//
//  Created by Felipe Trejos on 25/12/25.
//

import UIKit

@MainActor
class InvestmentDetailController: UIViewController {
    
    @IBOutlet weak var tickerStack: UIStackView!
    @IBOutlet weak var investmentStack: UIStackView!
    
    @IBOutlet weak var investmentImage: UIImageView!
    @IBOutlet weak var investmentName: UILabel!
    @IBOutlet weak var investmentMarket: UILabel!
    
    @IBOutlet weak var currentPrice: UILabel!
    @IBOutlet weak var dailyChange: UILabel!
    @IBOutlet weak var sinceBuy: UILabel!
    
    @IBOutlet weak var buyPosition: UILabel!
    @IBOutlet weak var quantity: UILabel!
    @IBOutlet weak var totalInvested: UILabel!
    @IBOutlet weak var currentValue: UILabel!
    
    var viewModel: InvestmentDetailViewModel?
    
    private let portfolioService = PortfolioService()
    
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
        investmentName.text = vm.ticker
        investmentMarket.text = vm.market
        
        currentPrice.text = vm.currentPriceText
        
        dailyChange.text = vm.dailyChangeText
        dailyChange.textColor = vm.dailyChangePositive ? .systemGreen : .systemRed
        
        sinceBuy.text = vm.sinceBuyText
        sinceBuy.textColor = vm.sinceBuyPositive ? .systemGreen : .systemRed
        
        buyPosition.text = vm.buyPositionText
        quantity.text = vm.quantityText
        totalInvested.text = vm.totalInvestedText
        currentValue.text = vm.currentValueText
    }
    
    @IBAction func deleteInvestmentTapped(_ sender: UIButton) {
        let alert = UIAlertController(
            title: "Delete Investment",
            message: "Are you sure you want to delete \(viewModel?.ticker ?? "this investment")? This action cannot be undone.",
            preferredStyle: .alert
        )
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "Delete", style: .destructive) { [weak self] _ in
            self?.deleteInvestment()
        })
        
        present(alert, animated: true)
    }
    
    private func deleteInvestment() {
        guard let id = viewModel?.id else { return }
        
        Task {
            do {
                try await portfolioService.deleteHolding(id: id)
                navigationController?.popViewController(animated: true)
            } catch {
                let errorAlert = UIAlertController(
                    title: "Error",
                    message: "Failed to delete investment. Please try again.",
                    preferredStyle: .alert
                )
                errorAlert.addAction(UIAlertAction(title: "OK", style: .default))
                present(errorAlert, animated: true)
            }
        }
    }
    
    @IBAction func addInvestmentTapped(_ sender: UIButton) {
        performSegue(withIdentifier: "showAddInvestment", sender: nil)
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "showAddInvestment",
           let addVC = segue.destination as? AddInvestmentController {
            addVC.prefilledTicker = viewModel?.ticker
            addVC.prefilledMarket = viewModel?.market
        }
    }
}
