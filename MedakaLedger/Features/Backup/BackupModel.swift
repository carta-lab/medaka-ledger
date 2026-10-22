import Foundation
import Observation
import SwiftData

// バックアップの書き出しと読み込みの状態（SCREENS.md 12）。重い処理は BackupActor で行い、進捗を表示する。

@MainActor
@Observable
final class BackupModel {
    var progress: Double?
    var error: UserFacingError?

    // 書き出し
    var exportDocument = BackupFileDocument()
    var isExporting = false
    private var exportedFile: URL?

    // 読み込み
    var isPickingFile = false
    var pendingFile: URL?
    var pendingManifest: BackupManifest?
    var isChoosingMode = false
    var isConfirmingReplace = false
    var resultMessage: String?
    var isShowingResult = false

    // 群CSV
    var csvDocument = CSVDocument(data: Data())
    var isExportingCSV = false

    var isWorking: Bool { progress != nil }

    var appVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? ""
    }

    // MARK: - 書き出し

    func export(includesPhotos: Bool, container: ModelContainer) {
        guard !isWorking else { return }
        progress = 0
        let version = appVersion
        let fileName = "\(BackupExporter.fileName()).\(BackupArchive.fileExtension)"
        Task {
            do {
                let file = try await Task.detached { [weak self] () throws -> URL in
                    let target = FileManager.default.temporaryDirectory.appending(path: fileName, directoryHint: .notDirectory)
                    let worker = BackupActor(modelContainer: container)
                    try await worker.export(includesPhotos: includesPhotos, appVersion: version, to: target) { value in
                        Task { @MainActor in self?.progress = value }
                    }
                    return target
                }.value
                exportedFile = file
                exportDocument = BackupFileDocument(url: file)
                progress = nil
                isExporting = true
            } catch {
                progress = nil
                self.error = UserFacingError(error, title: String(localized: "書き出せませんでした"))
            }
        }
    }

    /// 保存先の選択が終わったとき。書き出せたら最終バックアップの日時を残す。
    func exportFinished(_ result: Result<URL, any Error>, settings: AppSettings) {
        if let exportedFile {
            try? FileManager.default.removeItem(at: exportedFile)
        }
        exportedFile = nil
        exportDocument = BackupFileDocument()
        switch result {
        case .success:
            settings.lastBackupAt = Date()
        case let .failure(failure):
            if (failure as? CocoaError)?.code != .userCancelled {
                error = UserFacingError(failure, title: String(localized: "書き出せませんでした"))
            }
        }
    }

    // MARK: - 読み込み

    /// 選んだファイルの中身を調べて、読み込み方の選択を出す。
    func pick(_ result: Result<[URL], any Error>, container: ModelContainer) {
        switch result {
        case let .failure(failure):
            error = UserFacingError(failure, title: String(localized: "読み込めませんでした"))
        case let .success(urls):
            guard let url = urls.first, !isWorking else { return }
            progress = 0
            Task {
                do {
                    let (local, manifest) = try await Task.detached { () throws -> (URL, BackupManifest) in
                        let local = try Self.copyToTemporary(url)
                        let worker = BackupActor(modelContainer: container)
                        return (local, try await worker.inspect(file: local))
                    }.value
                    pendingFile = local
                    pendingManifest = manifest
                    progress = nil
                    isChoosingMode = true
                } catch {
                    progress = nil
                    self.error = UserFacingError(error, title: String(localized: "読み込めませんでした"))
                }
            }
        }
    }

    func restore(mode: BackupImportMode, container: ModelContainer) {
        guard let file = pendingFile, !isWorking else { return }
        progress = 0
        Task {
            do {
                let summary = try await Task.detached { [weak self] () throws -> BackupRestoreSummary in
                    let worker = BackupActor(modelContainer: container)
                    return try await worker.restore(file: file, mode: mode) { value in
                        Task { @MainActor in self?.progress = value }
                    }
                }.value
                finishRestore(summary)
            } catch {
                progress = nil
                self.error = UserFacingError(error, title: String(localized: "読み込めませんでした"))
            }
        }
    }

    func discardPending() {
        if let pendingFile {
            try? FileManager.default.removeItem(at: pendingFile)
        }
        pendingFile = nil
        pendingManifest = nil
    }

    private func finishRestore(_ summary: BackupRestoreSummary) {
        progress = nil
        let counts = summary.counts
        var message = String(localized: "容器\(counts.tanks.formatted())、系統\(counts.strains.formatted())、群\(counts.cohorts.formatted())、販売\(counts.sales.formatted())、写真\(counts.photos.formatted())を読み込みました。")
        if summary.skippedPhotos > 0 {
            message += String(localized: "写真\(summary.skippedPhotos.formatted())枚は本体が見つからず、読み込めませんでした。")
        }
        resultMessage = message
        isShowingResult = true
        discardPending()
    }

    /// 選んだファイルは使い終わるまで消えないように、アプリの一時フォルダへ写す。
    nonisolated private static func copyToTemporary(_ url: URL) throws -> URL {
        let scoped = url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }
        let target = FileManager.default.temporaryDirectory.appending(path: "import-\(UUID().uuidString).\(BackupArchive.fileExtension)", directoryHint: .notDirectory)
        try FileManager.default.copyItem(at: url, to: target)
        return target
    }

    // MARK: - 群CSV

    func exportCohortsCSV(_ cohorts: [Cohort]) {
        let rows = cohorts.map { cohort in
            CohortCSVRow(
                lineName: cohort.strain?.lineName ?? "",
                breedName: cohort.strain?.breedName ?? "",
                generation: cohort.generation,
                tankName: cohort.tank?.name ?? "",
                count: cohort.count,
                stage: cohort.stage,
                hatchedAt: cohort.hatchedAt,
                status: cohort.status,
                note: cohort.note
            )
        }
        csvDocument = CSVDocument(data: CSVExporter.cohortsCSV(rows, now: .now, calendar: .current))
        isExportingCSV = true
    }

    func csvFinished(_ result: Result<URL, any Error>) {
        if case let .failure(failure) = result, (failure as? CocoaError)?.code != .userCancelled {
            error = UserFacingError(failure, title: String(localized: "書き出せませんでした"))
        }
    }
}
