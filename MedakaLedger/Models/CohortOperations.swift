import Foundation
import SwiftData

// CountLedger の計算結果を SwiftData のモデルに適用する層（ARCHITECTURE.md 4.3）。
// 群の匹数、容器、段階、状態を変える操作は必ずここを通し、CohortEvent を残す。

enum CohortOperations {
    enum OperationError: LocalizedError, Equatable {
        case ledger(LedgerError)
        case sourceTankArchived
        case tankArchived
        case usedByBreedingSet
        case partnerMissing
        case missingCohort

        var errorDescription: String? {
            switch self {
            case let .ledger(error): error.message
            case .sourceTankArchived: String(localized: "移動元の容器がアーカイブされています。容器のアーカイブを解除してから削除してください。")
            case .tankArchived: String(localized: "この群の容器がアーカイブされています。容器のアーカイブを解除してから削除してください。")
            case .usedByBreedingSet: String(localized: "親魚セットに使われている群は削除できません。アーカイブしてください。")
            case .partnerMissing: String(localized: "分割元の群が削除されているため、この記録は削除できません。")
            case .missingCohort: String(localized: "群が見つかりません。")
            }
        }
    }

    // MARK: - 作成

    /// 群を作り、作成の記録を1件残す（DECISIONS.md C）。
    @discardableResult
    static func createCohort(
        strain: Strain?,
        tank: Tank?,
        count: Int?,
        maleCount: Int? = nil,
        femaleCount: Int? = nil,
        stage: GrowthStage,
        generation: Int = 0,
        acquiredAt: Date? = nil,
        hatchedAt: Date? = nil,
        label: String = "",
        note: String = "",
        date: Date,
        isSample: Bool = false,
        in context: ModelContext
    ) -> Cohort {
        let cohort = Cohort(
            label: label,
            generation: generation,
            count: count,
            maleCount: maleCount,
            femaleCount: femaleCount,
            stage: stage,
            hatchedAt: hatchedAt,
            acquiredAt: acquiredAt,
            note: note,
            isSample: isSample
        )
        context.insert(cohort)
        cohort.strain = strain
        cohort.tank = tank
        record(CountLedger.created(state(of: cohort), date: date), on: cohort, in: context)
        return cohort
    }

    // MARK: - 操作

    static func move(_ cohort: Cohort, to tank: Tank, date: Date, in context: ModelContext) throws(OperationError) {
        let outcome = try ledger { () throws(LedgerError) in try CountLedger.move(state(of: cohort), to: ref(tank), date: date) }
        apply(outcome.state, to: cohort)
        cohort.tank = tank
        record(outcome.event, on: cohort, in: context)
    }

    /// 分割。分割先の群を返す。分割先には created を残さず split を最初の出来事にする（DECISIONS.md H）。
    @discardableResult
    static func split(_ cohort: Cohort, amount: Int, to tank: Tank, label: String = "", date: Date, in context: ModelContext) throws(OperationError) -> Cohort {
        let newID = UUID()
        let result = try ledger { () throws(LedgerError) in
            try CountLedger.split(state(of: cohort), amount: amount, to: ref(tank), newCohortID: newID, date: date)
        }
        let child = Cohort(
            label: label,
            generation: cohort.generation,
            count: result.partner.state.count,
            stage: cohort.stage,
            hatchedAt: cohort.hatchedAt,
            acquiredAt: cohort.acquiredAt,
            sizeText: cohort.sizeText,
            isSample: cohort.isSample
        )
        child.id = newID
        context.insert(child)
        child.strain = cohort.strain
        child.tank = tank
        child.originBatch = cohort.originBatch

        apply(result.primary.state, to: cohort)
        record(result.primary.event, on: cohort, in: context)
        record(result.partner.event, on: child, in: context)
        return child
    }

    /// 統合。absorbed を absorber にまとめる。
    static func merge(_ absorbed: Cohort, into absorber: Cohort, date: Date, in context: ModelContext) throws(OperationError) {
        let result = try ledger { () throws(LedgerError) in
            try CountLedger.merge(into: state(of: absorber), from: state(of: absorbed), date: date)
        }
        apply(result.primary.state, to: absorber)
        apply(result.partner.state, to: absorbed)
        record(result.primary.event, on: absorber, in: context)
        record(result.partner.event, on: absorbed, in: context)
    }

    static func changeCount(_ cohort: Cohort, change: CountLedger.CountChange, date: Date, note: String = "", in context: ModelContext) throws(OperationError) {
        let outcome = try ledger { () throws(LedgerError) in
            try CountLedger.changeCount(state(of: cohort), change: change, date: date, note: note)
        }
        apply(outcome.state, to: cohort)
        record(outcome.event, on: cohort, in: context)
    }

    static func changeStage(_ cohort: Cohort, to stage: GrowthStage, date: Date, in context: ModelContext) throws(OperationError) {
        let outcome = try ledger { () throws(LedgerError) in try CountLedger.changeStage(state(of: cohort), to: stage, date: date) }
        apply(outcome.state, to: cohort)
        record(outcome.event, on: cohort, in: context)
    }

