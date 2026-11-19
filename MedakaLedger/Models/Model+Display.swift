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

// MARK: - 繁殖と作業記録

extension SchemaV1.BreedingSet {
    /// 一覧に出す名前。空なら「雄の系統×雌の系統 開始年月」（ARCHITECTURE.md 3.2）。
    var displayName: String {
        if !name.isEmpty { return name }
        let sire = sireCohort?.strain?.breedName ?? "?"
        let dam = damCohort?.strain?.breedName ?? "?"
        let started = startedAt.formatted(.dateTime.year().month())
        return "\(sire)×\(dam) \(started)"
    }

    var incubatingBatches: [EggBatch] {
        (eggBatches ?? []).filter { $0.status == .incubating }
    }

    /// 採卵日の新しい順。
    var sortedBatches: [EggBatch] {
        (eggBatches ?? []).sorted { $0.collectedAt > $1.collectedAt }
    }

    static var activePredicate: Predicate<BreedingSet> {
        #Predicate<BreedingSet> { $0.endedAt == nil }
    }

    static var endedPredicate: Predicate<BreedingSet> {
        #Predicate<BreedingSet> { $0.endedAt != nil }
    }
}

extension SchemaV1.EggBatch {
    var status: EggBatchStatus {
        get { EggBatchStatus(rawValue: statusRaw) ?? .incubating }
        set { statusRaw = newValue.rawValue }
    }

    /// 親魚セットの名前と採卵日。通知や一覧の見出しに使う。
    var title: String {
        let name = breedingSet?.displayName ?? String(localized: "親魚セット未設定")
        return "\(name) \(CohortText.shortDate(collectedAt))"
    }

    static var incubatingPredicate: Predicate<EggBatch> {
        let incubating = EggBatchStatus.incubating.rawValue
        return #Predicate<EggBatch> { $0.statusRaw == incubating }
    }
}

extension SchemaV1.MaintenanceLog {
    var kind: MaintenanceKind {
        get { MaintenanceKind(rawValue: kindRaw) ?? .other }
        set { kindRaw = newValue.rawValue }
    }

    /// 一覧と最近の記録に出す要点。
    var summary: String {
        switch kind {
        case .waterChange:
            percent.map { "\(kind.label) \($0.formatted())%" } ?? kind.label
        case .temperature:
            waterTempC.map { String(localized: "水温 \($0.formatted(.number.precision(.fractionLength(0...1))))℃") } ?? kind.label
        default:
            kind.label
        }
    }
}

extension SchemaV1.Tank {
    /// 最終水換えの日。記録が無ければ nil。
    var lastWaterChange: Date? {
        (logs ?? []).filter { $0.kind == .waterChange }.map(\.date).max()
    }

    /// 最後に記録した水温。記録が無ければ nil。
    var latestWaterTemp: Double? {
        (logs ?? [])
            .filter { $0.kind == .temperature && $0.waterTempC != nil }
            .max { $0.date < $1.date }?
            .waterTempC
    }

    var recentLogs: [MaintenanceLog] {
        (logs ?? []).sorted { $0.date > $1.date }
    }
}

extension SchemaV1.MaintenanceLog {
    static var recentDescriptor: FetchDescriptor<MaintenanceLog> {
        var descriptor = FetchDescriptor<MaintenanceLog>(sortBy: [SortDescriptor(\MaintenanceLog.date, order: .reverse)])
        descriptor.fetchLimit = 5
        return descriptor
    }
}

extension SchemaV1.EggBatch {
    static var recentDescriptor: FetchDescriptor<EggBatch> {
        var descriptor = FetchDescriptor<EggBatch>(sortBy: [SortDescriptor(\EggBatch.collectedAt, order: .reverse)])
        descriptor.fetchLimit = 5
        return descriptor
    }
}

// MARK: - 販売

extension SchemaV1.Sale {
    var unit: SaleUnit {
        get { SaleUnit(rawValue: unitRaw) ?? .fish }
        set { unitRaw = newValue.rawValue }
    }

    var channel: SaleChannel {
        get { SaleChannel(rawValue: channelRaw) ?? .other }
        set { channelRaw = newValue.rawValue }
    }

    var status: SaleStatus {
        get { SaleStatus(rawValue: statusRaw) ?? .sold }
        set { statusRaw = newValue.rawValue }
    }

    /// 「楊貴妃 F1」。品種名のスナップショットを使う。系統の指定が無い販売は「対象なし」。
    var titleText: String {
        guard !breedNameSnapshot.isEmpty else { return String(localized: "対象なし") }
        return "\(breedNameSnapshot) \(CohortText.generation(generation))"
    }

    static var recentDescriptor: FetchDescriptor<Sale> {
        var descriptor = FetchDescriptor<Sale>(sortBy: [SortDescriptor(\Sale.date, order: .reverse)])
        descriptor.fetchLimit = 5
        return descriptor
    }

    static var listedPredicate: Predicate<Sale> {
        let listed = SaleStatus.listed.rawValue
        return #Predicate<Sale> { $0.statusRaw == listed }
    }
}

enum SaleText {
    static func yen(_ amount: Int) -> String {
        String(localized: "\(amount.formatted())円")
    }

    /// 「ペア×2」「卵×10」。
    static func quantity(unit: SaleUnit, quantity: Int) -> String {
        "\(unit.label)×\(quantity.formatted())"
    }

    static func month(year: Int, month: Int) -> String {
        String(localized: "\(year.formatted(.number.grouping(.never)))年\(month.formatted())月")
    }
}
