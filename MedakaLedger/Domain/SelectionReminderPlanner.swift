import Foundation

// 選別の目安日の通知の計画（DECISIONS.md K）。孵化日から数えた日数（1回目、2回目、3回目）の朝8時に、
// その日が目安日の群をまとめて1件で知らせる。目安日は利用者が設定で変えられる値で、判定ではない。
// 記録済みの回は知らせない。過ぎた目安日は、あとから知らせない。

struct SelectionReminderInput: Equatable, Sendable {
    var cohortID: UUID
    /// 通知に出す名前。例「楊貴妃 F1」。
    var name: String
    var hatchedAt: Date
    /// 選別を記録済みの回（1、2、3）。
    var doneRounds: Set<Int>
}

enum SelectionReminderPlanner {
    /// iOSの予約は64件まで。孵化予定50件と産卵期の1件のほかに、10件を使う（NotificationPlanner）。
    static let maxNotifications = 10
    /// 既定の目安日。孵化日から数えた日数。数値は目安で、設定で変えられる。
    static let defaultDays = [21, 49, 84]
    static let dayRange = 1...365

    /// 3つとも範囲内でなければ、既定に戻す。
    static func normalizedDays(_ days: [Int]) -> [Int] {
        guard days.count == defaultDays.count, days.allSatisfy({ dayRange.contains($0) }) else { return defaultDays }
        return days
    }

    static func notifications(_ inputs: [SelectionReminderInput], days: [Int], now: Date, calendar: Calendar) -> [PlannedNotification] {
        struct Due {
            var cohortID: UUID
            var name: String
            var hatchedAt: Date
            var days: Int
        }
        let days = normalizedDays(days)
        var dueByFireDate: [Date: [Due]] = [:]
        for input in inputs {
            let hatchDay = calendar.startOfDay(for: input.hatchedAt)
            for (index, offset) in days.enumerated() where !input.doneRounds.contains(index + 1) {
                guard let day = calendar.date(byAdding: .day, value: offset, to: hatchDay),
                      let fireDate = calendar.date(bySettingHour: NotificationPlanner.fireHour, minute: 0, second: 0, of: day),
                      fireDate > now
                else { continue }
                dueByFireDate[fireDate, default: []].append(Due(cohortID: input.cohortID, name: input.name, hatchedAt: input.hatchedAt, days: offset))
            }
        }
        return dueByFireDate.keys.sorted().prefix(maxNotifications).compactMap { fireDate in
            guard let dues = dueByFireDate[fireDate]?.sorted(by: { ($0.hatchedAt, $0.name) < ($1.hatchedAt, $1.name) }),
                  let first = dues.first
            else { return nil }
            let components = calendar.dateComponents([.year, .month, .day], from: fireDate)
            let identifier = "selection-\(components.year ?? 0)-\(components.month ?? 0)-\(components.day ?? 0)"
            let cohortCount = Set(dues.map(\.cohortID)).count
            return PlannedNotification(
                identifier: identifier,
                kind: .selectionDue(firstName: first.name, cohortCount: cohortCount, days: first.days),
                fireDate: fireDate
            )
        }
    }
}
