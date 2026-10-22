import Foundation
import Testing
@testable import MedakaLedger

struct CountLedgerTests {
    private let day = Date(timeIntervalSince1970: 1_800_000_000)
    private let tankA = TankRef(id: UUID(), name: "A-1")
    private let tankB = TankRef(id: UUID(), name: "B-1")

    private func cohort(
        count: Int? = 30,
        tank: TankRef? = nil,
        stage: GrowthStage = .adult,
        status: CohortStatus = .active,
        strainID: UUID? = nil,
        generation: Int = 0,
        hatchedAt: Date? = nil,
        originBatchID: UUID? = nil,
        originBreedingSetID: UUID? = nil
    ) -> CohortState {
        CohortState(
            id: UUID(),
            strainID: strainID,
            generation: generation,
            count: count,
            tank: tank ?? tankA,
            stage: stage,
            status: status,
            hatchedAt: hatchedAt,
            acquiredAt: nil,
            originBatchID: originBatchID,
            originBreedingSetID: originBreedingSetID
        )
    }

    // MARK: 作成

    @Test func createdRecordsInitialCount() {
        let event = CountLedger.created(cohort(count: 12), date: day)
        #expect(event.kind == .created)
        #expect(event.countDelta == 12)
        #expect(event.previousCount == nil)
        #expect(event.toTank == tankA)
        #expect(event.reason == .recount)
    }

    @Test func createdDistinguishesZeroFromUncounted() {
        let zero = CountLedger.created(cohort(count: 0), date: day)
        #expect(zero.countDelta == 0)
        #expect(zero.reason == .recount)

        let uncounted = CountLedger.created(cohort(count: nil), date: day)
        #expect(uncounted.countDelta == 0)
        #expect(uncounted.reason == nil)
    }

    // MARK: 移動

    @Test func moveChangesTankAndRemembersSource() throws {
        let outcome = try CountLedger.move(cohort(), to: tankB, date: day)
        #expect(outcome.state.tank == tankB)
        #expect(outcome.event.kind == .move)
        #expect(outcome.event.fromTank == tankA)
        #expect(outcome.event.toTank == tankB)
        #expect(outcome.state.count == 30)
    }

