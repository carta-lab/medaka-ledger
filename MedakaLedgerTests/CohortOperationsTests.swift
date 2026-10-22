import Foundation
import SwiftData
import Testing
@testable import MedakaLedger

// CountLedger の結果を SwiftData に適用する層のテスト（ARCHITECTURE.md 4.3：適用部分はインメモリの ModelContainer で行う）。

@MainActor
struct CohortOperationsTests {
    private let container: ModelContainer
    private let context: ModelContext
    private let day = Date(timeIntervalSince1970: 1_800_000_000)

    init() throws {
        container = try ModelStore.makeContainer(inMemory: true)
        context = container.mainContext
    }

    private func makeTank(_ name: String, archived: Bool = false) -> Tank {
        let tank = Tank(name: name, kind: .nvBox)
        tank.isArchived = archived
        context.insert(tank)
        return tank
    }

    private func makeStrain() -> Strain {
        let strain = Strain(breedName: "楊貴妃")
        context.insert(strain)
        return strain
    }

    private func makeCohort(count: Int? = 30, tank: Tank, strain: Strain) -> Cohort {
        CohortOperations.createCohort(strain: strain, tank: tank, count: count, stage: .adult, acquiredAt: day, date: day, in: context)
    }

    @Test func containerOpensWithVersionedSchema() throws {
        #expect(ModelStore.schema.entities.count == SchemaV1.models.count)
        try context.save()
    }

    @Test func createLeavesCreatedEvent() throws {
        let cohort = makeCohort(tank: makeTank("A-1"), strain: makeStrain())
        try context.save()
        #expect(cohort.events?.count == 1)
        #expect(cohort.timeline.first?.kind == .created)
    }

    @Test func splitAndMergeLeaveEventsOnBothCohorts() throws {
        let strain = makeStrain()
        let a = makeTank("A-1")
        let b = makeTank("B-1")
        let source = makeCohort(count: 30, tank: a, strain: strain)

        let child = try CohortOperations.split(source, amount: 10, to: b, date: day, in: context)
        try context.save()
        #expect(source.count == 20)
        #expect(child.count == 10)
        #expect(child.tank?.id == b.id)
        #expect(child.strain?.id == strain.id)
        #expect(source.timeline.first?.kind == .split)
        #expect(child.timeline.first?.kind == .split)
        #expect(child.timeline.first?.relatedCohortID == source.id)

        try CohortOperations.merge(child, into: source, date: day, in: context)
        try context.save()
        #expect(source.count == 30)
        #expect(child.count == 0)
        #expect(child.status == .merged)
        #expect(source.timeline.first?.kind == .merge)
        #expect(child.timeline.first?.kind == .merge)
        #expect(child.timeline.first?.relatedCohortID == source.id)
    }

    @Test func deletingLatestMoveReturnsToSourceTank() throws {
        let a = makeTank("A-1")
        let b = makeTank("B-1")
        let cohort = makeCohort(tank: a, strain: makeStrain())
        try CohortOperations.move(cohort, to: b, date: day, in: context)
        try context.save()
        #expect(cohort.tank?.id == b.id)

        let moveEvent = try #require(cohort.timeline.first)
        try CohortOperations.deleteEvent(moveEvent, in: context)
        try context.save()
        #expect(cohort.tank?.id == a.id)
        #expect(cohort.events?.count == 1)
    }

    @Test func onlyLatestEventCanBeDeleted() throws {
        let cohort = makeCohort(count: 30, tank: makeTank("A-1"), strain: makeStrain())
        try CohortOperations.changeCount(cohort, change: .decrease(2, reason: .death), date: day, in: context)
        try CohortOperations.changeCount(cohort, change: .decrease(3, reason: .death), date: day, in: context)
        try context.save()

        let older = try #require((cohort.events ?? []).first { $0.countDelta == -2 })
        #expect(CohortOperations.deletionBlocker(for: older) == .notLatest)
        #expect(throws: CohortOperations.OperationError.ledger(.notLatest)) {
            try CohortOperations.deleteEvent(older, in: context)
        }

