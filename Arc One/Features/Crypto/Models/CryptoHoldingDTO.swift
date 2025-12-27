import FirebaseFirestore

struct CryptoHoldingDTO {
    let id: String
    let coinId: String      // CoinGecko ID: "bitcoin", "ethereum"
    let symbol: String      // "BTC", "ETH"
    let quantity: Double
    let avgBuyPrice: Double
    
    init?(doc: DocumentSnapshot) {
        guard let data = doc.data(),
              let coinId = data["coinId"] as? String,
              let symbol = data["symbol"] as? String,
              let quantity = data["quantity"] as? Double,
              let avgBuyPrice = data["avgBuyPrice"] as? Double
        else { return nil }
        
        self.id = doc.documentID
        self.coinId = coinId
        self.symbol = symbol
        self.quantity = quantity
        self.avgBuyPrice = avgBuyPrice
    }
}
