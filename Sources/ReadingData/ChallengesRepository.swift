import Foundation
import GRDB
import ReadingDomain

extension LocalStore: ChallengesRepository {
    public func ensureChallengeYear(year: Int) throws { try queue.write { db in
        _ = try ensureChallenges(year, db)
        try placeDeterministicChallenges(year, db)
    } }
    public func challengeYears() throws -> [Int] { try queue.read {
        try Int.fetchAll($0, sql: "SELECT year FROM challenge_years WHERE owner_id=? ORDER BY year DESC", arguments: [ownerID.uuidString])
    } }
    public func challengeYear(year: Int) throws -> ChallengeYearState { try queue.read { db in
        let config = try challengeConfig(year, db)
        let readings = try challengeReadings(db)
        let rows = try Row.fetchAll(db, sql: "SELECT a.* FROM challenge_assignments a JOIN challenge_prompts p ON p.owner_id=a.owner_id AND p.id=a.prompt_id WHERE a.owner_id=? AND p.year_id=? ORDER BY a.rowid", arguments: [ownerID.uuidString,config.id.uuidString])
        var assignments = [ChallengeAssignment](); var proposals = [ChallengeProposal]()
        for row in rows {
            let readingID = UUID(uuidString: row["reading_id"])!, promptID = UUID(uuidString: row["prompt_id"])!
            let evidence = try (row["evidence_json"] as String?).map { try JSONDecoder().decode(ChallengeEvidence.self, from: Data($0.utf8)) }
            let status: String = row["status"]
            if status == "confirmed", let record = readings.first(where: { $0.id == readingID }) {
                assignments.append(.init(id: UUID(uuidString: row["id"])!, readingID: readingID, promptID: promptID, bookID: record.book.id, source: row["source"], confidence: row["confidence"], evidence: evidence))
            } else if status == "proposed", let evidence, let confidence: Int = row["confidence"] {
                proposals.append(.init(id: UUID(uuidString: row["id"])!, readingID: readingID, promptID: promptID, confidence: confidence, evidence: evidence))
            }
        }
        let rejected = Set(try String.fetchAll(db, sql: "SELECT rejection_key FROM challenge_rejections WHERE owner_id=?", arguments: [ownerID.uuidString]))
        // Persist all eligible candidates, expose only one best match across Challenges.
        let best = ChallengeRules.best(proposals, prompts: config.prompts, readings: readings, occupied: Set(assignments.map(\.promptID)), rejected: rejected, year: year)
        let hasAnalysis = (try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM challenge_analysis WHERE owner_id=? AND year_id=?", arguments: [ownerID.uuidString,config.id.uuidString]) ?? 0) > 0
        return ChallengeYearState(configuration: config, assignments: assignments, proposals: best.map { [$0] } ?? [], readings: readings, hasAnalysis: hasAnalysis)
    } }
    public func storeChallengeProposals(_ proposals: [ChallengeProposal], year: Int) throws { try queue.write { db in
        let config = try challengeConfig(year, db); let readings = try challengeReadings(db)
        for proposal in proposals {
            guard (0...100).contains(proposal.confidence), proposal.evidence.usable,
                  let prompt = config.prompts.first(where: { $0.id == proposal.promptID }), prompt.challenge.semantic,
                  let record = readings.first(where: { $0.id == proposal.readingID }),
                  ChallengeRules.eligible(record, prompt: prompt, year: year, automatic: true) else { throw ChallengeError.invalidEvidence }
            try db.execute(sql: "INSERT INTO challenge_analysis(owner_id,year_id,reading_id,evidence_json) VALUES(?,?,?,?) ON CONFLICT(owner_id,year_id,reading_id) DO UPDATE SET evidence_json=excluded.evidence_json", arguments: [ownerID.uuidString,config.id.uuidString,record.id.uuidString,try challengeJSON(proposals.filter { $0.readingID == record.id })])
            guard proposal.confidence >= 70 else { continue }
            let rejection = ChallengeRules.rejectionKey(bookID: record.book.id, promptID: prompt.id, evidence: proposal.evidence)
            guard try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM challenge_rejections WHERE owner_id=? AND rejection_key=?", arguments: [ownerID.uuidString,rejection]) == 0,
                  try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM challenge_assignments WHERE owner_id=? AND prompt_id=? AND status='confirmed'", arguments: [ownerID.uuidString,prompt.id.uuidString]) == 0 else { continue }
            let evidenceJSON = try challengeJSON(proposal.evidence)
            // Identical evidence is idempotent even if an adapter generates another UUID.
            guard try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM challenge_assignments a JOIN readings r ON r.owner_id=a.owner_id AND r.id=a.reading_id WHERE a.owner_id=? AND r.book_id=? AND a.prompt_id=? AND a.evidence_fingerprint=?", arguments: [ownerID.uuidString,record.book.id.uuidString,prompt.id.uuidString,rejection]) == 0 else { continue }
            try db.execute(sql: "INSERT INTO challenge_assignments(owner_id,id,prompt_id,reading_id,status,confidence,evidence_fingerprint,source,evidence_json,created_at) VALUES(?,?,?,?,'proposed',?,?,?,?,?)", arguments: [ownerID.uuidString,proposal.id.uuidString,prompt.id.uuidString,record.id.uuidString,proposal.confidence,rejection,proposal.evidence.source,evidenceJSON,stamp()])
        }
        try refreshChallengeAttention(config, db)
        try enqueueChallenge(config.id, "challenge.proposals", proposals, db)
    } }
    public func confirmChallengeProposal(id: UUID, year: Int) throws { try queue.write { db in
        let config = try challengeConfig(year, db)
        guard let row = try Row.fetchOne(db, sql: "SELECT a.* FROM challenge_assignments a JOIN challenge_prompts p ON p.owner_id=a.owner_id AND p.id=a.prompt_id WHERE a.owner_id=? AND a.id=? AND p.year_id=?", arguments: [ownerID.uuidString,id.uuidString,config.id.uuidString]) else { throw ChallengeError.staleProposal }
        if row["status"] as String == "confirmed" { return }
        guard row["status"] as String == "proposed", let evidenceJSON: String = row["evidence_json"], let confidence: Int = row["confidence"] else { throw ChallengeError.staleProposal }
        let evidence = try JSONDecoder().decode(ChallengeEvidence.self, from: Data(evidenceJSON.utf8))
        guard evidence.usable, confidence >= 70 else { throw ChallengeError.invalidEvidence }
        let prompt = config.prompts.first { $0.id.uuidString == row["prompt_id"] as String }!
        let record = try challengeRecord(UUID(uuidString: row["reading_id"])!, db)
        try validateChallengeAssignment(prompt, record, config, db)
        let key = ChallengeRules.rejectionKey(bookID: record.book.id, promptID: prompt.id, evidence: evidence)
        guard try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM challenge_rejections WHERE owner_id=? AND rejection_key=?", arguments: [ownerID.uuidString,key]) == 0 else { throw ChallengeError.staleProposal }
        try db.execute(sql: "UPDATE challenge_assignments SET status='confirmed' WHERE owner_id=? AND id=?", arguments: [ownerID.uuidString,id.uuidString])
        try afterChallengeAssignment(config, record, db)
        try enqueueChallenge(id, "challenge.confirm", ["assignment":id.uuidString], db)
    } }
    public func rejectChallengeProposal(id: UUID, year: Int) throws { try queue.write { db in
        let config = try challengeConfig(year, db)
        guard let row = try Row.fetchOne(db, sql: "SELECT a.* FROM challenge_assignments a JOIN challenge_prompts p ON p.owner_id=a.owner_id AND p.id=a.prompt_id WHERE a.owner_id=? AND a.id=? AND p.year_id=? AND a.status IN ('proposed','rejected')", arguments: [ownerID.uuidString,id.uuidString,config.id.uuidString]) else { throw ChallengeError.staleProposal }
        if row["status"] as String == "rejected" { return }
        let record = try challengeRecord(UUID(uuidString: row["reading_id"])!, db)
        try db.execute(sql: "INSERT OR IGNORE INTO challenge_rejections(owner_id,rejection_key,book_id,prompt_id,rejected_at) VALUES(?,?,?,?,?)", arguments: [ownerID.uuidString,row["evidence_fingerprint"] as String,record.book.id.uuidString,row["prompt_id"] as String,stamp()])
        try db.execute(sql: "UPDATE challenge_assignments SET status='rejected' WHERE owner_id=? AND id=?", arguments: [ownerID.uuidString,id.uuidString])
        try refreshChallengeAttention(config, db)
        try enqueueChallenge(id, "challenge.reject", ["assignment":id.uuidString], db)
    } }
    public func assignChallenge(promptID: UUID, readingID: UUID, year: Int) throws { try queue.write { db in
        let config = try challengeConfig(year, db)
        guard let prompt = config.prompts.first(where: { $0.id == promptID }) else { throw ChallengeError.unavailablePrompt }
        let record = try challengeRecord(readingID, db)
        if try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM challenge_assignments WHERE owner_id=? AND prompt_id=? AND reading_id=? AND status='confirmed'", arguments: [ownerID.uuidString,promptID.uuidString,readingID.uuidString]) == 1 { return }
        try validateChallengeAssignment(prompt, record, config, db)
        try insertChallengeAssignment(prompt, record, source: "manual", db)
        try afterChallengeAssignment(config, record, db)
    } }
    public func replaceChallengeWeek(promptID: UUID, readingID: UUID, year: Int, confirmed: Bool) throws { try queue.write { db in
        guard confirmed else { throw DomainError.confirmationRequired }
        let config = try challengeConfig(year, db)
        guard let prompt = config.prompts.first(where: { $0.id == promptID }), prompt.challenge == .weeks else { throw ChallengeError.unavailablePrompt }
        let record = try challengeRecord(readingID, db)
        guard ChallengeRules.eligible(record, prompt: prompt, year: year) else { throw ChallengeError.ineligibleReading }
        let prior = try Row.fetchOne(db, sql: "SELECT id,reading_id FROM challenge_assignments WHERE owner_id=? AND prompt_id=? AND status='confirmed'", arguments: [ownerID.uuidString,promptID.uuidString])
        if let prior, prior["reading_id"] as String == readingID.uuidString { return }
        if let prior { try db.execute(sql: "UPDATE challenge_assignments SET status='rejected' WHERE owner_id=? AND id=?", arguments: [ownerID.uuidString,prior["id"] as String])
            try updateChallengeJournal(UUID(uuidString: prior["reading_id"])!, db)
        }
        try insertChallengeAssignment(prompt, record, source: "manual", db)
        try afterChallengeAssignment(config, record, db)
    } }
    public func removeChallengeAssignment(id: UUID, year: Int, confirmed: Bool) throws { try queue.write { db in
        guard confirmed else { throw DomainError.confirmationRequired }
        let config = try challengeConfig(year, db)
        guard let row = try Row.fetchOne(db, sql: "SELECT a.* FROM challenge_assignments a JOIN challenge_prompts p ON p.owner_id=a.owner_id AND p.id=a.prompt_id WHERE a.owner_id=? AND a.id=? AND p.year_id=? AND a.status='confirmed'", arguments: [ownerID.uuidString,id.uuidString,config.id.uuidString]) else { throw ChallengeError.staleProposal }
        try db.execute(sql: "UPDATE challenge_assignments SET status='rejected' WHERE owner_id=? AND id=?", arguments: [ownerID.uuidString,id.uuidString])
        try updateChallengeJournal(UUID(uuidString: row["reading_id"])!, db)
        try refreshChallengeAttention(config, db)
        try enqueueChallenge(id, "challenge.assignment.remove", ["assignment":id.uuidString], db)
    } }
    public func markChallengesCopied(readingID: UUID) throws { try queue.write { db in
        let payload = try challengeCopyPayload(readingID, db)
        guard !payload.isEmpty else { throw JournalError.notReady }
        try db.execute(sql: "UPDATE journal_components SET state='copied',copied_payload=?,copied_at=? WHERE owner_id=? AND reading_id=? AND component='challenges' AND state='ready'", arguments: [payload,stamp(),ownerID.uuidString,readingID.uuidString])
        guard db.changesCount == 1 else { throw JournalError.notReady }
        try enqueueChallenge(readingID, "challenge.journal.copied", ["payload":payload], db)
    } }
    // Called inside the existing live completion transaction; imports never invoke it.
    func createChallengeCompletionWork(reading: ReadingInstance, db: Database) throws {
        guard reading.status == .read, !reading.historical, let date = reading.finishDate else { return }
        _ = try ensureChallenges(date.year, db)
        if date.isoWeek.year != date.year { _ = try ensureChallenges(date.isoWeek.year, db) }
        try placeDeterministicChallenges(date.year, db)
        if date.isoWeek.year != date.year { try placeDeterministicChallenges(date.isoWeek.year, db) }
    }
    private func ensureChallenges(_ year: Int, _ db: Database) throws -> ChallengeConfiguration {
        if try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM challenge_years WHERE owner_id=? AND year=?", arguments: [ownerID.uuidString,year]) == 1 { return try challengeConfig(year, db) }
        let config = try ChallengeCatalog.configuration(year: year)
        try db.execute(sql: "INSERT INTO challenge_years(owner_id,id,year,version,content_json) VALUES(?,?,?,?,?)", arguments: [ownerID.uuidString,config.id.uuidString,year,config.version.rawValue,try challengeJSON(config)])
        for prompt in config.prompts { try db.execute(sql: "INSERT INTO challenge_prompts(owner_id,id,year_id,challenge_key,prompt_key,text,is_tbd) VALUES(?,?,?,?,?,?,?)", arguments: [ownerID.uuidString,prompt.id.uuidString,config.id.uuidString,prompt.challenge.rawValue,prompt.key,prompt.text,!prompt.available]) }
        try enqueueChallenge(config.id, "challenge.year.create", config, db)
        return config
    }
    private func challengeConfig(_ year: Int, _ db: Database) throws -> ChallengeConfiguration {
        guard let json = try String.fetchOne(db, sql: "SELECT content_json FROM challenge_years WHERE owner_id=? AND year=?", arguments: [ownerID.uuidString,year]) else { throw ChallengeError.unavailablePrompt }
        return try JSONDecoder().decode(ChallengeConfiguration.self, from: Data(json.utf8))
    }
    private func challengeReadings(_ db: Database) throws -> [ChallengeReading] {
        try String.fetchAll(db, sql: "SELECT id FROM readings WHERE owner_id=? AND deleted_at IS NULL ORDER BY finish_date,id", arguments: [ownerID.uuidString]).map { try challengeRecord(UUID(uuidString: $0)!, db) }
    }
    private func challengeRecord(_ id: UUID, _ db: Database) throws -> ChallengeReading {
        let value = try reading(id, db: db); let book = try catalog(value.bookID, db: db).book
        let ids = try String.fetchAll(db, sql: "SELECT DISTINCT series_id FROM series_entries WHERE owner_id=? AND book_id=?", arguments: [ownerID.uuidString,book.id.uuidString]).compactMap(UUID.init(uuidString:))
        return ChallengeReading(book: book, reading: value, seriesIDs: ids)
    }
    private func validateChallengeAssignment(_ prompt: ChallengePrompt, _ record: ChallengeReading, _ config: ChallengeConfiguration, _ db: Database) throws {
        guard prompt.available else { throw ChallengeError.unavailablePrompt }
        guard ChallengeRules.eligible(record, prompt: prompt, year: config.year) else { throw ChallengeError.ineligibleReading }
        guard try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM challenge_assignments WHERE owner_id=? AND prompt_id=? AND status='confirmed'", arguments: [ownerID.uuidString,prompt.id.uuidString]) == 0 else { throw ChallengeError.occupied }
        if prompt.challenge == .hundred {
            let used = try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM challenge_assignments a JOIN challenge_prompts p ON p.owner_id=a.owner_id AND p.id=a.prompt_id WHERE a.owner_id=? AND p.year_id=? AND p.challenge_key='hundred' AND a.reading_id=? AND a.status='confirmed'", arguments: [ownerID.uuidString,config.id.uuidString,record.id.uuidString]) ?? 0
            guard used == 0 else { throw ChallengeError.ineligibleReading }
        }
        if prompt.challenge == .alphabet {
            for seriesID in record.seriesIDs {
                let count = try Int.fetchOne(db, sql: "SELECT COUNT(DISTINCT r.book_id) FROM challenge_assignments a JOIN challenge_prompts p ON p.owner_id=a.owner_id AND p.id=a.prompt_id JOIN readings r ON r.owner_id=a.owner_id AND r.id=a.reading_id JOIN series_entries e ON e.owner_id=r.owner_id AND e.book_id=r.book_id WHERE a.owner_id=? AND p.year_id=? AND p.challenge_key='alphabet' AND a.status='confirmed' AND e.series_id=?", arguments: [ownerID.uuidString,config.id.uuidString,seriesID.uuidString]) ?? 0
                if count >= 2 { throw ChallengeError.seriesLimit }
            }
        }
    }
    private func insertChallengeAssignment(_ prompt: ChallengePrompt, _ record: ChallengeReading, source: String, _ db: Database) throws {
        let id = UUID()
        try db.execute(sql: "INSERT INTO challenge_assignments(owner_id,id,prompt_id,reading_id,status,source,created_at) VALUES(?,?,?,?,'confirmed',?,?)", arguments: [ownerID.uuidString,id.uuidString,prompt.id.uuidString,record.id.uuidString,source,stamp()])
        try enqueueChallenge(id, "challenge.assign", ["prompt":prompt.id.uuidString,"reading":record.id.uuidString,"source":source], db)
    }
    private func placeDeterministicChallenges(_ year: Int, _ db: Database) throws {
        let config = try challengeConfig(year, db); let records = try challengeReadings(db)
        for prompt in config.prompts where prompt.challenge == .weeks {
            let week = ISOWeek(year: year, week: Int(prompt.key)!)
            let prior = try Row.fetchOne(db, sql: "SELECT id,reading_id,source FROM challenge_assignments WHERE owner_id=? AND prompt_id=? AND status='confirmed'", arguments: [ownerID.uuidString,prompt.id.uuidString])
            if let prior, prior["source"] as String != "finish-date" { continue } // explicit manual choice wins
            let first = ChallengeRules.firstFinished(in: week, readings: records)
            if let prior, first?.id.uuidString == prior["reading_id"] as String { continue }
            if let prior {
                try db.execute(sql: "UPDATE challenge_assignments SET status='rejected' WHERE owner_id=? AND id=?", arguments: [ownerID.uuidString,prior["id"] as String])
                try updateChallengeJournal(UUID(uuidString: prior["reading_id"])!, db)
            }
            if let first { try insertChallengeAssignment(prompt, first, source: "finish-date", db); try updateChallengeJournal(first.id, db) }
            let tied = first == nil && records.contains { $0.reading.status == .read && !$0.reading.historical && $0.reading.finishDate?.isoWeek == week }
            try db.execute(sql: "INSERT INTO attention_items(owner_id,id,category,entity_id,reason,status,created_at) VALUES(?,?,'challenges',?,'finish-order',?,?) ON CONFLICT(owner_id,category,entity_id,reason) DO UPDATE SET status=excluded.status", arguments: [ownerID.uuidString,UUID().uuidString,prompt.id.uuidString,tied ? "open" : "resolved",stamp()])
        }
        // Completion slots, not semantic matches. Existing confirmed placements are stable.
        for record in records where record.reading.status == .read && !record.reading.historical && record.reading.finishDate?.year == year {
            let prior = try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM challenge_assignments a JOIN challenge_prompts p ON p.owner_id=a.owner_id AND p.id=a.prompt_id WHERE a.owner_id=? AND p.year_id=? AND p.challenge_key='hundred' AND a.reading_id=? AND a.status='confirmed'", arguments: [ownerID.uuidString,config.id.uuidString,record.id.uuidString]) ?? 0
            guard prior == 0 else { continue }
            for prompt in config.prompts where prompt.challenge == .hundred {
                let occupied = try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM challenge_assignments WHERE owner_id=? AND prompt_id=? AND status='confirmed'", arguments: [ownerID.uuidString,prompt.id.uuidString]) ?? 0
                if occupied == 0 { try insertChallengeAssignment(prompt, record, source: "completion", db); try updateChallengeJournal(record.id, db); break }
            }
        }
        try refreshChallengeAttention(config, db)
    }
    private func afterChallengeAssignment(_ config: ChallengeConfiguration, _ record: ChallengeReading, _ db: Database) throws {
        try updateChallengeJournal(record.id, db)
        try refreshChallengeAttention(config, db)
    }
    private func refreshChallengeAttention(_ config: ChallengeConfiguration, _ db: Database) throws {
        let candidates = try Row.fetchAll(db, sql: "SELECT a.*,r.book_id FROM challenge_assignments a JOIN challenge_prompts p ON p.owner_id=a.owner_id AND p.id=a.prompt_id JOIN readings r ON r.owner_id=a.owner_id AND r.id=a.reading_id WHERE a.owner_id=? AND p.year_id=?", arguments: [ownerID.uuidString,config.id.uuidString])
        let records = try challengeReadings(db)
        let occupied = Set(candidates.filter { $0["status"] as String == "confirmed" }.map { $0["prompt_id"] as String })
        for row in candidates {
            let promptID: String = row["prompt_id"], readingID: String = row["reading_id"]
            let prompt = config.prompts.first { $0.id.uuidString == promptID }!
            let record = records.first { $0.id.uuidString == readingID }
            let eligible = record.map { ChallengeRules.eligible($0, prompt: prompt, year: config.year) } ?? false
            let status: String = row["status"]
            let needsReview = status == "proposed" && !occupied.contains(promptID) && eligible
            let changedEligibility = status == "confirmed" && !eligible
            for (reason, open) in [("match-review",needsReview),("eligibility-changed",changedEligibility)] {
                try db.execute(sql: "INSERT INTO attention_items(owner_id,id,category,entity_id,reason,status,created_at) VALUES(?,?,'challenges',?,?,?,?) ON CONFLICT(owner_id,category,entity_id,reason) DO UPDATE SET status=excluded.status", arguments: [ownerID.uuidString,UUID().uuidString,row["id"] as String,reason,open ? "open" : "resolved",stamp()])
            }
        }
    }
    private func challengeCopyPayload(_ readingID: UUID, _ db: Database) throws -> String {
        let lines = try Row.fetchAll(db, sql: "SELECT p.challenge_key,p.text,y.year FROM challenge_assignments a JOIN challenge_prompts p ON p.owner_id=a.owner_id AND p.id=a.prompt_id JOIN challenge_years y ON y.owner_id=p.owner_id AND y.id=p.year_id WHERE a.owner_id=? AND a.reading_id=? AND a.status='confirmed' ORDER BY y.year,p.challenge_key,p.prompt_key", arguments: [ownerID.uuidString,readingID.uuidString]).map { row -> String in
            "\(row["year"] as Int) · \(ChallengeKind(rawValue: row["challenge_key"])!.name) · \(row["text"] as String)"
        }
        return lines.joined(separator: "\n")
    }
    private func updateChallengeJournal(_ readingID: UUID, _ db: Database) throws {
        let payload = try challengeCopyPayload(readingID, db)
        if let row = try Row.fetchOne(db, sql: "SELECT state,copied_payload FROM journal_components WHERE owner_id=? AND reading_id=? AND component='challenges'", arguments: [ownerID.uuidString,readingID.uuidString]) {
            if row["state"] as String == "copied", let copied: String = row["copied_payload"], copied != payload {
                let existing = try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM journal_corrections WHERE owner_id=? AND reading_id=? AND component='challenges' AND field='Assignments' AND current_value=? AND status='pending'", arguments: [ownerID.uuidString,readingID.uuidString,payload]) ?? 0
                if existing == 0 { try db.execute(sql: "INSERT INTO journal_corrections(owner_id,id,reading_id,component,field,previous_value,current_value,status,created_at) VALUES(?,?,?,'challenges','Assignments',?,?,'pending',?)", arguments: [ownerID.uuidString,UUID().uuidString,readingID.uuidString,copied,payload,stamp()]) }
            } else {
                try db.execute(sql: "UPDATE journal_components SET state=? WHERE owner_id=? AND reading_id=? AND component='challenges' AND state<>'copied'", arguments: [payload.isEmpty ? "pending" : "ready",ownerID.uuidString,readingID.uuidString])
            }
        }
    }
    private func challengeJSON<T: Encodable>(_ value: T) throws -> String { String(data: try JSONEncoder().encode(value), encoding: .utf8)! }
    private func enqueueChallenge<T: Encodable>(_ id: UUID, _ kind: String, _ value: T, _ db: Database) throws {
        var generation = try String.fetchOne(db, sql: "SELECT generation FROM sync_state WHERE owner_id=?", arguments: [ownerID.uuidString])
        if generation == nil { generation = UUID().uuidString; try db.execute(sql: "INSERT INTO sync_state(owner_id,generation) VALUES(?,?)", arguments: [ownerID.uuidString,generation]) }
        try enqueue(.init(ownerID: ownerID, entityID: id, expectedRevision: 0, generation: UUID(uuidString: generation!)!, kind: kind, payload: try JSONEncoder().encode(value)), db: db)
    }
}
