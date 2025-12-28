//
//  HoldingBreakdownCell.swift
//  Arc One
//
//  Created by Felipe Trejos on 28/12/25.
//

import UIKit

class HoldingBreakdownCell: UITableViewCell {

    @IBOutlet weak var holdingLogo: UIImageView!
    @IBOutlet weak var holdingName: UILabel!
    @IBOutlet weak var holdingPercentage: UILabel!
    @IBOutlet weak var holdingAmount: UILabel!
    @IBOutlet weak var holdingProgressBar: UIProgressView!
    
    override func awakeFromNib() {
        super.awakeFromNib()
        
        holdingLogo.layer.cornerRadius = 8
        holdingLogo.clipsToBounds = true
        
        holdingProgressBar.layer.cornerRadius = 4
        holdingProgressBar.clipsToBounds = true
    }
    
    func configure(with holding: HoldingBreakdown) {
        holdingName.text = holding.symbol
        holdingPercentage.text = String(format: "%.0f%%", holding.percentOfTotal)
        holdingAmount.text = Formatters.currency.string(from: holding.valueUSD as NSNumber)
        
        // Progress is 0-1, percent is 0-100
        holdingProgressBar.progress = Float(holding.percentOfTotal / 100)
        holdingProgressBar.tintColor = holding.isCrypto ? .systemPurple : .systemGreen
        
        holdingLogo.image = holding.icon ?? UIImage(systemName: holding.isCrypto ? "bitcoinsign.circle.fill" : "chart.line.uptrend.xyaxis.circle.fill")
    }
}
