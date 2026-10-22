import Foundation
import SwiftData
import Testing
@testable import MedakaLedger

@MainActor
struct SelectionLineageTests {
    private let container: ModelContainer
    private let context: ModelContext
    private let day = Date(timeIntervalSince1970: 1_800_000_000)

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

    private func makeCohort(strain: Strain, tank: Tank, count: Int? = 100, generation: Int = 0) -> Cohort {
        CohortOperations.createCohort(strain: strain, tank: tank, count: count, stage: .young, generation: generation, acquiredAt: day, date: day, in: context)
    }

    private func input(kept: Int, culled: Int, destination: CullDestination = .feed, tank: Tank? = nil, photos: [ProcessedPhoto] = []) -> SelectionOperations.Input {
        .init(date: day, round: 1, criteria: ["体型", "色"], kept: kept, culled: culled, destination: destination, separateTank: tank, note: "", photos: photos)
    }

    private func photo(at seconds: TimeInterval = 0) -> ProcessedPhoto {
        ProcessedPhoto(jpegData: Data([1, 2, 3]), thumbnailData: Data([1]), capturedAt: Date(timeIntervalSince1970: seconds))
    }

    // MARK: 選別

    @Test func selectionSetsCountToKeptAndRecordsTheEvent() throws {
        let cohort = makeCohort(strain: makeStrain("楊貴妃"), tank: makeTank("A-1"))
        let result = try SelectionOperations.record(for: cohort, input(kept: 60, culled: 40), in: context)
        try context.save()

        #expect(cohort.count == 60)
        #expect(result.culledCohort == nil)
        let countEvent = try #require(cohort.timeline.first)
        #expect(countEvent.kind == .countChange)
        #expect(countEvent.countDelta == -40)
        #expect(countEvent.note == "選別")
        #expect(result.selection.keptCount == 60)
        #expect(result.selection.culledCount == 40)
        #expect(result.selection.destination == .feed)
        #expect(result.selection.criteria == ["体型", "色"])
        #expect(cohort.selectionTotals.kept == 60)
        #expect(cohort.selectionTotals.culled == 40)
    }

    @Test func selectionToASeparateTankSplitsTheCulledFish() throws {
        let source = makeCohort(strain: makeStrain("楊貴妃"), tank: makeTank("A-1"))
        let spare = makeTank("B-1")
        let result = try SelectionOperations.record(for: source, input(kept: 60, culled: 40, destination: .separateTank, tank: spare), in: context)
        try context.save()

        let culled = try #require(result.culledCohort)
        #expect(source.count == 60)
        #expect(culled.count == 40)
        #expect(culled.tank?.id == spare.id)
        #expect(result.selection.culledCohortID == culled.id)
        #expect(source.timeline.first?.kind == .split)
        #expect(source.events?.filter { $0.kind == .countChange }.isEmpty == true)
    }

    @Test func selectionOnAnUncountedCohortRecountsToKept() throws {
        let cohort = makeCohort(strain: makeStrain("楊貴妃"), tank: makeTank("A-1"), count: nil)
        try SelectionOperations.record(for: cohort, input(kept: 25, culled: 10), in: context)
        #expect(cohort.count == 25)
        #expect(cohort.timeline.first?.reason == .recount)
    }

