import Foundation
import SwiftData

// バックアップの読み込み（ARCHITECTURE.md 5.3）。「置き換え」は全削除してから入れ、「追記」はIDが同じものを上書きして、なければ足す。
// 全て同じ ModelContext の中で行い、最後に1回だけ保存する。途中で失敗したら巻き戻す。

enum BackupImportMode: Sendable {
    case replace
    case append
}

struct BackupRestoreSummary: Equatable, Sendable {
    var counts: BackupManifest.Counts
    /// 本体のファイルが見つからず、取り込めなかった写真の数。
    var skippedPhotos: Int
}

enum BackupImporter {
    typealias Progress = @Sendable (Double) -> Void

    /// 写真の本体（photos/<id>.jpg）を探す場所。
    typealias PhotoLoader = (UUID) -> Data?
    /// 写真の本体からサムネイルを作る。作れなければ nil。
    typealias ThumbnailMaker = (Data) -> Data?

    /// manifest を ModelContext に入れる。保存まで行う。失敗したら巻き戻して投げる。
    @discardableResult
    static func restore(
        _ manifest: BackupManifest,
        mode: BackupImportMode,
        loadPhoto: PhotoLoader,
        makeThumbnail: ThumbnailMaker,
        into context: ModelContext,
        progress: Progress
    ) throws -> BackupRestoreSummary {
        if mode == .replace, !manifest.includesPhotos { throw BackupError.lightweightCannotReplace }
        do {
            let summary = try apply(manifest, mode: mode, loadPhoto: loadPhoto, makeThumbnail: makeThumbnail, into: context, progress: progress)
            try context.save()
            progress(1)
            return summary
        } catch {
            context.rollback()
            throw error
        }
    }

    // MARK: - 内部

