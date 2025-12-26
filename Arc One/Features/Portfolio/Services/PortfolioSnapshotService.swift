import Foundation
import FirebaseFirestore

struct PortfolioSnapshot {
    let dayId: String
    let dayStartUTC: Date
    let equityUSD: Double
    
    init?(data: [String: Any]) {
        guard
            let dayId = data["dayId"] as? String,
            let ts = data["dayStartUTC"] as? Timestamp,
            let equity = data["equityUSD"] as? Double
        else { return nil }
        
        self.dayId = dayId
        self.dayStartUTC = ts.dateValue()
        self.equityUSD = equity
    }
    
    init(dayId: String, dayStartUTC: Date, equityUSD: Double) {
        self.dayId = dayId
        self.dayStartUTC = dayStartUTC
        self.equityUSD = equityUSD
    }
}

final class PortfolioSnapshotService {

    private let db = FirebaseManager.db

    private var col: CollectionReference? {
        guard let uid = FirebaseManager.uid else { return nil }
        return db.collection("users").document(uid).collection("portfolio_snapshots")
    }
    
    // MARK: - Date Utilities
    
    /// Get the start of day in UTC for a given date
    static func utcDayStart(for date: Date) -> Date {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(secondsFromGMT: 0)!
        return cal.startOfDay(for: date)
    }
    
    /// Generate a day ID string (yyyy-MM-dd) for a given UTC date
    static func dayId(for dayStartUTC: Date) -> String {
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .gregorian)
        f.timeZone = TimeZone(secondsFromGMT: 0)
        f.dateFormat = "yyyy-MM-dd"
        return f.string(from: dayStartUTC)
    }
    
    // MARK: - CRUD

    func upsert(snapshot: PortfolioSnapshot) async throws {
        guard let col else { return }
        try await col.document(snapshot.dayId).setData([
            "dayId": snapshot.dayId,
            "dayStartUTC": Timestamp(date: snapshot.dayStartUTC),
            "equityUSD": snapshot.equityUSD,
            "updatedAt": FieldValue.serverTimestamp()
        ], merge: true)
    }

    func fetchSnapshots(lastNDays days: Int) async throws -> [PortfolioSnapshot] {
        guard let col else { return [] }

        let to = Self.utcDayStart(for: Date())
        let from = to.addingTimeInterval(TimeInterval(-(days - 1) * 86400))

        let qs = try await col
            .whereField("dayStartUTC", isGreaterThanOrEqualTo: Timestamp(date: from))
            .order(by: "dayStartUTC", descending: false)
            .getDocuments()

        return qs.documents.compactMap { PortfolioSnapshot(data: $0.data()) }
    }
}