    static func changeStatus(_ cohort: Cohort, to status: CohortStatus, date: Date, note: String = "", in context: ModelContext) throws(OperationError) {
        let outcome = try ledger { () throws(LedgerError) in
            try CountLedger.changeStatus(state(of: cohort), to: status, date: date, note: note)
        }
        apply(outcome.state, to: cohort)
        record(outcome.event, on: cohort, in: context)
    }

    // MARK: - 出来事の削除

    /// 削除できない理由。削除できるなら nil。分割と統合の相手側の確認は deleteEvent で行う。
    static func deletionBlocker(for event: CohortEvent) -> LedgerError? {
        if event.kind == .created { return .cannotDeleteCreation }
        guard let cohort = event.cohort else { return nil }
        return CountLedger.isLatest(event.id, among: stamps(of: cohort)) ? nil : .notLatest
    }

    /// 最新の出来事を削除し、群を元の状態に戻す（DECISIONS.md C）。
    /// 分割と統合は、相手側の対応する出来事も相手の最新である場合に限り、両方まとめて削除する。
    static func deleteEvent(_ event: CohortEvent, in context: ModelContext) throws(OperationError) {
        if let blocker = deletionBlocker(for: event) { throw .ledger(blocker) }
        guard let cohort = event.cohort else {
            context.delete(event)
            return
        }

        switch event.kind {
        case .split, .merge:
            guard let partner = event.relatedCohortID.flatMap({ fetchCohort(id: $0, in: context) }) else {
                // 分割先の群の split は、分割元が無いと匹数を戻せない（previousCount が無い）
                if event.kind == .split, event.countDelta > 0 { throw .partnerMissing }
                // 相手の群が削除済みなら、こちらだけ戻す
                if let blocker = revertBlocker(cohort, undoing: event, in: context) { throw blocker }
                try revert(cohort, undoing: event, in: context)
                context.delete(event)
                return
            }
            guard let partnerEvent = latestEvent(of: partner),
                  partnerEvent.kind == event.kind,
                  partnerEvent.relatedCohortID == cohort.id
            else { throw .ledger(.partnerNotLatest) }

            if event.kind == .split {
                // countDelta の符号で元の群（マイナス）と分割先（プラス）を見分ける
                let (sourceEvent, source, child) = event.countDelta < 0 ? (event, cohort, partner) : (partnerEvent, partner, cohort)
                // 分割先の群を消すと親魚セットの親が失われる
                if isUsedByBreedingSet(child) { throw .usedByBreedingSet }
                if let blocker = revertBlocker(source, undoing: sourceEvent, in: context) { throw blocker }
                try revert(source, undoing: sourceEvent, in: context)
                context.delete(sourceEvent)
                context.delete(child)
            } else {
                // 片方だけ戻ることがないよう、両方を確かめてから戻す
                if let blocker = revertBlocker(cohort, undoing: event, in: context)
                    ?? revertBlocker(partner, undoing: partnerEvent, in: context) { throw blocker }
                try revert(cohort, undoing: event, in: context)
                try revert(partner, undoing: partnerEvent, in: context)
                context.delete(event)
                context.delete(partnerEvent)
            }
        default:
            if let blocker = revertBlocker(cohort, undoing: event, in: context) { throw blocker }
            try revert(cohort, undoing: event, in: context)
            context.delete(event)
        }
    }

    /// 親魚セットの雄または雌に使われているか。使われている群は削除できず、アーカイブだけ（DECISIONS.md C）。
    static func isUsedByBreedingSet(_ cohort: Cohort) -> Bool {
        !(cohort.asSire ?? []).isEmpty || !(cohort.asDam ?? []).isEmpty
    }

    /// 群の削除。出来事、選別、写真も消える。分割や統合の相手の群は変えない（DECISIONS.md H）。
    static func deleteCohort(_ cohort: Cohort, in context: ModelContext) throws(OperationError) {
        if isUsedByBreedingSet(cohort) { throw .usedByBreedingSet }
        context.delete(cohort)
    }

    // MARK: - 統合の候補

    /// この群に統合できる群。同じ系統、同じ世代、同じ親魚セット（または入手個体どうし）の飼育中の群。
    static func mergeCandidates(for cohort: Cohort, in context: ModelContext) -> [Cohort] {
        let generation = cohort.generation
        let active = CohortStatus.active.rawValue
        let descriptor = FetchDescriptor<Cohort>(
            predicate: #Predicate<Cohort> { $0.generation == generation && $0.statusRaw == active },
            sortBy: [SortDescriptor(\Cohort.createdAt)]
        )
        let target = state(of: cohort)
        let fetched = (try? context.fetch(descriptor)) ?? []
        return fetched.filter { CountLedger.mergeBlocker(absorber: target, absorbed: state(of: $0)) == nil }
    }

    // MARK: - 変換

    static func state(of cohort: Cohort) -> CohortState {
        CohortState(
            id: cohort.id,
            strainID: cohort.strain?.id,
            generation: cohort.generation,
            count: cohort.count,
            tank: cohort.tank.map(ref),
            stage: cohort.stage,
            status: cohort.status,
            hatchedAt: cohort.hatchedAt,
            acquiredAt: cohort.acquiredAt,
            originBatchID: cohort.originBatch?.id,
            originBreedingSetID: cohort.originBatch?.breedingSet?.id
        )
    }

