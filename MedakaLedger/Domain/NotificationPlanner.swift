import Foundation

// ローカル通知の予約計画（SCREENS.md 14、DECISIONS.md F、G 3-9、K）。
// 文言はここでは作らず、種類と値だけを返す（文言は Notifications/NotificationScheduler.swift）。

struct HatchNotificationInput: Equatable, Sendable {
    var batchID: UUID
    var name: String
    var predictedDate: Date
}

struct PlannedNotification: Equatable, Sendable {
    enum Kind: Equatable, Sendable {
        case hatch(name: String)
        case seasonStart
        /// 選別の目安日。その日の先頭の群の名前、群の数、孵化からの日数。
        case selectionDue(firstName: String, cohortCount: Int, days: Int)
    }

    var identifier: String
    var kind: Kind
    var fireDate: Date
}

enum NotificationPlanner {
    /// iOSが予約しておける通知は64件まで。孵化予定は予定日の近い順に最大50件にする（DECISIONS.md G 3-9）。
    static let maxHatchNotifications = 50
    static let fireHour = 8

    static func hatchNotifications(_ inputs: [HatchNotificationInput], now: Date, calendar: Calendar) -> [PlannedNotification] {
        inputs
            .compactMap { input -> PlannedNotification? in
                guard let fireDate = morning(of: input.predictedDate, calendar: calendar), fireDate > now else { return nil }
                return PlannedNotification(identifier: "hatch-\(input.batchID.uuidString)", kind: .hatch(name: input.name), fireDate: fireDate)
            }
            .sorted { $0.fireDate < $1.fireDate }
            .prefix(maxHatchNotifications)
            .map { $0 }
    }

    /// 産卵期の最初の月の前月15日の朝8時（DECISIONS.md F）。次に来る日を返す。
    /// 産卵期が通年、または月が空なら nil。産卵期が年をまたぐ設定でも、始まりの月ごとに数える。
    static func seasonStartNotification(now: Date, months: [Int], calendar: Calendar) -> PlannedNotification? {
        let set = Set(months.filter { (1...12).contains($0) })
        guard !set.isEmpty, set.count < 12 else { return nil }
        let startMonths = set.filter { !set.contains($0 == 1 ? 12 : $0 - 1) }
        let year = calendar.component(.year, from: now)
        var candidates: [Date] = []
        for startMonth in startMonths {
            for yearOffset in 0...2 {
                let notifyMonth = startMonth == 1 ? 12 : startMonth - 1
                let notifyYear = year + yearOffset - (startMonth == 1 ? 1 : 0)
                let components = DateComponents(year: notifyYear, month: notifyMonth, day: 15, hour: fireHour)
                if let date = calendar.date(from: components), date > now {
                    candidates.append(date)
                }
            }
        }
        guard let fireDate = candidates.min() else { return nil }
        return PlannedNotification(identifier: "season-start", kind: .seasonStart, fireDate: fireDate)
    }

    private static func morning(of date: Date, calendar: Calendar) -> Date? {
        calendar.date(bySettingHour: fireHour, minute: 0, second: 0, of: calendar.startOfDay(for: date))
    }
}
