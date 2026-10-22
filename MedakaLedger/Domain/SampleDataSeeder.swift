import Foundation
import SwiftData

// サンプルデータ（ROADMAP.md 11/7、DECISIONS.md E、H）。容器6、系統2、群7（入手、分割、F1、F2）に、親魚セット3、採卵ロット4、選別3、作業記録4。全て isSample = true。
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
        _ = try SelectionOperations.record(
            for: miyukiAdults,
            .init(date: daysAgo(5), round: 3, criteria: ["体外光"], kept: 18, culled: 2, destination: .separateTank, separateTank: tanks[4], note: "光の強い個体を残した"),
            in: context
        )

        // 繁殖（第2週）：楊貴妃の親魚セットと、育卵中の採卵ロット2件
        let breedingSet = try BreedingOperations.createBreedingSet(
            .init(
                sire: yokihiAdults, dam: yokihiAdults, maleCount: 2, femaleCount: 4,
                tank: tanks[0], startedAt: daysAgo(40), name: "", note: "", movesParents: false
            ),
            in: context
        )
        for (offset, eggs) in [(3, 40), (9, 60)] {
            _ = try BreedingOperations.recordEggBatch(
                in: breedingSet, collectedAt: daysAgo(offset), eggCount: eggs,
                container: tanks[2], containerName: "", waterTempC: nil, note: "", context: context
            )
        }

        // 累代（第3週）：入手→F1→F2。血統図と選別の累計の確認用
        let f1Set = try BreedingOperations.createBreedingSet(
            .init(
                sire: yokihiAdults, dam: yokihiAdults, maleCount: 2, femaleCount: 4,
                tank: nil, startedAt: daysAgo(150), name: "", note: "", movesParents: false
            ),
            in: context
        )
        let f1Batch = try BreedingOperations.recordEggBatch(
            in: f1Set, collectedAt: daysAgo(120), eggCount: 80,
            container: nil, containerName: "採卵カップ", waterTempC: 24, note: "", context: context
        )
        let f1 = try BreedingOperations.recordHatch(
            of: f1Batch,
            .init(hatchedAt: daysAgo(110), hatchedCount: 60, tank: tanks[4], label: "春1番", note: "", childStrain: nil, addTo: nil),
            in: context
        )
        BreedingOperations.end(f1Set, on: daysAgo(100))
        try CohortOperations.changeStage(f1, to: .adult, date: daysAgo(40), in: context)
        _ = try SelectionOperations.record(
            for: f1,
            .init(date: daysAgo(80), round: 1, criteria: ["体型", "色"], kept: 45, culled: 15, destination: .feed, separateTank: nil, note: "奇形を弾いた"),
            in: context
        )
        let f2Set = try BreedingOperations.createBreedingSet(
            .init(sire: f1, dam: f1, maleCount: 1, femaleCount: 2, tank: nil, startedAt: daysAgo(70), name: "", note: "", movesParents: false),
            in: context
        )
        let f2Batch = try BreedingOperations.recordEggBatch(
            in: f2Set, collectedAt: daysAgo(60), eggCount: 50,
            container: nil, containerName: "採卵カップ", waterTempC: 25, note: "", context: context
        )
        let f2 = try BreedingOperations.recordHatch(
            of: f2Batch,
            .init(hatchedAt: daysAgo(50), hatchedCount: 40, tank: tanks[2], label: "", note: "", childStrain: nil, addTo: nil),
            in: context
        )
        _ = try SelectionOperations.record(
            for: f2,
            .init(date: daysAgo(20), round: 2, criteria: ["ラメ"], kept: 28, culled: 12, destination: .cheapSale, separateTank: nil, note: ""),
            in: context
        )

        // 作業記録：A-1とA-2は20日前、B-1は60日前の水換え。A-3に水温
        try MaintenanceOperations.record(on: [tanks[0], tanks[1]], kind: .waterChange, date: daysAgo(20), percent: 50, waterTempC: nil, note: "", in: context)
        try MaintenanceOperations.record(on: [tanks[3]], kind: .waterChange, date: daysAgo(60), percent: 30, waterTempC: nil, note: "", in: context)
        try MaintenanceOperations.record(on: [tanks[2]], kind: .temperature, date: daysAgo(2), percent: nil, waterTempC: 24, note: "", in: context)

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
