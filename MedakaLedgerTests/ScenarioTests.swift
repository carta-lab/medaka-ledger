import Foundation
import SwiftData
import Testing
@testable import MedakaLedger

// 通しシナリオ（ROADMAP.md 第5週 12/6）：春の立ち上げ、採卵、孵化、選別、販売、バックアップ、復元。
// 操作の層（CohortOperations、BreedingOperations、SelectionOperations、SaleOperations）を順に呼び、数と集計がつながることを確かめる。

@MainActor
struct ScenarioTests {
    private let day = Date(timeIntervalSinceReferenceDate: 800_000_000)

    private func daysLater(_ days: Int) -> Date {
        day.addingTimeInterval(Double(days) * 86_400)
    }

    @Test func 春の立ち上げから販売とバックアップの復元まで() throws {
        let container = try ModelStore.makeContainer(inMemory: true)
        let context = container.mainContext
        let restoredContainer = try ModelStore.makeContainer(inMemory: true)
        let restored = restoredContainer.mainContext

        // 春の立ち上げ：容器3、系統1、入手個体の群
        let tanks = (1...3).map { Tank(name: "A-\($0)", kind: .nvBox, sortOrder: $0) }
        tanks.forEach(context.insert)
        let strain = Strain(breedName: "楊貴妃", lineName: "〇〇めだか", source: "〇〇めだか", traitTags: ["朱赤"])
        context.insert(strain)
        let parents = CohortOperations.createCohort(
            strain: strain, tank: tanks[0], count: 10, maleCount: 4, femaleCount: 6, stage: .adult,
            acquiredAt: day, date: day, in: context
        )

        // 親魚セットを組み、採卵して、孵化させる
        let set = try BreedingOperations.createBreedingSet(
            .init(sire: parents, dam: parents, maleCount: 2, femaleCount: 4, tank: tanks[0], startedAt: day, name: "", note: "", movesParents: false),
            in: context
        )
        let batch = try BreedingOperations.recordEggBatch(
            in: set, collectedAt: daysLater(5), eggCount: 80, container: tanks[1], containerName: "", waterTempC: 25, note: "", context: context
        )
        let f1 = try BreedingOperations.recordHatch(
            of: batch,
            .init(hatchedAt: daysLater(15), hatchedCount: 60, tank: tanks[1], label: "春1番", note: "", childStrain: nil, addTo: nil),
            in: context
        )
        #expect(f1.generation == 1)
        #expect(f1.count == 60)
        #expect(f1.strain?.id == strain.id)
        #expect(batch.status == .hatched)

        // 選別：残し45、弾き15（餌用）。群の匹数は残し数になる
        try SelectionOperations.record(
            for: f1,
            .init(date: daysLater(40), round: 1, criteria: ["体型"], kept: 45, culled: 15, destination: .feed, separateTank: nil, note: ""),
            in: context
        )
        #expect(f1.count == 45)

        // 販売：ペア3組を群から減らして売り、卵も売る（卵は匹数を減らさない）
        try SaleOperations.record(
            .init(date: daysLater(70), cohort: f1, unit: .pair, quantity: 3, unitPrice: 8000, totalPrice: 24000, fee: 2400, shippingCost: 3000, channel: .yahooAuction, status: .shipped, shippedAt: daysLater(72)),
            reducesCohort: true, in: context
        )
        try SaleOperations.record(
            .init(date: daysLater(71), cohort: f1, unit: .eggs, quantity: 10, unitPrice: 100, totalPrice: 1000, channel: .direct, status: .sold),
            reducesCohort: true, in: context
        )
        try SaleOperations.record(
            .init(date: daysLater(72), cohort: f1, unit: .fish, quantity: 5, unitPrice: 2000, totalPrice: 10000, channel: .event, status: .listed),
            reducesCohort: false, in: context
        )
        try context.save()
        #expect(f1.count == 45 - 6)

        // 集計：売約と発送済だけ。出品中は入らない
        let sales = try context.fetch(FetchDescriptor<Sale>())
        let summary = SalesAggregations.summary(sales.map(SaleOperations.record(of:)))
        #expect(summary == SalesSummary(count: 2, revenue: 25000, fee: 2400, shipping: 3000))
        #expect(summary.net == 19600)

        // タイムラインに、採卵、選別、販売、匹数の減少が出る
        let kinds = f1.timelineItems.map { item -> String in
            switch item {
            case .event: "event"
            case .selection: "selection"
            case .sale: "sale"
            case .origin: "origin"
            }
        }
        #expect(kinds.contains("origin"))
        #expect(kinds.contains("selection"))
        #expect(kinds.filter { $0 == "sale" }.count == 3)

        // バックアップを書き出し、別のストアに置き換えで読み込むと、全てが一致する
        let root = FileManager.default.temporaryDirectory.appending(path: "scenario-\(UUID().uuidString)", directoryHint: .isDirectory)
        defer { try? FileManager.default.removeItem(at: root) }
        let work = root.appending(path: "work", directoryHint: .isDirectory)
        try BackupExporter.write(from: context, includesPhotos: true, appVersion: "1.0", to: work, progress: { _ in })
        let file = root.appending(path: "scenario.\(BackupPaths.fileExtension)", directoryHint: .notDirectory)
        try BackupArchive.create(from: work, to: file)
        let out = root.appending(path: "out", directoryHint: .isDirectory)
        try BackupArchive.extract(from: file, to: out)
        let manifest = try BackupManifest.decode(Data(contentsOf: out.appending(path: BackupPaths.manifestName, directoryHint: .notDirectory)))
        try BackupImporter.restore(manifest, mode: .replace, loadPhoto: { _ in nil }, makeThumbnail: { _ in nil }, into: restored, progress: { _ in })

        let restoredSales = try restored.fetch(FetchDescriptor<Sale>())
        #expect(SalesAggregations.summary(restoredSales.map(SaleOperations.record(of:))) == summary)
        let restoredF1 = try #require(try restored.fetch(FetchDescriptor<Cohort>()).first { $0.generation == 1 })
        #expect(restoredF1.count == 39)
        #expect(restoredF1.originBatch?.breedingSet?.sireCohort?.generation == 0)
        #expect(restoredF1.timelineItems.count == f1.timelineItems.count)

        // 血統：F1の親は入手個体
        let tree = LineageSource.tree(for: restoredF1, maxDepth: 2)
        #expect(tree != nil)
    }
}
