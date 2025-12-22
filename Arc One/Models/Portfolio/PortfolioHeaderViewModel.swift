//
//  PortfolioHeaderViewModel.swift
//  Arc One
//
//  Created by Felipe Trejos on 22/12/25.
//

import UIKit

struct PortfolioHeaderViewModel {
    let amountEUR: Double
    let changePercent: Double

    var amountText: String {
        let f = NumberFormatter()
        f.numberStyle = .currency
        f.currencyCode = "EUR"
        return f.string(from: amountEUR as NSNumber) ?? "\(amountEUR) €"
    }

    var changeText: String {
        let sign = changePercent >= 0 ? "▲" : "▼"
        return "\(sign) \(String(format: "%.2f", abs(changePercent)))%"
    }

    var changeColor: UIColor {
        changePercent >= 0 ? .systemGreen : .systemRed
    }
}
