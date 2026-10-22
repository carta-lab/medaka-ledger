import Foundation
import Testing
@testable import MedakaLedger

struct LineageResolverTests {
    private func info(_ id: UUID, _ name: String, generation: Int, sire: UUID? = nil, dam: UUID? = nil) -> LineageCohortInfo {
        LineageCohortInfo(id: id, strainName: name, generation: generation, hatchedAt: nil, sireID: sire, damID: dam)
    }

    private func lookup(_ infos: [LineageCohortInfo]) -> (UUID) -> LineageCohortInfo? {
        let table = Dictionary(uniqueKeysWithValues: infos.map { ($0.id, $0) })
        return { table[$0] }
    }

    @Test func acquiredCohortStopsAtItself() throws {
        let a = UUID()
        let node = try #require(LineageResolver.resolve(root: a, maxDepth: 5, lookup: lookup([info(a, "楊貴妃", generation: 0)])))
        #expect(node.sire == nil && node.dam == nil)
        #expect(!node.isTruncated)
        #expect(node.depth == 0)
    }

    @Test func threeGenerationsOfOneStrain() throws {
        let g0 = UUID(), g1 = UUID(), g2 = UUID()
        let infos = [
            info(g0, "楊貴妃", generation: 0),
            info(g1, "楊貴妃", generation: 1, sire: g0, dam: g0),
            info(g2, "楊貴妃", generation: 2, sire: g1, dam: g1),
        ]
        let node = try #require(LineageResolver.resolve(root: g2, maxDepth: 20, lookup: lookup(infos)))
        #expect(node.depth == 2)
        // 同じ群を雄と雌に使っても、両側に表示する
        #expect(node.sire?.info.id == g1)
        #expect(node.dam?.info.id == g1)
        #expect(node.sire?.sire?.info.id == g0)
        #expect(node.dam?.dam?.info.id == g0)
        #expect(!node.hasTruncation)
    }

    @Test func crossChangesStrainNameAtTheNode() throws {
        let a = UUID(), b = UUID(), child = UUID()
        let infos = [
            info(a, "楊貴妃", generation: 3),
            info(b, "幹之", generation: 2),
            info(child, "楊貴妃×幹之", generation: 1, sire: a, dam: b),
        ]
        let node = try #require(LineageResolver.resolve(root: child, maxDepth: 20, lookup: lookup(infos)))
        #expect(node.info.strainName == "楊貴妃×幹之")
        #expect(node.sire?.info.strainName == "楊貴妃")
        #expect(node.dam?.info.strainName == "幹之")
    }

    @Test func freeDepthLimitTruncatesAndMarksIt() throws {
        let ids = (0..<5).map { _ in UUID() }
        var infos = [info(ids[0], "A", generation: 0)]
        for index in 1..<5 {
            infos.append(info(ids[index], "A", generation: index, sire: ids[index - 1], dam: ids[index - 1]))
        }
        let node = try #require(LineageResolver.resolve(root: ids[4], maxDepth: FreeLimits.lineageDepth, lookup: lookup(infos)))
        #expect(node.depth == 2)
        #expect(node.sire?.sire?.isTruncated == true)
        #expect(node.hasTruncation)
        #expect(node.sire?.sire?.sire == nil)

        let full = try #require(LineageResolver.resolve(root: ids[4], maxDepth: LineageResolver.depthLimit(isPro: true), lookup: lookup(infos)))
        #expect(full.depth == 4)
        #expect(!full.hasTruncation)
    }

    @Test func depthLimitByPlan() {
        #expect(LineageResolver.depthLimit(isPro: false) == 2)
        #expect(LineageResolver.depthLimit(isPro: true) == LineageResolver.absoluteMaxDepth)
    }

    @Test func cycleIsCutOnThePathOnly() throws {
        let a = UUID(), b = UUID()
        // a の親が b、b の親が a（壊れたデータ）
        let infos = [info(a, "A", generation: 1, sire: b, dam: b), info(b, "B", generation: 1, sire: a, dam: a)]
        let node = try #require(LineageResolver.resolve(root: a, maxDepth: 20, lookup: lookup(infos)))
        #expect(node.sire?.info.id == b)
        #expect(node.sire?.sire?.isCycle == true)
        #expect(node.depth == 2)
    }

    @Test func missingParentIsLeftOut() throws {
        let child = UUID(), gone = UUID()
        let node = try #require(LineageResolver.resolve(root: child, maxDepth: 5, lookup: lookup([info(child, "A", generation: 1, sire: gone, dam: gone)])))
        #expect(node.sire == nil && node.dam == nil)
    }

    @Test func unknownRootGivesNil() {
        #expect(LineageResolver.resolve(root: UUID(), maxDepth: 5, lookup: lookup([])) == nil)
    }
}

struct SelectionPlannerTests {
    private let tank = TankRef(id: UUID(), name: "B-1")

    @Test func keptBelowCurrentAdjustsDown() throws {
        let plan = try SelectionPlanner.plan(currentCount: 100, kept: 60, culled: 40, destination: .feed, separateTank: nil)
        #expect(plan.split == nil)
        #expect(plan.adjustment == .adjust(-40))
    }

    @Test func keptEqualToCurrentNeedsNoAdjustment() throws {
        let plan = try SelectionPlanner.plan(currentCount: 30, kept: 30, culled: 5, destination: .dispose, separateTank: nil)
        #expect(plan.adjustment == nil)
    }

