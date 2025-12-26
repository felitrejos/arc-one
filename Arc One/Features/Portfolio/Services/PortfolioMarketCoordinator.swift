import UIKit

final class PortfolioMarketCoordinator {

    struct Result {
        var holdingVMs: [HoldingViewModel]
        let totalEquityUSD: Double
        let totalDailyPercent: Double
        let totalSinceBuyPercent: Double
        let quotes: [String: MarketQuote]
    }

    private let market: MarketDataServiceProtocol

    init(market: MarketDataServiceProtocol) {
        self.market = market
    }

    func compute(dtos: [HoldingDTO]) async throws -> Result {
        let tickers = Array(Set(dtos.map { $0.ticker.uppercased() }))
        
        // Fetch quotes and logos in parallel
        async let quotesTask = market.fetchQuotes(tickers: tickers)
        async let logosTask = market.fetchLogoURLs(tickers: tickers)
        
        let (quotes, logoURLs) = try await (quotesTask, logosTask)

        var vms: [HoldingViewModel] = []
        var totalEquity: Double = 0
        var weightedDaily: Double = 0
        var weightedSinceBuy: Double = 0

        for dto in dtos {
            let ticker = dto.ticker.uppercased()
            guard let quote = quotes[ticker] else { continue }

            let current = quote.currentPrice
            let prev = quote.previousClose
            let value = dto.quantity * current
            totalEquity += value

            let dailyPct = prev == 0 ? 0 : ((current - prev) / prev) * 100
            let sinceBuyPct = dto.avgBuyPrice == 0 ? 0 : ((current - dto.avgBuyPrice) / dto.avgBuyPrice) * 100

            weightedDaily += value * dailyPct
            weightedSinceBuy += value * sinceBuyPct

            vms.append(HoldingViewModel(
                name: ticker,
                valueUSD: value,
                sinceBuyChangePercent: sinceBuyPct,
                dailyChangePercent: dailyPct,
                icon: nil
            ))
        }

        // Load logo images asynchronously
        for i in vms.indices {
            let ticker = vms[i].name
            if let url = logoURLs[ticker] ?? nil {
                vms[i].icon = await ImageLoader.shared.load(url)
            }
        }

        let totalDaily = totalEquity == 0 ? 0 : weightedDaily / totalEquity
        let totalSinceBuy = totalEquity == 0 ? 0 : weightedSinceBuy / totalEquity

        return Result(
            holdingVMs: vms,
            totalEquityUSD: totalEquity,
            totalDailyPercent: totalDaily,
            totalSinceBuyPercent: totalSinceBuy,
            quotes: quotes
        )
    }
}
