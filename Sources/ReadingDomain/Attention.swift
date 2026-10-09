import Foundation

public enum AttentionCategory: String, CaseIterable, Codable, Sendable {
    case journal, series, challenges, books, `import`
    public var label: String { self == .import ? "Import" : rawValue.capitalized }
}

public enum AttentionPriority: String, CaseIterable, Codable, Sendable { case required, review, optional }
public enum AttentionStatus: String, Codable, Sendable { case open, resolved }

public enum AttentionFilter: String, CaseIterable, Sendable {
    case all = "All", journal = "Journal", series = "Series", challenges = "Challenges", books = "Books"
    public var category: AttentionCategory? { self == .all ? nil : AttentionCategory(rawValue: rawValue.lowercased()) }
}

public struct AttentionItem: Identifiable, Equatable, Sendable {
    public let id: UUID
    public let category: AttentionCategory
    public let priority: AttentionPriority
    public let entityID: UUID
    public let actionID: UUID?
    public let reason: String
    public let title: String
    public let detail: String
    public let source: String?
    public let status: AttentionStatus
    public let createdAt: Date
    public let resolvedAt: Date?
    public init(id: UUID, category: AttentionCategory, priority: AttentionPriority, entityID: UUID, actionID: UUID?, reason: String, title: String, detail: String, source: String?, status: AttentionStatus, createdAt: Date, resolvedAt: Date?) {
        self.id=id;self.category=category;self.priority=priority;self.entityID=entityID;self.actionID=actionID;self.reason=reason;self.title=title;self.detail=detail;self.source=source;self.status=status;self.createdAt=createdAt;self.resolvedAt=resolvedAt
    }
}

public struct AttentionDraft: Sendable {
    public let category: AttentionCategory; public let priority: AttentionPriority
    public let entityID: UUID; public let actionID: UUID?; public let reason: String
    public let title: String; public let detail: String; public let source: String?
    public init(category: AttentionCategory, priority: AttentionPriority = .review, entityID: UUID, actionID: UUID? = nil, reason: String, title: String, detail: String, source: String? = nil) {
        self.category=category;self.priority=priority;self.entityID=entityID;self.actionID=actionID;self.reason=reason;self.title=title;self.detail=detail;self.source=source
    }
}

public protocol AttentionRepository: Sendable {
    @discardableResult func createAttention(_ draft: AttentionDraft) throws -> AttentionItem
    func unresolvedAttention(filter: AttentionFilter) throws -> [AttentionItem]
    func unresolvedAttentionCount() throws -> Int
    func resolveAttention(id: UUID) throws
    func restartAttention(id: UUID) throws
}
