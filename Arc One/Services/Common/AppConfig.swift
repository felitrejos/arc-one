import Foundation

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
    
    static var coinGeckoAPIKey: String {
        requireString("COINGECKO_API_KEY")
    }
}
