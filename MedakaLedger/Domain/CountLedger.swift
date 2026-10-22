import Foundation

// 群の匹数、容器、段階、状態を変える操作の計算（ARCHITECTURE.md 4.3、DECISIONS.md C、H）。
// 値型を受け取って変更後の状態と出来事を返す。SwiftDataへの適用は Models/CohortOperations.swift で行う。

struct TankRef: Equatable, Sendable {
    var id: UUID
    var name: String
}

struct CohortState: Equatable, Sendable {
    var id: UUID
    var strainID: UUID?
    var generation: Int
    var count: Int?
    var tank: TankRef?
    var stage: GrowthStage
    var status: CohortStatus
    var hatchedAt: Date?
    var acquiredAt: Date?
    var originBatchID: UUID?
    var originBreedingSetID: UUID?
}

struct LedgerEvent: Equatable, Sendable {
    var kind: CohortEventKind
    var date: Date
    var countDelta: Int = 0
    var reason: CountChangeReason?
    var fromTank: TankRef?
    var toTank: TankRef?
    var relatedCohortID: UUID?
    var stage: GrowthStage?
    var status: CohortStatus?
    var previousCount: Int?
    var previousStage: GrowthStage
    var previousStatus: CohortStatus
    var note: String = ""
}

enum MergeBlocker: Equatable, Sendable {
    case sameCohort
    case notActive
    case differentStrain
    case differentGeneration
    case differentParents
}

enum LedgerError: Error, Equatable, Sendable {
    case notActive
    case invalidAmount
    case exceedsCount(current: Int)
    case sameTank
    case sameStage
    case sameStatus
    case cannotMerge(MergeBlocker)
    case notLatest
    case partnerNotLatest
    case cannotDeleteCreation
}

/// 出来事が同じ群の中で最新かを判定するための値。最新は保存した順（createdAt）で決める。
struct EventStamp: Equatable, Sendable {
    var id: UUID
    var createdAt: Date
}

enum CountLedger {
    struct Outcome: Equatable, Sendable {
        var state: CohortState
        var event: LedgerEvent
    }

    struct PairOutcome: Equatable, Sendable {
        var primary: Outcome
        var partner: Outcome
    }

    /// 増減の入力。死亡、飛び出し、譲渡は減った数、計数修正は数え直した数、その他は増減の差を受け取る。
    enum CountChange: Equatable, Sendable {
        case decrease(Int, reason: CountChangeReason)
        case recount(Int)
        case adjust(Int)
    }

    static func created(_ state: CohortState, date: Date, note: String = "") -> LedgerEvent {
        LedgerEvent(
            kind: .created,
            date: date,
            countDelta: state.count ?? 0,
            toTank: state.tank,
            previousCount: nil,
            previousStage: state.stage,
            previousStatus: state.status,
            note: note
        )
    }

    static func move(_ state: CohortState, to tank: TankRef, date: Date) throws(LedgerError) -> Outcome {
        guard state.status == .active else { throw .notActive }
        guard state.tank?.id != tank.id else { throw .sameTank }
        var next = state
        next.tank = tank
        var event = baseEvent(.move, state: state, date: date)
        event.fromTank = state.tank
        event.toTank = tank
        return Outcome(state: next, event: event)
    }

    /// 分割。primary が元の群、partner が分割先の群。匹数が未計数の元の群は未計数のまま。
    static func split(_ state: CohortState, amount: Int, to tank: TankRef, newCohortID: UUID, date: Date) throws(LedgerError) -> PairOutcome {
        guard state.status == .active else { throw .notActive }
        guard amount > 0 else { throw .invalidAmount }
        if let current = state.count, amount > current { throw .exceedsCount(current: current) }

        var source = state
        source.count = state.count.map { $0 - amount }
        var sourceEvent = baseEvent(.split, state: state, date: date)
        sourceEvent.countDelta = -amount
        sourceEvent.relatedCohortID = newCohortID
        sourceEvent.fromTank = state.tank
        sourceEvent.toTank = tank

        let child = CohortState(
            id: newCohortID,
            strainID: state.strainID,
            generation: state.generation,
            count: amount,
            tank: tank,
            stage: state.stage,
            status: .active,
            hatchedAt: state.hatchedAt,
            acquiredAt: state.acquiredAt,
            originBatchID: state.originBatchID,
            originBreedingSetID: state.originBreedingSetID
        )
        let childEvent = LedgerEvent(
            kind: .split,
            date: date,
            countDelta: amount,
            fromTank: state.tank,
            toTank: tank,
            relatedCohortID: state.id,
            previousCount: nil,
            previousStage: state.stage,
            previousStatus: .active
        )
        return PairOutcome(
            primary: Outcome(state: source, event: sourceEvent),
            partner: Outcome(state: child, event: childEvent)
        )
    }

    /// 統合できない理由。統合できるなら nil。
    static func mergeBlocker(absorber: CohortState, absorbed: CohortState) -> MergeBlocker? {
        if absorber.id == absorbed.id { return .sameCohort }
        if absorber.status != .active || absorbed.status != .active { return .notActive }
        if absorber.strainID != absorbed.strainID { return .differentStrain }
        if absorber.generation != absorbed.generation { return .differentGeneration }
        let bothAcquired = absorber.originBatchID == nil && absorbed.originBatchID == nil
        let sameParents = absorber.originBreedingSetID != nil && absorber.originBreedingSetID == absorbed.originBreedingSetID
        if !(bothAcquired || sameParents) { return .differentParents }
        return nil
    }

