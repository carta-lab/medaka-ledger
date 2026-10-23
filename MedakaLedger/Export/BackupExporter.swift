import Foundation
import SwiftData

// バックアップの書き出し（ARCHITECTURE.md 5.3）。ModelContext から manifest と写真を作る。
// 重い処理なので、BackupActor（ModelActor）の中で呼ぶ。

enum BackupExporter {
    /// 写真を1回に読む枚数。一度に全部をメモリに載せない。
    static let photoBatchSize = 50

    /// 進捗は 0...1。
    typealias Progress = @Sendable (Double) -> Void

    static func makeManifest(from context: ModelContext, includesPhotos: Bool, appVersion: String, now: Date = .now) throws -> BackupManifest {
        var manifest = BackupManifest(exportedAt: now, appVersion: appVersion, includesPhotos: includesPhotos)
        manifest.tanks = try context.fetch(FetchDescriptor<Tank>(sortBy: [SortDescriptor(\Tank.sortOrder), SortDescriptor(\Tank.createdAt)])).map(record)
        manifest.strains = try context.fetch(FetchDescriptor<Strain>(sortBy: [SortDescriptor(\Strain.sortOrder), SortDescriptor(\Strain.createdAt)])).map(record)
        manifest.cohorts = try context.fetch(FetchDescriptor<Cohort>(sortBy: [SortDescriptor(\Cohort.createdAt)])).map(record)
        manifest.cohortEvents = try context.fetch(FetchDescriptor<CohortEvent>(sortBy: [SortDescriptor(\CohortEvent.createdAt)])).map(record)
        manifest.breedingSets = try context.fetch(FetchDescriptor<BreedingSet>(sortBy: [SortDescriptor(\BreedingSet.startedAt)])).map(record)
        manifest.eggBatches = try context.fetch(FetchDescriptor<EggBatch>(sortBy: [SortDescriptor(\EggBatch.collectedAt)])).map(record)
        manifest.selectionEvents = try context.fetch(FetchDescriptor<SelectionEvent>(sortBy: [SortDescriptor(\SelectionEvent.date)])).map(record)
        manifest.sales = try context.fetch(FetchDescriptor<Sale>(sortBy: [SortDescriptor(\Sale.date)])).map(record)
        manifest.maintenanceLogs = try context.fetch(FetchDescriptor<MaintenanceLog>(sortBy: [SortDescriptor(\MaintenanceLog.date)])).map(record)
        if includesPhotos {
            manifest.photos = try context.fetch(FetchDescriptor<Photo>(sortBy: [SortDescriptor(\Photo.capturedAt)])).map(record)
        }
        return manifest
    }

    /// directory に manifest.json と photos/<id>.jpg を書く。
    static func write(
        from context: ModelContext,
        includesPhotos: Bool,
        appVersion: String,
        to directory: URL,
        progress: Progress
    ) throws {
        let fileManager = FileManager.default
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        let manifest = try makeManifest(from: context, includesPhotos: includesPhotos, appVersion: appVersion)
        try BackupManifest.encode(manifest).write(to: directory.appending(path: "manifest.json", directoryHint: .notDirectory))
        progress(0.1)
        guard includesPhotos, !manifest.photos.isEmpty else { return }

        let photosDirectory = directory.appending(path: "photos", directoryHint: .isDirectory)
        try fileManager.createDirectory(at: photosDirectory, withIntermediateDirectories: true)
        let total = manifest.photos.count
        var written = 0
        var offset = 0
        while offset < total {
            var descriptor = FetchDescriptor<Photo>(sortBy: [SortDescriptor(\Photo.capturedAt), SortDescriptor(\Photo.id)])
            descriptor.fetchOffset = offset
            descriptor.fetchLimit = photoBatchSize
            let batch = try context.fetch(descriptor)
            if batch.isEmpty { break }
            try autoreleasepool {
                for photo in batch {
                    let file = photosDirectory.appending(path: "\(photo.id.uuidString).jpg", directoryHint: .notDirectory)
                    try photo.jpegData.write(to: file)
                    written += 1
                }
            }
            offset += batch.count
            progress(0.1 + 0.8 * Double(written) / Double(total))
        }
    }

    /// 書き出し先のファイル名。「めだか台帳_2027-05-20.medakabackup」。
    static func fileName(now: Date = .now, calendar: Calendar = .current) -> String {
        String(localized: "めだか台帳_\(CSVExporter.isoDate(now, calendar: calendar))")
    }

    // MARK: - モデルから記録へ

    private static func record(_ tank: Tank) -> BackupManifest.TankRecord {
        .init(
            id: tank.id, name: tank.name, kindRaw: tank.kindRaw, capacityLiters: tank.capacityLiters, placementRaw: tank.placementRaw,
            location: tank.location, sortOrder: tank.sortOrder, note: tank.note, isArchived: tank.isArchived,
            createdAt: tank.createdAt, isSample: tank.isSample
        )
    }

