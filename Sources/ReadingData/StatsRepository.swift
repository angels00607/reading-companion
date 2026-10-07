import Foundation
import GRDB
import ReadingDomain

extension LocalStore: StatsRepository {
    #if DEBUG
    /// Explicit fictional stored-history fixture, never an import or live progress command.
    public func prepareStatsHistoricalPercentageQA(readingID: UUID) throws {
        try queue.write { db in
            try db.execute(sql:"UPDATE readings SET progress_mode='percentage',progress_percentage=100,current_page=NULL,total_pages=NULL WHERE owner_id=? AND id=? AND historical=1 AND status='read'",arguments:[ownerID.uuidString,readingID.uuidString])
        }
    }
    #endif
    public func stats(period: StatsPeriod) throws -> StatsSnapshot {
        guard period.valid else { throw StatsError.invalidPeriod }
        return try queue.read { db in try statsSnapshot(period, db) }
    }
    private func statsSnapshot(_ period: StatsPeriod, _ db: Database) throws -> StatsSnapshot {
        // Three batched fact queries plus one selections query; no per-Book hydration/N+1.
        let rows = try Row.fetchAll(db, sql: """
            SELECT r.*,b.title,b.author,b.cover_ref AS book_cover,e.cover_ref AS edition_cover
            FROM readings r JOIN books b ON b.owner_id=r.owner_id AND b.id=r.book_id
            LEFT JOIN editions e ON e.owner_id=r.owner_id AND e.id=r.edition_id
            WHERE r.owner_id=? AND r.deleted_at IS NULL AND b.deleted_at IS NULL
            """, arguments:[ownerID.uuidString])
        let observations=try Row.fetchAll(db,sql:"SELECT * FROM progress_observations WHERE owner_id=? ORDER BY ordinal,rowid",arguments:[ownerID.uuidString])
        let byReading=Dictionary(grouping:observations,by:{ $0["reading_id"] as String })
        let activity=try Row.fetchAll(db,sql:"SELECT reading_id,activity_date FROM reading_activity_dates WHERE owner_id=? ORDER BY activity_date",arguments:[ownerID.uuidString])
        let byActivity=Dictionary(grouping:activity,by:{ $0["reading_id"] as String })
        let facts=try rows.map { row -> StatsReading in
            let rid:String=row["id"]
            let obs=byReading[rid] ?? []
            // Exact original-unit resolved deltas only. Never use edition or percentage equivalents.
            let deltas=obs.compactMap { o -> Int? in
                guard o["mode"] as String == "page", !(o["requires_review"] as Bool),
                    let old:Int=o["previous_page"], let new:Int=o["new_page"] else { return nil }
                return new-old
            }
            let firstPage:Int?=obs.first?["previous_page"]
            let coverage = !obs.isEmpty && deltas.count == obs.count && firstPage == 0 && row["progress_mode"] as String == "page"
            let pageSubtotal=deltas.reduce(0,+)
            let state:String=row["rating_state"]
            let rating:Rating = state == "rated" ? try .validatedStars(row["rating_whole"]) : state == "unrated" ? .noRating : .unknown
            let rawFormat:String?=row["journal_format"]
            let bookCover:String?=row["book_cover"], editionCover:String?=row["edition_cover"]
            return StatsReading(id:UUID(uuidString:rid)!,bookID:UUID(uuidString:row["book_id"])!,title:row["title"],author:row["author"],
                coverReference:bookCover ?? editionCover,status:ReadingStatus(rawValue:row["status"])!,finish:try statsDate(row["finish_date"]),
                rating:rating,genre:row["primary_genre"],format:rawFormat.flatMap(JournalFormat.init(rawValue:)),
                observedPages:deltas.isEmpty || pageSubtotal < 0 ? nil : pageSubtotal,pageCoverageComplete:coverage && pageSubtotal >= 0,
                activityDates:try (byActivity[rid] ?? []).map { try statsDate($0["activity_date"])! })
        }
        let selections=try Row.fetchAll(db,sql:"SELECT * FROM best_book_selections WHERE owner_id=?",arguments:[ownerID.uuidString]).map { row in
            let rid:String?=row["reading_id"]
            return BestBookSelection(id:UUID(uuidString:row["id"])!,scope:row["scope"],period:row["period"],readingID:rid.flatMap(UUID.init(uuidString:)),revision:row["revision"])
        }
        return StatsRules.snapshot(period:period,readings:facts,selections:selections)
    }
    public func selectBestBook(period: StatsPeriod, readingID: UUID?, expectedRevision: Int) throws {
        guard period.valid, let scope=period.selectionScope else { throw StatsError.invalidPeriod }
        try queue.write { db in
            let snapshot=try statsSnapshot(period,db)
            guard (snapshot.selection?.revision ?? 0) == expectedRevision else { throw DomainError.staleRevision }
            if let readingID, !snapshot.candidates.contains(where:{ $0.id == readingID }) { throw StatsError.ineligibleSelection }
            if snapshot.selection?.readingID == readingID { return }
            let id=snapshot.selection?.id ?? UUID()
            let value=BestBookSelection(id:id,scope:scope,period:period.key,readingID:readingID,revision:expectedRevision+1)
            try db.execute(sql:"""
                INSERT INTO best_book_selections(owner_id,id,scope,period,reading_id,revision,created_at,updated_at)
                VALUES(?,?,?,?,?,?,?,?) ON CONFLICT(owner_id,scope,period)
                DO UPDATE SET reading_id=excluded.reading_id,revision=excluded.revision,updated_at=excluded.updated_at
                """,arguments:[ownerID.uuidString,id.uuidString,scope,period.key,readingID?.uuidString,value.revision,stamp(),stamp()])
            try enqueueStats(id,"stats.best_book.select",expectedRevision,value,db)
        }
    }
    public func recordReadingActivity(readingID: UUID, date: ReadingDate, sourceReference: String) throws {
        guard !sourceReference.trimmingCharacters(in:.whitespacesAndNewlines).isEmpty else { throw StatsError.invalidActivity }
        try queue.write { db in
            let reading = try reading(readingID,db:db)
            if try Int.fetchOne(db,sql:"SELECT COUNT(*) FROM reading_activity_dates WHERE owner_id=? AND reading_id=? AND activity_date=?",arguments:[ownerID.uuidString,readingID.uuidString,date.isoString]) == 1 { return }
            try db.execute(sql:"INSERT INTO reading_activity_dates(owner_id,reading_id,activity_date,source,source_reference,recorded_at) VALUES(?,?,?,'user',?,?)",arguments:[ownerID.uuidString,readingID.uuidString,date.isoString,sourceReference,stamp()])
            if !reading.historical, reading.status != .dnf {
                try recordGamificationActivity(key:"reading-day:\(readingID.uuidString):\(date.isoString)",family:.frequency,entity:readingID,activityDate:date.isoString,db:db)
            }
            try enqueueStats(readingID,"stats.activity.record",0,["date":date.isoString,"sourceReference":sourceReference],db)
        }
    }
    private func statsDate(_ raw: String?) throws -> ReadingDate? {
        guard let raw else { return nil }; return try JSONDecoder().decode(ReadingDate.self,from:JSONEncoder().encode(raw))
    }
    private func enqueueStats<T:Encodable>(_ id:UUID,_ kind:String,_ revision:Int,_ payload:T,_ db:Database) throws {
        var generation=try String.fetchOne(db,sql:"SELECT generation FROM sync_state WHERE owner_id=?",arguments:[ownerID.uuidString])
        if generation == nil { generation=UUID().uuidString; try db.execute(sql:"INSERT INTO sync_state(owner_id,generation) VALUES(?,?)",arguments:[ownerID.uuidString,generation]) }
        try enqueue(.init(ownerID:ownerID,entityID:id,expectedRevision:revision,generation:UUID(uuidString:generation!)!,kind:kind,payload:try JSONEncoder().encode(payload)),db:db)
    }
}
