import Foundation
import SwiftData

// 画面で使う表示用の値と、よく使う述語。

extension SchemaV1.Tank {
    var kind: TankKind {
        get { TankKind(rawValue: kindRaw) ?? .other }
        set { kindRaw = newValue.rawValue }
    }

    var placement: Placement {
        get { Placement(rawValue: placementRaw) ?? .outdoor }
        set { placementRaw = newValue.rawValue }
    }

    /// 今いる群（状態が飼育中の群。DECISIONS.md C）。古い順。
    var activeCohorts: [Cohort] {
        (cohorts ?? [])
            .filter { $0.status == .active }
            .sorted { $0.createdAt < $1.createdAt }
    }

    static var unarchivedPredicate: Predicate<Tank> {
        #Predicate<Tank> { $0.isArchived == false }
    }

    static var archivedPredicate: Predicate<Tank> {
        #Predicate<Tank> { $0.isArchived == true }
    }

    static var listSort: [SortDescriptor<Tank>] {
        [SortDescriptor(\Tank.sortOrder), SortDescriptor(\Tank.createdAt)]
    }
}

extension SchemaV1.Strain {
    var activeCohorts: [Cohort] {
        (cohorts ?? []).filter { $0.status == .active }
    }

    static var unarchivedPredicate: Predicate<Strain> {
        #Predicate<Strain> { $0.isArchived == false }
    }

    static var archivedPredicate: Predicate<Strain> {
        #Predicate<Strain> { $0.isArchived == true }
    }

    static var listSort: [SortDescriptor<Strain>] {
        [SortDescriptor(\Strain.sortOrder), SortDescriptor(\Strain.createdAt)]
    }
}

extension SchemaV1.Cohort {
    var stage: GrowthStage {
        get { GrowthStage(rawValue: stageRaw) ?? .adult }
        set { stageRaw = newValue.rawValue }
    }

    var status: CohortStatus {
        get { CohortStatus(rawValue: statusRaw) ?? .active }
        set { statusRaw = newValue.rawValue }
    }

    var isActive: Bool { status == .active }

    var generationLabel: String { CohortText.generation(generation) }

    var countText: String { CohortText.count(count) }

    /// 見出しに使う名前。系統の表示名、なければ「系統未設定」。
    var strainName: String {
        strain?.displayName ?? String(localized: "系統未設定")
    }

    var tankName: String {
        tank?.name ?? String(localized: "容器未設定")
    }

    /// 雌雄の内訳。どちらも未入力なら nil。
    var sexText: String? {
        guard maleCount != nil || femaleCount != nil else { return nil }
        let male = maleCount.map { $0.formatted() } ?? "?"
        let female = femaleCount.map { $0.formatted() } ?? "?"
        return String(localized: "雄\(male)・雌\(female)")
    }

    /// タイムラインの並び。日付の新しい順、同じ日付なら保存の新しい順（DECISIONS.md H）。
    var timeline: [CohortEvent] {
        (events ?? []).sorted { lhs, rhs in
            if lhs.date != rhs.date { return lhs.date > rhs.date }
            return lhs.createdAt > rhs.createdAt
        }
    }

    static var activePredicate: Predicate<Cohort> {
        let active = CohortStatus.active.rawValue
        return #Predicate<Cohort> { $0.statusRaw == active }
    }
}

extension SchemaV1.CohortEvent {
    var kind: CohortEventKind {
        get { CohortEventKind(rawValue: kindRaw) ?? .note }
        set { kindRaw = newValue.rawValue }
    }

    var reason: CountChangeReason? { CountChangeReason(rawValue: reasonRaw) }
    var stage: GrowthStage? { GrowthStage(rawValue: stageRaw) }
    var status: CohortStatus? { CohortStatus(rawValue: statusRaw) }
    var previousStage: GrowthStage { GrowthStage(rawValue: previousStageRaw) ?? .adult }
    var previousStatus: CohortStatus { CohortStatus(rawValue: previousStatusRaw) ?? .active }

    static var recentDescriptor: FetchDescriptor<CohortEvent> {
        var descriptor = FetchDescriptor<CohortEvent>(
            sortBy: [SortDescriptor(\CohortEvent.date, order: .reverse), SortDescriptor(\CohortEvent.createdAt, order: .reverse)]
        )
        descriptor.fetchLimit = 5
        return descriptor
    }
}

enum CohortText {
    static func generation(_ generation: Int) -> String {
        generation == 0 ? String(localized: "入手") : "F\(generation)"
    }

    static func count(_ count: Int?) -> String {
        guard let count else { return String(localized: "未計数") }
        return String(localized: "\(count.formatted())匹")
    }

    static func date(_ date: Date) -> String {
        date.formatted(.dateTime.year().month().day())
    }

    static func shortDate(_ date: Date) -> String {
        date.formatted(.dateTime.month().day())
    }
}
