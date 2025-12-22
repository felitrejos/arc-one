import Foundation

enum Formatters {
    static let currency: NumberFormatter = {
        let f = NumberFormatter()
        f.numberStyle = .currency
        f.currencyCode = "USD"
        return f
    }()

    static func percentText(_ value: Double) -> String {
        let sign = value >= 0 ? "▲" : "▼"
        return "\(sign) \(String(format: "%.2f", abs(value)))%"
    }
}
