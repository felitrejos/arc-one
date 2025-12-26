import Foundation
import FirebaseFirestore

struct IntradayPoint {
    let timestamp: Date
    let equityUSD: Double
    
    init(timestamp: Date, equityUSD: Double) {
        self.timestamp = timestamp
        self.equityUSD = equityUSD
    }
    
    init?(data: [String: Any]) {
        guard
            let ts = data["timestamp"] as? Timestamp,
            let equity = data["equityUSD"] as? Double
        else { return nil }
        
        self.timestamp = ts.dateValue()
        self.equityUSD = equity
    }
    
    var firestoreData: [String: Any] {
        ["timestamp": Timestamp(date: timestamp), "equityUSD": equityUSD]
    }
}

final class IntradayPointService {
    
    private let db = FirebaseManager.db
    
    private var col: CollectionReference? {
        guard let uid = FirebaseManager.uid else { return nil }
        return db.collection("users").document(uid).collection("intraday_points")
    }
    
    func save(point: IntradayPoint) async throws {
        guard let col else { return }
        let docId = String(Int(point.timestamp.timeIntervalSince1970))
        try await col.document(docId).setData(point.firestoreData)
    }
    
    func fetchTodayPoints() async throws -> [IntradayPoint] {
        guard let col else { return [] }
        
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        
        guard let dayStart = calendar.date(bySettingHour: 15, minute: 30, second: 0, of: today),
              let dayEnd = calendar.date(bySettingHour: 22, minute: 0, second: 0, of: today) else {
            return []
        }
        
        let qs = try await col
            .whereField("timestamp", isGreaterThanOrEqualTo: Timestamp(date: dayStart))
            .whereField("timestamp", isLessThanOrEqualTo: Timestamp(date: dayEnd))
            .order(by: "timestamp", descending: false)
            .getDocuments()
        
        return qs.documents.compactMap { IntradayPoint(data: $0.data()) }
    }
    
    func fetchYesterdayLastPoint() async throws -> IntradayPoint? {
        guard let col else { return nil }
        
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        
        let qs = try await col
            .whereField("timestamp", isLessThan: Timestamp(date: today))
            .order(by: "timestamp", descending: true)
            .limit(to: 1)
            .getDocuments()
        
        return qs.documents.first.flatMap { IntradayPoint(data: $0.data()) }
    }
    
    func deleteAll() async throws {
        guard let col else { return }
        
        let qs = try await col.getDocuments()
        guard !qs.documents.isEmpty else { return }
        
        let batch = db.batch()
        for doc in qs.documents {
            batch.deleteDocument(doc.reference)
        }
        try await batch.commit()
        
        print("[IntradayPointService] Deleted \(qs.documents.count) points")
    }
}
