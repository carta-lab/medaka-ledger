import Foundation

// 季節の判定（ARCHITECTURE.md 4.5）。今日の月が産卵期の月に含まれれば産卵期。

enum Season {
    static func isBreedingSeason(on date: Date, months: [Int], calendar: Calendar) -> Bool {
        months.contains(calendar.component(.month, from: date))
    }

    static func waterChangeWarningDays(on date: Date, months: [Int], inSeason: Int, offSeason: Int, calendar: Calendar) -> Int {
        isBreedingSeason(on: date, months: months, calendar: calendar) ? inSeason : offSeason
    }
}

enum DayCount {
    /// start から end までの日数。日付の境目でそろえる（孵化日を0日目とする。DECISIONS.md C）。
    static func days(from start: Date, to end: Date, calendar: Calendar) -> Int {
        let from = calendar.startOfDay(for: start)
        let to = calendar.startOfDay(for: end)
        return calendar.dateComponents([.day], from: from, to: to).day ?? 0
    }
}
