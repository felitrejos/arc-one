import UIKit

struct PortfolioHeaderViewModel {
    let amountUSD: Double
    let changePercent: Double

    var amountText: String { Formatters.currency.string(from: amountUSD as NSNumber) ?? "$0" }
    var changeText: String { Formatters.percentText(changePercent) }
    var changeColor: UIColor { changePercent >= 0 ? .systemGreen : .systemRed }
}
