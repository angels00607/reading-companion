import SwiftUI
import ReadingDomain
#if canImport(UIKit)
import UIKit
#endif

public struct NotificationSettingsScreen:View {
    @EnvironmentObject private var model:BooksModel
    @Environment(\.colorScheme) private var scheme
    @Environment(\.openURL) private var openURL
    @State private var preferences=NotificationPreferences()
    @State private var authorization:NotificationAuthorizationState = .unavailable
    @State private var loading=true
    @State private var error:String?
    public init(){}
    public var body:some View { BooksScreen("Notifications") {
        Text("Choose which Reading Companion updates may be delivered. These choices are separate from iOS permission.").foregroundStyle(DesignTokens.secondaryText(scheme)).fixedSize(horizontal:false,vertical:true)
        authorizationSection
        Text("CATEGORIES").font(DesignTokens.functionalFont(size:12,relativeTo:.caption,weight:.semiBold)).foregroundStyle(DesignTokens.secondaryText(scheme))
        preferenceToggle(.seriesReleases,preferences.seriesReleases)
        preferenceToggle(.releaseDateChanges,preferences.releaseDateChanges)
        preferenceToggle(.importAndSystem,preferences.importAndSystem)
        preferenceToggle(.challenges,preferences.challenges)
        preferenceToggle(.journal,preferences.journal)
        preferenceToggle(.quests,preferences.quests)
        preferenceToggle(.achievementsAndLevels,preferences.achievementsAndLevels ?? false)
        if preferences.achievementsAndLevels == nil { Text("No default is defined for Achievements & Levels. Changing this switch records your explicit choice.").font(DesignTokens.functionalFont(size:13)).foregroundStyle(DesignTokens.secondaryText(scheme)).fixedSize(horizontal:false,vertical:true) }
        Text("Turning notifications off never removes or resolves Needs Attention items.").font(DesignTokens.functionalFont(size:14)).foregroundStyle(DesignTokens.secondaryText(scheme)).fixedSize(horizontal:false,vertical:true)
        if loading { SkeletonRow() }
        if let error { StatePresentation(kind:.error,title:"Notification settings unavailable",message:error) }
    }.task { await load() }.accessibilityIdentifier("notifications.settings") }
    @ViewBuilder private var authorizationSection:some View {
        VStack(alignment:.leading,spacing:10) {
            Text("IOS PERMISSION").font(DesignTokens.functionalFont(size:12,relativeTo:.caption,weight:.semiBold)).foregroundStyle(DesignTokens.secondaryText(scheme))
            StatusChip(statusLabel,symbol:statusSymbol,tone:authorization == .denied ? .neutral:.active)
            switch authorization {
            case .notDetermined: AppButton("Allow Notifications") { Task { await requestPermission() } }.accessibilityIdentifier("notifications.request")
            case .denied:
                Text("Permission was denied. Reading Companion will not ask again; you can change this in iOS Settings.").foregroundStyle(DesignTokens.secondaryText(scheme)).fixedSize(horizontal:false,vertical:true)
                #if canImport(UIKit)
                AppButton("Open iOS Settings",kind:.secondary) { if let url=URL(string:UIApplication.openNotificationSettingsURLString){openURL(url)} }.accessibilityIdentifier("notifications.openSettings")
                #endif
            case .provisional: Text("iOS may deliver notifications quietly until you choose how they appear.").foregroundStyle(DesignTokens.secondaryText(scheme))
            case .unavailable: Text("Notification delivery is unavailable on this device. Your category preferences remain saved.").foregroundStyle(DesignTokens.secondaryText(scheme))
            case .authorized: EmptyView()
            }
        }.padding(16).background(DesignTokens.surface(scheme),in:RoundedRectangle(cornerRadius:DesignTokens.cardRadius))
    }
    private func preferenceToggle(_ category:NotificationCategory,_ enabled:Bool)->some View {
        Toggle(category.label,isOn:Binding(get:{enabled},set:{save(category,$0)})).frame(minHeight:44).accessibilityIdentifier("notifications."+category.rawValue)
    }
    private var statusLabel:String { switch authorization {case .authorized:"Allowed";case .denied:"Denied";case .notDetermined:"Not requested";case .provisional:"Delivered quietly";case .unavailable:"Unavailable"} }
    private var statusSymbol:String { switch authorization {case .authorized:"checkmark.circle";case .denied:"nosign";case .notDetermined:"bell";case .provisional:"bell.badge";case .unavailable:"bell.slash"} }
    @MainActor private func load() async {
        do { preferences=try model.notificationPreferencesRepository?.notificationPreferences() ?? .init();authorization=await model.notificationCoordinator?.authorizationStatus() ?? .unavailable;error=nil }
        catch { self.error="Existing preferences were not changed." }
        loading=false
    }
    private func save(_ category:NotificationCategory,_ enabled:Bool) {
        guard model.perform({try model.notificationPreferencesRepository?.setNotificationPreference(category,enabled:enabled)}) != nil else{return}
        Task { await model.notificationCoordinator?.reconcile();await load() }
    }
    @MainActor private func requestPermission() async { authorization=await model.notificationCoordinator?.requestAuthorization() ?? .unavailable }
}
