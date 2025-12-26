import Foundation

struct MarketQuote {
    let currentPrice: Double
    let previousClose: Double
}

struct TickerProfile {
    let name: String
    let logoURL: URL?
}

private struct FinnhubQuoteDTO: Decodable {
    let c: Double?
    let pc: Double?
}

private struct FinnhubProfileDTO: Decodable {
    let name: String?
    let logo: String?
}

protocol MarketDataServiceProtocol {
    func fetchQuotes(tickers: [String]) async throws -> [String: MarketQuote]
    func fetchLogoURLs(tickers: [String]) async throws -> [String: URL?]
    func fetchProfile(ticker: String) async throws -> TickerProfile?
}

enum AppConfig {
    static func requireString(_ key: String) -> String {
        guard
            let value = Bundle.main.object(forInfoDictionaryKey: key) as? String,
            !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        else {
            fatalError("Missing or empty Info.plist key: \(key)")
        }
        return value
    }

    static var finnhubAPIKey: String {
        requireString("FINNHUB_API_KEY")
    }
}

private final class FinnhubClient {
    private let session: URLSession
    private let apiKey: String
    private let baseURL = URL(string: "https://finnhub.io/api/v1")!

    init(session: URLSession = .shared, apiKey: String = AppConfig.finnhubAPIKey) {
        self.session = session
        self.apiKey = apiKey
    }

    func get<T: Decodable>(_ type: T.Type, path: String, queryItems: [URLQueryItem]) async throws -> T {
        var comps = URLComponents(url: baseURL.appendingPathComponent(path), resolvingAgainstBaseURL: false)!
        var items = queryItems
        items.append(URLQueryItem(name: "token", value: apiKey))
        comps.queryItems = items

        let (data, _) = try await session.data(from: comps.url!)
        return try JSONDecoder().decode(T.self, from: data)
    }
}

final class MarketDataService: MarketDataServiceProtocol {

    private let client = FinnhubClient()

    func fetchQuotes(tickers: [String]) async throws -> [String: MarketQuote] {
        let unique = Array(Set(tickers.map { $0.uppercased() }))

        return try await withThrowingTaskGroup(of: (String, MarketQuote?).self) { group in
            for t in unique {
                group.addTask { [client] in
                    let dto = try await client.get(FinnhubQuoteDTO.self, path: "quote", queryItems: [
                        URLQueryItem(name: "symbol", value: t)
                    ])
                    guard let c = dto.c, let pc = dto.pc, c > 0 else { return (t, nil) }
                    return (t, MarketQuote(currentPrice: c, previousClose: pc))
                }
            }

            var result: [String: MarketQuote] = [:]
            for try await (t, q) in group {
                if let q { result[t] = q }
            }
            return result
        }
    }

    func fetchLogoURLs(tickers: [String]) async throws -> [String: URL?] {
        let unique = Array(Set(tickers.map { $0.uppercased() }))

        return try await withThrowingTaskGroup(of: (String, URL?).self) { group in
            for t in unique {
                group.addTask { [client] in
                    let dto = try await client.get(FinnhubProfileDTO.self, path: "stock/profile2", queryItems: [
                        URLQueryItem(name: "symbol", value: t)
                    ])
                    return (t, dto.logo.flatMap(URL.init(string:)))
                }
            }

            var result: [String: URL?] = [:]
            for try await (t, url) in group {
                result[t] = url
            }
            return result
        }
    }

    func fetchProfile(ticker: String) async throws -> TickerProfile? {
        let dto = try await client.get(FinnhubProfileDTO.self, path: "stock/profile2", queryItems: [
            URLQueryItem(name: "symbol", value: ticker.uppercased())
        ])
        
        guard let name = dto.name, !name.isEmpty else { return nil }
        return TickerProfile(name: name, logoURL: dto.logo.flatMap(URL.init(string:)))
    }
}