    /// 統合。primary が吸収する群、partner が吸収される群。
    static func merge(into absorber: CohortState, from absorbed: CohortState, date: Date) throws(LedgerError) -> PairOutcome {
        if let blocker = mergeBlocker(absorber: absorber, absorbed: absorbed) { throw .cannotMerge(blocker) }

        var keeper = absorber
        if let a = absorber.count, let b = absorbed.count {
            keeper.count = a + b
        } else {
            keeper.count = nil
        }
        keeper.hatchedAt = earliest(absorber.hatchedAt, absorbed.hatchedAt)
        var keeperEvent = baseEvent(.merge, state: absorber, date: date)
        keeperEvent.countDelta = absorbed.count ?? 0
        keeperEvent.relatedCohortID = absorbed.id
        keeperEvent.fromTank = absorbed.tank
        keeperEvent.toTank = absorber.tank

        var gone = absorbed
        gone.count = 0
        gone.status = .merged
        var goneEvent = baseEvent(.merge, state: absorbed, date: date)
        goneEvent.countDelta = -(absorbed.count ?? 0)
        goneEvent.relatedCohortID = absorber.id
        goneEvent.status = .merged
        goneEvent.fromTank = absorbed.tank
        goneEvent.toTank = absorber.tank

        return PairOutcome(
            primary: Outcome(state: keeper, event: keeperEvent),
            partner: Outcome(state: gone, event: goneEvent)
        )
    }

    static func changeCount(_ state: CohortState, change: CountChange, date: Date, note: String = "") throws(LedgerError) -> Outcome {
        guard state.status == .active else { throw .notActive }
        var next = state
        var event = baseEvent(.countChange, state: state, date: date)
        event.note = note

        switch change {
        case let .decrease(amount, reason):
            guard amount > 0 else { throw .invalidAmount }
            event.reason = reason
            event.countDelta = -amount
            next.count = try applying(-amount, to: state.count)
        case let .adjust(delta):
            guard delta != 0 else { throw .invalidAmount }
            event.reason = .other
            event.countDelta = delta
            next.count = try applying(delta, to: state.count)
        case let .recount(newCount):
            guard newCount >= 0 else { throw .invalidAmount }
            event.reason = .recount
            event.countDelta = newCount - (state.count ?? 0)
            next.count = newCount
        }
        return Outcome(state: next, event: event)
    }

    static func changeStage(_ state: CohortState, to stage: GrowthStage, date: Date) throws(LedgerError) -> Outcome {
        guard state.status == .active else { throw .notActive }
        guard state.stage != stage else { throw .sameStage }
        var next = state
        next.stage = stage
        var event = baseEvent(.stageChange, state: state, date: date)
        event.stage = stage
        return Outcome(state: next, event: event)
    }

    static func changeStatus(_ state: CohortState, to status: CohortStatus, date: Date, note: String = "") throws(LedgerError) -> Outcome {
        guard state.status != status else { throw .sameStatus }
        var next = state
        next.status = status
        var event = baseEvent(.statusChange, state: state, date: date)
        event.status = status
        event.note = note
        return Outcome(state: next, event: event)
    }

    /// 出来事を取り消した後の状態。作成の記録は取り消せない（群の削除を使う）。
    /// 分割先の群の split は取り消さず、群ごと消す（CohortOperations が扱う）。
    static func revert(_ state: CohortState, undoing event: LedgerEvent) throws(LedgerError) -> CohortState {
        guard event.kind != .created else { throw .cannotDeleteCreation }
        var previous = state
        previous.count = event.previousCount
        previous.stage = event.previousStage
        previous.status = event.previousStatus
        if event.kind == .move {
            previous.tank = event.fromTank
        }
        return previous
    }

    /// 保存した順で最新の出来事か。同じ時刻なら id の大きいほうを新しいとみなす。
    static func isLatest(_ id: UUID, among stamps: [EventStamp]) -> Bool {
        latest(of: stamps)?.id == id
    }

    static func latest(of stamps: [EventStamp]) -> EventStamp? {
        stamps.max { lhs, rhs in
            if lhs.createdAt != rhs.createdAt { return lhs.createdAt < rhs.createdAt }
            return lhs.id.uuidString < rhs.id.uuidString
        }
    }

    // MARK: - Private

    private static func baseEvent(_ kind: CohortEventKind, state: CohortState, date: Date) -> LedgerEvent {
        LedgerEvent(
            kind: kind,
            date: date,
            previousCount: state.count,
            previousStage: state.stage,
            previousStatus: state.status
        )
    }

    private static func applying(_ delta: Int, to count: Int?) throws(LedgerError) -> Int? {
        guard let count else { return nil }
        let result = count + delta
        guard result >= 0 else { throw .exceedsCount(current: count) }
        return result
    }

    private static func earliest(_ lhs: Date?, _ rhs: Date?) -> Date? {
        switch (lhs, rhs) {
        case let (l?, r?): min(l, r)
        case let (l?, nil): l
        case let (nil, r?): r
        case (nil, nil): nil
        }
    }
}
