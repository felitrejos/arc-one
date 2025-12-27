import UIKit

enum CryptoPerformanceMode: String, CaseIterable {
    case sinceBuy = "Since buy"
    case daily = "Daily"
}

struct CryptoHoldingViewModel {
    let coinId: String
    let symbol: String
    let name: String
    let valueUSD: Double
    let sinceBuyChangePercent: Double
    let dailyChangePercent: Double
    var icon: UIImage?

    var valueText: String { Formatters.currency.string(from: valueUSD as NSNumber) ?? "$0" }

    func changeText(for mode: CryptoPerformanceMode) -> String {
        Formatters.percentText(percentValue(for: mode))
    }

    func changeColor(for mode: CryptoPerformanceMode) -> UIColor {
        Formatters.changeColor(percentValue(for: mode))
    }

    private func percentValue(for mode: CryptoPerformanceMode) -> Double {
        mode == .sinceBuy ? sinceBuyChangePercent : dailyChangePercent
    }
}
