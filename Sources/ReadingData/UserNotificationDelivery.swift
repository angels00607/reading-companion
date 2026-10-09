import Foundation
import ReadingDomain
#if canImport(UserNotifications)
import UserNotifications

public final class UserNotificationDelivery:@unchecked Sendable,NotificationDeliveryService {
    private let center:UNUserNotificationCenter
    public init(center:UNUserNotificationCenter = .current()){self.center=center}
    public func authorizationStatus() async -> NotificationAuthorizationState {
        let settings=await center.notificationSettings()
        return switch settings.authorizationStatus { case .authorized,.ephemeral:.authorized;case .denied:.denied;case .notDetermined:.notDetermined;case .provisional:.provisional;@unknown default:.unavailable }
    }
    public func requestAuthorization() async -> NotificationAuthorizationState {
        guard await authorizationStatus() == .notDetermined else { return await authorizationStatus() }
        do { _ = try await center.requestAuthorization(options:[.alert,.sound,.badge]);return await authorizationStatus() }
        catch { return .unavailable }
    }
    public func replacePending(category:NotificationCategory,events:[VerifiedNotificationEvent]) async throws {
        let prefix="readingcompanion.\(category.rawValue)."
        let pending=await center.pendingNotificationRequests().filter{$0.identifier.hasPrefix(prefix)}
        let desired=Set(events.map(\.id));let stale=pending.map(\.identifier).filter{!desired.contains($0)}
        if !stale.isEmpty { center.removePendingNotificationRequests(withIdentifiers:stale) }
        // UserNotifications replaces a pending request with the same identifier,
        // so a verified date change reschedules without creating a duplicate.
        for event in events {
            let content=UNMutableNotificationContent();content.title=event.title;content.body=event.body;content.sound = .default
            switch event.destination { case .series(let id):content.userInfo=["destination":"series","entity_id":id.uuidString];case .needsAttention:content.userInfo=["destination":"attention"] }
            var components=DateComponents();components.calendar=Calendar(identifier:.gregorian);components.year=event.date.year;components.month=event.date.month;components.day=event.date.day;components.hour=9
            try await center.add(UNNotificationRequest(identifier:event.id,content:content,trigger:UNCalendarNotificationTrigger(dateMatching:components,repeats:false)))
        }
    }
}
#else
public struct UserNotificationDelivery:NotificationDeliveryService {
    public init(){}
    public func authorizationStatus() async -> NotificationAuthorizationState{.unavailable}
    public func requestAuthorization() async -> NotificationAuthorizationState{.unavailable}
    public func replacePending(category:NotificationCategory,events:[VerifiedNotificationEvent]) async throws{}
}
#endif
