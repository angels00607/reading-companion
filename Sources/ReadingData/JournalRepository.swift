import Foundation
import GRDB
import ReadingDomain

private struct ReviewSnapshot: Codable, Equatable {
    let title: String; let author: String; let pages: Int?; let rating: Rating
    let format: JournalFormat; let start: ReadingDate?; let finish: ReadingDate?; let summary: String
}

extension LocalStore: JournalRepository {
    func createJournalCompletionWork(reading: ReadingInstance, db: Database) throws {
        guard JournalRules.mayGenerateCompletionWork(status: reading.status, origin: reading.historical ? .historicalImport : .user),
              reading.status == .read else { return }
        let entryID = UUID()
        try db.execute(sql: "INSERT OR IGNORE INTO journal_entries(owner_id,id,reading_id,book_id,created_at) VALUES(?,?,?,?,?)",
                       arguments: [ownerID.uuidString,entryID.uuidString,reading.id.uuidString,reading.bookID.uuidString,stamp()])
        for component in JournalComponent.allCases {
            try db.execute(sql: "INSERT OR IGNORE INTO journal_components(owner_id,id,reading_id,component,state,purpose) VALUES(?,?,?,?, 'pending','completion')",
                           arguments: [ownerID.uuidString,UUID().uuidString,reading.id.uuidString,component.rawValue])
        }
        try db.execute(sql: "INSERT OR IGNORE INTO favorites(owner_id,book_id,decision) VALUES(?,?,'pending')",
                       arguments: [ownerID.uuidString,reading.bookID.uuidString])
        _ = try ensureVolume(db)
    }

    public func journalInbox() throws -> [JournalInboxItem] {
        try queue.read { db in
            try String.fetchAll(db, sql: "SELECT reading_id FROM journal_entries WHERE owner_id=? ORDER BY rowid DESC", arguments: [ownerID.uuidString]).map {
                try inboxItem(UUID(uuidString: $0)!, db: db)
            }
        }
    }
    public func journalEntry(readingID: UUID) throws -> JournalEntry { try queue.read { try entry(readingID, db: $0) } }
    private func entry(_ readingID: UUID, db: Database) throws -> JournalEntry {
        guard let row = try Row.fetchOne(db, sql: "SELECT * FROM journal_entries WHERE owner_id=? AND reading_id=?", arguments: [ownerID.uuidString,readingID.uuidString]) else { throw JournalError.missingEntry }
        var states = [JournalComponent: JournalComponentStatus]()
        for component in try Row.fetchAll(db, sql: "SELECT component,state FROM journal_components WHERE owner_id=? AND reading_id=?", arguments: [ownerID.uuidString,readingID.uuidString]) {
            if let kind = JournalComponent(rawValue: component["component"]), let state = JournalComponentStatus(rawValue: component["state"]) { states[kind] = state }
        }
        return JournalEntry(id: UUID(uuidString: row["id"])!, readingID: readingID, bookID: UUID(uuidString: row["book_id"])!, summary: row["summary"], pageCount: row["page_count"], components: states)
    }
    private func inboxItem(_ readingID: UUID, db: Database) throws -> JournalInboxItem {
        let value = try reading(readingID, db: db); let record = try catalog(value.bookID, db: db)
        return JournalInboxItem(entry: try entry(readingID, db: db), book: record.book, reading: value)
    }