    @Test func keptAboveCurrentIsRejected() {
        #expect(throws: LedgerError.exceedsCount(current: 30)) {
            try SelectionPlanner.plan(currentCount: 30, kept: 31, culled: 0, destination: .feed, separateTank: nil)
        }
    }

    @Test func uncountedCohortIsRecountedToKept() throws {
        let plan = try SelectionPlanner.plan(currentCount: nil, kept: 25, culled: 10, destination: .cheapSale, separateTank: nil)
        #expect(plan.adjustment == .recount(25))
    }

    @Test func separateTankSplitsTheCulledAndMatchesKept() throws {
        let plan = try SelectionPlanner.plan(currentCount: 100, kept: 60, culled: 40, destination: .separateTank, separateTank: tank)
        #expect(plan.split?.amount == 40)
        #expect(plan.split?.tank == tank)
        #expect(plan.adjustment == nil)
    }

    @Test func separateTankWithDifferentCountsAdjustsTheRemainder() throws {
        // 100匹から40匹を分けると60匹。数えたら残しは58匹
        let plan = try SelectionPlanner.plan(currentCount: 100, kept: 58, culled: 40, destination: .separateTank, separateTank: tank)
        #expect(plan.split?.amount == 40)
        #expect(plan.adjustment == .adjust(-2))
    }

    @Test func separateTankNeedsATankAndCulledFish() {
        #expect(throws: LedgerError.invalidAmount) {
            try SelectionPlanner.plan(currentCount: 100, kept: 60, culled: 40, destination: .separateTank, separateTank: nil)
        }
        #expect(throws: LedgerError.invalidAmount) {
            try SelectionPlanner.plan(currentCount: 100, kept: 60, culled: 0, destination: .separateTank, separateTank: tank)
        }
    }

    @Test func culledMoreThanCurrentIsRejectedForSplit() {
        #expect(throws: LedgerError.exceedsCount(current: 30)) {
            try SelectionPlanner.plan(currentCount: 30, kept: 5, culled: 31, destination: .separateTank, separateTank: tank)
        }
    }

    @Test func separateTankOnUncountedCohortRecountsTheRemainder() throws {
        let plan = try SelectionPlanner.plan(currentCount: nil, kept: 20, culled: 30, destination: .separateTank, separateTank: tank)
        #expect(plan.split?.amount == 30)
        #expect(plan.adjustment == .recount(20))
    }

    @Test func emptyInputIsRejected() {
        #expect(throws: LedgerError.invalidAmount) {
            try SelectionPlanner.plan(currentCount: 10, kept: 0, culled: 0, destination: .feed, separateTank: nil)
        }
        #expect(throws: LedgerError.invalidAmount) {
            try SelectionPlanner.plan(currentCount: 10, kept: -1, culled: 3, destination: .feed, separateTank: nil)
        }
    }

    @Test func suggestedRoundAdvancesThenFallsBackToOther() {
        #expect(SelectionPlanner.suggestedRound(existingRounds: []) == 1)
        #expect(SelectionPlanner.suggestedRound(existingRounds: [1]) == 2)
        #expect(SelectionPlanner.suggestedRound(existingRounds: [1, 2, 0]) == 3)
        #expect(SelectionPlanner.suggestedRound(existingRounds: [1, 2, 3]) == SelectionPlanner.otherRound)
        #expect(SelectionPlanner.suggestedRound(existingRounds: [0, 0]) == 1)
    }
}

struct PhotoRulesTests {
    @Test func largeImagesAreScaledToTheLongSide() {
        let landscape = PhotoRules.fittedSize(width: 4032, height: 3024, maxLongSide: 1600)
        #expect(landscape.width == 1600)
        #expect(landscape.height == 1200)
        let portrait = PhotoRules.fittedSize(width: 3024, height: 4032, maxLongSide: 1600)
        #expect(portrait.width == 1200)
        #expect(portrait.height == 1600)
    }

    @Test func smallImagesAreNotEnlarged() {
        let size = PhotoRules.fittedSize(width: 800, height: 600, maxLongSide: 1600)
        #expect(size.width == 800 && size.height == 600)
        let exact = PhotoRules.fittedSize(width: 1600, height: 900, maxLongSide: 1600)
        #expect(exact.width == 1600 && exact.height == 900)
    }

    @Test func extremeAspectRatioKeepsAtLeastOnePixel() {
        let size = PhotoRules.fittedSize(width: 10_000, height: 1, maxLongSide: 1600)
        #expect(size.width == 1600)
        #expect(size.height == 1)
    }

    @Test func coverIsTheMarkedPhotoElseTheOldest() {
        let old = (id: UUID(), capturedAt: Date(timeIntervalSince1970: 100), isCover: false)
        let new = (id: UUID(), capturedAt: Date(timeIntervalSince1970: 200), isCover: false)
        #expect(PhotoRules.coverID(of: [new, old]) == old.id)
        let marked = (id: UUID(), capturedAt: Date(timeIntervalSince1970: 300), isCover: true)
        #expect(PhotoRules.coverID(of: [old, new, marked]) == marked.id)
        #expect(PhotoRules.coverID(of: []) == nil)
    }

    @Test func qualitiesAreTriedFromBestToWorst() {
        #expect(PhotoRules.jpegQualities == PhotoRules.jpegQualities.sorted(by: >))
        #expect(PhotoRules.byteBudget == 512_000)
    }
}
