import Foundation
import SwiftData

// サンプルデータv0（ROADMAP.md 11/7、DECISIONS.md E、H）。容器6、系統2、群4。全て isSample = true。
// サンプルはFreeの上限に数えず、「サンプルを全削除」でまとめて消す。

enum SampleDataSeeder {
    static func seed(into context: ModelContext, now: Date = .now, calendar: Calendar = .current) throws {
        func daysAgo(_ days: Int) -> Date {
            calendar.date(byAdding: .day, value: -days, to: now) ?? now
        }

        let order = try nextSortOrder(in: context)
        let tanks = [
            Tank(name: "A-1", kind: .nvBox, capacityLiters: 22, placement: .outdoor, location: "棚A", sortOrder: order, isSample: true),
            Tank(name: "A-2", kind: .nvBox, capacityLiters: 22, placement: .outdoor, location: "棚A", sortOrder: order + 1, isSample: true),
            Tank(name: "A-3", kind: .nvBox, capacityLiters: 13, placement: .outdoor, location: "棚A", sortOrder: order + 2, isSample: true),
            Tank(name: "B-1", kind: .toroBune, capacityLiters: 60, placement: .outdoor, location: "棚B", sortOrder: order + 3, isSample: true),
            Tank(name: "B-2", kind: .styrofoam, placement: .outdoor, location: "棚B", sortOrder: order + 4, isSample: true),
            Tank(name: "室内1", kind: .aquarium, capacityLiters: 30, placement: .indoor, location: "室内ラック", sortOrder: order + 5, isSample: true),
        ]
        for tank in tanks {
            context.insert(tank)
        }

        let strainOrder = try nextStrainSortOrder(in: context)
        let yokihi = Strain(
            breedName: "楊貴妃",
            lineName: "〇〇めだか春購入",
            source: "〇〇めだか",
            acquiredAt: daysAgo(200),
            traitTags: ["朱赤"],
            note: "サンプルの系統です。",
            sortOrder: strainOrder,
            isSample: true
        )
        let miyuki = Strain(
            breedName: "幹之",
            lineName: "光体型",
            source: "即売会",
            acquiredAt: daysAgo(150),
            traitTags: ["体外光", "ヒカリ体型"],
            note: "サンプルの系統です。",
            sortOrder: strainOrder + 1,
            isSample: true
        )
        context.insert(yokihi)
        context.insert(miyuki)

        let yokihiAdults = CohortOperations.createCohort(
            strain: yokihi, tank: tanks[0], count: 12, stage: .adult,
            acquiredAt: daysAgo(200), label: "親魚候補", date: daysAgo(200), isSample: true, in: context
        )
        try CohortOperations.changeCount(yokihiAdults, change: .decrease(1, reason: .death), date: daysAgo(120), in: context)
        _ = try CohortOperations.split(yokihiAdults, amount: 4, to: tanks[1], label: "選抜", date: daysAgo(90), in: context)

        let miyukiAdults = CohortOperations.createCohort(
            strain: miyuki, tank: tanks[3], count: nil, stage: .young,
            acquiredAt: daysAgo(150), label: "", date: daysAgo(150), isSample: true, in: context
        )
        try CohortOperations.changeCount(miyukiAdults, change: .recount(30), date: daysAgo(60), in: context)
        _ = try CohortOperations.split(miyukiAdults, amount: 10, to: tanks[5], label: "越冬用", date: daysAgo(30), in: context)
        try CohortOperations.changeStage(miyukiAdults, to: .adult, date: daysAgo(10), in: context)

        try context.save()
    }

    static func deleteSamples(in context: ModelContext) throws {
        try deleteAll(Photo.self, where: #Predicate<Photo> { $0.isSample == true }, in: context)
        try deleteAll(CohortEvent.self, where: #Predicate<CohortEvent> { $0.isSample == true }, in: context)
        try deleteAll(SelectionEvent.self, where: #Predicate<SelectionEvent> { $0.isSample == true }, in: context)
        try deleteAll(Sale.self, where: #Predicate<Sale> { $0.isSample == true }, in: context)
        try deleteAll(MaintenanceLog.self, where: #Predicate<MaintenanceLog> { $0.isSample == true }, in: context)
        try deleteAll(EggBatch.self, where: #Predicate<EggBatch> { $0.isSample == true }, in: context)
        try deleteAll(BreedingSet.self, where: #Predicate<BreedingSet> { $0.isSample == true }, in: context)
        try deleteAll(Cohort.self, where: #Predicate<Cohort> { $0.isSample == true }, in: context)
        try deleteAll(Strain.self, where: #Predicate<Strain> { $0.isSample == true }, in: context)
        try deleteAll(Tank.self, where: #Predicate<Tank> { $0.isSample == true }, in: context)
        try context.save()
    }

    static func deleteEverything(in context: ModelContext) throws {
        try deleteAll(Photo.self, where: nil, in: context)
        try deleteAll(CohortEvent.self, where: nil, in: context)
        try deleteAll(SelectionEvent.self, where: nil, in: context)
        try deleteAll(Sale.self, where: nil, in: context)
        try deleteAll(MaintenanceLog.self, where: nil, in: context)
        try deleteAll(EggBatch.self, where: nil, in: context)
        try deleteAll(BreedingSet.self, where: nil, in: context)
        try deleteAll(Cohort.self, where: nil, in: context)
        try deleteAll(Strain.self, where: nil, in: context)
        try deleteAll(Tank.self, where: nil, in: context)
        try context.save()
    }

    // MARK: - Private

    private static func deleteAll<T: PersistentModel>(_ type: T.Type, where predicate: Predicate<T>?, in context: ModelContext) throws {
        for model in try context.fetch(FetchDescriptor<T>(predicate: predicate)) {
            context.delete(model)
        }
    }

    private static func nextSortOrder(in context: ModelContext) throws -> Int {
        var descriptor = FetchDescriptor<Tank>(sortBy: [SortDescriptor(\Tank.sortOrder, order: .reverse)])
        descriptor.fetchLimit = 1
        return (try context.fetch(descriptor).first?.sortOrder ?? -1) + 1
    }

    private static func nextStrainSortOrder(in context: ModelContext) throws -> Int {
        var descriptor = FetchDescriptor<Strain>(sortBy: [SortDescriptor(\Strain.sortOrder, order: .reverse)])
        descriptor.fetchLimit = 1
        return (try context.fetch(descriptor).first?.sortOrder ?? -1) + 1
    }
}

/// サンプルの投入と削除をメインスレッドの外で行う（CLAUDE.md、DECISIONS.md G 3-2）。
/// Task.detached の中で生成して使う。
@ModelActor
actor SampleDataActor {
    func seed() throws {
        try SampleDataSeeder.seed(into: modelContext)
    }

    func deleteSamples() throws {
        try SampleDataSeeder.deleteSamples(in: modelContext)
    }

    func deleteEverything() throws {
        try SampleDataSeeder.deleteEverything(in: modelContext)
    }
}
