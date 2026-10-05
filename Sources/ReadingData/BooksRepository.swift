import Foundation
import GRDB
import ReadingDomain

extension LocalStore: BooksRepository {
    public func library(query: String = "", view: LibraryView = .all, sort: LibrarySort = .recentlyAdded,
                        filters: LibraryFilters = LibraryFilters(), limit: Int = 50, offset: Int = 0) throws -> [CatalogRecord] {
        try queue.read { db in
            var sql = "SELECT b.id FROM books b JOIN library_memberships m ON m.owner_id=b.owner_id AND m.book_id=b.id WHERE b.owner_id=? AND b.deleted_at IS NULL AND m.removed_at IS NULL"
            var args: [DatabaseValue] = [ownerID.uuidString.databaseValue]
            let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty {
                let escaped = trimmed.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "%", with: "\\%").replacingOccurrences(of: "_", with: "\\_")
                sql += " AND (b.title LIKE ? ESCAPE '\\' OR b.author LIKE ? ESCAPE '\\' OR b.series_name LIKE ? ESCAPE '\\')"
                args += Array(repeating: ("%" + escaped + "%").databaseValue, count: 3)
            }
            if view == .toRead { sql += " AND m.wants_to_read=1 AND NOT EXISTS(SELECT 1 FROM readings r WHERE r.owner_id=b.owner_id AND r.book_id=b.id AND r.deleted_at IS NULL AND r.status='currently_reading')" }
            if view == .read { sql += " AND EXISTS(SELECT 1 FROM readings r WHERE r.owner_id=b.owner_id AND r.book_id=b.id AND r.deleted_at IS NULL AND r.status='read')" }
            var readingClauses = [String]()
            if view == .read { readingClauses.append("r.status='read'") }
            if let status = filters.status { readingClauses.append("r.status=?"); args.append(status.rawValue.databaseValue) }
            if let year = filters.year { readingClauses.append("substr(r.finish_date,1,4)=?"); args.append(String(year).databaseValue) }
            if let rating = filters.rating { readingClauses.append("r.rating_whole=?"); args.append(rating.databaseValue) }
            if let genre = filters.genre { readingClauses.append("r.primary_genre=?"); args.append(genre.databaseValue) }
            if let format = filters.format { readingClauses.append("r.journal_format=?"); args.append(format.rawValue.databaseValue) }
            if !readingClauses.isEmpty { sql += " AND EXISTS(SELECT 1 FROM readings r WHERE r.owner_id=b.owner_id AND r.book_id=b.id AND r.deleted_at IS NULL AND " + readingClauses.joined(separator: " AND ") + ")" }
            if let inSeries = filters.inSeries { sql += inSeries ? " AND b.series_name IS NOT NULL" : " AND b.series_name IS NULL" }
            let pages = "(SELECT e.page_count FROM editions e WHERE e.owner_id=b.owner_id AND e.book_id=b.id ORDER BY e.rowid DESC LIMIT 1)"
            let finished = "(SELECT MAX(r.finish_date) FROM readings r WHERE r.owner_id=b.owner_id AND r.book_id=b.id AND r.status='read' AND r.deleted_at IS NULL)"
            switch sort {
            case .recentlyAdded: sql += " ORDER BY m.added_at DESC,b.id"
            case .title: sql += " ORDER BY b.title COLLATE NOCASE,b.id"
            case .titleDescending: sql += " ORDER BY b.title COLLATE NOCASE DESC,b.id"
            case .author: sql += " ORDER BY b.author COLLATE NOCASE,b.id"
            case .authorDescending: sql += " ORDER BY b.author COLLATE NOCASE DESC,b.id"
            case .pages, .pagesDescending: sql += " ORDER BY \(pages) IS NULL,\(pages)" + (sort == .pagesDescending ? " DESC" : "") + ",b.id"
            case .recentlyFinished, .oldest: sql += " ORDER BY \(finished) IS NULL,\(finished)" + (sort == .recentlyFinished ? " DESC" : "") + ",b.id"
            case .rating: sql += " ORDER BY (SELECT MAX(r.rating_whole) FROM readings r WHERE r.owner_id=b.owner_id AND r.book_id=b.id AND r.status='read') DESC,b.id"
            }
            sql += " LIMIT ? OFFSET ?"; args += [max(1, limit).databaseValue, max(0, offset).databaseValue]
            return try String.fetchAll(db, sql: sql, arguments: StatementArguments(args)).map { try catalog(UUID(uuidString: $0)!, db: db) }
        }
    }
    public func record(id: UUID) throws -> CatalogRecord { try queue.read { try catalog(id, db: $0) } }
    func catalog(_ id: UUID, db: Database) throws -> CatalogRecord {
        guard let row = try Row.fetchOne(db, sql: "SELECT b.*,m.wants_to_read FROM books b JOIN library_memberships m ON b.owner_id=m.owner_id AND b.id=m.book_id WHERE b.owner_id=? AND b.id=? AND b.deleted_at IS NULL", arguments: [ownerID.uuidString,id.uuidString]) else { throw BooksError.missingRecord }
        let editions = try Row.fetchAll(db, sql: "SELECT * FROM editions WHERE owner_id=? AND book_id=? ORDER BY rowid DESC", arguments: [ownerID.uuidString,id.uuidString]).map { row in
            Edition(id: UUID(uuidString: row["id"])!, bookID: id, language: row["language"], pageCount: row["page_count"], title: row["edition_title"], isbn10: row["isbn10"], isbn13: row["isbn13"], coverReference: row["cover_ref"], publisher: row["publisher"])
        }
        let readings = try String.fetchAll(db, sql: "SELECT id FROM readings WHERE owner_id=? AND book_id=? AND deleted_at IS NULL ORDER BY rowid DESC", arguments: [ownerID.uuidString,id.uuidString]).map { try reading(UUID(uuidString: $0)!, db: db) }
        return CatalogRecord(book: Book(id: id, ownerID: ownerID, title: row["title"], author: row["author"]), editions: editions, readings: readings, wantsToRead: row["wants_to_read"], coverReference: row["cover_ref"], synopsis: row["synopsis"], seriesName: row["series_name"], genreSuggestion: row["genre_suggestion"], revision: row["revision"])
    }
    func reading(_ id: UUID, db: Database) throws -> ReadingInstance {
        guard let row = try Row.fetchOne(db, sql: "SELECT * FROM readings WHERE owner_id=? AND id=? AND deleted_at IS NULL", arguments: [ownerID.uuidString,id.uuidString]) else { throw BooksError.missingRecord }
        let mode: String = row["progress_mode"]
        let progress: ReadingProgress = try mode == "page" ? .pages(current: row["current_page"], total: row["total_pages"]) : .percentage(row["progress_percentage"])
        var value = ReadingInstance(id: id, bookID: UUID(uuidString: row["book_id"])!, status: ReadingStatus(rawValue: row["status"])!, progress: progress, historical: row["historical"])
        let editionID: String? = row["edition_id"]; value.editionID = editionID.flatMap(UUID.init(uuidString:))
        value.startDate = try date(row["start_date"]); value.finishDate = try date(row["finish_date"])
        value.primaryGenre = row["primary_genre"]; value.revision = row["revision"]
        let format: String? = row["journal_format"]; value.journalFormat = format.flatMap(JournalFormat.init(rawValue:))
        let ratingState: String = row["rating_state"]
        value.rating = ratingState == "unrated" ? .noRating : ratingState == "rated" ? try .validatedStars(row["rating_whole"]) : .unknown
        value = try withObservations(value, db: db)
        return value
    }
    private func withObservations(_ reading: ReadingInstance, db: Database) throws -> ReadingInstance {
        // Domain initializer keeps observation history private; hydrate using its Codable boundary.
        let rows = try Row.fetchAll(db, sql: "SELECT * FROM progress_observations WHERE owner_id=? AND reading_id=? ORDER BY ordinal,rowid", arguments: [ownerID.uuidString,reading.id.uuidString])
        var observations = [ProgressObservation]()
        for row in rows {
            let mode: String = row["mode"]
            let value: ReadingProgress = try mode == "page" ? .pages(current: row["new_page"], total: row["total_pages"]) : .percentage(row["new_percentage"])
            let priorPage: Int? = row["previous_page"]; let priorPercent: Double? = row["previous_percentage"]
            let previous: ReadingProgress? = try mode == "page" ? (priorPage == nil ? nil : .pages(current: priorPage, total: row["total_pages"])) : (priorPercent == nil ? nil : .percentage(priorPercent))
            observations.append(ProgressObservation(id: UUID(uuidString: row["id"])!, readingID: reading.id, expectedRevision: row["base_revision"], value: value, previous: previous, recordedAt: ISO8601DateFormatter().date(from: row["recorded_at"]) ?? .distantPast, requiresReview: row["requires_review"]))
        }
        return reading.restoringObservations(observations)
    }
    private func date(_ string: String?) throws -> ReadingDate? {
        guard let string else { return nil }
        return try JSONDecoder().decode(ReadingDate.self, from: JSONEncoder().encode(string))
    }
    public func add(work: WorkCandidate, edition: EditionCandidate? = nil, choice: DuplicateChoice = .review) throws -> UUID {
        try queue.write { db in try addRecord(work: work, edition: edition, choice: choice, db: db) }
    }
    private func addRecord(work: WorkCandidate, edition: EditionCandidate?, choice: DuplicateChoice, db: Database) throws -> UUID {
        let title = try BooksRules.validatedText(work.title), author = try BooksRules.validatedText(work.author)
        if let pages = edition?.pageCount, pages <= 0 { throw DomainError.invalidProgress }
            let exact = try String.fetchAll(db, sql: "SELECT DISTINCT book_id FROM provider_links WHERE owner_id=? AND provider=? AND reference=?", arguments: [ownerID.uuidString,work.provider,work.reference])
            let isbn = try String.fetchAll(db, sql: "SELECT DISTINCT book_id FROM editions WHERE owner_id=? AND ((isbn13 IS NOT NULL AND isbn13=?) OR (isbn10 IS NOT NULL AND isbn10=?))", arguments: [ownerID.uuidString,edition?.isbn13,edition?.isbn10])
            let similar = try Row.fetchAll(db, sql: "SELECT id,title,author FROM books WHERE owner_id=? AND deleted_at IS NULL", arguments: [ownerID.uuidString]).filter { row in
                BooksRules.possibleDuplicate(title: title, author: author, existingTitle: row["title"], existingAuthor: row["author"])
            }.map { $0["id"] as String }
            let candidates = Array(Set(exact + isbn + similar)).compactMap(UUID.init(uuidString:))
            let id: UUID; let isNew: Bool
            switch choice {
            case .reuse(let selected):
                _ = try catalog(selected, db: db); id = selected; isNew = false
            case .addAnyway: id = UUID(); isNew = true
            case .review:
                if exact.count == 1 && Set(isbn).subtracting(exact).isEmpty { id = UUID(uuidString: exact[0])!; isNew = false }
                else if !candidates.isEmpty { throw BooksError.duplicateNeedsReview(candidates) }
                else { id = UUID(); isNew = true }
            }
            if isNew {
                try db.execute(sql: "INSERT INTO books(id,owner_id,title,author,cover_ref,synopsis) VALUES(?,?,?,?,?,?)", arguments: [id.uuidString,ownerID.uuidString,title,author,work.coverReference,work.synopsis])
                try db.execute(sql: "INSERT INTO library_memberships(owner_id,book_id,wants_to_read,added_at) VALUES(?,?,1,?)", arguments: [ownerID.uuidString,id.uuidString,stamp()])
                for (field,value) in [(BookField.title,title),(BookField.author,author),(.cover,work.coverReference),(.synopsis,work.synopsis)] where value != nil {
                    try provenance(id: id, type: "book", field: field.rawValue, source: work.provider, reference: work.reference, db: db)
                }
                try command(id: id, kind: "book.create", revision: 0, payload: BookCreatePayload(title: title, author: author, wantsToRead: true), db: db)
            } else { try propose(bookID: id, work: work, db: db) }
            try db.execute(sql: "INSERT OR IGNORE INTO provider_links(owner_id,book_id,provider,reference) VALUES(?,?,?,?)", arguments: [ownerID.uuidString,id.uuidString,work.provider,work.reference])
            if let edition {
                let existing = try String.fetchOne(db, sql: "SELECT edition_id FROM provider_links WHERE owner_id=? AND book_id=? AND provider=? AND reference=?", arguments: [ownerID.uuidString,id.uuidString,edition.provider,edition.reference])
                if existing == nil {
                    let matched = try String.fetchOne(db, sql: "SELECT id FROM editions WHERE owner_id=? AND book_id=? AND ((isbn13 IS NOT NULL AND isbn13=?) OR (isbn10 IS NOT NULL AND isbn10=?))", arguments: [ownerID.uuidString,id.uuidString,edition.isbn13,edition.isbn10])
                    let eid = matched.flatMap(UUID.init(uuidString:)) ?? UUID()
                    if matched == nil {
                    try db.execute(sql: "INSERT INTO editions(id,owner_id,book_id,language,page_count,edition_title,isbn10,isbn13,cover_ref,publisher) VALUES(?,?,?,?,?,?,?,?,?,?)", arguments: [eid.uuidString,ownerID.uuidString,id.uuidString,edition.language,edition.pageCount,edition.title,edition.isbn10,edition.isbn13,edition.coverReference,edition.publisher])
                    for field in ["language","page_count","edition_title","isbn10","isbn13","cover_ref","publisher"] { try provenance(id: eid, type: "edition", field: field, source: edition.provider, reference: edition.reference, db: db) }
                    }
                    try db.execute(sql: "INSERT INTO provider_links(owner_id,book_id,edition_id,provider,reference) VALUES(?,?,?,?,?)", arguments: [ownerID.uuidString,id.uuidString,eid.uuidString,edition.provider,edition.reference])
                }
            }
            let snapshot = try catalog(id, db: db)
            try command(id: id, kind: "catalog.snapshot", revision: snapshot.revision, payload: snapshot, db: db)
            return id
    }
    public func start(bookID: UUID, editionID: UUID?, mode: ProgressMode = .page, date: ReadingDate?) throws -> UUID {
        try queue.write { db in try startRecord(bookID: bookID, editionID: editionID, mode: mode, date: date, db: db) }
    }
    private func startRecord(bookID: UUID, editionID: UUID?, mode: ProgressMode, date: ReadingDate?, db: Database) throws -> UUID {
            let record = try catalog(bookID, db: db)
            guard record.active == nil else { throw BooksError.activeReadingExists }
            let edition = record.editions.first { $0.id == editionID }
            if editionID != nil && edition == nil { throw BooksError.missingRecord }
            var reading = ReadingInstance(bookID: bookID, progress: try mode == .page ? .pages(current: 0, total: edition?.pageCount) : .percentage())
            reading.editionID = editionID; reading.startDate = date
            if try Int.fetchOne(db, sql: "SELECT user_overridden FROM field_provenance WHERE owner_id=? AND entity_id=? AND entity_type='book' AND field='genreSuggestion'", arguments: [ownerID.uuidString,bookID.uuidString]) == 1 { reading.primaryGenre = record.genreSuggestion }
            try db.execute(sql: "INSERT INTO readings(id,owner_id,book_id,edition_id,status,progress_mode,current_page,total_pages,start_date,primary_genre) VALUES(?,?,?,?,?,?,?,?,?,?)", arguments: [reading.id.uuidString,ownerID.uuidString,bookID.uuidString,editionID?.uuidString,reading.status.rawValue,mode.rawValue,reading.progress.currentPage,reading.progress.totalPages,date?.isoString,reading.primaryGenre])
            try db.execute(sql: "UPDATE library_memberships SET wants_to_read=0 WHERE owner_id=? AND book_id=?", arguments: [ownerID.uuidString,bookID.uuidString])
            try command(id: reading.id, kind: "reading.start", revision: 0, payload: reading, db: db)
            return reading.id
    }
    public func recordCompleted(bookID: UUID, editionID: UUID?, date: ReadingDate?, rating: Rating) throws -> UUID {
        try queue.write { db in try completedRecord(bookID: bookID, editionID: editionID, date: date, rating: rating, db: db) }
    }
    private func completedRecord(bookID: UUID, editionID: UUID?, date: ReadingDate?, rating: Rating, db: Database) throws -> UUID {
            let record = try catalog(bookID, db: db)
            guard record.active == nil else { throw BooksError.activeReadingExists }
            if editionID != nil && !record.editions.contains(where: { $0.id == editionID }) { throw BooksError.missingRecord }
            var value = ReadingInstance(bookID: bookID, status: .read, progress: try .pages(), historical: true)
            value.editionID = editionID; value.finishDate = date; value.rating = rating
            try db.execute(sql: "INSERT INTO readings(id,owner_id,book_id,edition_id,status,progress_mode,historical) VALUES(?,?,?,?,'read','page',1)", arguments: [value.id.uuidString,ownerID.uuidString,bookID.uuidString,editionID?.uuidString])
            try save(value, db: db)
            try createJournalCompletionWork(reading: value, db: db)
            try db.execute(sql: "UPDATE library_memberships SET wants_to_read=0 WHERE owner_id=? AND book_id=?", arguments: [ownerID.uuidString,bookID.uuidString])
            try command(id: value.id, kind: "reading.completed_record", revision: 0, payload: value, db: db)
            return value.id
    }
    public func addWithIntent(work: WorkCandidate, edition: EditionCandidate?, choice: DuplicateChoice, intent: LibraryAddition, manualValues: [BookField: String]) throws -> UUID {
        try queue.write { db in
            let id = try addRecord(work: work, edition: edition, choice: choice, db: db)
            if !manualValues.isEmpty {
                try editBook(bookID: id, values: manualValues.mapValues { $0.isEmpty ? nil : $0 }, revision: catalog(id, db: db).revision, db: db)
            }
            let record = try catalog(id, db: db)
            let selectedEditionID: UUID?
            if let edition {
                selectedEditionID = try String.fetchOne(db, sql: "SELECT edition_id FROM provider_links WHERE owner_id=? AND book_id=? AND provider=? AND reference=?", arguments: [ownerID.uuidString,id.uuidString,edition.provider,edition.reference]).flatMap(UUID.init(uuidString:))
            } else { selectedEditionID = nil }
            let readingID: UUID?
            switch intent {
            case .toRead:
                try db.execute(sql: "UPDATE library_memberships SET wants_to_read=1 WHERE owner_id=? AND book_id=?", arguments: [ownerID.uuidString,id.uuidString]); readingID = nil
                try command(id: id, kind: "library.intent", revision: record.revision, payload: catalog(id, db: db), db: db)
            case .currentlyReading(let mode, let date): readingID = try startRecord(bookID: id, editionID: selectedEditionID, mode: mode, date: date, db: db)
            case .alreadyRead(let date, let rating): readingID = try completedRecord(bookID: id, editionID: selectedEditionID, date: date, rating: rating, db: db)
            }
            if let readingID, work.provider == "manual", let genre = manualValues[.genreSuggestion], !genre.isEmpty {
                var value = try reading(readingID, db: db); value.primaryGenre = genre; value.revision += 1
                try save(value, db: db); try provenance(id: readingID, type: "reading", field: "primary_genre", source: "manual", reference: nil, db: db)
                try command(id: readingID, kind: "reading.edit", revision: 0, payload: value, db: db)
            }
            return id
        }
    }
    public func providerWorks(bookID: UUID) throws -> [WorkCandidate] {
        try queue.read { db in
            let record = try catalog(bookID, db: db)
            return try Row.fetchAll(db, sql: "SELECT provider,reference FROM provider_links WHERE owner_id=? AND book_id=? AND edition_id IS NULL AND provider<>'manual'", arguments: [ownerID.uuidString,bookID.uuidString]).map { row in
                WorkCandidate(provider: row["provider"], reference: row["reference"], title: record.book.title, author: record.book.author)
            }
        }
    }
    public func update(readingID: UUID, value: ReadingProgress, revision: Int, observationID: UUID = UUID()) throws -> ProgressUpdateResult {
        try queue.write { db in
            var reading = try reading(readingID, db: db)
            let result = try ProgressRules.record(&reading, value: value, expectedRevision: revision, observationID: observationID)
            try save(reading, db: db)
            let observation: ProgressObservation
            switch result { case .applied(let o), .requiresReview(let o): observation = o }
            // A replay is a no-op, including the outbox. A changed retry is rejected by domain rules.
            if try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM progress_observations WHERE owner_id=? AND id=?", arguments: [ownerID.uuidString,observationID.uuidString]) == 0 {
                try db.execute(sql: "INSERT INTO progress_observations(owner_id,id,reading_id,mutation_id,mode,previous_page,new_page,total_pages,previous_percentage,new_percentage,recorded_at,base_revision,requires_review,ordinal) VALUES(?,?,?,?,?,?,?,?,?,?,?,?,?,(SELECT COALESCE(MAX(ordinal),0)+1 FROM progress_observations))", arguments: [ownerID.uuidString,observation.id.uuidString,readingID.uuidString,observation.id.uuidString,value.mode.rawValue,observation.previous?.currentPage,value.currentPage,value.totalPages,observation.previous?.percentage,value.percentage,stamp(observation.recordedAt),revision,observation.requiresReview])
                try command(id: readingID, kind: "reading.progress", revision: revision, payload: observation, mutationID: observationID, db: db)
                if observation.requiresReview { try db.execute(sql: "UPDATE outbox SET state='review' WHERE owner_id=? AND id=?", arguments: [ownerID.uuidString,observationID.uuidString]) }
            }
            return result
        }
    }
    public func finish(readingID: UUID, confirmed: Bool, date: ReadingDate?, revision: Int) throws {
        try queue.write { db in
            var reading = try reading(readingID, db: db)
            guard reading.revision == revision else { throw DomainError.staleRevision }
            guard !reading.progressObservations.contains(where: \.requiresReview) else { throw DomainError.staleRevision }
            let effects = try ReadingRules.finish(&reading, confirmed: confirmed, date: date, expectedRevision: revision)
            try save(reading, db: db)
            if effects.journalInbox { try createJournalCompletionWork(reading: reading, db: db) }
            try command(id: readingID, kind: "reading.finish", revision: revision, payload: reading, db: db)
        }
    }
    public func markDNF(readingID: UUID, revision: Int) throws { try mutate(readingID, revision: revision, kind: "reading.dnf") { try ReadingRules.markDNF(&$0) } }
    public func resume(readingID: UUID, revision: Int) throws {
        try queue.write { db in
            var reading = try reading(readingID, db: db)
            guard reading.revision == revision else { throw DomainError.staleRevision }
            guard try catalog(reading.bookID, db: db).active == nil else { throw BooksError.activeReadingExists }
            try ReadingRules.resume(&reading); try save(reading, db: db)
            try command(id: readingID, kind: "reading.resume", revision: revision, payload: reading, db: db)
        }
    }
    private func mutate(_ id: UUID, revision: Int, kind: String, body: (inout ReadingInstance) throws -> Void) throws {
        try queue.write { db in
            var reading = try reading(id, db: db)
            guard reading.revision == revision else { throw DomainError.staleRevision }
            try body(&reading); try save(reading, db: db)
            try command(id: id, kind: kind, revision: revision, payload: reading, db: db)
        }
    }
    private func save(_ reading: ReadingInstance, db: Database) throws {
        var ratingState = "unknown"; var rating: Int?
        switch reading.rating { case .unknown: break; case .noRating: ratingState = "unrated"; case .stars(let stars): _ = try Rating.validatedStars(stars); ratingState = "rated"; rating = stars }
        try db.execute(sql: "UPDATE readings SET status=?,progress_mode=?,current_page=?,total_pages=?,progress_percentage=?,start_date=?,finish_date=?,rating_state=?,rating_whole=?,journal_format=?,primary_genre=?,revision=? WHERE owner_id=? AND id=?", arguments: [reading.status.rawValue,reading.progress.mode.rawValue,reading.progress.currentPage,reading.progress.totalPages,reading.progress.percentage,reading.startDate?.isoString,reading.finishDate?.isoString,ratingState,rating,reading.journalFormat?.rawValue,reading.primaryGenre,reading.revision,ownerID.uuidString,reading.id.uuidString])
    }
    public func edit(bookID: UUID, values: [BookField: String?], revision: Int) throws {
        try queue.write { db in try editBook(bookID: bookID, values: values, revision: revision, db: db) }
    }
    private func editBook(bookID: UUID, values: [BookField: String?], revision: Int, db: Database) throws {
            guard try catalog(bookID, db: db).revision == revision else { throw DomainError.staleRevision }
            for (field,value) in values {
                let normalized = value?.trimmingCharacters(in: .whitespacesAndNewlines)
                if field == .title || field == .author { _ = try BooksRules.validatedText(normalized) }
                let stored = field == .cover && normalized?.isEmpty == true ? "" : normalized?.isEmpty == true ? nil : normalized
                try db.execute(sql: "UPDATE books SET \(column(field))=? WHERE owner_id=? AND id=?", arguments: [stored,ownerID.uuidString,bookID.uuidString])
                try provenance(id: bookID, type: "book", field: field.rawValue, source: "manual", reference: nil, db: db)
            }
            try db.execute(sql: "UPDATE books SET revision=revision+1 WHERE owner_id=? AND id=?", arguments: [ownerID.uuidString,bookID.uuidString])
            try command(id: bookID, kind: "book.edit", revision: revision, payload: catalog(bookID, db: db), db: db)
    }
    public func editEdition(_ edition: Edition, revision: Int) throws {
        try queue.write { db in try editEdition(edition, revision: revision, db: db) }
    }
    private func editEdition(_ edition: Edition, revision: Int, db: Database) throws {
        if let pages = edition.pageCount, pages <= 0 { throw DomainError.invalidProgress }
            guard try catalog(edition.bookID, db: db).revision == revision else { throw DomainError.staleRevision }
            guard try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM editions WHERE owner_id=? AND id=? AND book_id=?", arguments: [ownerID.uuidString,edition.id.uuidString,edition.bookID.uuidString]) == 1 else { throw BooksError.missingRecord }
            try db.execute(sql: "UPDATE editions SET language=?,page_count=?,edition_title=?,isbn10=?,isbn13=?,cover_ref=?,publisher=?,revision=revision+1 WHERE owner_id=? AND id=?", arguments: [edition.language,edition.pageCount,edition.title,edition.isbn10,edition.isbn13,edition.coverReference,edition.publisher,ownerID.uuidString,edition.id.uuidString])
            for field in ["language","page_count","edition_title","isbn10","isbn13","cover_ref","publisher"] { try provenance(id: edition.id, type: "edition", field: field, source: "manual", reference: nil, db: db) }
            try db.execute(sql: "UPDATE books SET revision=revision+1 WHERE owner_id=? AND id=?", arguments: [ownerID.uuidString,edition.bookID.uuidString])
            try command(id: edition.bookID, kind: "edition.edit", revision: revision, payload: edition, db: db)
    }
    public func editInfo(bookID: UUID, values: [BookField: String?], edition: Edition?, revision: Int) throws {
        try queue.write { db in
            if let edition, edition.bookID != bookID { throw BooksError.missingRecord }
            try editBook(bookID: bookID, values: values, revision: revision, db: db)
            if let edition { try editEdition(edition, revision: revision + 1, db: db) }
        }
    }
    public func editReading(readingID: UUID, start: ReadingDate?, finish: ReadingDate?, rating: Rating, genre: String?, format: JournalFormat?, revision: Int) throws {
        try queue.write { db in
            var value = try reading(readingID, db: db)
            guard value.revision == revision else { throw DomainError.staleRevision }
            value.startDate = start; if value.status == .read { value.finishDate = finish }
            let normalizedGenre = genre?.trimmingCharacters(in: .whitespacesAndNewlines)
            value.rating = rating; value.primaryGenre = normalizedGenre?.isEmpty == true ? nil : normalizedGenre
            if let format { try ReadingRules.setJournalFormat(format, origin: .user, reading: &value) }
            else { value.journalFormat = nil }
            value.revision += 1; try save(value, db: db)
            for field in ["start_date","finish_date","rating","primary_genre","journal_format"] { try provenance(id: readingID, type: "reading", field: field, source: "manual", reference: nil, db: db) }
            try command(id: readingID, kind: "reading.edit", revision: revision, payload: value, db: db)
        }
    }
    private func column(_ field: BookField) -> String {
        switch field { case .title: "title"; case .author: "author"; case .cover: "cover_ref"; case .synopsis: "synopsis"; case .series: "series_name"; case .genreSuggestion: "genre_suggestion" }
    }
    public func reviewProvider(bookID: UUID, work: WorkCandidate) throws { try queue.write { try propose(bookID: bookID, work: work, db: $0) } }
    private func propose(bookID: UUID, work: WorkCandidate, db: Database) throws {
        let record = try catalog(bookID, db: db)
        let fields: [(BookField,String?,String?)] = [(.title,record.book.title,work.title),(.author,record.book.author,work.author),(.cover,record.coverReference,work.coverReference),(.synopsis,record.synopsis,work.synopsis)]
        for (field,current,incoming) in fields where incoming != nil && current != incoming {
            let fingerprint = try String(data: JSONEncoder().encode([work.provider,work.reference,field.rawValue,incoming]), encoding: .utf8)!
            try db.execute(sql: "INSERT OR IGNORE INTO data_change_proposals(owner_id,id,entity_id,entity_type,field,current_json,proposed_json,evidence_fingerprint,status,source) VALUES(?,?,?,'book',?,?,?,?,'pending',?)", arguments: [ownerID.uuidString,UUID().uuidString,bookID.uuidString,field.rawValue,json(current),json(incoming),fingerprint,work.provider + " " + work.reference])
        }
    }
    public func proposals(bookID: UUID) throws -> [MetadataReview] {
        try queue.read { db in
            try Row.fetchAll(db, sql: "SELECT * FROM data_change_proposals WHERE owner_id=? AND entity_id=? AND entity_type='book' AND status='pending'", arguments: [ownerID.uuidString,bookID.uuidString]).map { row in
                MetadataReview(id: UUID(uuidString: row["id"])!, bookID: bookID, field: BookField(rawValue: row["field"])!, current: try JSONDecoder().decode(String?.self, from: Data((row["current_json"] as String).utf8)), proposed: try JSONDecoder().decode(String?.self, from: Data((row["proposed_json"] as String).utf8)), source: row["source"] ?? "External provider")
            }
        }
    }
    public func decide(proposalID: UUID, accept: Bool) throws {
        try queue.write { db in
            guard let row = try Row.fetchOne(db, sql: "SELECT * FROM data_change_proposals WHERE owner_id=? AND id=? AND status='pending'", arguments: [ownerID.uuidString,proposalID.uuidString]), let field = BookField(rawValue: row["field"]), let bookID = UUID(uuidString: row["entity_id"]) else { throw BooksError.missingRecord }
            if accept {
                let current = try String.fetchOne(db, sql: "SELECT \(column(field)) FROM books WHERE owner_id=? AND id=?", arguments: [ownerID.uuidString,bookID.uuidString])
                guard try json(current) == (row["current_json"] as String) else { throw DomainError.staleRevision }
                let proposed = try JSONDecoder().decode(String?.self, from: Data((row["proposed_json"] as String).utf8))
                if field == .title || field == .author { _ = try BooksRules.validatedText(proposed) }
                try db.execute(sql: "UPDATE books SET \(column(field))=?,revision=revision+1 WHERE owner_id=? AND id=?", arguments: [proposed,ownerID.uuidString,bookID.uuidString])
                try provenance(id: bookID, type: "book", field: field.rawValue, source: "manual", reference: row["source"], db: db)
            }
            try db.execute(sql: "UPDATE data_change_proposals SET status=? WHERE owner_id=? AND id=?", arguments: [accept ? "accepted" : "kept",ownerID.uuidString,proposalID.uuidString])
            try command(id: bookID, kind: "book.proposal_decision", revision: 0, payload: catalog(bookID, db: db), db: db)
        }
    }
    public func resolveProgress(readingID: UUID, observationID: UUID, apply: Bool, revision: Int) throws {
        try queue.write { db in
            var reading = try reading(readingID, db: db)
            guard reading.revision == revision, reading.status == .currentlyReading,
                  let selected = reading.progressObservations.first(where: { $0.id == observationID && $0.requiresReview }), selected.value.mode == reading.progress.mode else { throw DomainError.staleRevision }
            // Resolution is explicit. Preserve the original observation unchanged and record the decision.
            if apply {
                let result = try ProgressRules.record(&reading, value: selected.value, expectedRevision: revision)
                if case .applied(let o) = result {
                    try db.execute(sql: "INSERT INTO progress_observations(owner_id,id,reading_id,mutation_id,mode,previous_page,new_page,total_pages,previous_percentage,new_percentage,recorded_at,base_revision,requires_review,ordinal) VALUES(?,?,?,?,?,?,?,?,?,?,?,?,0,(SELECT COALESCE(MAX(ordinal),0)+1 FROM progress_observations))", arguments: [ownerID.uuidString,o.id.uuidString,readingID.uuidString,o.id.uuidString,o.value.mode.rawValue,o.previous?.currentPage,o.value.currentPage,o.value.totalPages,o.previous?.percentage,o.value.percentage,stamp(),revision])
                }
            }
            try db.execute(sql: "UPDATE progress_observations SET requires_review=0 WHERE owner_id=? AND id=?", arguments: [ownerID.uuidString,observationID.uuidString])
            // Queue remains durable; the conflict command is superseded by an explicit resolution command.
            try db.execute(sql: "UPDATE outbox SET state='pending' WHERE owner_id=? AND id=?", arguments: [ownerID.uuidString,observationID.uuidString])
            try save(reading, db: db)
            try command(id: readingID, kind: "reading.resolve", revision: revision, payload: self.reading(readingID, db: db), db: db)
        }
    }
    private func provenance(id: UUID, type: String, field: String, source: String, reference: String?, db: Database) throws {
        try db.execute(sql: "INSERT OR REPLACE INTO field_provenance(owner_id,entity_id,entity_type,field,source,source_ref,user_overridden) VALUES(?,?,?,?,?,?,?)", arguments: [ownerID.uuidString,id.uuidString,type,field,source,reference,source == "manual"])
    }
    private func command<T: Encodable>(id: UUID, kind: String, revision: Int, payload: T, mutationID: UUID = UUID(), db: Database) throws {
        var generation = try String.fetchOne(db, sql: "SELECT generation FROM sync_state WHERE owner_id=?", arguments: [ownerID.uuidString])
        if generation == nil { generation = UUID().uuidString; try db.execute(sql: "INSERT INTO sync_state(owner_id,generation) VALUES(?,?)", arguments: [ownerID.uuidString,generation]) }
        try enqueue(MutationEnvelope(id: mutationID, ownerID: ownerID, entityID: id, expectedRevision: revision, generation: UUID(uuidString: generation!)!, kind: kind, payload: JSONEncoder().encode(payload)), db: db)
    }
    func stamp(_ value: Date = Date()) -> String { ISO8601DateFormatter().string(from: value) }
    private func json(_ value: String?) throws -> String { String(data: try JSONEncoder().encode(value), encoding: .utf8)! }
}
