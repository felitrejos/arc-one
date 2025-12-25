//
//  AddInvestmentController.swift
//  Arc One
//
//  Created by Felipe Trejos on 25/12/25.
//

import UIKit

class AddInvestmentController: UIViewController {
    
    @IBOutlet weak var marketButton: UIButton!
    @IBOutlet weak var tickerButton: UIButton!
    
    @IBOutlet weak var tickerLogo: UIImageView!
    @IBOutlet weak var tickerName: UIImageView!
    
    @IBOutlet weak var priceInput: UITextField!
    @IBOutlet weak var quantityInput: UITextField!
    
    @IBOutlet weak var addInvestmentButton: UIButton!
    
    @IBOutlet weak var marketBg: UIImageView!
    @IBOutlet weak var infoBg: UIImageView!
    
    @IBOutlet weak var priceBg: UIImageView!
    @IBOutlet weak var quantityBg: UIImageView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        
    }
    
    func setupUI() {
        [marketBg, infoBg, priceBg, quantityBg].forEach {
            $0?.layer.cornerRadius = 14
            $0?.layer.masksToBounds = true
        }
        
        priceInput.applyAuthStyle()
        quantityInput.applyAuthStyle()

        marketButton.layer.cornerRadius = 12
        tickerButton.layer.cornerRadius = 12
        addInvestmentButton.layer.cornerRadius = 14
    }
    
    @IBAction func addInvestmentTapped(_ sender: UIButton) {
        dismiss(animated: true)
    }
}
