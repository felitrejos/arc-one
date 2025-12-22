//
//  HoldingViewModel.swift
//  Arc One
//
//  Created by Felipe Trejos on 22/12/25.
//

import UIKit

struct HoldingViewModel {
    let name: String
    let valueEUR: Double
    let sinceBuyChangePercent: Double
    let dailyChangePercent: Double
    let icon: UIImage?

    var valueText: String {
        let f = NumberFormatter()
        f.numberStyle = .currency
        f.currencyCode = "EUR"
        return f.string(from: valueEUR as NSNumber) ?? "\(valueEUR) €"
    }

    func changeText(for mode: PerformanceMode) -> String {
        let value = percentValue(for: mode)
        let sign = value >= 0 ? "▲" : "▼"
        return "\(sign) \(String(format: "%.2f", abs(value)))%"
    }

    func changeColor(for mode: PerformanceMode) -> UIColor {
        percentValue(for: mode) >= 0 ? .systemGreen : .systemRed
    }

    private func percentValue(for mode: PerformanceMode) -> Double {
        mode == .sinceBuy ? sinceBuyChangePercent : dailyChangePercent
    }
}
