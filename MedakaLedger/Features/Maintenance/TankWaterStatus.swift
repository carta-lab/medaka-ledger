import Foundation

// 容器の最終水換えからの日数と警告（PRD.md F7）。容器一覧と容器詳細で使う。

struct TankWaterStatus {
    let days: Int?
    let isOverdue: Bool

    @MainActor
    init(tank: Tank, settings: AppSettings, now: Date = .now, calendar: Calendar = .current) {
        let days = MaintenanceRules.daysSinceLastWaterChange(lastWaterChange: tank.lastWaterChange, today: now, calendar: calendar)
        let warningDays = Season.waterChangeWarningDays(
            on: now,
            months: settings.breedingSeasonMonths,
            inSeason: settings.waterChangeWarningDays,
            offSeason: settings.winterWaterChangeWarningDays,
            calendar: calendar
        )
        self.days = days
        // 飼育中の群がいない容器は、水換えが遅れていても警告しない
        self.isOverdue = !tank.activeCohorts.isEmpty && MaintenanceRules.isOverdue(daysSince: days, warningDays: warningDays)
    }

    var text: String {
        guard let days else { return String(localized: "水換えの記録なし") }
        if days == 0 { return String(localized: "水換え 今日") }
        return String(localized: "水換え \(days.formatted())日前")
    }
}
