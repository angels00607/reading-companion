import Foundation
import GRDB
import ReadingDomain

extension LocalStore: SeriesRepository {
    public func series(query: String = "", filter: SeriesFilter = .all, sort: SeriesSort = .recentlyUpdated) throws -> [SeriesDetail] {
        try queue.read { db in
            var sql = "SELECT DISTINCT s.id FROM series s LEFT JOIN series_entries e ON e.owner_id=s.owner_id AND e.series_id=s.id WHERE s.owner_id=?"
            var arguments: [DatabaseValue] = [ownerID.uuidString.databaseValue]
            let value = query.trimmingCharacters(in: .whitespacesAndNewlines)
            if !value.isEmpty {
                let escaped = value.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "%", with: "\\%").replacingOccurrences(of: "_", with: "\\_")
                sql += " AND (s.name LIKE ? ESCAPE '\\' OR e.title LIKE ? ESCAPE '\\')"
                arguments += [("%" + escaped + "%").databaseValue, ("%" + escaped + "%").databaseValue]
            }
            let details = try String.fetchAll(db, sql: sql, arguments: StatementArguments(arguments)).map { try detail(UUID(uuidString: $0)!, db) }
            let filtered = details.filter { detail in
                switch filter {
                case .all: true
                case .active: detail.series.effectiveStatus == .active
                case .waiting: detail.series.effectiveStatus == .waiting
                case .completed: detail.series.effectiveStatus == .completed
                case .abandoned: detail.series.effectiveStatus == .abandoned
                case .needsAttention: (try? proposalCount(detail.series.id, db)) ?? 0 > 0
                }
            }
            return filtered.sorted { lhs, rhs in
                switch sort {
                case .recentlyUpdated: return lhs.series.updatedAt > rhs.series.updatedAt
                case .alphabetical: return lhs.series.name.localizedCaseInsensitiveCompare(rhs.series.name) == .orderedAscending
                case .progress:
                    let lp = lhs.confirmedTotal == 0 ? -1 : Double(lhs.readConfirmed) / Double(lhs.confirmedTotal)
                    let rp = rhs.confirmedTotal == 0 ? -1 : Double(rhs.readConfirmed) / Double(rhs.confirmedTotal)
                    return lp == rp ? lhs.series.name < rhs.series.name : lp > rp
                case .recentlyRead: return lhs.readConfirmed == rhs.readConfirmed ? lhs.series.updatedAt > rhs.series.updatedAt : lhs.readConfirmed > rhs.readConfirmed
                }
            }
        }
    }

    public func seriesDetail(id: UUID) throws -> SeriesDetail { try queue.read { try detail(id, $0) } }

    public func saveSeries(_ series: ReadingSeries, entries: [SeriesEntry]) throws {
        guard series.ownerID == ownerID, !series.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              entries.allSatisfy({ $0.seriesID == series.id && !$0.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }) else { throw DomainError.invalidTransition }
        try queue.write { db in
            let evidence = String(data: try JSONEncoder().encode(series.evidence), encoding: .utf8)!
            try db.execute(sql: "INSERT INTO series(owner_id,id,name,author,user_status_override,evidence_json,final_total_known,updated_at) VALUES(?,?,?,?,?,?,?,?) ON CONFLICT(owner_id,id) DO UPDATE SET name=excluded.name,author=excluded.author,user_status_override=excluded.user_status_override,evidence_json=excluded.evidence_json,final_total_known=excluded.final_total_known,updated_at=excluded.updated_at", arguments: [ownerID.uuidString,series.id.uuidString,series.name,series.author,series.userStatusOverride?.rawValue,evidence,series.finalTotalKnown,stamp(series.updatedAt)])
            for entry in entries {
                let release = releaseColumns(entry.release)
                try db.execute(sql: "INSERT INTO series_entries(owner_id,id,series_id,book_id,title,position,kind,publication,release_precision,release_value,included,tracker_included) VALUES(?,?,?,?,?,?,?,?,?,?,?,?) ON CONFLICT(owner_id,id) DO UPDATE SET book_id=excluded.book_id,title=excluded.title,position=excluded.position,kind=excluded.kind,publication=excluded.publication,release_precision=excluded.release_precision,release_value=excluded.release_value,included=excluded.included,tracker_included=excluded.tracker_included", arguments: [ownerID.uuidString,entry.id.uuidString,series.id.uuidString,entry.bookID?.uuidString,entry.title,NSDecimalNumber(decimal: entry.position).stringValue,entry.kind.rawValue,entry.publication.rawValue,release.0,release.1,entry.included,entry.includedInTracker])
            }
            try db.execute(sql: """
                UPDATE journal_components SET state='ready'
                WHERE owner_id=? AND component='series' AND state='pending'
                  AND reading_id IN (
                    SELECT r.id FROM readings r JOIN series_entries e
                    ON e.owner_id=r.owner_id AND e.book_id=r.book_id
                    WHERE e.owner_id=? AND e.series_id=? AND e.included=1 AND r.status='read'
                  )
                """, arguments: [ownerID.uuidString,ownerID.uuidString,series.id.uuidString])
        }
    }

    public func setStatusOverride(seriesID: UUID, status: SeriesStatus?) throws { try queue.write { db in
        guard try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM series WHERE owner_id=? AND id=?", arguments: [ownerID.uuidString,seriesID.uuidString]) == 1 else { throw DomainError.invalidTransition }
        try db.execute(sql: "UPDATE series SET user_status_override=?,updated_at=? WHERE owner_id=? AND id=?", arguments: [status?.rawValue,stamp(),ownerID.uuidString,seriesID.uuidString])
    } }
    public func setTrackerInclusion(entryID: UUID, included: Bool) throws { try queue.write { db in
        try db.execute(sql: "UPDATE series_entries SET tracker_included=? WHERE owner_id=? AND id=?", arguments: [included,ownerID.uuidString,entryID.uuidString])
    } }

    public func proposals(seriesID: UUID? = nil) throws -> [SeriesChangeProposal] { try queue.read { db in
        var sql = "SELECT * FROM data_change_proposals WHERE owner_id=? AND entity_type='series' AND status='pending'"
        var args: [DatabaseValue] = [ownerID.uuidString.databaseValue]
        if let seriesID { sql += " AND entity_id=?"; args.append(seriesID.uuidString.databaseValue) }
        sql += " ORDER BY rowid"
        return try Row.fetchAll(db, sql: sql, arguments: StatementArguments(args)).map { row in
            SeriesChangeProposal(id: UUID(uuidString: row["id"])!, seriesID: UUID(uuidString: row["entity_id"])!, field: row["field"], current: row["current_json"], proposed: row["proposed_json"], source: row["source"] ?? "Catalogue", evidenceFingerprint: row["evidence_fingerprint"])
        }
    } }
    public func propose(seriesID: UUID, field: String, current: String, proposed: String, source: String, evidenceFingerprint: String) throws {
        guard current != proposed, !evidenceFingerprint.isEmpty else { return }
        try queue.write { db in
            _ = try detail(seriesID, db)
            let rejected = try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM series_rejections WHERE owner_id=? AND series_id=? AND field=? AND evidence_fingerprint=?", arguments: [ownerID.uuidString,seriesID.uuidString,field,evidenceFingerprint]) ?? 0
            guard rejected == 0 else { return }
            try db.execute(sql: "INSERT OR IGNORE INTO data_change_proposals(owner_id,id,entity_id,entity_type,field,current_json,proposed_json,evidence_fingerprint,status,source) VALUES(?,?,?,'series',?,?,?,?, 'pending',?)", arguments: [ownerID.uuidString,UUID().uuidString,seriesID.uuidString,field,current,proposed,evidenceFingerprint,source])
        }
    }
    public func acceptProposal(id: UUID) throws { try queue.write { db in
        guard let row = try Row.fetchOne(db, sql: "SELECT * FROM data_change_proposals WHERE owner_id=? AND id=? AND entity_type='series' AND status='pending'", arguments: [ownerID.uuidString,id.uuidString]) else { throw DomainError.invalidTransition }
        let seriesID: String = row["entity_id"], field: String = row["field"], proposed: String = row["proposed_json"]
        if field == "Series name" { try db.execute(sql: "UPDATE series SET name=?,updated_at=? WHERE owner_id=? AND id=?", arguments: [proposed,stamp(),ownerID.uuidString,seriesID]) }
        else if field == "Status", let status = SeriesStatus(rawValue: proposed) { try db.execute(sql: "UPDATE series SET user_status_override=?,updated_at=? WHERE owner_id=? AND id=?", arguments: [status.rawValue,stamp(),ownerID.uuidString,seriesID]) }
        else if field == "Position", Decimal(string: proposed) != nil {
            let matches = try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM series_entries WHERE owner_id=? AND series_id=? AND position=?", arguments: [ownerID.uuidString,seriesID,row["current_json"] as String]) ?? 0
            guard matches == 1 else { throw DomainError.invalidTransition }
            try db.execute(sql: "UPDATE series_entries SET position=? WHERE owner_id=? AND series_id=? AND position=?", arguments: [proposed,ownerID.uuidString,seriesID,row["current_json"] as String])
        }
        else { throw DomainError.invalidTransition }
        try db.execute(sql: "UPDATE data_change_proposals SET status='accepted' WHERE owner_id=? AND id=?", arguments: [ownerID.uuidString,id.uuidString])
    } }
    public func rejectProposal(id: UUID) throws { try queue.write { db in
        guard let row = try Row.fetchOne(db, sql: "SELECT entity_id,field,evidence_fingerprint FROM data_change_proposals WHERE owner_id=? AND id=? AND entity_type='series' AND status='pending'", arguments: [ownerID.uuidString,id.uuidString]) else { throw DomainError.invalidTransition }
        try db.execute(sql: "INSERT OR IGNORE INTO series_rejections(owner_id,series_id,field,evidence_fingerprint,rejected_at) VALUES(?,?,?,?,?)", arguments: [ownerID.uuidString,row["entity_id"] as String,row["field"] as String,row["evidence_fingerprint"] as String,stamp()])
        try db.execute(sql: "UPDATE data_change_proposals SET status='kept' WHERE owner_id=? AND id=?", arguments: [ownerID.uuidString,id.uuidString])
    } }
    public func setSeriesJournalReady(readingID: UUID, ready: Bool) throws { try queue.write { db in
        let state = ready ? "ready" : "pending"
        try db.execute(sql: "UPDATE journal_components SET state=? WHERE owner_id=? AND reading_id=? AND component='series' AND state<>'copied'", arguments: [state,ownerID.uuidString,readingID.uuidString])
    } }

    private func detail(_ id: UUID, _ db: Database) throws -> SeriesDetail {
        guard let row = try Row.fetchOne(db, sql: "SELECT * FROM series WHERE owner_id=? AND id=?", arguments: [ownerID.uuidString,id.uuidString]) else { throw DomainError.invalidTransition }
        let evidence: SeriesStatusEvidence = try JSONDecoder().decode(SeriesStatusEvidence.self, from: Data((row["evidence_json"] as String).utf8))
        let updated = ISO8601DateFormatter().date(from: row["updated_at"]) ?? .distantPast
        let entries = try Row.fetchAll(db, sql: "SELECT e.*, EXISTS(SELECT 1 FROM readings r WHERE r.owner_id=e.owner_id AND r.book_id=e.book_id AND r.status='read' AND r.deleted_at IS NULL) AS is_read FROM series_entries e WHERE e.owner_id=? AND e.series_id=?", arguments: [ownerID.uuidString,id.uuidString]).map { entry -> SeriesEntry in
            let book: String? = entry["book_id"], precision: String = entry["release_precision"], stored: String? = entry["release_value"]
            let release: ReleaseValue = try precision == "exact" ? .exact(JSONDecoder().decode(ReadingDate.self, from: JSONEncoder().encode(stored!))) : precision == "year" ? .year(Int(stored!)!) : .unknown
            return SeriesEntry(id: UUID(uuidString: entry["id"])!, seriesID: id, bookID: book.flatMap(UUID.init(uuidString:)), title: entry["title"], position: Decimal(string: entry["position"] as String)!, kind: SeriesEntryKind(rawValue: entry["kind"])!, publication: PublicationState(rawValue: entry["publication"])!, release: release, included: entry["included"], includedInTracker: entry["tracker_included"], isRead: entry["is_read"])
        }
        let includedPublished = entries.filter { $0.included && $0.publication == .published }
        let includedConfirmed = SeriesRules.confirmedEntries(entries).filter(\.included)
        var derived = evidence
        if !includedPublished.isEmpty {
            derived.hasUnreadIncludedPublished = includedPublished.contains { !$0.isRead }
            derived.allIncludedPublishedRead = includedPublished.allSatisfy(\.isRead)
        }
        if !includedConfirmed.isEmpty { derived.allIncludedConfirmedRead = includedConfirmed.allSatisfy(\.isRead) }
        if entries.contains(where: { $0.included && $0.publication == .announced }) { derived.hasAnnouncedOrExpectedFutureEntry = true }
        let value = ReadingSeries(id: id, ownerID: ownerID, name: row["name"], author: row["author"], userStatusOverride: (row["user_status_override"] as String?).flatMap(SeriesStatus.init(rawValue:)), evidence: derived, finalTotalKnown: row["final_total_known"], updatedAt: updated)
        return SeriesDetail(series: value, entries: entries)
    }
    private func proposalCount(_ id: UUID, _ db: Database) throws -> Int { try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM data_change_proposals WHERE owner_id=? AND entity_type='series' AND entity_id=? AND status='pending'", arguments: [ownerID.uuidString,id.uuidString]) ?? 0 }
    private func releaseColumns(_ value: ReleaseValue) -> (String,String?) { switch value { case .exact(let date): ("exact",date.isoString); case .year(let year): ("year",String(year)); case .unknown: ("unknown",nil) } }
}
