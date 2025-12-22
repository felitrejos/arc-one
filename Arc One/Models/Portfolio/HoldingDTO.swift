//
//  HoldingDTO.swift
//  Arc One
//
//  Created by Felipe Trejos on 22/12/25.
//

import FirebaseFirestore

struct HoldingDTO {
    let id: String
    let ticker: String
    let quantity: Double
    let avgBuyPrice: Double
    let buyDate: Timestamp

    init?(doc: QueryDocumentSnapshot) {
        let d = doc.data()

        guard
            let ticker = d["ticker"] as? String,
            let quantity = d["quantity"] as? Double,
            let avgBuyPrice = d["avgBuyPrice"] as? Double,
            let buyDate = d["buyDate"] as? Timestamp
        else { return nil }

        self.id = doc.documentID
        self.ticker = ticker
        self.quantity = quantity
        self.avgBuyPrice = avgBuyPrice
        self.buyDate = buyDate
    }
}
