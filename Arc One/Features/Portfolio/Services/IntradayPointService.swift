import Foundation
import FirebaseFirestore

/// A single intraday data point (timestamp + equity)
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
        [
            "timestamp": Timestamp(date: timestamp),
            "equityUSD": equityUSD
        ]
    }
}

/// Service for persisting intraday (1D) chart data points to Firestore
final class IntradayPointService {
    
    private let db = FirebaseManager.db
    
    /// Collection: users/{uid}/intraday_points
    private var col: CollectionReference? {
        guard let uid = FirebaseManager.uid else { return nil }
        return db.collection("users").document(uid).collection("intraday_points")
    }
    
    /// Save a new intraday point
    func save(point: IntradayPoint) async throws {
        guard let col else { return }
        
        // Use timestamp as document ID for uniqueness
        let docId = String(Int(point.timestamp.timeIntervalSince1970))
        try await col.document(docId).setData(point.firestoreData)
    }
    
    /// Fetch all intraday points for today (from 3:30pm onwards, local time)
    func fetchTodayPoints() async throws -> [IntradayPoint] {
        guard let col else { return [] }
        
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        
        // Start of today at 3:30pm (15:30)
        guard let dayStart = calendar.date(bySettingHour: 15, minute: 30, second: 0, of: today) else {
            return []
        }
        
        // End of today at 10pm (22:00)
        guard let dayEnd = calendar.date(bySettingHour: 22, minute: 0, second: 0, of: today) else {
            return []
        }
        
        let qs = try await col
            .whereField("timestamp", isGreaterThanOrEqualTo: Timestamp(date: dayStart))
            .whereField("timestamp", isLessThanOrEqualTo: Timestamp(date: dayEnd))
            .order(by: "timestamp", descending: false)
            .getDocuments()
        
        return qs.documents.compactMap { IntradayPoint(data: $0.data()) }
    }
    
    /// Delete old intraday points (older than today)
    func cleanupOldPoints() async throws {
        guard let col else { return }
        
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        
        let qs = try await col
            .whereField("timestamp", isLessThan: Timestamp(date: today))
            .getDocuments()
        
        let batch = db.batch()
        for doc in qs.documents {
            batch.deleteDocument(doc.reference)
        }
        
        if !qs.documents.isEmpty {
            try await batch.commit()
            print("[IntradayPointService] Cleaned up \(qs.documents.count) old points")
        }
    }
}
