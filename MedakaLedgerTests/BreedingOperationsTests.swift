import Foundation
import SwiftData
import Testing
@testable import MedakaLedger

@MainActor
struct BreedingOperationsTests {
    private let container: ModelContainer
    private let context: ModelContext
    private let day = Date(timeIntervalSince1970: 1_800_000_000)
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Tokyo") ?? .current
        return calendar
    }

    init() throws {
        container = try ModelStore.makeContainer(inMemory: true)
        context = container.mainContext
    }

    private func makeTank(_ name: String) -> Tank {
        let tank = Tank(name: name, kind: .nvBox)
        context.insert(tank)
        return tank
    }

    private func makeStrain(_ breed: String) -> Strain {
        let strain = Strain(breedName: breed)
        context.insert(strain)
        return strain
    }

    private func makeCohort(strain: Strain, tank: Tank, count: Int? = 10, generation: Int = 0) -> Cohort {
        CohortOperations.createCohort(
            strain: strain, tank: tank, count: count, stage: .adult, generation: generation,
            acquiredAt: day, date: day, in: context
        )
    }

    private func makeSet(sire: Cohort, dam: Cohort, tank: Tank? = nil, movesParents: Bool = false) throws -> BreedingSet {
        try BreedingOperations.createBreedingSet(
            .init(sire: sire, dam: dam, maleCount: 1, femaleCount: 2, tank: tank, startedAt: day, name: "", note: "", movesParents: movesParents),
            in: context
        )
    }

    private func hatchInput(tank: Tank, count: Int? = 40, childStrain: BreedingOperations.ChildStrainChoice? = nil, addTo: Cohort? = nil) -> BreedingOperations.HatchInput {
        .init(hatchedAt: day, hatchedCount: count, tank: tank, label: "", note: "", childStrain: childStrain, addTo: addTo)
    }

    private func recordBatch(_ set: BreedingSet, container tank: Tank? = nil) throws -> EggBatch {
        try BreedingOperations.recordEggBatch(
            in: set, collectedAt: day, eggCount: 50, container: tank, containerName: "", waterTempC: nil, note: "", context: context
        )
    }

    // MARK: 親魚セット

    @Test func sameStrainSetDecidesOffspringStrainAtCreation() throws {
        let strain = makeStrain("楊貴妃")
        let cohort = makeCohort(strain: strain, tank: makeTank("A-1"))
        let set = try makeSet(sire: cohort, dam: cohort)
        #expect(set.offspringStrain?.id == strain.id)
        #expect(set.isActive)
    }

    @Test func crossLeavesOffspringStrainEmpty() throws {
        let sire = makeCohort(strain: makeStrain("楊貴妃"), tank: makeTank("A-1"))
        let dam = makeCohort(strain: makeStrain("幹之"), tank: makeTank("A-2"))
        let set = try makeSet(sire: sire, dam: dam)
        #expect(set.offspringStrain == nil)
        #expect(BreedingOperations.defaultChildBreedName(sire: sire, dam: dam) == "楊貴妃×幹之")
    }

    @Test func movingParentsToSetTankLeavesMoveEvents() throws {
        let strain = makeStrain("楊貴妃")
        let sire = makeCohort(strain: strain, tank: makeTank("A-1"))
        let dam = makeCohort(strain: strain, tank: makeTank("A-2"))
        let target = makeTank("B-1")
        let set = try makeSet(sire: sire, dam: dam, tank: target, movesParents: true)
        #expect(sire.tank?.id == target.id)
        #expect(dam.tank?.id == target.id)
        #expect(sire.timeline.first?.kind == .move)
        #expect(set.tank?.id == target.id)
    }

    @Test func notMovingParentsKeepsTheirTanks() throws {
        let strain = makeStrain("楊貴妃")
        let tankA = makeTank("A-1")
        let cohort = makeCohort(strain: strain, tank: tankA)
        _ = try makeSet(sire: cohort, dam: cohort, tank: makeTank("B-1"), movesParents: false)
        #expect(cohort.tank?.id == tankA.id)
        #expect(cohort.events?.count == 1)
    }

    @Test func sameCohortAsSireAndDamIsMovedOnce() throws {
        let cohort = makeCohort(strain: makeStrain("楊貴妃"), tank: makeTank("A-1"))
        _ = try makeSet(sire: cohort, dam: cohort, tank: makeTank("B-1"), movesParents: true)
        #expect(cohort.events?.filter { $0.kind == .move }.count == 1)
    }

    @Test func inactiveParentOrEmptyCountsAreRejected() throws {
        let strain = makeStrain("楊貴妃")
        let cohort = makeCohort(strain: strain, tank: makeTank("A-1"))
        let ended = makeCohort(strain: strain, tank: makeTank("A-2"))
        ended.status = .lost
        #expect(throws: BreedingOperations.OperationError.parentNotActive) {
            try makeSet(sire: ended, dam: cohort)
        }
        #expect(throws: BreedingOperations.OperationError.invalidCount) {
            try BreedingOperations.createBreedingSet(
                .init(sire: cohort, dam: cohort, maleCount: 0, femaleCount: 0, tank: nil, startedAt: day, name: "", note: "", movesParents: false),
                in: context
            )
        }
    }

    // MARK: 採卵

    @Test func eggBatchIsIncubatingAndEndedSetRejectsMore() throws {
        let cohort = makeCohort(strain: makeStrain("楊貴妃"), tank: makeTank("A-1"))
        let set = try makeSet(sire: cohort, dam: cohort)
        let batch = try recordBatch(set)
        #expect(batch.status == .incubating)
        #expect(set.incubatingBatches.count == 1)

        BreedingOperations.end(set, on: day)
        #expect(!set.isActive)
        #expect(throws: BreedingOperations.OperationError.setEnded) {
            try recordBatch(set)
        }
    }

    // MARK: 孵化

    @Test func hatchFromSameStrainIncrementsMaxGeneration() throws {
        let strain = makeStrain("楊貴妃")
        let sire = makeCohort(strain: strain, tank: makeTank("A-1"), generation: 1)
        let dam = makeCohort(strain: strain, tank: makeTank("A-2"), generation: 2)
        let set = try makeSet(sire: sire, dam: dam)
        let batch = try recordBatch(set)
        let nursery = makeTank("針子1")

        let child = try BreedingOperations.recordHatch(of: batch, hatchInput(tank: nursery), in: context)
        try context.save()
        #expect(child.generation == 3)
        #expect(child.strain?.id == strain.id)
        #expect(child.stage == .hatchling)
        #expect(child.count == 40)
        #expect(child.tank?.id == nursery.id)
        #expect(child.hatchedAt == day)
        #expect(child.originBatch?.id == batch.id)
        #expect(child.timeline.first?.kind == .created)
        #expect(batch.status == .hatched)
        #expect(batch.hatchedCount == 40)
    }

    @Test func crossHatchNeedsStrainChoiceThenCreatesNewStrainAtF1() throws {
        let sire = makeCohort(strain: makeStrain("楊貴妃"), tank: makeTank("A-1"), generation: 3)
        let dam = makeCohort(strain: makeStrain("幹之"), tank: makeTank("A-2"), generation: 2)
        let set = try makeSet(sire: sire, dam: dam)
        let batch = try recordBatch(set)
        let nursery = makeTank("針子1")

        #expect(throws: BreedingOperations.OperationError.childStrainRequired) {
            try BreedingOperations.recordHatch(of: batch, hatchInput(tank: nursery), in: context)
        }
        #expect(batch.status == .incubating)

        let child = try BreedingOperations.recordHatch(
            of: batch,
            hatchInput(tank: nursery, childStrain: .createNew(breedName: "楊貴妃×幹之", lineName: "")),
            in: context
        )
        try context.save()
        #expect(child.generation == 1)
        #expect(child.strain?.breedName == "楊貴妃×幹之")
        #expect(set.offspringStrain?.id == child.strain?.id)
        let strains = try context.fetch(FetchDescriptor<Strain>())
        #expect(strains.count == 3)
    }

    @Test func crossHatchCanPickAnExistingStrain() throws {
        let sire = makeCohort(strain: makeStrain("楊貴妃"), tank: makeTank("A-1"))
        let dam = makeCohort(strain: makeStrain("幹之"), tank: makeTank("A-2"))
        let existing = makeStrain("既存の交配")
        let set = try makeSet(sire: sire, dam: dam)
        let batch = try recordBatch(set)
        let child = try BreedingOperations.recordHatch(of: batch, hatchInput(tank: makeTank("針子1"), childStrain: .existing(existing)), in: context)
        #expect(child.strain?.id == existing.id)
        #expect(try context.fetch(FetchDescriptor<Strain>()).count == 3)
    }

    @Test func secondHatchCanCreateNewCohortOrAddToExisting() throws {
        let cohort = makeCohort(strain: makeStrain("楊貴妃"), tank: makeTank("A-1"))
        let set = try makeSet(sire: cohort, dam: cohort)
        let batch = try recordBatch(set)
        let nursery = makeTank("針子1")

        let first = try BreedingOperations.recordHatch(of: batch, hatchInput(tank: nursery, count: 20), in: context)
        let second = try BreedingOperations.recordHatch(of: batch, hatchInput(tank: nursery, count: 15), in: context)
        #expect(first.id != second.id)

        let added = try BreedingOperations.recordHatch(of: batch, hatchInput(tank: nursery, count: 5, addTo: first), in: context)
        try context.save()
        #expect(added.id == first.id)
        #expect(first.count == 25)
        #expect(first.timeline.first?.kind == .countChange)
        #expect(batch.hatchedCount == 40)
        #expect(batch.resultCohorts?.count == 2)
    }

    @Test func addingToACohortFromAnotherBatchIsRejected() throws {
        let cohort = makeCohort(strain: makeStrain("楊貴妃"), tank: makeTank("A-1"))
        let set = try makeSet(sire: cohort, dam: cohort)
        let batch = try recordBatch(set)
        #expect(throws: BreedingOperations.OperationError.targetCohortNotFromBatch) {
            try BreedingOperations.recordHatch(of: batch, hatchInput(tank: makeTank("針子1"), addTo: cohort), in: context)
        }
    }

    @Test func newCohortNeedsATank() throws {
        let cohort = makeCohort(strain: makeStrain("楊貴妃"), tank: makeTank("A-1"))
        let batch = try recordBatch(try makeSet(sire: cohort, dam: cohort))
        let input = BreedingOperations.HatchInput(hatchedAt: day, hatchedCount: 5, tank: nil, label: "", note: "", childStrain: nil, addTo: nil)
        #expect(throws: BreedingOperations.OperationError.tankRequired) {
            try BreedingOperations.recordHatch(of: batch, input, in: context)
        }
    }

    @Test func discardedBatchCannotHatch() throws {
        let cohort = makeCohort(strain: makeStrain("楊貴妃"), tank: makeTank("A-1"))
        let set = try makeSet(sire: cohort, dam: cohort)
        let batch = try recordBatch(set)
        BreedingOperations.discard(batch)
        #expect(batch.status == .discarded)
        #expect(throws: BreedingOperations.OperationError.batchDiscarded) {
            try BreedingOperations.recordHatch(of: batch, hatchInput(tank: makeTank("針子1")), in: context)
        }
    }

    @Test func hatchedCohortCanBeMergedWithSiblingFromSameSet() throws {
        let cohort = makeCohort(strain: makeStrain("楊貴妃"), tank: makeTank("A-1"))
        let set = try makeSet(sire: cohort, dam: cohort)
        let first = try BreedingOperations.recordHatch(of: try recordBatch(set), hatchInput(tank: makeTank("針子1"), count: 20), in: context)
        let second = try BreedingOperations.recordHatch(of: try recordBatch(set), hatchInput(tank: makeTank("針子2"), count: 10), in: context)
        try CohortOperations.merge(second, into: first, date: day, in: context)
        #expect(first.count == 30)
    }

    // MARK: 孵化予定日

    @Test func predictionUsesContainerTemperatureLogs() throws {
        let cohort = makeCohort(strain: makeStrain("楊貴妃"), tank: makeTank("A-1"))
        let set = try makeSet(sire: cohort, dam: cohort)
        let cup = makeTank("カップ")
        let batch = try recordBatch(set, container: cup)
        let settings = BreedingOperations.HatchSettings(degreeDaysToHatch: 250, defaultWaterTempC: 25)

        let plain = try #require(BreedingOperations.prediction(for: batch, settings: settings, calendar: calendar))
        #expect(HatchPredictor.daysRemaining(until: plain, today: day, calendar: calendar) == 10)

        // 採卵日から5日間30℃の記録があれば、150 + 25×4 = 250 で9日目に積算が届く
        for offset in 0..<5 {
            let log = MaintenanceLog()
            log.kind = .temperature
            log.waterTempC = 30
            log.date = calendar.date(byAdding: .day, value: offset, to: day) ?? day
            context.insert(log)
            log.tank = cup
        }
        let warmer = try #require(BreedingOperations.prediction(for: batch, settings: settings, calendar: calendar))
        #expect(HatchPredictor.daysRemaining(until: warmer, today: day, calendar: calendar) == 9)
    }

    // MARK: 作業記録

    @Test func maintenanceRecordsOneLogPerTank() throws {
        let tanks = [makeTank("A-1"), makeTank("A-2"), makeTank("A-3")]
        let logs = try MaintenanceOperations.record(on: tanks, kind: .waterChange, date: day, percent: 50, waterTempC: nil, note: "", in: context)
        try context.save()
        #expect(logs.count == 3)
        #expect(tanks.allSatisfy { $0.lastWaterChange == day })
        #expect(tanks.allSatisfy { $0.recentLogs.first?.percent == 50 })
    }

    @Test func maintenanceValidation() throws {
        let tank = makeTank("A-1")
        #expect(throws: MaintenanceOperations.OperationError.noTank) {
            try MaintenanceOperations.record(on: [], kind: .cleaning, date: day, percent: nil, waterTempC: nil, note: "", in: context)
        }
        #expect(throws: MaintenanceOperations.OperationError.temperatureRequired) {
            try MaintenanceOperations.record(on: [tank], kind: .temperature, date: day, percent: nil, waterTempC: nil, note: "", in: context)
        }
        #expect(throws: MaintenanceOperations.OperationError.invalidPercent) {
            try MaintenanceOperations.record(on: [tank], kind: .waterChange, date: day, percent: 120, waterTempC: nil, note: "", in: context)
        }
    }

    @Test func lastWaterChangeIgnoresOtherKindsAndTakesLatest() throws {
        let tank = makeTank("A-1")
        let older = day.addingTimeInterval(-86_400 * 10)
        try MaintenanceOperations.record(on: [tank], kind: .waterChange, date: older, percent: 30, waterTempC: nil, note: "", in: context)
        try MaintenanceOperations.record(on: [tank], kind: .topUp, date: day, percent: nil, waterTempC: nil, note: "", in: context)
        #expect(tank.lastWaterChange == older)
        try MaintenanceOperations.record(on: [tank], kind: .waterChange, date: day, percent: 50, waterTempC: nil, note: "", in: context)
        #expect(tank.lastWaterChange == day)
    }
}
