import Foundation
import Observation

struct RecentRecord: Identifiable {
    let id: String
    let date: Date
    let symbolName: String
    let title: String
    let subtitle: String
    let route: Route?
}

struct OverdueTank: Identifiable {
    let tank: Tank
    let days: Int
    var id: UUID { tank.id }
}

@MainActor
@Observable
final class HomeModel {
    enum Sheet: String, Identifiable {
        case eggBatch, waterChange, temperature, photo, settings
        var id: String { rawValue }
    }

    var activeSheet: Sheet?
    var hatchingBatch: EggBatch?
    var isShowingDebugMenu = false

    /// 越冬中の群：屋外の容器にいる飼育中の群（DECISIONS.md E）。
    func winteringCohorts(from activeCohorts: [Cohort]) -> [Cohort] {
        activeCohorts.filter { cohort in
            guard let tank = cohort.tank, !tank.isArchived else { return false }
            return tank.placement == .outdoor
        }
    }

    /// 孵化予定が今日か明日、または予定日を過ぎたロット（PRD.md F8）。
    func hatchDue(from entries: [BatchEntry]) -> [BatchEntry] {
        entries.filter { ($0.info.remainingDays ?? Int.max) <= 1 }
    }

    /// 水換えの期限を超えた容器。飼育中の群がいる容器で、最終水換えの記録があるものだけ（DECISIONS.md H）。
    /// 日数が多い順に最大5件。
    func overdueTanks(_ tanks: [Tank], settings: AppSettings, now: Date = .now, calendar: Calendar = .current) -> [OverdueTank] {
        let warningDays = Season.waterChangeWarningDays(
            on: now,
            months: settings.breedingSeasonMonths,
            inSeason: settings.waterChangeWarningDays,
            offSeason: settings.winterWaterChangeWarningDays,
            calendar: calendar
        )
        return tanks
            .filter { !$0.activeCohorts.isEmpty }
            .compactMap { tank -> OverdueTank? in
                let days = MaintenanceRules.daysSinceLastWaterChange(lastWaterChange: tank.lastWaterChange, today: now, calendar: calendar)
                guard MaintenanceRules.isOverdue(daysSince: days, warningDays: warningDays), let days else { return nil }
                return OverdueTank(tank: tank, days: days)
            }
            .sorted { $0.days > $1.days }
            .prefix(5)
            .map { $0 }
    }

    /// 最近の記録。種類ごとに最新5件を取得し、日付順に混ぜて5件にする（DECISIONS.md E、G 3-6）。
    func recentRecords(events: [CohortEvent], batches: [EggBatch], logs: [MaintenanceLog]) -> [RecentRecord] {
        let eventRecords = events.compactMap { event -> RecentRecord? in
            guard let cohort = event.cohort else { return nil }
            return RecentRecord(
                id: "event-\(event.id.uuidString)",
                date: event.date,
                symbolName: event.kind.symbolName,
                title: "\(cohort.strainName) \(cohort.generationLabel)",
                subtitle: CohortEventText.summary(event),
                route: .cohort(cohort)
            )
        }
        let batchRecords = batches.map { batch in
            RecentRecord(
                id: "batch-\(batch.id.uuidString)",
                date: batch.collectedAt,
                symbolName: "circle.grid.3x3",
                title: batch.breedingSet?.displayName ?? String(localized: "親魚セット未設定"),
                subtitle: batch.eggCount.map { String(localized: "採卵 卵\($0.formatted())個") } ?? String(localized: "採卵"),
                route: batch.breedingSet.map { .breedingSet($0) }
            )
        }
        let logRecords = logs.map { log in
            RecentRecord(
                id: "log-\(log.id.uuidString)",
                date: log.date,
                symbolName: log.kind == .temperature ? "thermometer.medium" : "drop",
                title: log.tank?.name ?? String(localized: "容器未設定"),
                subtitle: log.summary,
                route: log.tank.map { .tank($0) }
            )
        }
        return Aggregations.mergeRecent([eventRecords, batchRecords, logRecords], date: { $0.date }, limit: 5)
    }
}