    public func saveBookReview(readingID: UUID, draft: BookReviewDraft) throws {
        let summary = draft.summary.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !summary.isEmpty, draft.pageCount.map({ $0 > 0 }) ?? true else { throw JournalError.invalidSummary }
        try queue.write { db in
            var reading = try reading(readingID, db: db); guard reading.status == .read else { throw JournalError.missingEntry }
            let old = try copiedSnapshot(readingID, db: db)
            reading.rating = draft.rating; reading.startDate = draft.start; reading.finishDate = draft.finish
            try ReadingRules.setJournalFormat(draft.format, origin: .user, reading: &reading); reading.revision += 1
            try saveReadingForJournal(reading, db: db)
            try refreshChallengesAfterReadingEdit(readingID, db: db)
            try db.execute(sql: "UPDATE journal_entries SET summary=?,page_count=? WHERE owner_id=? AND reading_id=?", arguments: [summary,draft.pageCount,ownerID.uuidString,readingID.uuidString])
            let record = try catalog(reading.bookID, db: db)
            let current = ReviewSnapshot(title: record.book.title, author: record.book.author, pages: draft.pageCount, rating: draft.rating, format: draft.format, start: draft.start, finish: draft.finish, summary: summary)
            if let old { try createCorrections(readingID: readingID, old: old, current: current, db: db) }
            let state: JournalComponentStatus = JournalRules.bookReviewReady(summary: summary, rating: draft.rating, format: draft.format) ? .ready : .pending
            try db.execute(sql: "UPDATE journal_components SET state=? WHERE owner_id=? AND reading_id=? AND component='book_review' AND state<>'copied'", arguments: [state.rawValue,ownerID.uuidString,readingID.uuidString])
            try enqueueJournal(readingID, "journal.review.save", current, db)
        }
    }
    private func saveReadingForJournal(_ reading: ReadingInstance, db: Database) throws {
        var state = "unknown"; var stars: Int?
        switch reading.rating { case .unknown: break; case .noRating: state = "unrated"; case .stars(let value): state = "rated"; stars = value }
        try db.execute(sql: "UPDATE readings SET start_date=?,finish_date=?,rating_state=?,rating_whole=?,journal_format=?,revision=? WHERE owner_id=? AND id=?", arguments: [reading.startDate?.isoString,reading.finishDate?.isoString,state,stars,reading.journalFormat?.rawValue,reading.revision,ownerID.uuidString,reading.id.uuidString])
    }