    @Test func moveToSameTankIsRejected() {
        #expect(throws: LedgerError.sameTank) {
            try CountLedger.move(cohort(), to: tankA, date: day)
        }
    }

    @Test func endedCohortCannotMove() {
        #expect(throws: LedgerError.notActive) {
            try CountLedger.move(cohort(status: .soldOut), to: tankB, date: day)
        }
    }

    // MARK: 分割

    @Test func splitMovesFishToNewCohort() throws {
        let strainID = UUID()
        let batchID = UUID()
        let hatched = day.addingTimeInterval(-86_400 * 30)
        let source = cohort(count: 30, stage: .fry, strainID: strainID, generation: 1, hatchedAt: hatched, originBatchID: batchID)
        let newID = UUID()
        let result = try CountLedger.split(source, amount: 10, to: tankB, newCohortID: newID, date: day)

        #expect(result.primary.state.count == 20)
        #expect(result.primary.event.kind == .split)
        #expect(result.primary.event.countDelta == -10)
        #expect(result.primary.event.relatedCohortID == newID)
        #expect(result.primary.event.previousCount == 30)

        let child = result.partner.state
        #expect(child.id == newID)
        #expect(child.count == 10)
        #expect(child.tank == tankB)
        #expect(child.strainID == strainID)
        #expect(child.generation == 1)
        #expect(child.stage == .fry)
        #expect(child.hatchedAt == hatched)
        #expect(child.originBatchID == batchID)
        #expect(result.partner.event.countDelta == 10)
        #expect(result.partner.event.relatedCohortID == source.id)
    }

    @Test func splitBeyondCurrentCountIsRejected() {
        #expect(throws: LedgerError.exceedsCount(current: 5)) {
            try CountLedger.split(cohort(count: 5), amount: 6, to: tankB, newCohortID: UUID(), date: day)
        }
    }

    @Test func splitOfWholeCountLeavesZero() throws {
        let result = try CountLedger.split(cohort(count: 5), amount: 5, to: tankB, newCohortID: UUID(), date: day)
        #expect(result.primary.state.count == 0)
    }

    @Test func splitOfUncountedCohortKeepsSourceUncounted() throws {
        let result = try CountLedger.split(cohort(count: nil), amount: 40, to: tankB, newCohortID: UUID(), date: day)
        #expect(result.primary.state.count == nil)
        #expect(result.partner.state.count == 40)
    }

    @Test(arguments: [0, -3])
    func splitNeedsPositiveAmount(amount: Int) {
        #expect(throws: LedgerError.invalidAmount) {
            try CountLedger.split(cohort(), amount: amount, to: tankB, newCohortID: UUID(), date: day)
        }
    }

    // MARK: 統合

    @Test func mergeAddsCountsAndEndsAbsorbedCohort() throws {
        let strainID = UUID()
        let early = day.addingTimeInterval(-86_400 * 40)
        let late = day.addingTimeInterval(-86_400 * 30)
        let keeper = cohort(count: 20, tank: tankA, stage: .young, strainID: strainID, hatchedAt: late)
        let other = cohort(count: 15, tank: tankB, stage: .fry, strainID: strainID, hatchedAt: early)
        let result = try CountLedger.merge(into: keeper, from: other, date: day)

        #expect(result.primary.state.count == 35)
        #expect(result.primary.state.tank == tankA)
        #expect(result.primary.state.stage == .young)
        #expect(result.primary.state.hatchedAt == early)
        #expect(result.primary.event.countDelta == 15)
        #expect(result.primary.event.relatedCohortID == other.id)

        #expect(result.partner.state.count == 0)
        #expect(result.partner.state.status == .merged)
        #expect(result.partner.event.countDelta == -15)
        #expect(result.partner.event.status == .merged)
        #expect(result.partner.event.previousCount == 15)
        #expect(result.partner.event.previousStatus == .active)
    }

    @Test func mergeWithUncountedCohortIsUncounted() throws {
        let strainID = UUID()
        let result = try CountLedger.merge(
            into: cohort(count: 20, strainID: strainID),
            from: cohort(count: nil, strainID: strainID),
            date: day
        )
        #expect(result.primary.state.count == nil)
    }

    @Test func mergeConditions() {
        let strainID = UUID()
        let setID = UUID()
        let base = cohort(strainID: strainID, generation: 1, originBatchID: UUID(), originBreedingSetID: setID)

        #expect(CountLedger.mergeBlocker(absorber: base, absorbed: base) == .sameCohort)
        #expect(CountLedger.mergeBlocker(absorber: base, absorbed: cohort(strainID: UUID(), generation: 1, originBatchID: UUID(), originBreedingSetID: setID)) == .differentStrain)
        #expect(CountLedger.mergeBlocker(absorber: base, absorbed: cohort(strainID: strainID, generation: 2, originBatchID: UUID(), originBreedingSetID: setID)) == .differentGeneration)
        #expect(CountLedger.mergeBlocker(absorber: base, absorbed: cohort(strainID: strainID, generation: 1, originBatchID: UUID(), originBreedingSetID: UUID())) == .differentParents)
        #expect(CountLedger.mergeBlocker(absorber: base, absorbed: cohort(strainID: strainID, generation: 1)) == .differentParents)
        #expect(CountLedger.mergeBlocker(absorber: base, absorbed: cohort(status: .merged, strainID: strainID, generation: 1, originBatchID: UUID(), originBreedingSetID: setID)) == .notActive)
        // 同じ親魚セットの別のロットから生まれた群どうしは統合できる
        #expect(CountLedger.mergeBlocker(absorber: base, absorbed: cohort(strainID: strainID, generation: 1, originBatchID: UUID(), originBreedingSetID: setID)) == nil)
        // 入手個体どうしは統合できる
        #expect(CountLedger.mergeBlocker(absorber: cohort(strainID: strainID), absorbed: cohort(strainID: strainID)) == nil)
    }

    @Test func mergeWithBlockerThrows() {
        #expect(throws: LedgerError.cannotMerge(.differentStrain)) {
            try CountLedger.merge(into: cohort(strainID: UUID()), from: cohort(strainID: UUID()), date: day)
        }
    }

    // MARK: 増減

    @Test func decreaseReducesCount() throws {
        let outcome = try CountLedger.changeCount(cohort(count: 30), change: .decrease(3, reason: .death), date: day)
        #expect(outcome.state.count == 27)
        #expect(outcome.event.kind == .countChange)
        #expect(outcome.event.reason == .death)
        #expect(outcome.event.countDelta == -3)
        #expect(outcome.event.previousCount == 30)
    }

    @Test func decreaseBelowZeroIsRejected() {
        #expect(throws: LedgerError.exceedsCount(current: 2)) {
            try CountLedger.changeCount(cohort(count: 2), change: .decrease(3, reason: .jumpedOut), date: day)
        }
    }

    @Test func negativeAdjustBelowZeroIsRejected() {
        #expect(throws: LedgerError.exceedsCount(current: 2)) {
            try CountLedger.changeCount(cohort(count: 2), change: .adjust(-5), date: day)
        }
    }

    @Test func decreaseOnUncountedCohortKeepsUncounted() throws {
        let outcome = try CountLedger.changeCount(cohort(count: nil), change: .decrease(3, reason: .death), date: day)
        #expect(outcome.state.count == nil)
        #expect(outcome.event.countDelta == -3)
        #expect(outcome.event.previousCount == nil)
    }

    @Test func recountSetsAbsoluteCount() throws {
        let outcome = try CountLedger.changeCount(cohort(count: 30), change: .recount(26), date: day)
        #expect(outcome.state.count == 26)
        #expect(outcome.event.reason == .recount)
        #expect(outcome.event.countDelta == -4)
    }

    @Test func recountFromUncounted() throws {
        let outcome = try CountLedger.changeCount(cohort(count: nil), change: .recount(48), date: day)
        #expect(outcome.state.count == 48)
        #expect(outcome.event.previousCount == nil)
    }

    @Test func adjustCanIncrease() throws {
        let outcome = try CountLedger.changeCount(cohort(count: 10), change: .adjust(4), date: day, note: "見落とし")
        #expect(outcome.state.count == 14)
        #expect(outcome.event.reason == .other)
        #expect(outcome.event.note == "見落とし")
    }

    @Test func invalidAmountsAreRejected() {
        #expect(throws: LedgerError.invalidAmount) {
            try CountLedger.changeCount(cohort(), change: .decrease(0, reason: .death), date: day)
        }
        #expect(throws: LedgerError.invalidAmount) {
            try CountLedger.changeCount(cohort(), change: .adjust(0), date: day)
        }
        #expect(throws: LedgerError.invalidAmount) {
            try CountLedger.changeCount(cohort(), change: .recount(-1), date: day)
        }
    }

    // MARK: 段階と状態

    @Test func stageChangeRemembersPreviousStage() throws {
        let outcome = try CountLedger.changeStage(cohort(stage: .hatchling), to: .fry, date: day)
        #expect(outcome.state.stage == .fry)
        #expect(outcome.event.stage == .fry)
        #expect(outcome.event.previousStage == .hatchling)
    }

    @Test func sameStageIsRejected() {
        #expect(throws: LedgerError.sameStage) {
            try CountLedger.changeStage(cohort(stage: .adult), to: .adult, date: day)
        }
    }

    @Test func statusChangeRecordsNewStatus() throws {
        let outcome = try CountLedger.changeStatus(cohort(count: 0), to: .soldOut, date: day)
        #expect(outcome.state.status == .soldOut)
        #expect(outcome.event.status == .soldOut)
        #expect(outcome.event.previousStatus == .active)
    }

    // MARK: 取り消し

    @Test func revertMoveRestoresTank() throws {
        let before = cohort()
        let outcome = try CountLedger.move(before, to: tankB, date: day)
        let reverted = try CountLedger.revert(outcome.state, undoing: outcome.event)
        #expect(reverted == before)
    }

    @Test func revertSplitRestoresSourceCount() throws {
        let before = cohort(count: 30)
        let result = try CountLedger.split(before, amount: 12, to: tankB, newCohortID: UUID(), date: day)
        let reverted = try CountLedger.revert(result.primary.state, undoing: result.primary.event)
        #expect(reverted == before)
    }

    @Test func revertMergeRestoresBothCohorts() throws {
        let strainID = UUID()
        let keeper = cohort(count: 20, strainID: strainID)
        let other = cohort(count: 15, tank: tankB, strainID: strainID)
        let result = try CountLedger.merge(into: keeper, from: other, date: day)
        #expect(try CountLedger.revert(result.primary.state, undoing: result.primary.event) == keeper)
        #expect(try CountLedger.revert(result.partner.state, undoing: result.partner.event) == other)
    }

    @Test func revertCountChangeAndStageAndStatus() throws {
        let before = cohort(count: nil, stage: .hatchling)
        let counted = try CountLedger.changeCount(before, change: .recount(50), date: day)
        #expect(try CountLedger.revert(counted.state, undoing: counted.event) == before)

        let staged = try CountLedger.changeStage(before, to: .fry, date: day)
        #expect(try CountLedger.revert(staged.state, undoing: staged.event) == before)

        let ended = try CountLedger.changeStatus(before, to: .lost, date: day)
        #expect(try CountLedger.revert(ended.state, undoing: ended.event) == before)
    }

    @Test func creationCannotBeReverted() {
        let state = cohort()
        let event = CountLedger.created(state, date: day)
        #expect(throws: LedgerError.cannotDeleteCreation) {
            try CountLedger.revert(state, undoing: event)
        }
    }

    // MARK: 最新の判定

    @Test func latestIsDecidedBySaveOrder() {
        let first = EventStamp(id: UUID(), createdAt: day)
        let second = EventStamp(id: UUID(), createdAt: day.addingTimeInterval(1))
        #expect(CountLedger.isLatest(second.id, among: [first, second]))
        #expect(!CountLedger.isLatest(first.id, among: [second, first]))
        #expect(CountLedger.latest(of: []) == nil)
    }
}
