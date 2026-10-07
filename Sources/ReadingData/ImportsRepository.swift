import Foundation
import CryptoKit
import GRDB
import ReadingDomain

extension LocalStore: ImportsRepository {
    #if DEBUG
    public func importAcceptanceSummary() throws -> String {
        try queue.read { db in
            func count(_ table:String) throws -> Int { try Int.fetchOne(db,sql:"SELECT COUNT(*) FROM \(table) WHERE owner_id=?",arguments:[ownerID.uuidString]) ?? 0 }
            let xp=try Int.fetchOne(db,sql:"SELECT COALESCE(SUM(amount),0) FROM xp_awards WHERE owner_id=?",arguments:[ownerID.uuidString]) ?? 0
            let progress=try Int.fetchOne(db,sql:"SELECT COALESCE(SUM(progress),0) FROM quest_instances WHERE owner_id=?",arguments:[ownerID.uuidString]) ?? 0
            let achievements=try Int.fetchOne(db,sql:"SELECT COUNT(*) FROM achievement_progress WHERE owner_id=? AND unlocked_at IS NOT NULL",arguments:[ownerID.uuidString]) ?? 0
            return "\(try count("readings")) readings · \(xp) XP · \(progress) Quest progress · \(achievements) Achievements · \(try count("challenge_assignments")) Challenges · \(try count("journal_entries")) Inbox"
        }
    }
    #endif
    public func previewStoryGraph(_ data: Data) throws -> ImportPreview {
        let rows = try StoryGraphAdapter.rows(data)
        return try queue.read { db in
            let candidates = try importCandidates(rows,db:db)
            return ImportPreview(id: UUID(), fingerprint: importHash(data), libraryFingerprint: try importLibraryFingerprint(db), candidates: candidates)
        }
    }
    private func importCandidates(_ rows:[StoryGraphRow],db:Database) throws -> [ImportCandidate] {
        let identities=Dictionary(grouping:rows,by:\.identity)
        let evidence=try identities.mapValues { try Set($0.map(importRowFingerprint)) }
        let titles=Dictionary(grouping:rows,by: { $0.title.folding(options:[.caseInsensitive,.diacriticInsensitive],locale:Locale(identifier:"en_US_POSIX"))+"\u{1F}"+$0.author.folding(options:[.caseInsensitive,.diacriticInsensitive],locale:Locale(identifier:"en_US_POSIX")) })
        var seen=Set<String>()
        return try rows.map { row in
            let ordinary=try importCandidate(row,db:db)
            let fingerprints=evidence[row.identity,default:[]]
            let titleKey=row.title.folding(options:[.caseInsensitive,.diacriticInsensitive],locale:Locale(identifier:"en_US_POSIX"))+"\u{1F}"+row.author.folding(options:[.caseInsensitive,.diacriticInsensitive],locale:Locale(identifier:"en_US_POSIX"))
            let differentIdentities=Set(titles[titleKey,default:[]].map(\.identity)).count>1
            if fingerprints.count>1 || differentIdentities {
                return ImportCandidate(id:ordinary.id,row:row,group:.review,bookID:ordinary.bookID,matches:ordinary.matches,explanation:"Repeated or competing identities in this file require explicit review. No work or reading is silently merged.")
            }
            if !seen.insert(row.identity).inserted {
                return ImportCandidate(id:ordinary.id,row:row,group:.unchanged,bookID:ordinary.bookID,matches:ordinary.matches,explanation:"An identical source row is already included once in this preview.")
            }
            return ordinary
        }
    }
    private func importCandidate(_ row: StoryGraphRow, db: Database) throws -> ImportCandidate {
        let links = try String.fetchAll(db, sql: "SELECT DISTINCT book_id FROM import_occurrences WHERE owner_id=? AND source_identity=?", arguments: [ownerID.uuidString,row.identity])
        let isbn = try String.fetchAll(db, sql: "SELECT DISTINCT book_id FROM editions WHERE owner_id=? AND (isbn13=? OR isbn10=?)", arguments: [ownerID.uuidString,row.isbn,row.isbn])
        let similar = try Row.fetchAll(db, sql: "SELECT id,title,author FROM books WHERE owner_id=? AND deleted_at IS NULL", arguments: [ownerID.uuidString]).filter {
            BooksRules.possibleDuplicate(title: row.title, author: row.author, existingTitle: $0["title"], existingAuthor: $0["author"])
        }.map { $0["id"] as String }
        let exact = Set(links + isbn)
        let matches = Set(links + isbn + similar).compactMap(UUID.init(uuidString:)).sorted { $0.uuidString < $1.uuidString }
        let known = links.count == 1 && exact.count == 1 ? UUID(uuidString: links[0]) : nil
        let group: ImportGroup
        let explanation: String
        let kept = try String.fetchOne(db,sql:"SELECT status FROM import_candidates WHERE owner_id=? AND fingerprint=?",arguments:[ownerID.uuidString,try importRowFingerprint(row)]) == "kept"
        if kept { group = .unchanged; explanation = "You kept this source row unapplied. The same normalized evidence is suppressed." }
        else if !row.issues.isEmpty { group = .review; explanation = row.issues.joined(separator: " ") }
        else if let known {
            let changes = try importDifferences(row, bookID: known, db: db)
            let stored = try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM import_occurrences WHERE owner_id=? AND source_identity=? AND occurrence>0", arguments: [ownerID.uuidString,row.identity]) ?? 0
            let expectedCount = row.status == "read" ? row.finishes.count : row.status == "to-read" ? 0 : 1
            let expectedStatus = row.status == "currently-reading" ? "currently_reading" : row.status == "did-not-finish" ? "dnf" : row.status
            let differentStatus = try Int.fetchOne(db,sql:"SELECT COUNT(*) FROM import_occurrences i JOIN readings r ON r.owner_id=i.owner_id AND r.id=i.reading_id WHERE i.owner_id=? AND i.source_identity=? AND (r.status<>? OR r.deleted_at IS NOT NULL)",arguments:[ownerID.uuidString,row.identity,expectedStatus]) ?? 0
            if stored != expectedCount || differentStatus > 0 { group = .review; explanation = "The source reading history or status changed. Your local readings will not be replaced." }
            else { group = changes.isEmpty ? .unchanged : .updates; explanation = changes.isEmpty ? "Previously imported identity and supplied facts match, or unchanged rejected evidence is kept." : "Known imported identity. Differences will become proposals; current values remain unchanged." }
        } else if !matches.isEmpty { group = .review; explanation = "Possible existing book. ISBN or title/author evidence needs your explicit identity decision." }
        else { group = .newBooks; explanation = "No existing identity or conservative title/author match. Supplied history will be stored without live rewards." }
        return ImportCandidate(id: UUID(), row: row, group: group, bookID: known, matches: matches, explanation: explanation)
    }
    private struct Difference {
        let entity: UUID; let type: String; let field: String; let current: String?; let proposed: String?
        let fingerprint: String
    }
    private func importDifferences(_ row: StoryGraphRow, bookID: UUID, db: Database) throws -> [Difference] {
        let book = try catalog(bookID, db: db)
        var facts: [(UUID,String,String,String?,String?)] = [(bookID,"book","title",book.book.title,row.title),(bookID,"book","author",book.book.author,row.author)]
        for index in row.finishes.indices {
            if let id = try String.fetchOne(db, sql: "SELECT reading_id FROM import_occurrences WHERE owner_id=? AND source_identity=? AND occurrence=?", arguments: [ownerID.uuidString,row.identity,index + 1]).flatMap(UUID.init(uuidString:)) {
                let reading = try reading(id, db: db)
                facts.append((id,"reading","start_date",reading.startDate?.isoString,row.starts[index]?.isoString))
                facts.append((id,"reading","finish_date",reading.finishDate?.isoString,row.finishes[index]?.isoString))
                // A book-level exported rating is not assigned to every reread.
                if index == row.finishes.count - 1, row.rating != .unknown {
                    facts.append((id,"reading","rating",try importJSON(reading.rating),try importJSON(row.rating)))
                }
            }
        }
        return try facts.compactMap { entity,type,field,current,proposed in
            guard proposed != nil, current != proposed else { return nil }
            let fingerprint = importHash(Data(try importJSON([row.identity,field,proposed]).utf8))
            let status = try String.fetchOne(db, sql: "SELECT status FROM data_change_proposals WHERE owner_id=? AND entity_id=? AND entity_type=? AND field=? AND evidence_fingerprint=?", arguments: [ownerID.uuidString,entity.uuidString,"import_" + type,field,fingerprint])
            guard status != "kept" && status != "edited" else { return nil }
            return Difference(entity: entity, type: type, field: field, current: current, proposed: proposed, fingerprint: fingerprint)
        }
    }
    public func applyImport(_ preview: ImportPreview, confirmed: Bool) throws -> ImportHistory {
        guard confirmed else { throw ImportError.confirmationRequired }
        return try queue.write { db in
            if let existing = try importRun(fingerprint: preview.fingerprint, db: db) { return existing }
            guard preview.libraryFingerprint == (try importLibraryFingerprint(db)) else { throw ImportError.stalePreview }
            // Recompute from normalized facts; never trust a caller's classification or selected UUID.
            let candidates = try importCandidates(preview.candidates.map(\.row),db:db)
            let beforeBooks = try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM books WHERE owner_id=?", arguments: [ownerID.uuidString]) ?? 0
            let beforeReadings = try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM readings WHERE owner_id=?", arguments: [ownerID.uuidString]) ?? 0
            // Insert history last using a deferred foreign-key transaction? Candidates are staged after history below.
            var pending = [ImportCandidate](); var unchanged = 0
            for candidate in candidates {
                switch candidate.group {
                case .review: pending.append(candidate)
                case .unchanged: unchanged += 1
                case .updates:
                    try importProposals(candidate.row, bookID: candidate.bookID!, db: db)
                case .newBooks:
                    // Re-evaluate after earlier rows, preventing duplicate source identities within one file.
                    let live = try importCandidate(candidate.row, db: db)
                    if live.group == .newBooks { try importNewHistory(candidate.row, bookID: nil, db: db) }
                    else if live.group == .unchanged { unchanged += 1 }
                    else { pending.append(live) }
                }
            }
            let afterBooks = try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM books WHERE owner_id=?", arguments: [ownerID.uuidString]) ?? 0
            let afterReadings = try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM readings WHERE owner_id=?", arguments: [ownerID.uuidString]) ?? 0
            let history = ImportHistory(id: preview.id, completedAt: stamp(), rows: candidates.count, newBooks: afterBooks-beforeBooks, newReadings: afterReadings-beforeReadings, review: pending.count+candidates.filter { $0.group == .updates }.count, unchanged: unchanged)
            try db.execute(sql: "INSERT INTO import_runs VALUES(?,?,?,?,?,?,?,?,?)", arguments: [ownerID.uuidString,history.id.uuidString,preview.fingerprint,history.completedAt,history.rows,history.newBooks,history.newReadings,history.review,history.unchanged])
            for candidate in pending {
                let fingerprint = try importRowFingerprint(candidate.row)
                try db.execute(sql: "INSERT OR IGNORE INTO import_candidates VALUES(?,?,?,?,?,'pending')", arguments: [ownerID.uuidString,candidate.id.uuidString,history.id.uuidString,try importJSON(candidate),fingerprint])
                if db.changesCount > 0 { try importAttention(candidate.id, reason: "Review imported identity or incomplete information", db: db) }
            }
            try importCommand(id: history.id, kind: "import.commit", payload: history, db: db)
            return history
        }
    }
    private func importNewHistory(_ row: StoryGraphRow, bookID selected: UUID?, db: Database) throws {
        guard row.issues.isEmpty else { throw ImportError.invalidResolution }
        let bookID = selected ?? UUID()
        if selected == nil {
            try db.execute(sql: "INSERT INTO books(id,owner_id,title,author) VALUES(?,?,?,?)", arguments: [bookID.uuidString,ownerID.uuidString,row.title,row.author])
            try db.execute(sql: "INSERT INTO library_memberships(owner_id,book_id,wants_to_read,added_at) VALUES(?,?,?,?)", arguments: [ownerID.uuidString,bookID.uuidString,row.status == "to-read",stamp()])
            for field in ["title","author"] { try importProvenance(bookID, type:"book", field:field, reference:row.identity, db:db) }
        } else { _ = try catalog(bookID, db:db) }
        var editionID: String?
        if let isbn = row.isbn {
            editionID = try String.fetchOne(db, sql:"SELECT id FROM editions WHERE owner_id=? AND book_id=? AND (isbn13=? OR isbn10=?)",arguments:[ownerID.uuidString,bookID.uuidString,isbn,isbn])
            if editionID == nil {
                editionID = UUID().uuidString
                try db.execute(sql:"INSERT INTO editions(id,owner_id,book_id,isbn13,isbn10) VALUES(?,?,?,?,?)",arguments:[editionID,ownerID.uuidString,bookID.uuidString,isbn.count == 13 ? isbn : nil,isbn.count == 10 ? isbn : nil])
                try importProvenance(UUID(uuidString:editionID!)!,type:"edition",field:isbn.count == 13 ? "isbn13" : "isbn10",reference:row.identity,db:db)
            }
        }
        try db.execute(sql:"INSERT OR IGNORE INTO import_occurrences VALUES(?,?,0,?,NULL,?)",arguments:[ownerID.uuidString,row.identity,bookID.uuidString,editionID])
        if row.status == "to-read" {
            try importCommand(id:bookID,kind:"import.catalog",payload:catalog(bookID,db:db),db:db)
            return
        }
        let count = row.status == "read" ? row.finishes.count : 1
        if row.status == "currently-reading", try catalog(bookID,db:db).active != nil { throw ImportError.invalidResolution }
        for index in 0..<count {
            guard try Int.fetchOne(db,sql:"SELECT COUNT(*) FROM import_occurrences WHERE owner_id=? AND source_identity=? AND occurrence=?",arguments:[ownerID.uuidString,row.identity,index+1]) == 0 else { continue }
            let id = UUID()
            let status = row.status == "read" ? "read" : row.status == "did-not-finish" ? "dnf" : "currently_reading"
            let finish = row.status == "read" ? row.finishes[index]?.isoString : nil
            let start = row.status == "read" ? row.starts[index]?.isoString : nil
            let rating = index == count-1 ? row.rating : .unknown
            let ratingState: String; let whole: Int?
            switch rating { case .unknown: ratingState="unknown"; whole=nil; case .noRating: ratingState="unrated"; whole=nil; case .stars(let n):ratingState="rated";whole=n }
            // Dedicated historical write path. No finish/start command, consumer, activity, progress observation or Inbox producer.
            try db.execute(sql:"INSERT INTO readings(id,owner_id,book_id,edition_id,status,progress_mode,current_page,historical,start_date,finish_date,rating_state,rating_whole) VALUES(?,?,?,?,?,'page',NULL,?,?,?,?,?)",arguments:[id.uuidString,ownerID.uuidString,bookID.uuidString,editionID,status,status != "currently_reading",start,finish,ratingState,whole])
            try db.execute(sql:"INSERT INTO import_occurrences VALUES(?,?,?,?,?,?)",arguments:[ownerID.uuidString,row.identity,index+1,bookID.uuidString,id.uuidString,editionID])
            for field in ["start_date","finish_date","rating"] { try importProvenance(id,type:"reading",field:field,reference:row.identity,db:db) }
        }
        try importCommand(id:bookID,kind:"import.catalog",payload:catalog(bookID,db:db),db:db)
    }
    private func importProposals(_ row: StoryGraphRow, bookID: UUID, db: Database) throws {
        for difference in try importDifferences(row,bookID:bookID,db:db) {
            let id = UUID()
            try db.execute(sql:"INSERT OR IGNORE INTO data_change_proposals(owner_id,id,entity_id,entity_type,field,current_json,proposed_json,evidence_fingerprint,status,source) VALUES(?,?,?,?,?,?,?,?,'pending',?)",arguments:[ownerID.uuidString,id.uuidString,difference.entity.uuidString,"import_"+difference.type,difference.field,try importJSON(difference.current),try importJSON(difference.proposed),difference.fingerprint,"StoryGraph CSV · "+row.identity])
            if db.changesCount > 0 { try importAttention(id,reason:"Review imported "+difference.field,db:db) }
        }
    }
    public func importReviews() throws -> [ImportReview] {
        try queue.read { db in
            try Row.fetchAll(db,sql:"SELECT p.*,COALESCE(f.user_overridden,0) AS protected FROM data_change_proposals p LEFT JOIN field_provenance f ON f.owner_id=p.owner_id AND f.entity_id=p.entity_id AND f.entity_type=substr(p.entity_type,8) AND f.field=p.field WHERE p.owner_id=? AND p.entity_type IN ('import_book','import_reading') AND p.status='pending' ORDER BY p.rowid",arguments:[ownerID.uuidString]).map { row in
                let entity=UUID(uuidString:row["entity_id"])!,field:String=row["field"],type:String=row["entity_type"]
                let current=try importCurrent(entity:entity,type:type,field:field,db:db)
                let proposed = try JSONDecoder().decode(String?.self,from:Data((row["proposed_json"] as String).utf8))
                let canAccept = type == "import_book" ? true : try reading(entity,db:db).historical
                return ImportReview(id:UUID(uuidString:row["id"])!,entityID:entity,field:field,current:importDisplay(current,field:field),proposed:importDisplay(proposed,field:field),source:row["source"],userOverridden:row["protected"],currentFingerprint:importHash(Data(try importJSON(current).utf8)),canAccept:canAccept)
            }
        }
    }
    public func decideImport(id: UUID, accept: Bool) throws {
        try decideImport(id:id,accept:accept,currentFingerprint:nil)
    }
    public func decideImport(id: UUID, accept: Bool, currentFingerprint:String?) throws {
        try queue.write { db in
            guard let row = try Row.fetchOne(db,sql:"SELECT * FROM data_change_proposals WHERE owner_id=? AND id=? AND entity_type IN ('import_book','import_reading') AND status='pending'",arguments:[ownerID.uuidString,id.uuidString]) else { throw ImportError.invalidResolution }
            let entity = UUID(uuidString:row["entity_id"])!, field:String=row["field"], type:String=row["entity_type"]
            var previous = try JSONDecoder().decode(String?.self,from:Data((row["current_json"] as String).utf8))
            let proposed = try JSONDecoder().decode(String?.self,from:Data((row["proposed_json"] as String).utf8))
            if accept {
                guard let proposed else { throw ImportError.invalidResolution }
                if let currentFingerprint {
                    let live=try importCurrent(entity:entity,type:type,field:field,db:db)
                    guard currentFingerprint == importHash(Data(try importJSON(live).utf8)) else { throw ImportError.stalePreview }
                    previous=live
                }
                if type == "import_book" {
                    guard ["title","author"].contains(field) else { throw ImportError.invalidResolution }
                    let current = try String.fetchOne(db,sql:"SELECT \(field) FROM books WHERE owner_id=? AND id=?",arguments:[ownerID.uuidString,entity.uuidString])
                    guard current == previous else { throw ImportError.stalePreview }
                    _ = try BooksRules.validatedText(proposed)
                    try db.execute(sql:"UPDATE books SET \(field)=?,revision=revision+1 WHERE owner_id=? AND id=?",arguments:[proposed,ownerID.uuidString,entity.uuidString])
                } else {
                    let reading = try reading(entity,db:db)
                    guard reading.historical else { throw ImportError.invalidResolution }
                    if field == "rating" {
                        guard try importJSON(reading.rating) == previous else { throw ImportError.stalePreview }
                        let rating = try JSONDecoder().decode(Rating.self,from:Data(proposed.utf8))
                        let state:String;let stars:Int?
                        switch rating { case .unknown: state="unknown";stars=nil;case .noRating:state="unrated";stars=nil;case .stars(let n):_ = try Rating.validatedStars(n);state="rated";stars=n }
                        try db.execute(sql:"UPDATE readings SET rating_state=?,rating_whole=?,revision=revision+1 WHERE owner_id=? AND id=?",arguments:[state,stars,ownerID.uuidString,entity.uuidString])
                    } else {
                        guard ["start_date","finish_date"].contains(field), reading.status == .read else { throw ImportError.invalidResolution }
                        guard (field == "start_date" ? reading.startDate?.isoString : reading.finishDate?.isoString) == previous else { throw ImportError.stalePreview }
                        let date = try JSONDecoder().decode(ReadingDate.self,from:JSONEncoder().encode(proposed))
                        if field == "start_date", let finish=reading.finishDate, date>finish { throw ImportError.invalidResolution }
                        if field == "finish_date", let start=reading.startDate, date<start { throw ImportError.invalidResolution }
                        try db.execute(sql:"UPDATE readings SET \(field)=?,revision=revision+1 WHERE owner_id=? AND id=?",arguments:[proposed,ownerID.uuidString,entity.uuidString])
                    }
                    // Copied physical data uses the existing correction system; import never queues fresh Inbox work.
                    try refreshCopiedReviewCorrections(readingID:entity,db:db)
                }
                // An explicit human accepted correction is user-authoritative.
                try db.execute(sql:"INSERT OR REPLACE INTO field_provenance(owner_id,entity_id,entity_type,field,source,source_ref,user_overridden) VALUES(?,?,?,?, 'manual',?,1)",arguments:[ownerID.uuidString,entity.uuidString,type == "import_book" ? "book":"reading",field,row["source"] as String])
                let bookID = type == "import_book" ? entity : try reading(entity,db:db).bookID
                if type == "import_book" {
                    for reading in try catalog(bookID,db:db).readings { try refreshCopiedReviewCorrections(readingID:reading.id,db:db) }
                }
                try importCommand(id:bookID,kind:"import.catalog",payload:catalog(bookID,db:db),db:db)
            }
            try db.execute(sql:"UPDATE data_change_proposals SET status=? WHERE owner_id=? AND id=?",arguments:[accept ? "accepted":"kept",ownerID.uuidString,id.uuidString])
            try importResolveAttention(id,db:db)
            try importCommand(id:id,kind:"import.review",payload:["decision":accept ? "accepted":"kept"],db:db)
        }
    }
    public func pendingImportCandidates() throws -> [ImportCandidate] {
        try queue.read { db in try String.fetchAll(db,sql:"SELECT candidate_json FROM import_candidates WHERE owner_id=? AND status='pending' ORDER BY rowid",arguments:[ownerID.uuidString]).map {
            let stored=try JSONDecoder().decode(ImportCandidate.self,from:Data($0.utf8)),live=try importCandidate(stored.row,db:db)
            return ImportCandidate(id:stored.id,row:stored.row,group:.review,bookID:live.bookID,matches:live.matches,explanation:stored.explanation)
        } }
    }
    public func resolveImportCandidate(id: UUID, bookID: UUID?, createSeparateBook: Bool, confirmed: Bool) throws {
        guard confirmed else { throw ImportError.confirmationRequired }
        try queue.write { db in
            guard let json = try String.fetchOne(db,sql:"SELECT candidate_json FROM import_candidates WHERE owner_id=? AND id=? AND status='pending'",arguments:[ownerID.uuidString,id.uuidString]) else { throw ImportError.invalidResolution }
            let candidate = try JSONDecoder().decode(ImportCandidate.self,from:Data(json.utf8))
            guard candidate.row.issues.isEmpty, (bookID != nil) != createSeparateBook else { throw ImportError.invalidResolution }
            if let bookID {
                let live=try importCandidate(candidate.row,db:db)
                guard live.matches.contains(bookID) || live.bookID == bookID else { throw ImportError.invalidResolution }
                let known = try String.fetchOne(db,sql:"SELECT book_id FROM import_occurrences WHERE owner_id=? AND source_identity=? AND occurrence=0",arguments:[ownerID.uuidString,candidate.row.identity])
                guard known == nil || known == bookID.uuidString else { throw ImportError.invalidResolution }
                // Identity decision explicitly selects the existing canonical Book; existing local readings are preserved.
                try importNewHistory(candidate.row,bookID:bookID,db:db)
                try importProposals(candidate.row,bookID:bookID,db:db)
            } else {
                guard try Int.fetchOne(db,sql:"SELECT COUNT(*) FROM import_occurrences WHERE owner_id=? AND source_identity=?",arguments:[ownerID.uuidString,candidate.row.identity]) == 0 else { throw ImportError.invalidResolution }
                try importNewHistory(candidate.row,bookID:nil,db:db)
            }
            try db.execute(sql:"UPDATE import_candidates SET status='resolved' WHERE owner_id=? AND id=?",arguments:[ownerID.uuidString,id.uuidString]); try importResolveAttention(id,db:db)
            try importCommand(id:id,kind:"import.resolve",payload:["decision":"resolved"],db:db)
        }
    }
    public func skipImportCandidate(id: UUID, confirmed: Bool) throws {
        guard confirmed else { throw ImportError.confirmationRequired }
        try queue.write { db in
            guard try Int.fetchOne(db,sql:"SELECT COUNT(*) FROM import_candidates WHERE owner_id=? AND id=? AND status='pending'",arguments:[ownerID.uuidString,id.uuidString]) == 1 else { throw ImportError.invalidResolution }
            try db.execute(sql:"UPDATE import_candidates SET status='kept' WHERE owner_id=? AND id=?",arguments:[ownerID.uuidString,id.uuidString]);try importResolveAttention(id,db:db)
            try importCommand(id:id,kind:"import.skip",payload:["decision":"kept"],db:db)
        }
    }
    public func linkImportCandidate(id:UUID,bookID:UUID,readingIDs:[UUID],confirmed:Bool) throws {
        guard confirmed else { throw ImportError.confirmationRequired }
        try queue.write { db in
            guard let json=try String.fetchOne(db,sql:"SELECT candidate_json FROM import_candidates WHERE owner_id=? AND id=? AND status='pending'",arguments:[ownerID.uuidString,id.uuidString]) else { throw ImportError.invalidResolution }
            let candidate=try JSONDecoder().decode(ImportCandidate.self,from:Data(json.utf8))
            let live=try importCandidate(candidate.row,db:db)
            guard candidate.row.issues.isEmpty,candidate.row.status == "read",live.matches.contains(bookID) || live.bookID == bookID,
                  readingIDs.count == candidate.row.finishes.count,Set(readingIDs).count == readingIDs.count,
                  try Int.fetchOne(db,sql:"SELECT COUNT(*) FROM import_occurrences WHERE owner_id=? AND source_identity=?",arguments:[ownerID.uuidString,candidate.row.identity]) == 0 else { throw ImportError.invalidResolution }
            let record=try catalog(bookID,db:db)
            for id in readingIDs { guard record.readings.contains(where:{$0.id == id && $0.status == .read}) else { throw ImportError.invalidResolution } }
            try db.execute(sql:"INSERT INTO import_occurrences VALUES(?,?,0,?,NULL,NULL)",arguments:[ownerID.uuidString,candidate.row.identity,bookID.uuidString])
            for (index,readingID) in readingIDs.enumerated() {
                try db.execute(sql:"INSERT INTO import_occurrences VALUES(?,?,?,?,?,NULL)",arguments:[ownerID.uuidString,candidate.row.identity,index+1,bookID.uuidString,readingID.uuidString])
            }
            // Only explicit identity links are written. Existing live/historical status, Format and origin never change.
            try importProposals(candidate.row,bookID:bookID,db:db)
            try db.execute(sql:"UPDATE import_candidates SET status='resolved' WHERE owner_id=? AND id=?",arguments:[ownerID.uuidString,id.uuidString])
            try importResolveAttention(id,db:db);try importCommand(id:id,kind:"import.link",payload:readingIDs,db:db)
        }
    }
    public func importHistory() throws -> [ImportHistory] { try queue.read { db in try Row.fetchAll(db,sql:"SELECT * FROM import_runs WHERE owner_id=? ORDER BY rowid DESC",arguments:[ownerID.uuidString]).map(importHistoryRow) } }
    private func importRun(fingerprint: String, db: Database) throws -> ImportHistory? { try Row.fetchOne(db,sql:"SELECT * FROM import_runs WHERE owner_id=? AND fingerprint=?",arguments:[ownerID.uuidString,fingerprint]).map(importHistoryRow) }
    private func importHistoryRow(_ row: Row) -> ImportHistory { ImportHistory(id:UUID(uuidString:row["id"])!,completedAt:row["completed_at"],rows:row["rows_count"],newBooks:row["new_books"],newReadings:row["new_readings"],review:row["review_count"],unchanged:row["unchanged_count"]) }
    private func importAttention(_ id: UUID, reason: String, db: Database) throws { try db.execute(sql:"INSERT OR IGNORE INTO attention_items VALUES(?,?,'import',?,?,'open',?)",arguments:[ownerID.uuidString,UUID().uuidString,id.uuidString,reason,stamp()]) }
    private func importResolveAttention(_ id: UUID, db: Database) throws { try db.execute(sql:"UPDATE attention_items SET status='resolved' WHERE owner_id=? AND category='import' AND entity_id=?",arguments:[ownerID.uuidString,id.uuidString]) }
    private func importProvenance(_ id:UUID,type:String,field:String,reference:String,db:Database) throws { try db.execute(sql:"INSERT OR IGNORE INTO field_provenance(owner_id,entity_id,entity_type,field,source,source_ref,user_overridden) VALUES(?,?,?,?,'storygraph_csv',?,0)",arguments:[ownerID.uuidString,id.uuidString,type,field,reference]) }
    private func importCommand<T:Encodable>(id:UUID,kind:String,payload:T,db:Database) throws {
        var generation = try String.fetchOne(db,sql:"SELECT generation FROM sync_state WHERE owner_id=?",arguments:[ownerID.uuidString])
        if generation == nil { generation=UUID().uuidString;try db.execute(sql:"INSERT INTO sync_state(owner_id,generation) VALUES(?,?)",arguments:[ownerID.uuidString,generation]) }
        try enqueue(MutationEnvelope(ownerID:ownerID,entityID:id,expectedRevision:0,generation:UUID(uuidString:generation!)!,kind:kind,payload:JSONEncoder().encode(payload)),db:db)
    }
    private func importLibraryFingerprint(_ db:Database) throws -> String {
        // Covers local edits, removals, identity decisions and proposal state; transactional preview/apply has no stale silent overwrite.
        var parts = [String]()
        for table in ["books","editions","readings","library_memberships","field_provenance","data_change_proposals","import_occurrences","import_candidates"] {
            let rows = try Row.fetchAll(db,sql:"SELECT * FROM \(table) WHERE owner_id=? ORDER BY rowid",arguments:[ownerID.uuidString])
            parts.append(contentsOf:rows.map { $0.description })
        }
        return importHash(Data(parts.joined(separator:"\n").utf8))
    }
    private func importHash(_ data:Data) -> String { SHA256.hash(data:data).map { String(format:"%02x",$0) }.joined() }
    private func importCurrent(entity:UUID,type:String,field:String,db:Database) throws -> String? {
        if type == "import_book" {
            guard ["title","author"].contains(field) else { throw ImportError.invalidResolution }
            return try String.fetchOne(db,sql:"SELECT \(field) FROM books WHERE owner_id=? AND id=?",arguments:[ownerID.uuidString,entity.uuidString])
        }
        let reading=try reading(entity,db:db)
        switch field {
        case "start_date":return reading.startDate?.isoString
        case "finish_date":return reading.finishDate?.isoString
        case "rating":return try importJSON(reading.rating)
        default:throw ImportError.invalidResolution
        }
    }
    private func importRowFingerprint(_ row:StoryGraphRow) throws -> String {
        var value=try JSONSerialization.jsonObject(with:JSONEncoder().encode(row)) as! [String:Any]
        value.removeValue(forKey:"number")
        return importHash(try JSONSerialization.data(withJSONObject:value,options:[.sortedKeys]))
    }
    private func importJSON<T:Encodable>(_ value:T) throws -> String { let encoder=JSONEncoder();encoder.outputFormatting=[.sortedKeys];return String(data:try encoder.encode(value),encoding:.utf8)! }
    private func importDisplay(_ text:String?,field:String) -> String {
        guard let text else { return "Unknown" }
        guard field == "rating", let rating=try? JSONDecoder().decode(Rating.self,from:Data(text.utf8)) else { return text }
        return switch rating { case .unknown:"Unknown";case .noRating:"No rating";case .stars(let n):"\(n) stars" }
    }
}
