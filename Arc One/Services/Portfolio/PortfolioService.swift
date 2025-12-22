//
//  PortfolioRepository.swift
//  Arc One
//
//  Created by Felipe Trejos on 22/12/25.
//

import FirebaseFirestore

final class PortfolioService {

    private let db = FirebaseManager.db

    func addHolding(
        ticker: String,
        quantity: Double,
        avgBuyPrice: Double
    ) async throws {
        guard let uid = FirebaseManager.uid else { return }

        let data: [String: Any] = [
            "ticker": ticker,
            "quantity": quantity,
            "avgBuyPrice": avgBuyPrice,
            "buyDate": Timestamp(date: Date()),
            "createdAt": FieldValue.serverTimestamp(),
            "updatedAt": FieldValue.serverTimestamp(),
            "assetType": "stock"
        ]

        try await db
            .collection("users")
            .document(uid)
            .collection("holdings")
            .addDocument(data: data)
    }

    func listenHoldings(
        onChange: @escaping ([HoldingDTO]) -> Void
    ) -> ListenerRegistration? {
        guard let uid = FirebaseManager.uid else { return nil }

        return db
            .collection("users")
            .document(uid)
            .collection("holdings")
            .order(by: "createdAt", descending: true)
            .addSnapshotListener { snapshot, _ in
                let result = snapshot?.documents.compactMap {
                    HoldingDTO(doc: $0)
                } ?? []

                onChange(result)
            }
    }
}