    static func ledgerEvent(from event: CohortEvent) -> LedgerEvent {
        LedgerEvent(
            kind: event.kind,
            date: event.date,
            countDelta: event.countDelta,
            reason: event.reason,
            fromTank: event.fromTankID.map { TankRef(id: $0, name: event.fromTankName) },
            toTank: event.toTankID.map { TankRef(id: $0, name: event.toTankName) },
            relatedCohortID: event.relatedCohortID,
            stage: event.stage,
            status: event.status,
            previousCount: event.previousCount,
            previousStage: event.previousStage,
            previousStatus: event.previousStatus,
            note: event.note
        )
    }

    // MARK: - Private

    private static func ref(_ tank: Tank) -> TankRef {
        TankRef(id: tank.id, name: tank.name)
    }

    private static func ledger<T>(_ body: () throws(LedgerError) -> T) throws(OperationError) -> T {
        do {
            return try body()
        } catch {
            throw .ledger(error)
        }
    }

    private static func apply(_ state: CohortState, to cohort: Cohort) {
        cohort.count = state.count
        cohort.stage = state.stage
        cohort.status = state.status
        cohort.hatchedAt = state.hatchedAt
    }

    /// 取り消すとアーカイブ済みの容器に飼育中の群がいることになる場合は止める（DECISIONS.md H）。
    private static func revertBlocker(_ cohort: Cohort, undoing event: CohortEvent, in context: ModelContext) -> OperationError? {
        if event.kind == .move, let sourceID = event.fromTankID, fetchTank(id: sourceID, in: context)?.isArchived == true {
            return .sourceTankArchived
        }
        if event.previousStatus == .active, !cohort.isActive, cohort.tank?.isArchived == true {
            return .tankArchived
        }
        return nil
    }

    private static func revert(_ cohort: Cohort, undoing event: CohortEvent, in context: ModelContext) throws(OperationError) {
        let ledgerEvent = ledgerEvent(from: event)
        if event.kind == .move {
            if let sourceID = event.fromTankID {
                cohort.tank = fetchTank(id: sourceID, in: context)
            } else {
                cohort.tank = nil
            }
        }
        let previous = try ledger { () throws(LedgerError) in try CountLedger.revert(state(of: cohort), undoing: ledgerEvent) }
        cohort.count = previous.count
        cohort.stage = previous.stage
        cohort.status = previous.status
    }

    @discardableResult
    private static func record(_ ledgerEvent: LedgerEvent, on cohort: Cohort, in context: ModelContext) -> CohortEvent {
        let event = CohortEvent()
        event.date = ledgerEvent.date
        event.kind = ledgerEvent.kind
        event.countDelta = ledgerEvent.countDelta
        event.reasonRaw = ledgerEvent.reason?.rawValue ?? ""
        event.fromTankID = ledgerEvent.fromTank?.id
        event.fromTankName = ledgerEvent.fromTank?.name ?? ""
        event.toTankID = ledgerEvent.toTank?.id
        event.toTankName = ledgerEvent.toTank?.name ?? ""
        event.relatedCohortID = ledgerEvent.relatedCohortID
        event.stageRaw = ledgerEvent.stage?.rawValue ?? ""
        event.statusRaw = ledgerEvent.status?.rawValue ?? ""
        event.previousCount = ledgerEvent.previousCount
        event.previousStageRaw = ledgerEvent.previousStage.rawValue
        event.previousStatusRaw = ledgerEvent.previousStatus.rawValue
        event.note = ledgerEvent.note
        event.isSample = cohort.isSample
        event.createdAt = nextStamp(for: cohort)
        context.insert(event)
        event.cohort = cohort
        return event
    }

    /// 同じ群の中で保存日時が必ず増えるようにする。
    private static func nextStamp(for cohort: Cohort) -> Date {
        let now = Date()
        guard let latest = CountLedger.latest(of: stamps(of: cohort)) else { return now }
        return max(now, latest.createdAt.addingTimeInterval(0.001))
    }

    private static func stamps(of cohort: Cohort) -> [EventStamp] {
        (cohort.events ?? []).map { EventStamp(id: $0.id, createdAt: $0.createdAt) }
    }

    private static func latestEvent(of cohort: Cohort) -> CohortEvent? {
        guard let latest = CountLedger.latest(of: stamps(of: cohort)) else { return nil }
        return (cohort.events ?? []).first { $0.id == latest.id }
    }

    private static func fetchCohort(id: UUID, in context: ModelContext) -> Cohort? {
        var descriptor = FetchDescriptor<Cohort>(predicate: #Predicate<Cohort> { $0.id == id })
        descriptor.fetchLimit = 1
        return (try? context.fetch(descriptor))?.first
    }

    private static func fetchTank(id: UUID, in context: ModelContext) -> Tank? {
        var descriptor = FetchDescriptor<Tank>(predicate: #Predicate<Tank> { $0.id == id })
        descriptor.fetchLimit = 1
        return (try? context.fetch(descriptor))?.first
    }
}
