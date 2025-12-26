import FirebaseFirestore

final class PortfolioService {

    private let db = FirebaseManager.db

    func addHolding(
        ticker: String,
        market: String,
        quantity: Double,
        avgBuyPrice: Double
    ) async throws {
        guard let uid = FirebaseManager.uid else { return }
        
        let col = db.collection("users").document(uid).collection("holdings")
        
        // Check for existing holding with same ticker
        let existing = try await col
            .whereField("ticker", isEqualTo: ticker)
            .limit(to: 1)
            .getDocuments()
        
        if let doc = existing.documents.first,
           let oldQty = doc.data()["quantity"] as? Double,
           let oldPrice = doc.data()["avgBuyPrice"] as? Double {
            
            // Calculate weighted average price
            let newQty = oldQty + quantity
            let newAvgPrice = ((oldQty * oldPrice) + (quantity * avgBuyPrice)) / newQty
            
            // Update existing document
            try await doc.reference.updateData([
                "quantity": newQty,
                "avgBuyPrice": newAvgPrice,
                "updatedAt": FieldValue.serverTimestamp()
            ])
        } else {
            // Create new document
            try await col.addDocument(data: [
                "ticker": ticker,
                "market": market,
                "quantity": quantity,
                "avgBuyPrice": avgBuyPrice,
                "buyDate": Timestamp(date: Date()),
                "createdAt": FieldValue.serverTimestamp(),
                "updatedAt": FieldValue.serverTimestamp(),
                "assetType": "stock"
            ])
        }
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

    func deleteHolding(id: String) async throws {
        guard let uid = FirebaseManager.uid else { return }

        try await db
            .collection("users")
            .document(uid)
            .collection("holdings")
            .document(id)
            .delete()
    }
}
