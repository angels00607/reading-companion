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
                    }
                    try db.execute(sql:"INSERT INTO sync_incoming(owner_id,sequence,mutation_id,entity_id,revision,generation,kind,payload,deleted_at,applied_at) VALUES(?,?,?,?,?,?,?,?,?,?)",arguments:[ownerID.uuidString,change.sequence,change.mutationID.uuidString,change.entityID.uuidString,change.revision,change.generation.uuidString,change.kind,change.payload,change.deletedAt,self.stamp()])
                }
                cursor=max(cursor,change.sequence)
            }
            try db.execute(sql:"INSERT INTO sync_state(owner_id,generation,pull_cursor) VALUES(?,?,?) ON CONFLICT(owner_id) DO UPDATE SET pull_cursor=MAX(pull_cursor,excluded.pull_cursor)",arguments:[ownerID.uuidString,(changes.last?.generation ?? UUID()).uuidString,cursor])
        }
    }
}
