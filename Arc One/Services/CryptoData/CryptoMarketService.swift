import Foundation

struct CryptoQuote {
    let currentPrice: Double
    let previousClose: Double  // For daily % calculation
}

struct CryptoProfile {
    let name: String
    let logoURL: URL?
}

private struct CoinGeckoMarketDTO: Decodable {
    let id: String
    let name: String
    let image: String?
    let current_price: Double?
    let price_change_percentage_24h: Double?
}

final class CryptoMarketService {
    
    private let baseURL = "https://api.coingecko.com/api/v3"
    private let apiKey = AppConfig.coinGeckoAPIKey
    
    // Hardcoded top coins - CoinGecko IDs
    static let availableCoins: [(id: String, symbol: String, name: String)] = [
        ("bitcoin", "BTC", "Bitcoin"),
        ("ethereum", "ETH", "Ethereum"),
        ("tether", "USDT", "Tether"),
        ("binancecoin", "BNB", "BNB"),
        ("solana", "SOL", "Solana"),
        ("ripple", "XRP", "XRP"),
        ("usd-coin", "USDC", "USD Coin"),
        ("cardano", "ADA", "Cardano"),
        ("dogecoin", "DOGE", "Dogecoin"),
        ("avalanche-2", "AVAX", "Avalanche"),
        ("polkadot", "DOT", "Polkadot"),
        ("tron", "TRX", "TRON"),
        ("chainlink", "LINK", "Chainlink"),
        ("polygon-ecosystem-token", "POL", "Polygon"),
        ("shiba-inu", "SHIB", "Shiba Inu"),
        ("litecoin", "LTC", "Litecoin"),
        ("bitcoin-cash", "BCH", "Bitcoin Cash"),
        ("uniswap", "UNI", "Uniswap"),
        ("stellar", "XLM", "Stellar"),
        ("monero", "XMR", "Monero"),
        ("pepe", "PEPE", "Pepe"),
        ("aave", "AAVE", "Aave"),
        ("render-token", "RNDR", "Render"),
        ("the-graph", "GRT", "The Graph"),
        ("cosmos", "ATOM", "Cosmos")
    ]
    
    private func makeRequest(url: URL) async throws -> Data {
        var request = URLRequest(url: url)
        request.addValue(apiKey, forHTTPHeaderField: "x-cg-demo-api-key")
        let (data, _) = try await URLSession.shared.data(for: request)
        return data
    }
    
    /// Fetch current prices and 24h change for multiple coins
    func fetchQuotes(coinIds: [String]) async throws -> [String: CryptoQuote] {
        guard !coinIds.isEmpty else { return [:] }
        
        let ids = coinIds.joined(separator: ",")
        let urlString = "\(baseURL)/coins/markets?vs_currency=usd&ids=\(ids)&price_change_percentage=24h"
        
        guard let url = URL(string: urlString) else { return [:] }
        
        let data = try await makeRequest(url: url)
        let coins = try JSONDecoder().decode([CoinGeckoMarketDTO].self, from: data)
        
        var result: [String: CryptoQuote] = [:]
        for coin in coins {
            let currentPrice = coin.current_price ?? 0
            let dailyChange = coin.price_change_percentage_24h ?? 0
            // Calculate previous close from current price and daily change
            let previousClose = dailyChange == 0 ? currentPrice : currentPrice / (1 + dailyChange / 100)
            
            result[coin.id] = CryptoQuote(
                currentPrice: currentPrice,
                previousClose: previousClose
            )
        }
        return result
    }
    
    /// Fetch coin profile (name, logo)
    func fetchProfile(coinId: String) async throws -> CryptoProfile? {
        // First check hardcoded list
        if let coin = Self.availableCoins.first(where: { $0.id == coinId }) {
            // Fetch logo from API
            let urlString = "\(baseURL)/coins/\(coinId)?localization=false&tickers=false&market_data=false&community_data=false&developer_data=false"
            
            guard let url = URL(string: urlString) else {
                return CryptoProfile(name: coin.name, logoURL: nil)
            }
            
            let data = try await makeRequest(url: url)
            let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
            let image = (json?["image"] as? [String: Any])?["large"] as? String
            
            return CryptoProfile(
                name: coin.name,
                logoURL: image.flatMap { URL(string: $0) }
            )
        }
        return nil
    }
}