    private static func apply(
        _ manifest: BackupManifest,
        mode: BackupImportMode,
        loadPhoto: PhotoLoader,
        makeThumbnail: ThumbnailMaker,
        into context: ModelContext,
        progress: Progress
    ) throws -> BackupRestoreSummary {
        if mode == .replace {
            try SampleDataSeeder.deleteEverything(in: context, saves: false)
        }
        progress(0.05)

        var registry = try Registry(context: context, loadsExisting: mode == .append)

        for record in manifest.tanks {
            let tank = registry.tanks[record.id] ?? insert(Tank(), into: context, registry: &registry.tanks, id: record.id)
            tank.name = record.name
            tank.kindRaw = record.kindRaw
            tank.capacityLiters = record.capacityLiters
            tank.placementRaw = record.placementRaw
            tank.location = record.location
            tank.sortOrder = record.sortOrder
            tank.note = record.note
            tank.isArchived = record.isArchived
            tank.createdAt = record.createdAt
            tank.isSample = record.isSample
        }
        for record in manifest.strains {
            let strain = registry.strains[record.id] ?? insert(Strain(), into: context, registry: &registry.strains, id: record.id)
            strain.breedName = record.breedName
            strain.lineName = record.lineName
            strain.source = record.source
            strain.acquiredAt = record.acquiredAt
            strain.traitTags = record.traitTags
            strain.note = record.note
            strain.sortOrder = record.sortOrder
            strain.isArchived = record.isArchived
            strain.createdAt = record.createdAt
            strain.isSample = record.isSample
        }
        progress(0.15)

        // 群と採卵ロット、親魚セットは互いを参照するので、まず本体だけを作り、そのあとで関係をつなぐ
        for record in manifest.cohorts {
            let cohort = registry.cohorts[record.id] ?? insert(Cohort(), into: context, registry: &registry.cohorts, id: record.id)
            cohort.label = record.label
            cohort.generation = record.generation
            cohort.count = record.count
            cohort.maleCount = record.maleCount
            cohort.femaleCount = record.femaleCount
            cohort.stageRaw = record.stageRaw
            cohort.statusRaw = record.statusRaw
            cohort.hatchedAt = record.hatchedAt
            cohort.acquiredAt = record.acquiredAt
            cohort.sizeText = record.sizeText
            cohort.note = record.note
            cohort.createdAt = record.createdAt
            cohort.isSample = record.isSample
        }
        for record in manifest.breedingSets {
            let set = registry.breedingSets[record.id] ?? insert(BreedingSet(), into: context, registry: &registry.breedingSets, id: record.id)
            set.name = record.name
            set.maleCount = record.maleCount
            set.femaleCount = record.femaleCount
            set.startedAt = record.startedAt
            set.endedAt = record.endedAt
            set.note = record.note
            set.isSample = record.isSample
        }
        for record in manifest.eggBatches {
            let batch = registry.eggBatches[record.id] ?? insert(EggBatch(), into: context, registry: &registry.eggBatches, id: record.id)
            batch.collectedAt = record.collectedAt
            batch.eggCount = record.eggCount
            batch.containerName = record.containerName
            batch.waterTempC = record.waterTempC
            batch.statusRaw = record.statusRaw
            batch.hatchedAt = record.hatchedAt
            batch.hatchedCount = record.hatchedCount
            batch.note = record.note
            batch.isSample = record.isSample
        }
        progress(0.3)

        for record in manifest.cohorts {
            guard let cohort = registry.cohorts[record.id] else { continue }
            cohort.strain = record.strainID.flatMap { registry.strains[$0] }
            cohort.tank = record.tankID.flatMap { registry.tanks[$0] }
            cohort.originBatch = record.originBatchID.flatMap { registry.eggBatches[$0] }
        }
        for record in manifest.breedingSets {
            guard let set = registry.breedingSets[record.id] else { continue }
            set.sireCohort = record.sireCohortID.flatMap { registry.cohorts[$0] }
            set.damCohort = record.damCohortID.flatMap { registry.cohorts[$0] }
            set.tank = record.tankID.flatMap { registry.tanks[$0] }
            set.offspringStrain = record.offspringStrainID.flatMap { registry.strains[$0] }
        }
        for record in manifest.eggBatches {
            guard let batch = registry.eggBatches[record.id] else { continue }
            batch.breedingSet = record.breedingSetID.flatMap { registry.breedingSets[$0] }
            batch.container = record.containerID.flatMap { registry.tanks[$0] }
        }
        progress(0.4)

        for record in manifest.cohortEvents {
            let event = registry.cohortEvents[record.id] ?? insert(CohortEvent(), into: context, registry: &registry.cohortEvents, id: record.id)
            event.date = record.date
            event.kindRaw = record.kindRaw
            event.countDelta = record.countDelta
            event.reasonRaw = record.reasonRaw
            event.fromTankID = record.fromTankID
            event.fromTankName = record.fromTankName
            event.toTankID = record.toTankID
            event.toTankName = record.toTankName
            event.relatedCohortID = record.relatedCohortID
            event.stageRaw = record.stageRaw
            event.previousCount = record.previousCount
            event.previousStageRaw = record.previousStageRaw
            event.previousStatusRaw = record.previousStatusRaw
            event.statusRaw = record.statusRaw
            event.createdAt = record.createdAt
            event.note = record.note
            event.isSample = record.isSample
            event.cohort = record.cohortID.flatMap { registry.cohorts[$0] }
        }
        for record in manifest.selectionEvents {
            let selection = registry.selections[record.id] ?? insert(SelectionEvent(), into: context, registry: &registry.selections, id: record.id)
            selection.date = record.date
            selection.round = record.round
            selection.criteria = record.criteria
            selection.keptCount = record.keptCount
            selection.culledCount = record.culledCount
            selection.cullDestinationRaw = record.cullDestinationRaw
            selection.culledCohortID = record.culledCohortID
            selection.note = record.note
            selection.isSample = record.isSample
            selection.cohort = record.cohortID.flatMap { registry.cohorts[$0] }
        }
        for record in manifest.sales {
            let sale = registry.sales[record.id] ?? insert(Sale(), into: context, registry: &registry.sales, id: record.id)
            sale.date = record.date
            sale.unitRaw = record.unitRaw
            sale.quantity = record.quantity
            sale.unitPrice = record.unitPrice
            sale.totalPrice = record.totalPrice
            sale.fee = record.fee
            sale.shippingCost = record.shippingCost
            sale.channelRaw = record.channelRaw
            sale.statusRaw = record.statusRaw
            sale.shippedAt = record.shippedAt
            sale.buyerMemo = record.buyerMemo
            sale.note = record.note
            sale.breedNameSnapshot = record.breedNameSnapshot
            sale.lineNameSnapshot = record.lineNameSnapshot
            sale.generation = record.generation
            sale.isSample = record.isSample
            sale.cohort = record.cohortID.flatMap { registry.cohorts[$0] }
            sale.strain = record.strainID.flatMap { registry.strains[$0] }
        }
        for record in manifest.maintenanceLogs {
            let log = registry.logs[record.id] ?? insert(MaintenanceLog(), into: context, registry: &registry.logs, id: record.id)
            log.date = record.date
            log.kindRaw = record.kindRaw
            log.percent = record.percent
            log.waterTempC = record.waterTempC
            log.note = record.note
            log.isSample = record.isSample
            log.tank = record.tankID.flatMap { registry.tanks[$0] }
        }
        progress(0.5)

        var skipped = 0
        let totalPhotos = max(manifest.photos.count, 1)
        for (index, record) in manifest.photos.enumerated() {
            let existing = registry.photos[record.id]
            let data = loadPhoto(record.id)
            // 本体が無く、まだ端末にもない写真は作れない
            if data == nil, existing == nil {
                skipped += 1
                continue
            }
            let photo = existing ?? insert(Photo(), into: context, registry: &registry.photos, id: record.id)
            if let data {
                photo.jpegData = data
                photo.thumbnailData = makeThumbnail(data) ?? data
            }
            photo.capturedAt = record.capturedAt
            photo.caption = record.caption
            photo.isCover = record.isCover
            photo.isSample = record.isSample
            photo.cohort = record.cohortID.flatMap { registry.cohorts[$0] }
            photo.tank = record.tankID.flatMap { registry.tanks[$0] }
            photo.strain = record.strainID.flatMap { registry.strains[$0] }
            photo.selection = record.selectionID.flatMap { registry.selections[$0] }
            progress(0.5 + 0.45 * Double(index + 1) / Double(totalPhotos))
        }
        return BackupRestoreSummary(counts: manifest.counts, skippedPhotos: skipped)
    }