    private static func record(_ strain: Strain) -> BackupManifest.StrainRecord {
        .init(
            id: strain.id, breedName: strain.breedName, lineName: strain.lineName, source: strain.source,
            acquiredAt: strain.acquiredAt, traitTags: strain.traitTags, note: strain.note, sortOrder: strain.sortOrder,
            isArchived: strain.isArchived, createdAt: strain.createdAt, isSample: strain.isSample
        )
    }

    private static func record(_ cohort: Cohort) -> BackupManifest.CohortRecord {
        .init(
            id: cohort.id, label: cohort.label, generation: cohort.generation, count: cohort.count, maleCount: cohort.maleCount,
            femaleCount: cohort.femaleCount, stageRaw: cohort.stageRaw, statusRaw: cohort.statusRaw, hatchedAt: cohort.hatchedAt,
            acquiredAt: cohort.acquiredAt, sizeText: cohort.sizeText, note: cohort.note, createdAt: cohort.createdAt,
            isSample: cohort.isSample, strainID: cohort.strain?.id, tankID: cohort.tank?.id, originBatchID: cohort.originBatch?.id
        )
    }

    private static func record(_ event: CohortEvent) -> BackupManifest.CohortEventRecord {
        .init(
            id: event.id, date: event.date, kindRaw: event.kindRaw, countDelta: event.countDelta, reasonRaw: event.reasonRaw,
            fromTankID: event.fromTankID, fromTankName: event.fromTankName, toTankID: event.toTankID, toTankName: event.toTankName,
            relatedCohortID: event.relatedCohortID, stageRaw: event.stageRaw, previousCount: event.previousCount,
            previousStageRaw: event.previousStageRaw, previousStatusRaw: event.previousStatusRaw, statusRaw: event.statusRaw,
            createdAt: event.createdAt, note: event.note, isSample: event.isSample, cohortID: event.cohort?.id
        )
    }

    private static func record(_ set: BreedingSet) -> BackupManifest.BreedingSetRecord {
        .init(
            id: set.id, name: set.name, maleCount: set.maleCount, femaleCount: set.femaleCount, startedAt: set.startedAt,
            endedAt: set.endedAt, note: set.note, isSample: set.isSample, sireCohortID: set.sireCohort?.id,
            damCohortID: set.damCohort?.id, tankID: set.tank?.id, offspringStrainID: set.offspringStrain?.id
        )
    }

    private static func record(_ batch: EggBatch) -> BackupManifest.EggBatchRecord {
        .init(
            id: batch.id, collectedAt: batch.collectedAt, eggCount: batch.eggCount, containerName: batch.containerName,
            waterTempC: batch.waterTempC, statusRaw: batch.statusRaw, hatchedAt: batch.hatchedAt, hatchedCount: batch.hatchedCount,
            note: batch.note, isSample: batch.isSample, breedingSetID: batch.breedingSet?.id, containerID: batch.container?.id
        )
    }

    private static func record(_ selection: SelectionEvent) -> BackupManifest.SelectionEventRecord {
        .init(
            id: selection.id, date: selection.date, round: selection.round, criteria: selection.criteria,
            keptCount: selection.keptCount, culledCount: selection.culledCount, cullDestinationRaw: selection.cullDestinationRaw,
            culledCohortID: selection.culledCohortID, note: selection.note, isSample: selection.isSample, cohortID: selection.cohort?.id
        )
    }

    private static func record(_ sale: Sale) -> BackupManifest.SaleBackupRecord {
        .init(
            id: sale.id, date: sale.date, unitRaw: sale.unitRaw, quantity: sale.quantity, unitPrice: sale.unitPrice,
            totalPrice: sale.totalPrice, fee: sale.fee, shippingCost: sale.shippingCost, channelRaw: sale.channelRaw,
            statusRaw: sale.statusRaw, shippedAt: sale.shippedAt, buyerMemo: sale.buyerMemo, note: sale.note,
            breedNameSnapshot: sale.breedNameSnapshot, lineNameSnapshot: sale.lineNameSnapshot, generation: sale.generation,
            isSample: sale.isSample, cohortID: sale.cohort?.id, strainID: sale.strain?.id
        )
    }

    private static func record(_ log: MaintenanceLog) -> BackupManifest.MaintenanceLogRecord {
        .init(
            id: log.id, date: log.date, kindRaw: log.kindRaw, percent: log.percent, waterTempC: log.waterTempC,
            note: log.note, isSample: log.isSample, tankID: log.tank?.id
        )
    }

    private static func record(_ photo: Photo) -> BackupManifest.PhotoRecord {
        .init(
            id: photo.id, capturedAt: photo.capturedAt, caption: photo.caption, isCover: photo.isCover, isSample: photo.isSample,
            cohortID: photo.cohort?.id, tankID: photo.tank?.id, strainID: photo.strain?.id, selectionID: photo.selection?.id
        )
    }
}