    @Test func invalidSelectionChangesNothing() throws {
        let cohort = makeCohort(strain: makeStrain("楊貴妃"), tank: makeTank("A-1"), count: 30)
        #expect(throws: SelectionOperations.OperationError.ledger(.exceedsCount(current: 30))) {
            try SelectionOperations.record(for: cohort, input(kept: 31, culled: 0), in: context)
        }
        #expect(cohort.count == 30)
        #expect(cohort.events?.count == 1)
        #expect(try context.fetch(FetchDescriptor<SelectionEvent>()).isEmpty)
    }

    @Test func separateTankMustDifferFromTheCurrentTank() throws {
        let tank = makeTank("A-1")
        let cohort = makeCohort(strain: makeStrain("楊貴妃"), tank: tank)
        #expect(throws: SelectionOperations.OperationError.ledger(.sameTank)) {
            try SelectionOperations.record(for: cohort, input(kept: 50, culled: 50, destination: .separateTank, tank: tank), in: context)
        }
        #expect(cohort.count == 100)
    }

    @Test func endedCohortCannotBeSelected() throws {
        let cohort = makeCohort(strain: makeStrain("楊貴妃"), tank: makeTank("A-1"))
        cohort.status = .soldOut
        #expect(throws: SelectionOperations.OperationError.ledger(.notActive)) {
            try SelectionOperations.record(for: cohort, input(kept: 10, culled: 5), in: context)
        }
    }

    @Test func selectionPhotosAreAttachedToTheSelection() throws {
        let cohort = makeCohort(strain: makeStrain("楊貴妃"), tank: makeTank("A-1"))
        let result = try SelectionOperations.record(for: cohort, input(kept: 60, culled: 40, photos: [photo(), photo(at: 5)]), in: context)
        try context.save()
        #expect(PhotoOwner.selection(result.selection).photos.count == 2)
    }

    @Test func totalsAddUpAcrossSelections() throws {
        let cohort = makeCohort(strain: makeStrain("楊貴妃"), tank: makeTank("A-1"))
        try SelectionOperations.record(for: cohort, input(kept: 80, culled: 20), in: context)
        try SelectionOperations.record(for: cohort, input(kept: 50, culled: 30), in: context)
        #expect(cohort.selectionTotals.kept == 130)
        #expect(cohort.selectionTotals.culled == 50)
        #expect(cohort.count == 50)
    }

    // MARK: タイムライン

    @Test func timelineMixesEventsSelectionsAndOrigin() throws {
        let strain = makeStrain("楊貴妃")
        let parent = makeCohort(strain: strain, tank: makeTank("A-1"))
        let set = try BreedingOperations.createBreedingSet(
            .init(sire: parent, dam: parent, maleCount: 1, femaleCount: 2, tank: nil, startedAt: day, name: "", note: "", movesParents: false),
            in: context
        )
        let batch = try BreedingOperations.recordEggBatch(in: set, collectedAt: day.addingTimeInterval(-86_400 * 10), eggCount: 50, container: nil, containerName: "", waterTempC: nil, note: "", context: context)
        let child = try BreedingOperations.recordHatch(
            of: batch,
            .init(hatchedAt: day.addingTimeInterval(-86_400), hatchedCount: 40, tank: makeTank("針子1"), label: "", note: "", childStrain: nil, addTo: nil),
            in: context
        )
        try SelectionOperations.record(for: child, input(kept: 30, culled: 10), in: context)

        let items = child.timelineItems
        #expect(items.count >= 4)
        guard case .origin = items.last else {
            Issue.record("採卵からの孵化が最後（最も古い）に出ていない")
            return
        }
        #expect(items.contains { if case .selection = $0 { true } else { false } })
        #expect(items.map(\.date) == items.map(\.date).sorted(by: >))
    }

    // MARK: 血統

    @Test func lineageTreeFollowsHatchedGenerations() throws {
        let strain = makeStrain("楊貴妃")
        let g0 = makeCohort(strain: strain, tank: makeTank("A-1"), count: 10)
        var parent = g0
        var latest = g0
        for _ in 1...3 {
            let set = try BreedingOperations.createBreedingSet(
                .init(sire: parent, dam: parent, maleCount: 1, femaleCount: 2, tank: nil, startedAt: day, name: "", note: "", movesParents: false),
                in: context
            )
            let batch = try BreedingOperations.recordEggBatch(in: set, collectedAt: day, eggCount: 10, container: nil, containerName: "", waterTempC: nil, note: "", context: context)
            latest = try BreedingOperations.recordHatch(
                of: batch,
                .init(hatchedAt: day, hatchedCount: 10, tank: makeTank("T\(parent.generation)"), label: "", note: "", childStrain: nil, addTo: nil),
                in: context
            )
            parent = latest
        }
        try context.save()

        #expect(latest.generation == 3)
        let free = try #require(LineageSource.tree(for: latest, maxDepth: LineageResolver.depthLimit(isPro: false)))
        #expect(free.depth == 2)
        #expect(free.hasTruncation)
        let full = try #require(LineageSource.tree(for: latest, maxDepth: LineageResolver.depthLimit(isPro: true)))
        #expect(full.depth == 3)
        #expect(!full.hasTruncation)
        #expect(full.sire?.sire?.sire?.info.id == g0.id)
        #expect(LineageSource.cohort(id: g0.id, in: latest)?.id == g0.id)
    }

    @Test func lineageOfACrossShowsBothParentStrains() throws {
        let sire = makeCohort(strain: makeStrain("楊貴妃"), tank: makeTank("A-1"), count: 10)
        let dam = makeCohort(strain: makeStrain("幹之"), tank: makeTank("A-2"), count: 10)
        let set = try BreedingOperations.createBreedingSet(
            .init(sire: sire, dam: dam, maleCount: 1, femaleCount: 2, tank: nil, startedAt: day, name: "", note: "", movesParents: false),
            in: context
        )
        let batch = try BreedingOperations.recordEggBatch(in: set, collectedAt: day, eggCount: 10, container: nil, containerName: "", waterTempC: nil, note: "", context: context)
        let child = try BreedingOperations.recordHatch(
            of: batch,
            .init(hatchedAt: day, hatchedCount: 10, tank: makeTank("針子1"), label: "", note: "", childStrain: .createNew(breedName: "楊貴妃×幹之", lineName: ""), addTo: nil),
            in: context
        )
        let tree = try #require(LineageSource.tree(for: child, maxDepth: 2))
        #expect(tree.info.strainName == "楊貴妃×幹之")
        #expect(tree.sire?.info.strainName == "楊貴妃")
        #expect(tree.dam?.info.strainName == "幹之")
    }

    // MARK: 写真

    @Test func photosAttachToEachOwnerKind() throws {
        let strain = makeStrain("楊貴妃")
        let tank = makeTank("A-1")
        let cohort = makeCohort(strain: strain, tank: tank)
        PhotoOperations.add(photo(at: 1), to: .cohort(cohort), in: context)
        PhotoOperations.add(photo(at: 2), to: .tank(tank), in: context)
        PhotoOperations.add(photo(at: 3), to: .strain(strain), in: context)
        try context.save()
        #expect(PhotoOwner.cohort(cohort).photos.count == 1)
        #expect(PhotoOwner.tank(tank).photos.count == 1)
        #expect(PhotoOwner.strain(strain).photos.count == 1)
    }

    @Test func coverIsOldestUntilOneIsMarked() throws {
        let cohort = makeCohort(strain: makeStrain("楊貴妃"), tank: makeTank("A-1"))
        let newer = PhotoOperations.add(photo(at: 200), to: .cohort(cohort), in: context)
        let older = PhotoOperations.add(photo(at: 100), to: .cohort(cohort), in: context)
        #expect(cohort.coverPhoto?.id == older.id)

        PhotoOperations.setCover(newer, among: PhotoOwner.cohort(cohort).photos)
        #expect(cohort.coverPhoto?.id == newer.id)
        #expect(older.isCover == false)

        PhotoOperations.setCover(older, among: PhotoOwner.cohort(cohort).photos)
        #expect(newer.isCover == false)
        #expect(cohort.coverPhoto?.id == older.id)
    }

    @Test func deletingAPhotoRemovesItFromTheOwner() throws {
        let cohort = makeCohort(strain: makeStrain("楊貴妃"), tank: makeTank("A-1"))
        let first = PhotoOperations.add(photo(at: 1), to: .cohort(cohort), in: context)
        PhotoOperations.add(photo(at: 2), to: .cohort(cohort), in: context)
        try context.save()
        PhotoOperations.delete(first, in: context)
        try context.save()
        #expect(PhotoOwner.cohort(cohort).photos.count == 1)
    }

    @Test func strainCoverFallsBackToTheOldestCohortCover() throws {
        let strain = makeStrain("楊貴妃")
        let cohort = makeCohort(strain: strain, tank: makeTank("A-1"))
        let cohortPhoto = PhotoOperations.add(photo(at: 50), to: .cohort(cohort), in: context)
        #expect(strain.coverPhoto?.id == cohortPhoto.id)
        let own = PhotoOperations.add(photo(at: 90), to: .strain(strain), in: context)
        #expect(strain.coverPhoto?.id == own.id)
    }

    @Test func deletingACohortDeletesItsPhotosAndSelections() throws {
        let cohort = makeCohort(strain: makeStrain("楊貴妃"), tank: makeTank("A-1"))
        PhotoOperations.add(photo(), to: .cohort(cohort), in: context)
        try SelectionOperations.record(for: cohort, input(kept: 50, culled: 50, photos: [photo()]), in: context)
        try context.save()
        try CohortOperations.deleteCohort(cohort, in: context)
        try context.save()
        #expect(try context.fetch(FetchDescriptor<Photo>()).isEmpty)
        #expect(try context.fetch(FetchDescriptor<SelectionEvent>()).isEmpty)
    }
}
