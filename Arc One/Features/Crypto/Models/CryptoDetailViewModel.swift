import UIKit

struct CryptoDetailViewModel {
    let id: String
    let coinId: String
    let symbol: String
    let name: String
    let image: UIImage?
    let currentPriceText: String
    let dailyChangeText: String
    let dailyChangePositive: Bool
    let sinceBuyText: String
    let sinceBuyPositive: Bool
    let buyPositionText: String
    let quantityText: String
    let totalInvestedText: String
    let currentValueText: String
}
