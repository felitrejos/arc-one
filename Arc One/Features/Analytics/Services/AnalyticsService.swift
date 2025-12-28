import FirebaseFirestore

final class AnalyticsService {
    
    private let db = FirebaseManager.db
    private let portfolioCoordinator = PortfolioMarketCoordinator(market: MarketDataService())
    private let cryptoCoordinator = CryptoMarketCoordinator()
    
    func fetchAnalytics() async throws -> AnalyticsData {
        guard let uid = FirebaseManager.uid else {
            return emptyAnalytics()
        }
        
        // Fetch stock holdings
        let stockDocs = try await db
            .collection("users")
            .document(uid)
            .collection("holdings")
            .getDocuments()
        
        let stockDTOs = stockDocs.documents.compactMap { HoldingDTO(doc: $0) }
        
        // Fetch crypto holdings
        let cryptoDocs = try await db
            .collection("users")
            .document(uid)
            .collection("crypto_holdings")
            .getDocuments()
        
        let cryptoDTOs = cryptoDocs.documents.compactMap { CryptoHoldingDTO(doc: $0) }
        
        // Get market data for stocks
        var stocksValue: Double = 0
        var stocksChange: Double = 0
        var stockHoldings: [HoldingBreakdown] = []
        
        if !stockDTOs.isEmpty {
            let stockResult = try await portfolioCoordinator.compute(dtos: stockDTOs)
            stocksValue = stockResult.totalEquityUSD
            stocksChange = stockResult.totalDailyPercent
            
            stockHoldings = stockResult.holdingVMs.map { vm in
                HoldingBreakdown(
                    symbol: vm.name,
                    valueUSD: vm.valueUSD,
                    percentOfTotal: 0,
                    isCrypto: false,
                    icon: vm.icon
                )
            }
        }
        
        // Get market data for crypto
        var cryptoValue: Double = 0
        var cryptoChange: Double = 0
        var cryptoHoldings: [HoldingBreakdown] = []
        
        if !cryptoDTOs.isEmpty {
            let cryptoResult = try await cryptoCoordinator.compute(dtos: cryptoDTOs)
            cryptoValue = cryptoResult.totalEquityUSD
            cryptoChange = cryptoResult.totalDailyPercent
            
            cryptoHoldings = cryptoResult.holdingVMs.map { vm in
                HoldingBreakdown(
                    symbol: vm.symbol,
                    valueUSD: vm.valueUSD,
                    percentOfTotal: 0,
                    isCrypto: true,
                    icon: vm.icon
                )
            }
        }
        
        // Calculate totals
        let totalValue = stocksValue + cryptoValue
        let stocksPercent = totalValue == 0 ? 0 : (stocksValue / totalValue) * 100
        let cryptoPercent = totalValue == 0 ? 0 : (cryptoValue / totalValue) * 100
        
        // Weighted average change
        let totalChange = totalValue == 0 ? 0 :
            ((stocksValue * stocksChange) + (cryptoValue * cryptoChange)) / totalValue
        
        // Combine and sort all holdings by value
        var allHoldings = stockHoldings + cryptoHoldings
        allHoldings.sort { $0.valueUSD > $1.valueUSD }
        
        // Calculate percent of total for each holding
        allHoldings = allHoldings.map { holding in
            var updated = holding
            updated.percentOfTotal = totalValue == 0 ? 0 : (holding.valueUSD / totalValue) * 100
            return updated
        }
        
        // Take top 5
        let topHoldings = Array(allHoldings.prefix(5))
        
        return AnalyticsData(
            totalPortfolioValue: totalValue,
            totalChangePercent: totalChange,
            stocksValue: stocksValue,
            stocksPercent: stocksPercent,
            cryptoValue: cryptoValue,
            cryptoPercent: cryptoPercent,
            topHoldings: topHoldings
        )
    }
    
    private func emptyAnalytics() -> AnalyticsData {
        AnalyticsData(
            totalPortfolioValue: 0,
            totalChangePercent: 0,
            stocksValue: 0,
            stocksPercent: 0,
            cryptoValue: 0,
            cryptoPercent: 0,
            topHoldings: []
        )
    }
}