    public func setFavorite(bookID: UUID, decision: JournalDecision) throws {
        try queue.write { db in
            _ = try catalog(bookID,db:db)
            let previous = try String.fetchOne(db,sql:"SELECT decision FROM favorites WHERE owner_id=? AND book_id=?",arguments:[ownerID.uuidString,bookID.uuidString])
            if previous != decision.rawValue {
                let day = QuestPeriod(cadence:.daily,now:gamificationNow(),timeZone:gamificationTimeZone).key
                try recordGamificationActivity(key:"organization:favorite:\(bookID.uuidString):\(day)",family:.organization,entity:bookID,db:db)
            }
            try db.execute(sql: "INSERT INTO favorites(owner_id,book_id,decision) VALUES(?,?,?) ON CONFLICT(owner_id,book_id) DO UPDATE SET decision=excluded.decision", arguments: [ownerID.uuidString,bookID.uuidString,decision.rawValue])
            let state = decision == .selected ? "ready" : decision == .none ? "none" : "pending"
            try db.execute(sql: "UPDATE journal_components SET state=? WHERE owner_id=? AND component='favorite' AND reading_id IN (SELECT reading_id FROM journal_entries WHERE owner_id=? AND book_id=?) AND state<>'copied'", arguments: [state,ownerID.uuidString,ownerID.uuidString,bookID.uuidString])
        }
    }
    public func favoriteDecision(bookID: UUID) throws -> JournalDecision { try queue.read { db in
        let value = try String.fetchOne(db, sql: "SELECT decision FROM favorites WHERE owner_id=? AND book_id=?", arguments: [ownerID.uuidString,bookID.uuidString]); return value.flatMap(JournalDecision.init(rawValue:)) ?? .pending
    } }
    public func quotes(bookID: UUID) throws -> [JournalQuote] { try queue.read { db in try Row.fetchAll(db, sql: "SELECT * FROM quotes WHERE owner_id=? AND book_id=? ORDER BY rowid", arguments: [ownerID.uuidString,bookID.uuidString]).map { row in
        let reading: String? = row["reading_id"]; let copied: String? = row["copied_at"]
        return JournalQuote(id: UUID(uuidString: row["id"])!, bookID: bookID, readingID: reading.flatMap(UUID.init(uuidString:)), text: row["quote_text"], source: row["source"], includeInJournal: row["include_in_journal"], copiedAt: copied.flatMap(ISO8601DateFormatter().date(from:)))
    } } }
    public func saveQuote(_ quote: JournalQuote) throws {
        let text = quote.text.trimmingCharacters(in: .whitespacesAndNewlines); guard !text.isEmpty else { throw JournalError.invalidQuote }
        try queue.write { db in
            _ = try catalog(quote.bookID, db: db)
            try db.execute(sql: "INSERT INTO quotes(owner_id,id,book_id,reading_id,quote_text,source,include_in_journal,copied_at) VALUES(?,?,?,?,?,?,?,?) ON CONFLICT(owner_id,id) DO UPDATE SET quote_text=excluded.quote_text,source=excluded.source,include_in_journal=excluded.include_in_journal", arguments: [ownerID.uuidString,quote.id.uuidString,quote.bookID.uuidString,quote.readingID?.uuidString,text,quote.source?.nilIfEmpty,quote.includeInJournal,quote.copiedAt.map(stamp)])
            if quote.includeInJournal, let readingID = quote.readingID { try db.execute(sql: "UPDATE journal_components SET state='ready' WHERE owner_id=? AND reading_id=? AND component='quote' AND state<>'copied'", arguments: [ownerID.uuidString,readingID.uuidString]) }
        }
    }
    public func deleteQuote(id: UUID) throws { try queue.write { try $0.execute(sql: "DELETE FROM quotes WHERE owner_id=? AND id=?", arguments: [ownerID.uuidString,id.uuidString]) } }
    public func markQuoteCopied(id: UUID) throws { try queue.write { db in
        guard let row = try Row.fetchOne(db, sql: "SELECT reading_id,include_in_journal FROM quotes WHERE owner_id=? AND id=?", arguments: [ownerID.uuidString,id.uuidString]), row["include_in_journal"] as Bool else { throw JournalError.notReady }
        let volume = try ensureVolume(db); let readingID: String? = row["reading_id"]
        try db.execute(sql: "UPDATE quotes SET copied_at=?,volume_id=? WHERE owner_id=? AND id=?", arguments: [stamp(),volume.uuidString,ownerID.uuidString,id.uuidString])
        if let readingID {
            let remaining = try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM quotes WHERE owner_id=? AND reading_id=? AND include_in_journal=1 AND copied_at IS NULL", arguments: [ownerID.uuidString,readingID]) ?? 0
            if remaining == 0 { try db.execute(sql: "UPDATE journal_components SET state='copied',copied_at=? WHERE owner_id=? AND reading_id=? AND component='quote'", arguments: [stamp(),ownerID.uuidString,readingID]) }
        }
    } }
    public func markFavoriteCopied(bookID: UUID, readingID: UUID) throws { try queue.write { db in
        guard try String.fetchOne(db, sql: "SELECT decision FROM favorites WHERE owner_id=? AND book_id=?", arguments: [ownerID.uuidString,bookID.uuidString]) == "selected" else { throw JournalError.notReady }
        let volume = try ensureVolume(db)
        try db.execute(sql: "UPDATE favorites SET copied_at=?,volume_id=? WHERE owner_id=? AND book_id=?", arguments: [stamp(),volume.uuidString,ownerID.uuidString,bookID.uuidString])
        try db.execute(sql: "UPDATE journal_components SET state='copied',copied_at=? WHERE owner_id=? AND reading_id=? AND component='favorite'", arguments: [stamp(),ownerID.uuidString,readingID.uuidString])
    } }
    public func setNoQuote(readingID: UUID, value: Bool) throws { try queue.write { db in
        _ = try entry(readingID, db: db); try db.execute(sql: "UPDATE journal_components SET state=? WHERE owner_id=? AND reading_id=? AND component='quote' AND state<>'copied'", arguments: [value ? "none" : "pending",ownerID.uuidString,readingID.uuidString])
    } }
    public func readyForSession() throws -> [JournalInboxItem] { try queue.read { db in
        try String.fetchAll(db, sql: "SELECT reading_id FROM journal_components WHERE owner_id=? AND component='book_review' AND state='ready' ORDER BY rowid", arguments: [ownerID.uuidString]).map { try inboxItem(UUID(uuidString: $0)!, db: db) }
    } }
    public func markBookReviewCopied(readingID: UUID) throws { try queue.write { db in
        let item = try inboxItem(readingID, db: db); guard item.entry.bookReviewState == .ready, let format = item.reading.journalFormat, let summary = item.entry.summary else { throw JournalError.notReady }
        let snapshot = ReviewSnapshot(title: item.book.title, author: item.book.author, pages: item.entry.pageCount, rating: item.reading.rating, format: format, start: item.reading.startDate, finish: item.reading.finishDate, summary: summary)
        let payload = String(data: try JSONEncoder().encode(snapshot), encoding: .utf8)!
        let volume = try ensureVolume(db)
        try db.execute(sql: "UPDATE journal_components SET state='copied',copied_payload=?,copied_at=? WHERE owner_id=? AND reading_id=? AND component='book_review'", arguments: [payload,stamp(),ownerID.uuidString,readingID.uuidString])
        try db.execute(sql: "UPDATE journal_entries SET volume_id=? WHERE owner_id=? AND reading_id=?", arguments: [volume.uuidString,ownerID.uuidString,readingID.uuidString])

        if !item.reading.historical {
            _ = try insertXPAward(try XPAward(semanticKey:"journal-work:\(readingID.uuidString):book-review",source:.journalWork,amount:GamificationBalance.amount(for:.journalWork)),db:db)
            try recordGamificationActivity(key:"journal-work:\(readingID.uuidString):book-review",family:.journalActivity,entity:readingID,db:db)
        }
        try enqueueJournal(readingID, "journal.review.copied", ["volume":volume.uuidString], db)
    } }
    public func corrections() throws -> [JournalCorrection] { try queue.read { db in try Row.fetchAll(db, sql: "SELECT * FROM journal_corrections WHERE owner_id=? ORDER BY status,created_at DESC", arguments: [ownerID.uuidString]).map { row in JournalCorrection(id: UUID(uuidString: row["id"])!, readingID: UUID(uuidString: row["reading_id"])!, component: JournalComponent(rawValue: row["component"])!, field: row["field"], previousValue: row["previous_value"], currentValue: row["current_value"], resolved: (row["status"] as String) == "resolved") } } }
    public func resolveCorrection(id: UUID) throws { try queue.write { try $0.execute(sql: "UPDATE journal_corrections SET status='resolved',resolved_at=? WHERE owner_id=? AND id=? AND status='pending'", arguments: [stamp(),ownerID.uuidString,id.uuidString]) } }
    public func journalUsage() throws -> JournalUsage { try queue.read { db in
        let id = try ensureVolume(db); let row = try Row.fetchOne(db, sql: "SELECT * FROM journal_volumes WHERE owner_id=? AND id=?", arguments: [ownerID.uuidString,id.uuidString])!
        let volume = JournalVolume(id: id, number: row["number"], archived: row["archived"], createdAt: ISO8601DateFormatter().date(from: row["created_at"])!, archivedAt: nil)
        let reviews = try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM journal_entries WHERE owner_id=? AND volume_id=?", arguments: [ownerID.uuidString,id.uuidString]) ?? 0
        let readings = try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM readings WHERE owner_id=? AND status='read'", arguments: [ownerID.uuidString]) ?? 0
        let favorites = try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM favorites WHERE owner_id=? AND decision='selected'", arguments: [ownerID.uuidString]) ?? 0
        let quotes = try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM quotes WHERE owner_id=? AND include_in_journal=1", arguments: [ownerID.uuidString]) ?? 0
        return JournalUsage(volume: volume, bookReviews: reviews, readingLogBooks: readings, favorites: favorites, quotes: quotes)
    } }
    public func archiveFullVolume() throws { try queue.write { db in
        let id = try ensureVolume(db)
        let reviews = try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM journal_entries WHERE owner_id=? AND volume_id=?", arguments: [ownerID.uuidString,id.uuidString]) ?? 0
        guard reviews >= JournalRules.bookReviewCapacity else { throw JournalError.volumeNotFull }
        try db.execute(sql: "UPDATE journal_volumes SET archived=1,archived_at=? WHERE owner_id=? AND id=?", arguments: [stamp(),ownerID.uuidString,id.uuidString])
        _ = try ensureVolume(db)
    } }

