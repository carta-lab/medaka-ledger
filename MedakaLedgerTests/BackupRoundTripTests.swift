import Foundation
import SwiftData
import Testing
@testable import MedakaLedger

@MainActor
struct BackupRoundTripTests {
    private let now = Date(timeIntervalSinceReferenceDate: 800_000_000)

    /// ModelContext はコンテナを保持しない。コンテナが先に解放されるとクラッシュするので、テストが終わるまで持っておく。
    private final class ContainerKeeper {
        var containers: [ModelContainer] = []
    }

    private let keeper = ContainerKeeper()

    private func makeContext() throws -> ModelContext {
        let container = try ModelStore.makeContainer(inMemory: true)
        keeper.containers.append(container)
        return container.mainContext
    }

    /// サンプルに、写真と購入者メモ付きの販売を足したデータ。
    private func populate(_ context: ModelContext) throws {
        try SampleDataSeeder.seed(into: context)
        let cohort = try #require(try context.fetch(FetchDescriptor<Cohort>(sortBy: [SortDescriptor(\Cohort.createdAt)])).first)
        let strain = try #require(cohort.strain)
        let tank = try #require(cohort.tank)
        let selection = try #require(try context.fetch(FetchDescriptor<SelectionEvent>()).first)
        for (index, owner) in [PhotoOwner.cohort(cohort), .tank(tank), .strain(strain), .selection(selection)].enumerated() {
            let photo = PhotoOperations.add(
                ProcessedPhoto(
                    jpegData: Data("写真\(index)".utf8) + Data(repeating: UInt8(index), count: 1000),
                    thumbnailData: Data([UInt8(index)]),
                    capturedAt: Date(timeIntervalSinceReferenceDate: 700_000_000 + Double(index))
                ),
                to: owner,
                in: context
            )
            photo.caption = "説明,\(index)"
            photo.isCover = index == 0
        }
        let sale = try SaleOperations.record(
            .init(date: now, cohort: cohort, unit: .trio, quantity: 2, unitPrice: 5000, totalPrice: 9000, fee: 500, shippingCost: 800, channel: .consignment, status: .shipped, shippedAt: now, buyerMemo: "山田, 太郎\n様", note: "値引き"),
            reducesCohort: true,
            in: context
        )
        _ = sale
        try context.save()
    }

    /// 並びに依存せず比べる（同じ日付の記録は取り出しの順が決まらない）。
    private func normalized(_ manifest: BackupManifest) -> BackupManifest {
        var result = manifest
        result.exportedAt = now
        result.tanks.sort { $0.id.uuidString < $1.id.uuidString }
        result.strains.sort { $0.id.uuidString < $1.id.uuidString }
        result.cohorts.sort { $0.id.uuidString < $1.id.uuidString }
        result.cohortEvents.sort { $0.id.uuidString < $1.id.uuidString }
        result.breedingSets.sort { $0.id.uuidString < $1.id.uuidString }
        result.eggBatches.sort { $0.id.uuidString < $1.id.uuidString }
        result.selectionEvents.sort { $0.id.uuidString < $1.id.uuidString }
        result.sales.sort { $0.id.uuidString < $1.id.uuidString }
        result.maintenanceLogs.sort { $0.id.uuidString < $1.id.uuidString }
        result.photos.sort { $0.id.uuidString < $1.id.uuidString }
        return result
    }

