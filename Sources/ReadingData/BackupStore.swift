import Foundation
import GRDB
import ReadingDomain

public struct BackupPreview: Equatable, Sendable {
    public let token: String
    public let createdAt: String
    public let entityCounts: [String: Int]
    public let incomingRecords: Int
    public let existingRecords: Int
    public let permanentXPAwardsAdded: Int
}

public enum BackupRestoreError: Error, Equatable {
    case confirmationRequired, stalePreview, invalidRelationship, invalidValue, postRestoreIntegrity
}

private enum BackupScalar: Codable, Equatable, Sendable {
    case text(String), integer(Int64), real(Double), blob(Data), null

    private enum Keys: String, CodingKey { case type, text, integer, real, blob }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: Keys.self)
        switch try c.decode(String.self, forKey: .type) {
        case "text": self = .text(try c.decode(String.self, forKey: .text))
        case "integer": self = .integer(try c.decode(Int64.self, forKey: .integer))
        case "real": self = .real(try c.decode(Double.self, forKey: .real))
        case "blob": self = .blob(try c.decode(Data.self, forKey: .blob))
        case "null": self = .null
        default: throw BackupRestoreError.invalidValue
        }
    }
    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: Keys.self)
        switch self {
        case .text(let v): try c.encode("text", forKey:.type); try c.encode(v, forKey:.text)
        case .integer(let v): try c.encode("integer", forKey:.type); try c.encode(v, forKey:.integer)
        case .real(let v): try c.encode("real", forKey:.type); try c.encode(v, forKey:.real)
        case .blob(let v): try c.encode("blob", forKey:.type); try c.encode(v, forKey:.blob)
        case .null: try c.encode("null", forKey:.type)
        }
    }
    var databaseValue: DatabaseValue {
        switch self { case .text(let v): v.databaseValue; case .integer(let v): v.databaseValue
        case .real(let v): v.databaseValue; case .blob(let v): v.databaseValue; case .null: .null }
    }
}

private struct BackupRecord: Codable, Equatable, Sendable { let fields: [String: BackupScalar] }
private struct TypedBackupPayload: Codable, Sendable {
    let schemaVersion: Int
    let entities: [String: [BackupRecord]]
}

