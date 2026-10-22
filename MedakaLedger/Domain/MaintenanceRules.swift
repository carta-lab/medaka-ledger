import Foundation

// 最終水換えからの日数と警告（PRD.md F7、DECISIONS.md H）。

enum MaintenanceRules {
    /// 最終水換えからの日数。記録が無ければ nil。
    static func daysSinceLastWaterChange(lastWaterChange: Date?, today: Date, calendar: Calendar) -> Int? {
        lastWaterChange.map { DayCount.days(from: $0, to: today, calendar: calendar) }
    }

    /// 警告日数を超えたか。記録が無い容器は警告しない（記録のない新しい容器を並べて警告しないため）。
    static func isOverdue(daysSince: Int?, warningDays: Int) -> Bool {
        guard let daysSince else { return false }
        return daysSince > warningDays
    }
}
