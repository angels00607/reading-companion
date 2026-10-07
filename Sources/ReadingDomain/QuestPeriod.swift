import Foundation

/// Calendar boundaries, independent of database row order. ISO weeks use week-year.
public struct QuestPeriod: Equatable, Sendable {
    public let cadence: QuestCadence
    public let key: String
    public let start: Date
    public let end: Date
    public let availableDays: Int
    public init(cadence: QuestCadence, now: Date, timeZone: TimeZone = .current) {
        var cal = Calendar(identifier: cadence == .weekly ? .iso8601 : .gregorian)
        cal.timeZone = timeZone
        let component: Calendar.Component = cadence == .daily ? .day : cadence == .weekly ? .weekOfYear : .month
        let interval = cal.dateInterval(of: component, for: now)!
        self.cadence = cadence; start = interval.start; end = interval.end
        let c = cal.dateComponents([.year,.month,.day,.yearForWeekOfYear,.weekOfYear], from: now)
        switch cadence {
        case .daily: key = String(format:"%04d-%02d-%02d",c.year!,c.month!,c.day!)
        case .weekly: key = String(format:"%04d-W%02d",c.yearForWeekOfYear!,c.weekOfYear!)
        case .monthly: key = String(format:"%04d-%02d",c.year!,c.month!)
        }
        availableDays = max(1,cal.dateComponents([.day],from:cal.startOfDay(for:now),to:interval.end).day ?? 1)
    }
    public static func start(cadence: QuestCadence, key: String, timeZone: TimeZone = .current) -> Date? {
        var cal = Calendar(identifier: cadence == .weekly ? .iso8601 : .gregorian); cal.timeZone = timeZone
        if cadence == .weekly {
            let parts = key.components(separatedBy:"-W")
            guard parts.count == 2, let year = Int(parts[0]), let week = Int(parts[1]), (1...53).contains(week) else { return nil }
            guard let date = cal.date(from:DateComponents(yearForWeekOfYear:year,weekOfYear:week,weekday:2)), QuestPeriod(cadence:cadence,now:date,timeZone:timeZone).key == key else { return nil }; return date
        }
        let parts = key.split(separator:"-").compactMap { Int($0) }
        guard parts.count == (cadence == .daily ? 3 : 2), let date = cal.date(from:DateComponents(year:parts[0],month:parts[1],day:cadence == .daily ? parts[2] : 1)), QuestPeriod(cadence:cadence,now:date,timeZone:timeZone).key == key else { return nil }; return date
    }
    public static func cooldownAllows(_ template: QuestTemplate, cadence: QuestCadence, periodKey: String, history: [QuestInstance], timeZone: TimeZone = .current) -> Bool {
        guard let current = start(cadence:cadence,key:periodKey,timeZone:timeZone) else { return history.isEmpty }
        var cal = Calendar(identifier: cadence == .weekly ? .iso8601 : .gregorian); cal.timeZone = timeZone
        let component: Calendar.Component = cadence == .daily ? .day : cadence == .weekly ? .weekOfYear : .month
        for q in history where q.cadence == cadence && q.templateKey == template.key {
            guard let previous = start(cadence:cadence,key:q.periodKey,timeZone:timeZone) else { continue }
            // N intervening quiet periods must finish. Rerolled instances count as use.
            if (cal.dateComponents([component],from:previous,to:current).value(for:component) ?? 0) <= template.cooldownPeriods { return false }
        }
        return true
    }
}