/// Strict logical export/restore boundary. SQLite implementation details, outbox,
/// sessions, sync receipts and credentials are deliberately absent.
public extension LocalStore {
    func makePortableBackup(appVersion: String, createdAt: Date = Date(), sourceDevice: String = "iOS",
                            assets: [String: Data] = [:]) throws -> Data {
        let entities = try queue.read { db in
            var result = [String: [BackupRecord]]()
            for spec in Self.backupSpecs {
                let allowed = Set(spec.columns)
                let rows = try Row.fetchAll(db, sql: "SELECT \(spec.columns.joined(separator: ",")) FROM \(spec.table) WHERE owner_id=? ORDER BY \(spec.order)", arguments:[ownerID.uuidString])
                result[spec.collection] = try rows.map { row in
                    var fields = [String:BackupScalar]()
                    for column in spec.columns {
                        guard allowed.contains(column) else { throw BackupRestoreError.invalidValue }
                        let value: DatabaseValue = row[column]
                        switch value.storage {
                        case .null: fields[column] = .null
                        case .int64(let v): fields[column] = .integer(v)
                        case .double(let v): fields[column] = .real(v)
                        case .string(let v): fields[column] = .text(v)
                        case .blob(let v): fields[column] = .blob(v)
                        }
                    }
                    return BackupRecord(fields: fields)
                }
            }
            return result
        }
        let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys]
        let json = try encoder.encode(TypedBackupPayload(schemaVersion: PortableBackupCodec.schemaVersion, entities:entities))
        return try PortableBackupCodec().encode(json:json,assets:assets,appVersion:appVersion,createdAt:createdAt,sourceDevice:sourceDevice)
    }

    func previewPortableRestore(_ archive: Data) throws -> BackupPreview {
        let decoded = try PortableBackupCodec().decode(archive)
        let payload = try Self.decodeTypedPayload(decoded.json)
        try Self.validate(payload)
        let state = try backupStateToken()
        let existing = try queue.read { db in try Self.backupSpecs.reduce(0) { sum,spec in
            sum + (try Int.fetchOne(db,sql:"SELECT COUNT(*) FROM \(spec.table) WHERE owner_id=?",arguments:[ownerID.uuidString]) ?? 0)
        } }
        let incomingKeys = Set((payload.entities["xpAwards"] ?? []).compactMap { record -> String? in
            if case .text(let value)? = record.fields["semantic_key"] { return value }; return nil
        })
        let existingKeys = try queue.read { db in Set(try String.fetchAll(db,sql:"SELECT semantic_key FROM xp_awards WHERE owner_id=?",arguments:[ownerID.uuidString])) }
        return BackupPreview(token:state,createdAt:decoded.manifest.createdAt,entityCounts:decoded.manifest.entityCounts,
            incomingRecords:payload.entities.values.reduce(0){$0+$1.count},existingRecords:existing,
            permanentXPAwardsAdded:incomingKeys.subtracting(existingKeys).count)
    }

    func restorePortableBackup(_ archive: Data, preview: BackupPreview, confirmed: Bool) throws {
        guard confirmed else { throw BackupRestoreError.confirmationRequired }
        guard try backupStateToken() == preview.token else { throw BackupRestoreError.stalePreview }
        let decoded = try PortableBackupCodec().decode(archive)
        let payload = try Self.decodeTypedPayload(decoded.json); try Self.validate(payload)
        try queue.write { db in
            try Self.validatePermanentXP(payload,ownerID:ownerID,db:db)
            for spec in Self.backupSpecs {
                for record in payload.entities[spec.collection] ?? [] {
                    let columns = spec.columns.filter { record.fields[$0] != nil }
                    guard Set(record.fields.keys) == Set(columns) else { throw BackupRestoreError.invalidValue }
                    let names = ["owner_id"] + columns
                    let values = [ownerID.uuidString.databaseValue] + columns.map { record.fields[$0]!.databaseValue }
                    // Existing local facts win. XP is a permanent semantic-key union;
                    // immutable import/history rows remain untouched on a repeated restore.
                    try db.execute(sql:"INSERT OR IGNORE INTO \(spec.table)(\(names.joined(separator:","))) VALUES(\(Array(repeating:"?",count:names.count).joined(separator:",")))",arguments:StatementArguments(values))
                }
            }
            let violations = try Row.fetchAll(db,sql:"PRAGMA foreign_key_check")
            guard violations.isEmpty else { throw BackupRestoreError.invalidRelationship }
            // A restore is a new synchronization generation. Historical outbox work
            // is never replayed and restore itself emits no live events or XP.
            try db.execute(sql:"DELETE FROM outbox WHERE owner_id=?",arguments:[ownerID.uuidString])
            try db.execute(sql:"INSERT INTO sync_state(owner_id,generation,pull_cursor) VALUES(?,?,0) ON CONFLICT(owner_id) DO UPDATE SET generation=excluded.generation,pull_cursor=0",arguments:[ownerID.uuidString,UUID().uuidString])
        }
        _ = try previewPortableRestore(archive)
    }

    private func backupStateToken() throws -> String {
        try queue.read { db in
            var pieces = [String]()
            for spec in Self.backupSpecs {
                let count = try Int.fetchOne(db,sql:"SELECT COUNT(*) FROM \(spec.table) WHERE owner_id=?",arguments:[ownerID.uuidString]) ?? 0
                pieces.append("\(spec.table):\(count)")
            }
            return pieces.joined(separator:"|")
        }
    }

    private static func decodeTypedPayload(_ data: Data) throws -> TypedBackupPayload {
        do { return try JSONDecoder().decode(TypedBackupPayload.self,from:data) }
        catch let e as BackupRestoreError { throw e }
        catch { throw PortableBackupError.invalidPayload }
    }
    private static func validate(_ payload: TypedBackupPayload) throws {
        guard payload.schemaVersion == PortableBackupCodec.schemaVersion,
              Set(payload.entities.keys) == Set(backupSpecs.map(\.collection)) else { throw PortableBackupError.invalidPayload }
        for spec in backupSpecs { for record in payload.entities[spec.collection] ?? [] {
            guard Set(record.fields.keys) == Set(spec.columns) else { throw PortableBackupError.invalidPayload }
        } }
    }
    private static func validatePermanentXP(_ payload:TypedBackupPayload,ownerID:UUID,db:Database) throws {
        func text(_ record:BackupRecord,_ key:String)->String? { if case .text(let v)?=record.fields[key]{return v};return nil }
        func integer(_ record:BackupRecord,_ key:String)->Int64? { if case .integer(let v)?=record.fields[key]{return v};return nil }
        var metadata=[String:String]()
        for record in payload.entities["xpAwardMetadata"] ?? [] {
            guard let key=text(record,"semantic_key"),let source=text(record,"source"),XPSource(rawValue:source) != nil else { throw BackupRestoreError.invalidValue }
            guard metadata.updateValue(source,forKey:key)==nil else{throw BackupRestoreError.invalidValue}
        }
        var total:Int64=0
        for record in payload.entities["xpAwards"] ?? [] {
            guard let key=text(record,"semantic_key"),!key.isEmpty,let amount=integer(record,"amount"),amount>=0,
                  metadata[key] != nil else { throw BackupRestoreError.invalidValue }
            let (next,overflow)=total.addingReportingOverflow(amount);guard !overflow else{throw BackupRestoreError.invalidValue};total=next
            if let row=try Row.fetchOne(db,sql:"SELECT a.amount,m.source FROM xp_awards a JOIN xp_award_metadata m USING(owner_id,semantic_key) WHERE a.owner_id=? AND a.semantic_key=?",arguments:[ownerID.uuidString,key]) {
                guard (row["amount"] as Int64)==amount,(row["source"] as String)==metadata[key] else { throw BackupRestoreError.invalidValue }
            }
        }
    }
}

