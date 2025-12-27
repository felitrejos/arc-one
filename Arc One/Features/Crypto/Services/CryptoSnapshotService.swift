import Foundation
import FirebaseFirestore

struct CryptoSnapshot {
    let dayId: String
    let date: Date
    let equityUSD: Double
    
    init(date: Date, equityUSD: Double) {
        self.dayId = Self.dayId(for: date)
        self.date = date
        self.equityUSD = equityUSD
    }
    
    init?(data: [String: Any]) {
        guard
            let dayId = data["dayId"] as? String,
            let ts = data["date"] as? Timestamp,
            let equity = data["equityUSD"] as? Double
        else { return nil }
        
        self.dayId = dayId
        self.date = ts.dateValue()
        self.equityUSD = equity
    }
    
    static func dayId(for date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.timeZone = TimeZone(secondsFromGMT: 0)
        return f.string(from: date)
    }
}

final class CryptoSnapshotService {

    private let db = FirebaseManager.db

    private var col: CollectionReference? {
        guard let uid = FirebaseManager.uid else { return nil }
        return db.collection("users").document(uid).collection("crypto_snapshots")
    }

    func save(snapshot: CryptoSnapshot) async throws {
        guard let col else { return }
        try await col.document(snapshot.dayId).setData([
            "dayId": snapshot.dayId,
            "date": Timestamp(date: snapshot.date),
            "equityUSD": snapshot.equityUSD
        ])
    }

    func fetchSnapshots(lastNDays days: Int) async throws -> [CryptoSnapshot] {
        guard let col else { return [] }

        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        guard let from = calendar.date(byAdding: .day, value: -(days - 1), to: today) else { return [] }

        let qs = try await col
            .whereField("date", isGreaterThanOrEqualTo: Timestamp(date: from))
            .order(by: "date", descending: false)
            .getDocuments()

        return qs.documents.compactMap { CryptoSnapshot(data: $0.data()) }
    }
}
