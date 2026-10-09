import Foundation
import GRDB
import ReadingDomain

extension LocalStore: AttentionRepository {
    @discardableResult public func createAttention(_ draft: AttentionDraft) throws -> AttentionItem {
        try queue.write { db in try upsertAttention(draft, db: db) }
    }
    public func unresolvedAttention(filter: AttentionFilter = .all) throws -> [AttentionItem] {
        try queue.read { db in
            var sql="SELECT * FROM attention_items WHERE owner_id=? AND status='open'"
            var args:[DatabaseValue]=[ownerID.uuidString.databaseValue]
            if let category=filter.category { sql += " AND category=?"; args.append(category.rawValue.databaseValue) }
            sql += " ORDER BY CASE priority WHEN 'required' THEN 0 WHEN 'review' THEN 1 ELSE 2 END,created_at,id"
            return try Row.fetchAll(db,sql:sql,arguments:StatementArguments(args)).map(attentionItem)
        }
    }
    public func unresolvedAttentionCount() throws -> Int { try queue.read { try Int.fetchOne($0,sql:"SELECT COUNT(*) FROM attention_items WHERE owner_id=? AND status='open'",arguments:[ownerID.uuidString]) ?? 0 } }
    public func resolveAttention(id: UUID) throws { try queue.write { try resolveAttention(id:id,db:$0) } }
    public func restartAttention(id: UUID) throws { try queue.write { db in
        guard try Int.fetchOne(db,sql:"SELECT COUNT(*) FROM attention_items WHERE owner_id=? AND id=?",arguments:[ownerID.uuidString,id.uuidString]) == 1 else { throw DomainError.invalidTransition }
        try db.execute(sql:"UPDATE attention_items SET status='open',resolved_at=NULL WHERE owner_id=? AND id=?",arguments:[ownerID.uuidString,id.uuidString])
    } }

    @discardableResult func upsertAttention(_ draft: AttentionDraft, db: Database) throws -> AttentionItem {
        guard !draft.reason.isEmpty, !draft.title.isEmpty else { throw DomainError.invalidTransition }
        let id=UUID(), now=stamp()
        try db.execute(sql:"""
            INSERT INTO attention_items(owner_id,id,category,entity_id,reason,status,created_at,priority,title,detail,source,action_id,resolved_at)
            VALUES(?,?,?,?,?,'open',?,?,?,?,?,?,NULL)
            ON CONFLICT(owner_id,category,entity_id,reason) DO UPDATE SET
              priority=CASE WHEN attention_items.status='open' THEN excluded.priority ELSE attention_items.priority END,
              title=CASE WHEN attention_items.status='open' THEN excluded.title ELSE attention_items.title END,
              detail=CASE WHEN attention_items.status='open' THEN excluded.detail ELSE attention_items.detail END,
              source=CASE WHEN attention_items.status='open' THEN excluded.source ELSE attention_items.source END,
              action_id=CASE WHEN attention_items.status='open' THEN excluded.action_id ELSE attention_items.action_id END
            """,arguments:[ownerID.uuidString,id.uuidString,draft.category.rawValue,draft.entityID.uuidString,draft.reason,now,draft.priority.rawValue,draft.title,draft.detail,draft.source,draft.actionID?.uuidString])
        let row=try Row.fetchOne(db,sql:"SELECT * FROM attention_items WHERE owner_id=? AND category=? AND entity_id=? AND reason=?",arguments:[ownerID.uuidString,draft.category.rawValue,draft.entityID.uuidString,draft.reason])!
        return attentionItem(row)
    }
    func resolveAttention(id:UUID,db:Database) throws { try db.execute(sql:"UPDATE attention_items SET status='resolved',resolved_at=? WHERE owner_id=? AND id=? AND status='open'",arguments:[stamp(),ownerID.uuidString,id.uuidString]) }
    func resolveAttention(category:AttentionCategory, actionID:UUID, db:Database) throws { try db.execute(sql:"UPDATE attention_items SET status='resolved',resolved_at=? WHERE owner_id=? AND category=? AND (action_id=? OR entity_id=?) AND status='open'",arguments:[stamp(),ownerID.uuidString,category.rawValue,actionID.uuidString,actionID.uuidString]) }
    private func attentionItem(_ row:Row) -> AttentionItem {
        let action:String?=row["action_id"], resolved:String?=row["resolved_at"]
        return AttentionItem(id:UUID(uuidString:row["id"])!,category:AttentionCategory(rawValue:row["category"])!,priority:AttentionPriority(rawValue:row["priority"])!,entityID:UUID(uuidString:row["entity_id"])!,actionID:action.flatMap(UUID.init(uuidString:)),reason:row["reason"],title:row["title"],detail:row["detail"],source:row["source"],status:AttentionStatus(rawValue:row["status"])!,createdAt:ISO8601DateFormatter().date(from:row["created_at"]) ?? .distantPast,resolvedAt:resolved.flatMap{ISO8601DateFormatter().date(from:$0)})
    }
}
