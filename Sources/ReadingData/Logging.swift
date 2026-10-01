import OSLog

/// Only predetermined event names and opaque operation IDs. Never pass user text or tokens.
public enum FoundationLog {
    private static let logger = Logger(subsystem: "ReadingCompanion", category: "Foundation")
    public enum Event: String { case migrationCompleted, syncStarted, syncFailed, mutationNeedsReview }
    public static func record(_ event: Event) { logger.info("Foundation event: \(event.rawValue, privacy: .public)") }
}