private struct BackupTableSpec {
    let collection:String, table:String, columns:[String], order:String
}

private extension LocalStore {
    static let backupSpecs:[BackupTableSpec] = [
        .init(collection:"books",table:"books",columns:["id","title","author","revision","deleted_at","cover_ref","synopsis","series_name","genre_suggestion"],order:"id"),
        .init(collection:"libraryMemberships",table:"library_memberships",columns:["book_id","wants_to_read","added_at","removed_at"],order:"book_id"),
        .init(collection:"editions",table:"editions",columns:["id","book_id","language","page_count","isbn13","revision","edition_title","isbn10","cover_ref","publisher"],order:"id"),
        .init(collection:"readings",table:"readings",columns:["id","book_id","edition_id","status","progress_mode","current_page","total_pages","progress_percentage","start_date","finish_date","rating_state","rating_whole","journal_format","historical","revision","deleted_at","primary_genre"],order:"id"),
        .init(collection:"progressObservations",table:"progress_observations",columns:["id","reading_id","mutation_id","mode","previous_page","new_page","total_pages","previous_percentage","new_percentage","recorded_at","base_revision","requires_review","ordinal"],order:"ordinal,id"),
        .init(collection:"journalEntries",table:"journal_entries",columns:["id","reading_id","book_id","summary","page_count","volume_id","created_at"],order:"id"),
        .init(collection:"journalComponents",table:"journal_components",columns:["id","reading_id","component","state","copied_payload","copied_at","purpose"],order:"id"),
        .init(collection:"quotes",table:"quotes",columns:["id","book_id","reading_id","quote_text","source","include_in_journal","volume_id","copied_at"],order:"id"),
        .init(collection:"favorites",table:"favorites",columns:["book_id","decision","volume_id","copied_at"],order:"book_id"),
        .init(collection:"journalVolumes",table:"journal_volumes",columns:["id","number","archived","created_at","archived_at"],order:"number"),
        .init(collection:"journalCorrections",table:"journal_corrections",columns:["id","reading_id","component","field","previous_value","current_value","status","created_at","resolved_at"],order:"id"),
        .init(collection:"series",table:"series",columns:["id","name","author","user_status_override","evidence_json","final_total_known","updated_at"],order:"id"),
        .init(collection:"seriesEntries",table:"series_entries",columns:["id","series_id","book_id","title","position","kind","publication","release_precision","release_value","included","tracker_included"],order:"id"),
        .init(collection:"seriesRejections",table:"series_rejections",columns:["series_id","field","evidence_fingerprint","rejected_at"],order:"series_id,field,evidence_fingerprint"),
        .init(collection:"challengeYears",table:"challenge_years",columns:["id","year","version","content_json"],order:"year"),
        .init(collection:"challengePrompts",table:"challenge_prompts",columns:["id","year_id","challenge_key","prompt_key","text","is_tbd"],order:"id"),
        .init(collection:"challengeAssignments",table:"challenge_assignments",columns:["id","prompt_id","reading_id","status","confidence","evidence_fingerprint","source","evidence_json","created_at"],order:"id"),
        .init(collection:"challengeRejections",table:"challenge_rejections",columns:["rejection_key","book_id","prompt_id","rejected_at"],order:"rejection_key"),
        .init(collection:"challengeAnalysis",table:"challenge_analysis",columns:["year_id","reading_id","evidence_json"],order:"year_id,reading_id"),
        .init(collection:"bestBookSelections",table:"best_book_selections",columns:["id","scope","period","reading_id","revision","created_at","updated_at"],order:"id"),
        .init(collection:"readingActivityDates",table:"reading_activity_dates",columns:["reading_id","activity_date","source","source_reference","recorded_at"],order:"reading_id,activity_date"),
        .init(collection:"readerProfiles",table:"reader_profiles",columns:["display_name","avatar_symbol","reading_since","favorite_books_json","favorite_series","favorite_author","favorite_genre","featured_achievement_keys_json","updated_at"],order:"display_name"),
        .init(collection:"quests",table:"quest_instances",columns:["id","template_key","cadence","period_key","title","unit","target","progress","completed_at","rerolled_at"],order:"id"),
        .init(collection:"questLifecycle",table:"quest_lifecycle",columns:["quest_id","slot","baseline","created_at"],order:"quest_id,slot"),
        .init(collection:"achievements",table:"achievement_progress",columns:["achievement_key","progress","unlocked_at"],order:"achievement_key"),
        .init(collection:"cosmetics",table:"user_cosmetics",columns:["cosmetic_key","state","updated_at"],order:"cosmetic_key"),
        .init(collection:"gamificationActivity",table:"gamification_activity",columns:["semantic_key","family","entity_id","quantity","activity_date","occurred_at"],order:"semantic_key"),
        .init(collection:"xpAwards",table:"xp_awards",columns:["semantic_key","amount","awarded_at"],order:"semantic_key"),
        .init(collection:"xpAwardMetadata",table:"xp_award_metadata",columns:["semantic_key","source"],order:"semantic_key"),
        .init(collection:"attention",table:"attention_items",columns:["id","category","entity_id","reason","status","created_at"],order:"id"),
        .init(collection:"proposals",table:"data_change_proposals",columns:["id","entity_id","entity_type","field","current_json","proposed_json","evidence_fingerprint","status","source"],order:"id"),
        .init(collection:"provenance",table:"field_provenance",columns:["entity_id","entity_type","field","source","source_ref","evidence_fingerprint","user_overridden"],order:"entity_type,entity_id,field"),
        .init(collection:"providerLinks",table:"provider_links",columns:["book_id","edition_id","provider","reference"],order:"book_id,provider,reference"),
        .init(collection:"importRuns",table:"import_runs",columns:["id","fingerprint","completed_at","rows_count","new_books","new_readings","review_count","unchanged_count"],order:"id"),
        .init(collection:"importCandidates",table:"import_candidates",columns:["id","run_id","candidate_json","fingerprint","status"],order:"id"),
        .init(collection:"importOccurrences",table:"import_occurrences",columns:["source_identity","occurrence","book_id","reading_id","edition_id"],order:"source_identity,occurrence")
    ]
}
