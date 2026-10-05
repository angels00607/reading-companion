/// Each non-nil fact must have reliable evidence; nil means unknown, not false.
public struct SeriesStatusEvidence: Codable, Equatable, Sendable {
    public var hasUnreadIncludedPublished: Bool?
    public var allIncludedPublishedRead: Bool?
    public var allIncludedConfirmedRead: Bool?
    public var hasAnnouncedOrExpectedFutureEntry: Bool?
    public var knownOngoing: Bool?
    public var confirmedComplete: Bool?
    public init(hasUnreadIncludedPublished: Bool? = nil, allIncludedPublishedRead: Bool? = nil,
                allIncludedConfirmedRead: Bool? = nil, hasAnnouncedOrExpectedFutureEntry: Bool? = nil,
                knownOngoing: Bool? = nil, confirmedComplete: Bool? = nil) {
        self.hasUnreadIncludedPublished = hasUnreadIncludedPublished
        self.allIncludedPublishedRead = allIncludedPublishedRead
        self.allIncludedConfirmedRead = allIncludedConfirmedRead
        self.hasAnnouncedOrExpectedFutureEntry = hasAnnouncedOrExpectedFutureEntry
        self.knownOngoing = knownOngoing; self.confirmedComplete = confirmedComplete
    }
}