        let latest = try #require((cohort.events ?? []).first { $0.countDelta == -3 })
        try CohortOperations.deleteEvent(latest, in: context)
        #expect(cohort.count == 28)
    }

    @Test func creationCannotBeDeleted() throws {
        let cohort = makeCohort(tank: makeTank("A-1"), strain: makeStrain())
        let created = try #require(cohort.timeline.first)
        #expect(CohortOperations.deletionBlocker(for: created) == .cannotDeleteCreation)
    }

    @Test func deletingSplitRemovesChildAndRestoresCount() throws {
        let source = makeCohort(count: 30, tank: makeTank("A-1"), strain: makeStrain())
        let child = try CohortOperations.split(source, amount: 12, to: makeTank("B-1"), date: day, in: context)
        try context.save()

        let childSplit = try #require(child.timeline.first)
        try CohortOperations.deleteEvent(childSplit, in: context)
        try context.save()
        #expect(source.count == 30)
        #expect(source.events?.count == 1)
        let remaining = try context.fetch(FetchDescriptor<Cohort>())
        #expect(remaining.count == 1)
    }

    @Test func splitCannotBeDeletedAfterChildHasLaterRecords() throws {
        let source = makeCohort(count: 30, tank: makeTank("A-1"), strain: makeStrain())
        let child = try CohortOperations.split(source, amount: 12, to: makeTank("B-1"), date: day, in: context)
        try CohortOperations.changeCount(child, change: .decrease(1, reason: .death), date: day, in: context)
        try context.save()

        let sourceSplit = try #require(source.timeline.first)
        #expect(throws: CohortOperations.OperationError.ledger(.partnerNotLatest)) {
            try CohortOperations.deleteEvent(sourceSplit, in: context)
        }
        #expect(source.count == 18)
    }

    @Test func deletingMergeRestoresBothCohorts() throws {
        let strain = makeStrain()
        let keeper = makeCohort(count: 20, tank: makeTank("A-1"), strain: strain)
        let other = makeCohort(count: 15, tank: makeTank("B-1"), strain: strain)
        try CohortOperations.merge(other, into: keeper, date: day, in: context)
        try context.save()

        let mergeEvent = try #require(keeper.timeline.first)
        try CohortOperations.deleteEvent(mergeEvent, in: context)
        try context.save()
        #expect(keeper.count == 20)
        #expect(other.count == 15)
        #expect(other.status == .active)
        #expect(keeper.events?.count == 1)
        #expect(other.events?.count == 1)
    }

    @Test func moveBackToArchivedTankIsBlocked() throws {
        let a = makeTank("A-1")
        let cohort = makeCohort(tank: a, strain: makeStrain())
        try CohortOperations.move(cohort, to: makeTank("B-1"), date: day, in: context)
        a.isArchived = true
        try context.save()

        let moveEvent = try #require(cohort.timeline.first)
        #expect(throws: CohortOperations.OperationError.sourceTankArchived) {
            try CohortOperations.deleteEvent(moveEvent, in: context)
        }
    }

    @Test func endingCohortCanBeUndone() throws {
        let cohort = makeCohort(count: 1, tank: makeTank("A-1"), strain: makeStrain())
        try CohortOperations.changeCount(cohort, change: .decrease(1, reason: .death), date: day, in: context)
        try CohortOperations.changeStatus(cohort, to: .lost, date: day, in: context)
        try context.save()
        #expect(cohort.status == .lost)
        #expect(cohort.timeline.first?.status == .lost)

        let ended = try #require(cohort.timeline.first)
        try CohortOperations.deleteEvent(ended, in: context)
        #expect(cohort.status == .active)
        #expect(cohort.count == 0)
    }

    @Test func mergeCandidatesFollowConditions() throws {
        let strain = makeStrain()
        let otherStrain = makeStrain()
        let tank = makeTank("A-1")
        let base = makeCohort(tank: tank, strain: strain)
        let sameStrain = makeCohort(tank: makeTank("B-1"), strain: strain)
        _ = makeCohort(tank: tank, strain: otherStrain)
        try context.save()

        let candidates = CohortOperations.mergeCandidates(for: base, in: context)
        #expect(candidates.map(\.id) == [sameStrain.id])
    }

    @Test func sampleDataCanBeSeededAndRemoved() throws {
        let ownTank = makeTank("自分の容器")
        try context.save()

        try SampleDataSeeder.seed(into: context, now: day)
        let tanks = try context.fetch(FetchDescriptor<Tank>())
        let strains = try context.fetch(FetchDescriptor<Strain>())
        let cohorts = try context.fetch(FetchDescriptor<Cohort>())
        #expect(tanks.filter(\.isSample).count == 6)
        #expect(strains.filter(\.isSample).count == 2)
        #expect(cohorts.filter(\.isSample).count == 4)

        try SampleDataSeeder.deleteSamples(in: context)
        let left = try context.fetch(FetchDescriptor<Tank>())
        #expect(left.map(\.id) == [ownTank.id])
        #expect(try context.fetch(FetchDescriptor<Cohort>()).isEmpty)
        #expect(try context.fetch(FetchDescriptor<CohortEvent>()).isEmpty)
    }
}
