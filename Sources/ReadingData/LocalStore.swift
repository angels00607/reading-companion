import Foundation
import GRDB
import ReadingDomain

/// One account per store. Local mutations and queue records share the same transaction.
public final class LocalStore: @unchecked Sendable, OutboxRepository {
    let queue: DatabaseQueue
    public let ownerID: UUID
    let gamificationNow: @Sendable () -> Date
    let gamificationTimeZone: TimeZone
    public init(path: String, ownerID: UUID, gamificationNow: @escaping @Sendable () -> Date = { Date() }, timeZone: TimeZone = .current) throws {
        self.gamificationNow = gamificationNow; self.gamificationTimeZone = timeZone
        self.ownerID = ownerID
        var configuration = Configuration()
        configuration.foreignKeysEnabled = true
        queue = try DatabaseQueue(path: path, configuration: configuration)
        var migrator = DatabaseMigrator()
        migrator.registerMigration("local_v1") { db in
            let url = Bundle.module.url(forResource: "local_v1", withExtension: "sql")!
            try db.execute(sql: String(contentsOf: url, encoding: .utf8))
        }
        migrator.registerMigration("local_v2", foreignKeyChecks: .deferred) { db in
            let url = Bundle.module.url(forResource: "local_v2", withExtension: "sql")!
            try db.execute(sql: String(contentsOf: url, encoding: .utf8))
        }
        migrator.registerMigration("local_v3") { db in
            let url = Bundle.module.url(forResource: "local_v3", withExtension: "sql")!
            try db.execute(sql: String(contentsOf: url, encoding: .utf8))
        }
        migrator.registerMigration("local_v4") { db in
            let url = Bundle.module.url(forResource: "local_v4", withExtension: "sql")!
            try db.execute(sql: String(contentsOf: url, encoding: .utf8))
        }
        migrator.registerMigration("local_v5") { db in
            let url = Bundle.module.url(forResource: "local_v5", withExtension: "sql")!
            try db.execute(sql: String(contentsOf: url, encoding: .utf8))
        }
        migrator.registerMigration("local_v6") { db in
            let url = Bundle.module.url(forResource: "local_v6", withExtension: "sql")!
            try db.execute(sql: String(contentsOf: url, encoding: .utf8))
        }
        migrator.registerMigration("local_v7") { db in
            let url = Bundle.module.url(forResource: "local_v7", withExtension: "sql")!
            try db.execute(sql: String(contentsOf: url, encoding: .utf8))
        }
        migrator.registerMigration("local_v8") { db in
            let url = Bundle.module.url(forResource: "local_v8", withExtension: "sql")!
            try db.execute(sql: String(contentsOf: url, encoding: .utf8))
        }
        migrator.registerMigration("local_v9") { db in
            let url = Bundle.module.url(forResource: "local_v9", withExtension: "sql")!
            try db.execute(sql: String(contentsOf: url, encoding: .utf8))
        }
        migrator.registerMigration("local_v10") { db in
            let url = Bundle.module.url(forResource: "local_v10", withExtension: "sql")!
            try db.execute(sql: String(contentsOf: url, encoding: .utf8))
        }
        migrator.registerMigration("local_v11") { db in
            let url = Bundle.module.url(forResource: "local_v11", withExtension: "sql")!
            try db.execute(sql: String(contentsOf: url, encoding: .utf8))
        }
        migrator.registerMigration("local_v12") { db in
            let url = Bundle.module.url(forResource:"local_v12",withExtension:"sql")!
            try db.execute(sql:String(contentsOf:url,encoding:.utf8))
        }
        try migrator.migrate(queue)
    }
    public func addBook(_ book: Book, wantsToRead: Bool, mutation: MutationEnvelope) throws {
        guard book.ownerID == ownerID, mutation.ownerID == ownerID,
              mutation.entityID == book.id, mutation.kind == "book.create" else { throw DomainError.invalidTransition }
        let payload = try JSONDecoder().decode(BookCreatePayload.self, from: mutation.payload)
        guard payload.title == book.title, payload.author == book.author,
              payload.wantsToRead == wantsToRead else { throw DomainError.invalidTransition }
        try queue.write { db in
            let existing = try String.fetchOne(db, sql: "SELECT generation FROM sync_state WHERE owner_id=?",
                                               arguments: [ownerID.uuidString])
            if let existing {
                guard existing == mutation.generation.uuidString else { throw DomainError.staleRevision }
            } else {
                try db.execute(sql: "INSERT INTO sync_state(owner_id,generation) VALUES(?,?)",
                               arguments: [ownerID.uuidString,mutation.generation.uuidString])
            }
            try db.execute(sql: "INSERT INTO books(id,owner_id,title,author) VALUES (?,?,?,?)",
                           arguments: [book.id.uuidString, ownerID.uuidString, book.title, book.author])
            try db.execute(sql: "INSERT INTO library_memberships(owner_id,book_id,wants_to_read,added_at) VALUES (?,?,?,?)",
                           arguments: [ownerID.uuidString, book.id.uuidString, wantsToRead, ISO8601DateFormatter().string(from: Date())])
            try enqueue(mutation, db: db)
        }
    }
    func enqueue(_ mutation: MutationEnvelope, db: Database) throws {
        try db.execute(sql: """
            INSERT INTO outbox(id,owner_id,entity_id,expected_revision,generation,command_version,kind,payload,ordinal)
            VALUES (?,?,?,?,?,?,?,?,(SELECT COALESCE(MAX(ordinal),0)+1 FROM outbox))
            """, arguments: [mutation.id.uuidString, mutation.ownerID.uuidString, mutation.entityID.uuidString,
                mutation.expectedRevision, mutation.generation.uuidString, mutation.commandVersion,
                mutation.kind, mutation.payload])
    }
    public func pending(ownerID: UUID) async throws -> [MutationEnvelope] {
        guard ownerID == self.ownerID else { throw DomainError.invalidTransition }
        return try await queue.read { db in
            try Row.fetchAll(db, sql: """
                SELECT * FROM outbox WHERE owner_id=? AND state='pending'
                AND ordinal < COALESCE((SELECT MIN(ordinal) FROM outbox WHERE owner_id=? AND state='review'),9223372036854775807)
                ORDER BY ordinal
                """, arguments: [ownerID.uuidString,ownerID.uuidString]).map { row in
                guard let id = UUID(uuidString: row["id"]), let entity = UUID(uuidString: row["entity_id"]),
                      let generation = UUID(uuidString: row["generation"]) else { throw DomainError.invalidTransition }
                return MutationEnvelope(id: id, ownerID: ownerID, entityID: entity,
                    expectedRevision: row["expected_revision"], generation: generation,
                    commandVersion: row["command_version"], kind: row["kind"], payload: row["payload"])
            }
        }
    }
    public func acknowledge(id: UUID, revision: Int) async throws {
        try await queue.write { [self] db in
            if let row = try Row.fetchOne(db, sql: "SELECT entity_id,kind FROM outbox WHERE owner_id=? AND id=?",
                                          arguments: [ownerID.uuidString,id.uuidString]) {
                let kind: String = row["kind"]
                guard revision >= 1 else { throw DomainError.invalidTransition }
                let entityID: String = row["entity_id"]
                if kind.hasPrefix("book.") {
                    try db.execute(sql: "UPDATE books SET revision=MAX(revision,?) WHERE owner_id=? AND id=?",
                                   arguments: [revision,ownerID.uuidString,entityID])
                }
                try db.execute(sql:"INSERT OR IGNORE INTO sync_receipts(owner_id,mutation_id,entity_id,revision,acknowledged_at) VALUES(?,?,?,?,?)",arguments:[ownerID.uuidString,id.uuidString,entityID,revision,ISO8601DateFormatter().string(from:Date())])
            }
            try db.execute(sql: "DELETE FROM outbox WHERE owner_id=? AND id=?", arguments: [ownerID.uuidString,id.uuidString])
        }
    }
    public func requireReview(id: UUID) async throws {
        try await requireReview(id:id,serverRevision:nil,staleGeneration:false)
    }
    public func requireReview(id:UUID,serverRevision:Int?,staleGeneration:Bool) async throws {
        try await queue.write { [self] db in
            if let row = try Row.fetchOne(db,sql:"SELECT entity_id,expected_revision FROM outbox WHERE owner_id=? AND id=?",arguments:[ownerID.uuidString,id.uuidString]) {
                try db.execute(sql:"INSERT OR IGNORE INTO sync_conflicts(owner_id,mutation_id,entity_id,local_revision,server_revision,reason,created_at) VALUES(?,?,?,?,?,?,?)",arguments:[ownerID.uuidString,id.uuidString,row["entity_id"] as String,row["expected_revision"] as Int,serverRevision,staleGeneration ? "stale_generation":"revision",ISO8601DateFormatter().string(from:Date())])
            }
            try db.execute(sql: "UPDATE outbox SET state='review' WHERE owner_id=? AND id=?", arguments: [ownerID.uuidString,id.uuidString])
        }
    }
    func enqueueTombstone(entityType:String,entityID:UUID,kind:String,db:Database) throws {
        var generation=try String.fetchOne(db,sql:"SELECT generation FROM sync_state WHERE owner_id=?",arguments:[ownerID.uuidString])
        if generation==nil { generation=UUID().uuidString;try db.execute(sql:"INSERT INTO sync_state(owner_id,generation) VALUES(?,?)",arguments:[ownerID.uuidString,generation]) }
        let mutationID=UUID(),deletedAt=ISO8601DateFormatter().string(from:Date())
        try db.execute(sql:"INSERT INTO sync_tombstones(owner_id,entity_type,entity_id,deleted_at,revision,mutation_id) VALUES(?,?,?,?,0,?) ON CONFLICT(owner_id,entity_type,entity_id) DO NOTHING",arguments:[ownerID.uuidString,entityType,entityID.uuidString,deletedAt,mutationID.uuidString])
        struct Payload:Codable { let entityType:String;let entityID:UUID;let deletedAt:String }
        try enqueue(MutationEnvelope(id:mutationID,ownerID:ownerID,entityID:entityID,expectedRevision:0,generation:UUID(uuidString:generation!)!,kind:kind,payload:try JSONEncoder().encode(Payload(entityType:entityType,entityID:entityID,deletedAt:deletedAt))),db:db)
    }
    public func recordAttemptFailure(id: UUID) async throws {
        try await queue.write { [self] db in
            try db.execute(sql:"UPDATE outbox SET attempt_count=attempt_count+1,last_attempt_at=?,last_error='transport_unavailable' WHERE owner_id=? AND id=?",arguments:[ISO8601DateFormatter().string(from:Date()),ownerID.uuidString,id.uuidString])
        }
    }
    public func bookCount() throws -> Int {
        try queue.read { db in
            try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM books WHERE owner_id=?", arguments: [ownerID.uuidString]) ?? 0
        }
    }
}

