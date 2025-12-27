import UIKit

struct CryptoMarketResult {
    var holdingVMs: [CryptoHoldingViewModel]
    let quotes: [String: CryptoQuote]
    let totalEquityUSD: Double
    let totalDailyPercent: Double
}

final class CryptoMarketCoordinator {
    
    private let market: CryptoMarketService
    
    init(market: CryptoMarketService = CryptoMarketService()) {
        self.market = market
    }
    
    func compute(dtos: [CryptoHoldingDTO]) async throws -> CryptoMarketResult {
        guard !dtos.isEmpty else {
            return CryptoMarketResult(holdingVMs: [], quotes: [:], totalEquityUSD: 0, totalDailyPercent: 0)
        }
        
        let coinIds = dtos.map { $0.coinId }
        let quotes = try await market.fetchQuotes(coinIds: coinIds)
        
        var holdingVMs: [CryptoHoldingViewModel] = []
        var totalEquity: Double = 0
        var weightedDailySum: Double = 0
        
        for dto in dtos {
            let quote = quotes[dto.coinId]
            let currentPrice = quote?.currentPrice ?? dto.avgBuyPrice
            let previousClose = quote?.previousClose ?? dto.avgBuyPrice
            
            let dailyPercent = previousClose == 0 ? 0 : ((currentPrice - previousClose) / previousClose) * 100
            
            let currentValue = currentPrice * dto.quantity
            let costBasis = dto.avgBuyPrice * dto.quantity
            let sinceBuyPercent = costBasis == 0 ? 0 : ((currentValue - costBasis) / costBasis) * 100
            
            totalEquity += currentValue
            weightedDailySum += currentValue * dailyPercent
            
            let coinName = CryptoMarketService.availableCoins.first { $0.id == dto.coinId }?.name ?? dto.symbol
            
            let vm = CryptoHoldingViewModel(
                coinId: dto.coinId,
                symbol: dto.symbol,
                name: coinName,
                valueUSD: currentValue,
                sinceBuyChangePercent: sinceBuyPercent,
                dailyChangePercent: dailyPercent,
                icon: nil
            )
            holdingVMs.append(vm)
        }
        
        // Load logo images asynchronously
        for i in holdingVMs.indices {
            let coinId = holdingVMs[i].coinId
            if let profile = try? await market.fetchProfile(coinId: coinId),
               let url = profile.logoURL {
                holdingVMs[i].icon = await ImageLoader.shared.load(url)
            }
        }
        
        let totalDailyPercent = totalEquity == 0 ? 0 : weightedDailySum / totalEquity
        
        return CryptoMarketResult(
            holdingVMs: holdingVMs,
            quotes: quotes,
            totalEquityUSD: totalEquity,
            totalDailyPercent: totalDailyPercent
        )
    }
}