    /// 新しいモデルを作ってIDを付け、登録簿に入れる。
    private static func insert<Model: PersistentModel & Identified>(
        _ model: Model,
        into context: ModelContext,
        registry: inout [UUID: Model],
        id: UUID
    ) -> Model {
        model.id = id
        context.insert(model)
        registry[id] = model
        return model
    }

    /// IDで引ける、既にあるモデルと、この読み込みで作ったモデル。
    private struct Registry {
        var tanks: [UUID: Tank] = [:]
        var strains: [UUID: Strain] = [:]
        var cohorts: [UUID: Cohort] = [:]
        var cohortEvents: [UUID: CohortEvent] = [:]
        var breedingSets: [UUID: BreedingSet] = [:]
        var eggBatches: [UUID: EggBatch] = [:]
        var selections: [UUID: SelectionEvent] = [:]
        var sales: [UUID: Sale] = [:]
        var logs: [UUID: MaintenanceLog] = [:]
        var photos: [UUID: Photo] = [:]

        init(context: ModelContext, loadsExisting: Bool) throws {
            guard loadsExisting else { return }
            tanks = try Self.index(context)
            strains = try Self.index(context)
            cohorts = try Self.index(context)
            cohortEvents = try Self.index(context)
            breedingSets = try Self.index(context)
            eggBatches = try Self.index(context)
            selections = try Self.index(context)
            sales = try Self.index(context)
            logs = try Self.index(context)
            photos = try Self.index(context)
        }

        private static func index<Model: PersistentModel & Identified>(_ context: ModelContext) throws -> [UUID: Model] {
            try context.fetch(FetchDescriptor<Model>()).reduce(into: [:]) { result, model in
                // 同じIDが複数あっても最初のものを使う
                if result[model.id] == nil { result[model.id] = model }
            }
        }
    }
}

/// id を持つモデル。バックアップの読み込みでIDを付けるために使う。
protocol Identified: AnyObject {
    var id: UUID { get set }
}

extension SchemaV1.Tank: Identified {}
extension SchemaV1.Strain: Identified {}
extension SchemaV1.Cohort: Identified {}
extension SchemaV1.CohortEvent: Identified {}
extension SchemaV1.BreedingSet: Identified {}
extension SchemaV1.EggBatch: Identified {}
extension SchemaV1.SelectionEvent: Identified {}
extension SchemaV1.Sale: Identified {}
extension SchemaV1.MaintenanceLog: Identified {}
extension SchemaV1.Photo: Identified {}
