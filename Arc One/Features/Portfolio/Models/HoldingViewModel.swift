import UIKit

struct HoldingViewModel {
    let name: String
    let valueUSD: Double
    let sinceBuyChangePercent: Double
    let dailyChangePercent: Double
    var icon: UIImage?

    var valueText: String { Formatters.currency.string(from: valueUSD as NSNumber) ?? "$0" }

    func changeText(for mode: PerformanceMode) -> String {
        Formatters.percentText(percentValue(for: mode))
    }

    func changeColor(for mode: PerformanceMode) -> UIColor {
        Formatters.changeColor(percentValue(for: mode))
    }

    private func percentValue(for mode: PerformanceMode) -> Double {
        mode == .sinceBuy ? sinceBuyChangePercent : dailyChangePercent
    }
}
