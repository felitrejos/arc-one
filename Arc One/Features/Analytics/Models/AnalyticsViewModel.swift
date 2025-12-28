import UIKit

struct AnalyticsData {
    let totalPortfolioValue: Double
    let totalChangePercent: Double
    
    let stocksValue: Double
    let stocksPercent: Double
    
    let cryptoValue: Double
    let cryptoPercent: Double
    
    let topHoldings: [HoldingBreakdown]
}

struct HoldingBreakdown {
    let symbol: String
    let valueUSD: Double
    var percentOfTotal: Double
    let isCrypto: Bool
    var icon: UIImage?
}
