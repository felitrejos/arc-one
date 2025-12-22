import Foundation
import FirebaseFirestore

struct PortfolioSnapshot {
    let dayId: String
    let dayStartUTC: Date
    let equityUSD: Double
}

final class PortfolioSnapshotService {

    private let db = FirebaseManager.db

    private var col: CollectionReference? {
        guard let uid = FirebaseManager.uid else { return nil }
        return db.collection("users").document(uid).collection("portfolio_snapshots")
    }

    func upsert(snapshot: PortfolioSnapshot) async throws {
        guard let col else {
            print("[SnapshotService] Cannot upsert: user not authenticated (uid is nil)")
            return
        }
        try await col.document(snapshot.dayId).setData([
            "dayId": snapshot.dayId,
            "dayStartUTC": Timestamp(date: snapshot.dayStartUTC),
            "equityUSD": snapshot.equityUSD,
            "updatedAt": FieldValue.serverTimestamp()
        ], merge: true)
    }

    func latestSnapshot() async throws -> PortfolioSnapshot? {
        guard let col else {
            print("[SnapshotService] Cannot fetch latest: user not authenticated (uid is nil)")
            return nil
        }
        let snap = try await col
            .order(by: "dayStartUTC", descending: true)
            .limit(to: 1)
            .getDocuments()

        guard let doc = snap.documents.first else { return nil }
        let d = doc.data()
        guard
            let dayId = d["dayId"] as? String,
            let ts = d["dayStartUTC"] as? Timestamp,
            let equity = d["equityUSD"] as? Double
        else { return nil }

        return PortfolioSnapshot(dayId: dayId, dayStartUTC: ts.dateValue(), equityUSD: equity)
    }

    func fetchSnapshots(lastNDays days: Int) async throws -> [PortfolioSnapshot] {
        guard let col else {
            print("[SnapshotService] Cannot fetch snapshots: user not authenticated (uid is nil)")
            return []
        }

        let now = Date()
        let to = PortfolioHistoryBuilder.utcDayStart(for: now)
        let from = to.addingTimeInterval(TimeInterval(-(days - 1) * 24 * 60 * 60))

        let qs = try await col
            .whereField("dayStartUTC", isGreaterThanOrEqualTo: Timestamp(date: from))
            .order(by: "dayStartUTC", descending: false)
            .getDocuments()

        return qs.documents.compactMap { doc in
            let d = doc.data()
            guard
                let dayId = d["dayId"] as? String,
                let ts = d["dayStartUTC"] as? Timestamp,
                let equity = d["equityUSD"] as? Double
            else { return nil }

            return PortfolioSnapshot(dayId: dayId, dayStartUTC: ts.dateValue(), equityUSD: equity)
        }
    }
}
