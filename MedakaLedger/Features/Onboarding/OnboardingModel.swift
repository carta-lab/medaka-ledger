import Foundation
import Observation
import SwiftData

// 初回の案内の状態（SCREENS.md 1）。容器を3個、系統を1本と入手個体の群を作る。各ページは「あとで」で飛ばせる。

@MainActor
@Observable
final class OnboardingModel {
    enum Page: Int, CaseIterable {
        case intro, tanks, strain
    }

    var page: Page = .intro
    var error: UserFacingError?

    // 容器
    var tankNames: [String]
    var kind: TankKind = .nvBox
    var placement: Placement = .outdoor
    private(set) var createdTanks: [Tank] = []

    // 系統と群
    var breedName = ""
    var source = ""
    var count: Int?
    var tank: Tank?

    init(existingTankNames: [String]) {
        // 名前の初期値は A-1、A-2、A-3。既に容器があれば、最後の名前の次から（TankNaming）
        var names: [String] = []
        var previous = existingTankNames.last ?? ""
        for _ in 0..<3 {
            let next = previous.isEmpty ? "A-1" : TankNaming.nextName(after: previous)
            names.append(next)
            previous = next
        }
        tankNames = names
    }

    var trimmedTankNames: [String] {
        tankNames.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
    }

    var canSaveTanks: Bool { !trimmedTankNames.isEmpty }

    var trimmedBreedName: String { breedName.trimmingCharacters(in: .whitespacesAndNewlines) }

    var canSaveStrain: Bool { !trimmedBreedName.isEmpty }

    func next() {
        if let following = Page(rawValue: page.rawValue + 1) {
            page = following
        }
    }

    var isLastPage: Bool { page == Page.allCases.last }

    /// 入力した名前の容器を作る。作れたら true。
    func saveTanks(in context: ModelContext) -> Bool {
        do {
            var order = try nextSortOrder(in: context)
            var created: [Tank] = []
            for name in trimmedTankNames {
                let tank = Tank(name: name, kind: kind, placement: placement, sortOrder: order)
                context.insert(tank)
                created.append(tank)
                order += 1
            }
            try context.save()
            createdTanks = created
            tank = created.first
            return true
        } catch {
            context.rollback()
            self.error = UserFacingError(error)
            return false
        }
    }

    /// 系統を作り、匹数が入っていれば入手個体の群も作る。作れたら true。
    func saveStrain(in context: ModelContext, today: Date = .now) -> Bool {
        do {
            let strain = Strain(breedName: trimmedBreedName, source: source.trimmingCharacters(in: .whitespacesAndNewlines), sortOrder: try nextStrainSortOrder(in: context))
            context.insert(strain)
            if let count, count > 0 {
                CohortOperations.createCohort(
                    strain: strain, tank: tank, count: count, stage: .adult,
                    acquiredAt: today, date: today, in: context
                )
            }
            try context.save()
            return true
        } catch {
            context.rollback()
            self.error = UserFacingError(error)
            return false
        }
    }

    private func nextSortOrder(in context: ModelContext) throws -> Int {
        var descriptor = FetchDescriptor<Tank>(sortBy: [SortDescriptor(\Tank.sortOrder, order: .reverse)])
        descriptor.fetchLimit = 1
        return (try context.fetch(descriptor).first?.sortOrder ?? -1) + 1
    }

    private func nextStrainSortOrder(in context: ModelContext) throws -> Int {
        var descriptor = FetchDescriptor<Strain>(sortBy: [SortDescriptor(\Strain.sortOrder, order: .reverse)])
        descriptor.fetchLimit = 1
        return (try context.fetch(descriptor).first?.sortOrder ?? -1) + 1
    }
}