    private func ensureVolume(_ db: Database) throws -> UUID {
        if let value = try String.fetchOne(db, sql: "SELECT id FROM journal_volumes WHERE owner_id=? AND archived=0 ORDER BY number DESC LIMIT 1", arguments: [ownerID.uuidString]) { return UUID(uuidString: value)! }
        let id = UUID(); let number = (try Int.fetchOne(db, sql: "SELECT COALESCE(MAX(number),0)+1 FROM journal_volumes WHERE owner_id=?", arguments: [ownerID.uuidString])) ?? 1
        try db.execute(sql: "INSERT INTO journal_volumes(owner_id,id,number,created_at) VALUES(?,?,?,?)", arguments: [ownerID.uuidString,id.uuidString,number,stamp()]); return id
    }
    private func copiedSnapshot(_ readingID: UUID, db: Database) throws -> ReviewSnapshot? {
        guard let payload = try String.fetchOne(db, sql: "SELECT copied_payload FROM journal_components WHERE owner_id=? AND reading_id=? AND component='book_review' AND state='copied'", arguments: [ownerID.uuidString,readingID.uuidString]) else { return nil }
        return try JSONDecoder().decode(ReviewSnapshot.self, from: Data(payload.utf8))
    }
    private func createCorrections(readingID: UUID, old: ReviewSnapshot, current: ReviewSnapshot, db: Database) throws {
        let values: [(String,String,String)] = [("Title",old.title,current.title),("Author",old.author,current.author),("Pages",old.pages.map(String.init) ?? "Unknown",current.pages.map(String.init) ?? "Unknown"),("Rating",String(describing: old.rating),String(describing: current.rating)),("Format",old.format.rawValue,current.format.rawValue),("Start",old.start?.isoString ?? "Unknown",current.start?.isoString ?? "Unknown"),("Finish",old.finish?.isoString ?? "Unknown",current.finish?.isoString ?? "Unknown"),("Summary",old.summary,current.summary)]
        for (field,previous,now) in values where previous != now { try db.execute(sql: "INSERT INTO journal_corrections(owner_id,id,reading_id,component,field,previous_value,current_value,status,created_at) VALUES(?,?,?,'book_review',?,?,?,'pending',?)", arguments: [ownerID.uuidString,UUID().uuidString,readingID.uuidString,field,previous,now,stamp()]) }
    }
    private func enqueueJournal<T: Encodable>(_ id: UUID, _ kind: String, _ payload: T, _ db: Database) throws {
        var generation = try String.fetchOne(db, sql: "SELECT generation FROM sync_state WHERE owner_id=?", arguments: [ownerID.uuidString]); if generation == nil { generation = UUID().uuidString; try db.execute(sql: "INSERT INTO sync_state(owner_id,generation) VALUES(?,?)", arguments: [ownerID.uuidString,generation]) }
        try enqueue(MutationEnvelope(id: UUID(), ownerID: ownerID, entityID: id, expectedRevision: 0, generation: UUID(uuidString: generation!)!, kind: kind, payload: try JSONEncoder().encode(payload)), db: db)
    }
}

private extension String { var nilIfEmpty: String? { isEmpty ? nil : self } }
