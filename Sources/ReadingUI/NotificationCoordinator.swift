import Foundation
import ReadingDomain

public actor NotificationCoordinator {
    private let repository:any NotificationPreferencesRepository
    private let delivery:any NotificationDeliveryService
    private let today:@Sendable () -> ReadingDate
    public init(repository:any NotificationPreferencesRepository,delivery:any NotificationDeliveryService,today:@escaping @Sendable () -> ReadingDate={
        let parts=Calendar(identifier:.gregorian).dateComponents([.year,.month,.day],from:Date())
        return try! ReadingDate(year:parts.year!,month:parts.month!,day:parts.day!)
    }){self.repository=repository;self.delivery=delivery;self.today=today}
    public func authorizationStatus() async -> NotificationAuthorizationState { await delivery.authorizationStatus() }
    public func requestAuthorization() async -> NotificationAuthorizationState {
        let status=await delivery.requestAuthorization();await reconcile();return status
    }
    public func reconcile() async {
        let preferences:NotificationPreferences
        do { preferences=try repository.notificationPreferences() } catch { return }
        let status=await delivery.authorizationStatus()
        let allowed=status == .authorized || status == .provisional
        let events=(try? repository.verifiedNotificationEvents(after:today())) ?? []
        for category in NotificationCategory.allCases {
            let desired=allowed && preferences.enabled(category) ? events.filter{$0.category == category} : []
            try? await delivery.replacePending(category:category,events:desired)
        }
    }
}