extension LocalStore:SyncReplicaRepository {
    public func pullCursor(ownerID:UUID) async throws->Int64 {
        guard ownerID==self.ownerID else{throw DomainError.invalidTransition}
        return try await queue.read { try Int64.fetchOne($0,sql:"SELECT pull_cursor FROM sync_state WHERE owner_id=?",arguments:[ownerID.uuidString]) ?? 0 }
    }
    public func applyRemote(_ changes:[RemoteChange],ownerID:UUID) async throws {
        guard ownerID==self.ownerID else{throw DomainError.invalidTransition}
        try await queue.write { [self] db in
            var cursor=try Int64.fetchOne(db,sql:"SELECT pull_cursor FROM sync_state WHERE owner_id=?",arguments:[ownerID.uuidString]) ?? 0
            for change in changes.sorted(by:{$0.sequence<$1.sequence}) {
                guard change.sequence>cursor else{continue}
                let duplicate=(try Int.fetchOne(db,sql:"SELECT COUNT(*) FROM sync_incoming WHERE owner_id=? AND mutation_id=?",arguments:[ownerID.uuidString,change.mutationID.uuidString]) ?? 0)>0
                if !duplicate {
                    let locallyPending=(try Int.fetchOne(db,sql:"SELECT COUNT(*) FROM outbox WHERE owner_id=? AND entity_id=?",arguments:[ownerID.uuidString,change.entityID.uuidString]) ?? 0)>0
                    if locallyPending {
                        try db.execute(sql:"INSERT OR IGNORE INTO sync_conflicts(owner_id,mutation_id,entity_id,local_revision,server_revision,reason,created_at) VALUES(?,?,?,0,?,'revision',?)",arguments:[ownerID.uuidString,change.mutationID.uuidString,change.entityID.uuidString,change.revision,self.stamp()])
                    } else if change.kind=="book.create" {
                        let value=try JSONDecoder().decode(BookCreatePayload.self,from:change.payload)
                        try db.execute(sql:"INSERT OR IGNORE INTO books(id,owner_id,title,author,revision) VALUES(?,?,?,?,?)",arguments:[change.entityID.uuidString,ownerID.uuidString,value.title,value.author,change.revision])
                        try db.execute(sql:"INSERT OR IGNORE INTO library_memberships(owner_id,book_id,wants_to_read,added_at) VALUES(?,?,?,?)",arguments:[ownerID.uuidString,change.entityID.uuidString,value.wantsToRead,self.stamp()])
                    } else if change.kind=="journal.quote.delete" {
                        try db.execute(sql:"DELETE FROM quotes WHERE owner_id=? AND id=?",arguments:[ownerID.uuidString,change.entityID.uuidString])
                        try db.execute(sql:"INSERT OR IGNORE INTO sync_tombstones(owner_id,entity_type,entity_id,deleted_at,revision,mutation_id) VALUES(?,'quote',?,?,?,?)",arguments:[ownerID.uuidString,change.entityID.uuidString,change.deletedAt ?? self.stamp(),change.revision,change.mutationID.uuidString])
                    } else if change.kind=="reading.progress" {
                        let observation=try JSONDecoder().decode(ProgressObservation.self,from:change.payload)
                        guard observation.id==change.mutationID,observation.readingID==change.entityID,
                              let row=try Row.fetchOne(db,sql:"SELECT revision,progress_mode,current_page,total_pages,progress_percentage FROM readings WHERE owner_id=? AND id=?",arguments:[ownerID.uuidString,change.entityID.uuidString]) else{throw DomainError.invalidTransition}
                        let localRevision:Int=row["revision"],localMode:String=row["progress_mode"]
                        let review=observation.requiresReview || observation.expectedRevision != localRevision || observation.value.mode.rawValue != localMode
                        try db.execute(sql:"INSERT OR IGNORE INTO progress_observations(owner_id,id,reading_id,mutation_id,mode,previous_page,new_page,total_pages,previous_percentage,new_percentage,recorded_at,base_revision,requires_review,ordinal) VALUES(?,?,?,?,?,?,?,?,?,?,?,?,?,(SELECT COALESCE(MAX(ordinal),0)+1 FROM progress_observations))",arguments:[ownerID.uuidString,observation.id.uuidString,observation.readingID.uuidString,observation.id.uuidString,observation.value.mode.rawValue,review ? nil : row["current_page"],observation.value.currentPage,observation.value.totalPages,review ? nil : row["progress_percentage"],observation.value.percentage,self.stamp(observation.recordedAt),observation.expectedRevision,review])
                        if review {
                            try db.execute(sql:"INSERT OR IGNORE INTO sync_conflicts(owner_id,mutation_id,entity_id,local_revision,server_revision,reason,created_at) VALUES(?,?,?,?,?,'revision',?)",arguments:[ownerID.uuidString,change.mutationID.uuidString,change.entityID.uuidString,localRevision,change.revision,self.stamp()])
                        } else {
                            try db.execute(sql:"UPDATE readings SET progress_mode=?,current_page=?,total_pages=?,progress_percentage=?,revision=revision+1 WHERE owner_id=? AND id=?",arguments:[observation.value.mode.rawValue,observation.value.currentPage,observation.value.totalPages,observation.value.percentage,ownerID.uuidString,change.entityID.uuidString])
                        }
                    } else if ["catalog.snapshot","library.intent","book.edit","book.proposal_decision"].contains(change.kind) {
                        let value=try JSONDecoder().decode(CatalogRecord.self,from:change.payload)
                        guard value.book.ownerID==ownerID,value.id==change.entityID else{throw DomainError.invalidTransition}
                        try self.applyRemoteCatalog(value,db:db)
                    } else if ["reading.start","reading.completed_record","reading.resolve","reading.finish","reading.dnf","reading.resume","reading.edit"].contains(change.kind) {
                        let value=try JSONDecoder().decode(ReadingInstance.self,from:change.payload)
                        guard value.id==change.entityID else{throw DomainError.invalidTransition}
                        try self.applyRemoteReading(value,db:db)
                    } else if change.kind=="edition.edit" {
                        let value=try JSONDecoder().decode(Edition.self,from:change.payload)
                        guard value.bookID==change.entityID else{throw DomainError.invalidTransition}
                        try db.execute(sql:"INSERT INTO editions(id,owner_id,book_id,language,page_count,isbn13,edition_title,isbn10,cover_ref,publisher,revision) VALUES(?,?,?,?,?,?,?,?,?,?,?) ON CONFLICT(owner_id,id) DO UPDATE SET language=excluded.language,page_count=excluded.page_count,isbn13=excluded.isbn13,edition_title=excluded.edition_title,isbn10=excluded.isbn10,cover_ref=excluded.cover_ref,publisher=excluded.publisher,revision=MAX(editions.revision,excluded.revision)",arguments:[value.id.uuidString,ownerID.uuidString,value.bookID.uuidString,value.language,value.pageCount,value.isbn13,value.title,value.isbn10,value.coverReference,value.publisher,change.revision])
                    } else {
                        // Never silently drop an understood and authenticated remote
                        // command that this binary cannot safely materialize.
                        try db.execute(sql:"INSERT OR IGNORE INTO sync_conflicts(owner_id,mutation_id,entity_id,local_revision,server_revision,reason,created_at) VALUES(?,?,?,0,?,'revision',?)",arguments:[ownerID.uuidString,change.mutationID.uuidString,change.entityID.uuidString,change.revision,self.stamp()])
                    }
                    try db.execute(sql:"INSERT INTO sync_incoming(owner_id,sequence,mutation_id,entity_id,revision,generation,kind,payload,deleted_at,applied_at) VALUES(?,?,?,?,?,?,?,?,?,?)",arguments:[ownerID.uuidString,change.sequence,change.mutationID.uuidString,change.entityID.uuidString,change.revision,change.generation.uuidString,change.kind,change.payload,change.deletedAt,self.stamp()])
                }
                cursor=max(cursor,change.sequence)
            }
            try db.execute(sql:"INSERT INTO sync_state(owner_id,generation,pull_cursor) VALUES(?,?,?) ON CONFLICT(owner_id) DO UPDATE SET pull_cursor=MAX(pull_cursor,excluded.pull_cursor)",arguments:[ownerID.uuidString,(changes.last?.generation ?? UUID()).uuidString,cursor])
        }
    }
    private func applyRemoteCatalog(_ value:CatalogRecord,db:Database) throws {
        let current=try Int.fetchOne(db,sql:"SELECT revision FROM books WHERE owner_id=? AND id=?",arguments:[ownerID.uuidString,value.id.uuidString])
        guard current==nil || current!<=value.revision else{throw DomainError.staleRevision}
        try db.execute(sql:"INSERT INTO books(id,owner_id,title,author,revision,cover_ref,synopsis,series_name,genre_suggestion) VALUES(?,?,?,?,?,?,?,?,?) ON CONFLICT(owner_id,id) DO UPDATE SET title=excluded.title,author=excluded.author,revision=excluded.revision,cover_ref=excluded.cover_ref,synopsis=excluded.synopsis,series_name=excluded.series_name,genre_suggestion=excluded.genre_suggestion",arguments:[value.id.uuidString,ownerID.uuidString,value.book.title,value.book.author,value.revision,value.coverReference,value.synopsis,value.seriesName,value.genreSuggestion])
        try db.execute(sql:"INSERT INTO library_memberships(owner_id,book_id,wants_to_read,added_at) VALUES(?,?,?,?) ON CONFLICT(owner_id,book_id) DO UPDATE SET wants_to_read=excluded.wants_to_read,removed_at=NULL",arguments:[ownerID.uuidString,value.id.uuidString,value.wantsToRead,stamp()])
        for edition in value.editions { try db.execute(sql:"INSERT INTO editions(id,owner_id,book_id,language,page_count,isbn13,edition_title,isbn10,cover_ref,publisher,revision) VALUES(?,?,?,?,?,?,?,?,?,?,0) ON CONFLICT(owner_id,id) DO UPDATE SET language=excluded.language,page_count=excluded.page_count,isbn13=excluded.isbn13,edition_title=excluded.edition_title,isbn10=excluded.isbn10,cover_ref=excluded.cover_ref,publisher=excluded.publisher",arguments:[edition.id.uuidString,ownerID.uuidString,edition.bookID.uuidString,edition.language,edition.pageCount,edition.isbn13,edition.title,edition.isbn10,edition.coverReference,edition.publisher]) }
        for reading in value.readings { try applyRemoteReading(reading,db:db) }
    }
    private func applyRemoteReading(_ value:ReadingInstance,db:Database) throws {
        guard (try Int.fetchOne(db,sql:"SELECT COUNT(*) FROM books WHERE owner_id=? AND id=?",arguments:[ownerID.uuidString,value.bookID.uuidString]) ?? 0)==1 else{throw DomainError.invalidTransition}
        let current=try Int.fetchOne(db,sql:"SELECT revision FROM readings WHERE owner_id=? AND id=?",arguments:[ownerID.uuidString,value.id.uuidString])
        guard current==nil || current!<=value.revision else{throw DomainError.staleRevision}
        var ratingState="unknown";var rating:Int?
        switch value.rating{case .unknown:break;case .noRating:ratingState="unrated";case .stars(let stars):ratingState="rated";rating=stars}
        try db.execute(sql:"INSERT INTO readings(id,owner_id,book_id,edition_id,status,progress_mode,current_page,total_pages,progress_percentage,start_date,finish_date,rating_state,rating_whole,journal_format,historical,revision,primary_genre) VALUES(?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?) ON CONFLICT(owner_id,id) DO UPDATE SET edition_id=excluded.edition_id,status=excluded.status,progress_mode=excluded.progress_mode,current_page=excluded.current_page,total_pages=excluded.total_pages,progress_percentage=excluded.progress_percentage,start_date=excluded.start_date,finish_date=excluded.finish_date,rating_state=excluded.rating_state,rating_whole=excluded.rating_whole,journal_format=excluded.journal_format,historical=excluded.historical,revision=excluded.revision,primary_genre=excluded.primary_genre",arguments:[value.id.uuidString,ownerID.uuidString,value.bookID.uuidString,value.editionID?.uuidString,value.status.rawValue,value.progress.mode.rawValue,value.progress.currentPage,value.progress.totalPages,value.progress.percentage,value.startDate?.isoString,value.finishDate?.isoString,ratingState,rating,value.journalFormat?.rawValue,value.historical,value.revision,value.primaryGenre])
        for observation in value.progressObservations {
            try db.execute(sql:"INSERT OR IGNORE INTO progress_observations(owner_id,id,reading_id,mutation_id,mode,previous_page,new_page,total_pages,previous_percentage,new_percentage,recorded_at,base_revision,requires_review,ordinal) VALUES(?,?,?,?,?,?,?,?,?,?,?,?,?,(SELECT COALESCE(MAX(ordinal),0)+1 FROM progress_observations))",arguments:[ownerID.uuidString,observation.id.uuidString,value.id.uuidString,observation.id.uuidString,observation.value.mode.rawValue,observation.previous?.currentPage,observation.value.currentPage,observation.value.totalPages,observation.previous?.percentage,observation.value.percentage,stamp(observation.recordedAt),observation.expectedRevision,observation.requiresReview])
        }
    }
}