    private func temporaryDirectory() throws -> URL {
        let url = FileManager.default.temporaryDirectory.appending(path: "backup-test-\(UUID().uuidString)", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    /// 書き出し、ファイルにまとめ、展開して、manifest と写真の読み出し口を返す。
    private func exportAndExtract(from context: ModelContext, includesPhotos: Bool, in root: URL) throws -> (BackupManifest, BackupImporter.PhotoLoader) {
        let work = root.appending(path: "work", directoryHint: .isDirectory)
        try BackupExporter.write(from: context, includesPhotos: includesPhotos, appVersion: "1.0", to: work, progress: { _ in })
        let file = root.appending(path: "test.\(BackupPaths.fileExtension)", directoryHint: .notDirectory)
        try BackupArchive.create(from: work, to: file)
        let out = root.appending(path: "out", directoryHint: .isDirectory)
        try BackupArchive.extract(from: file, to: out)
        let manifest = try BackupManifest.decode(Data(contentsOf: out.appending(path: BackupPaths.manifestName, directoryHint: .notDirectory)))
        let photos = out.appending(path: BackupPaths.photosDirectoryName, directoryHint: .isDirectory)
        let loader: BackupImporter.PhotoLoader = { id in
            try? Data(contentsOf: photos.appending(path: "\(id.uuidString).jpg", directoryHint: .notDirectory))
        }
        return (manifest, loader)
    }

    @Test func 置き換えの往復で全モデルと写真が一致する() throws {
        let source = try makeContext()
        try populate(source)
        let root = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }

        let (manifest, loader) = try exportAndExtract(from: source, includesPhotos: true, in: root)
        #expect(manifest.photos.count == 4)
        #expect(manifest.sales.contains { $0.buyerMemo == "山田, 太郎\n様" })

        let target = try makeContext()
        // 読み込み先に、消えるはずの別のデータを入れておく
        target.insert(Tank(name: "消える容器", kind: .cup))
        try target.save()
        try BackupImporter.restore(manifest, mode: .replace, loadPhoto: loader, makeThumbnail: { _ in Data([9]) }, into: target, progress: { _ in })

        let before = try BackupExporter.makeManifest(from: source, includesPhotos: true, appVersion: "1.0", now: now)
        let after = try BackupExporter.makeManifest(from: target, includesPhotos: true, appVersion: "1.0", now: now)
        #expect(normalized(before) == normalized(after))
        #expect(try target.fetch(FetchDescriptor<Tank>()).contains { $0.name == "消える容器" } == false)

        // 写真の本体が同じで、サムネイルは作り直される
        let originals = Dictionary(uniqueKeysWithValues: try source.fetch(FetchDescriptor<Photo>()).map { ($0.id, $0.jpegData) })
        let restored = try target.fetch(FetchDescriptor<Photo>())
        #expect(restored.count == 4)
        for photo in restored {
            #expect(originals[photo.id] == photo.jpegData)
            #expect(photo.thumbnailData == Data([9]))
        }
    }

    @Test func 関係がつながり直る() throws {
        let source = try makeContext()
        try populate(source)
        let root = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        let (manifest, loader) = try exportAndExtract(from: source, includesPhotos: true, in: root)
        let target = try makeContext()
        try BackupImporter.restore(manifest, mode: .replace, loadPhoto: loader, makeThumbnail: { _ in nil }, into: target, progress: { _ in })

        let cohorts = try target.fetch(FetchDescriptor<Cohort>())
        #expect(cohorts.allSatisfy { $0.strain != nil })
        let hatched = cohorts.filter { $0.originBatch != nil }
        #expect(!hatched.isEmpty)
        let sale = try #require(try target.fetch(FetchDescriptor<Sale>()).first { $0.buyerMemo.hasPrefix("山田") })
        #expect(sale.cohort != nil)
        #expect(sale.strain?.id == sale.cohort?.strain?.id)
        let sets = try target.fetch(FetchDescriptor<BreedingSet>())
        #expect(sets.allSatisfy { $0.sireCohort != nil && $0.damCohort != nil })
        #expect(try target.fetch(FetchDescriptor<CohortEvent>()).allSatisfy { $0.cohort != nil })
    }

    @Test func 追記は同じIDを上書きして足りないものを足す() throws {
        let source = try makeContext()
        try populate(source)
        let root = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        let (manifest, loader) = try exportAndExtract(from: source, includesPhotos: true, in: root)

        let target = try makeContext()
        try BackupImporter.restore(manifest, mode: .replace, loadPhoto: loader, makeThumbnail: { _ in nil }, into: target, progress: { _ in })
        // 読み込み後に、端末側で変えたものと足したもの
        let tank = try #require(try target.fetch(FetchDescriptor<Tank>()).first)
        let originalName = tank.name
        tank.name = "変更した名前"
        target.insert(Tank(name: "端末にだけある容器", kind: .cup))
        try target.save()

        let countBefore = try target.fetch(FetchDescriptor<Tank>()).count
        try BackupImporter.restore(manifest, mode: .append, loadPhoto: loader, makeThumbnail: { _ in nil }, into: target, progress: { _ in })

        let tanks = try target.fetch(FetchDescriptor<Tank>())
        #expect(tanks.count == countBefore)
        #expect(tanks.contains { $0.id == tank.id && $0.name == originalName })
        #expect(tanks.contains { $0.name == "端末にだけある容器" })
        #expect(try target.fetch(FetchDescriptor<Photo>()).count == 4)
    }

    @Test func 軽量版は追記だけで読み込める() throws {
        let source = try makeContext()
        try populate(source)
        let root = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        let (manifest, loader) = try exportAndExtract(from: source, includesPhotos: false, in: root)
        #expect(!manifest.includesPhotos)
        #expect(manifest.photos.isEmpty)

        let target = try makeContext()
        target.insert(Tank(name: "既にある容器", kind: .cup))
        try target.save()
        #expect(throws: BackupError.lightweightCannotReplace) {
            try BackupImporter.restore(manifest, mode: .replace, loadPhoto: loader, makeThumbnail: { _ in nil }, into: target, progress: { _ in })
        }
        // 止められたので、今のデータは残っている
        #expect(try target.fetch(FetchDescriptor<Tank>()).map(\.name) == ["既にある容器"])

        try BackupImporter.restore(manifest, mode: .append, loadPhoto: loader, makeThumbnail: { _ in nil }, into: target, progress: { _ in })
        #expect(try target.fetch(FetchDescriptor<Tank>()).count == 7)
        #expect(try target.fetch(FetchDescriptor<Photo>()).isEmpty)
    }

    @Test func 本体が無い写真は飛ばして数える() throws {
        let source = try makeContext()
        try populate(source)
        let root = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        let (manifest, _) = try exportAndExtract(from: source, includesPhotos: true, in: root)
        let target = try makeContext()
        let summary = try BackupImporter.restore(manifest, mode: .replace, loadPhoto: { _ in nil }, makeThumbnail: { _ in nil }, into: target, progress: { _ in })
        #expect(summary.skippedPhotos == 4)
        #expect(try target.fetch(FetchDescriptor<Photo>()).isEmpty)
        #expect(try target.fetch(FetchDescriptor<Cohort>()).count == manifest.cohorts.count)
    }

    @Test func アーカイブは壊れたファイルを拒否する() throws {
        let root = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        let file = root.appending(path: "broken.\(BackupPaths.fileExtension)", directoryHint: .notDirectory)
        try Data("これはバックアップではありません".utf8).write(to: file)
        #expect(throws: BackupError.self) {
            try BackupArchive.extract(from: file, to: root.appending(path: "out", directoryHint: .isDirectory))
        }
    }
}
