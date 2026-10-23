import Foundation
import SwiftData

// バックアップの書き出しと読み込みを、メインスレッドの外で行う（ARCHITECTURE.md 5.3、CLAUDE.md）。
// ModelActor は Task.detached の中で生成して使う。

@ModelActor
actor BackupActor {
    /// 書き出して file に置く。
    func export(includesPhotos: Bool, appVersion: String, to file: URL, progress: @escaping BackupExporter.Progress) throws {
        let work = FileManager.default.temporaryDirectory.appending(path: "backup-\(UUID().uuidString)", directoryHint: .isDirectory)
        defer { try? FileManager.default.removeItem(at: work) }
        try BackupExporter.write(from: modelContext, includesPhotos: includesPhotos, appVersion: appVersion, to: work) { value in
            progress(value * 0.9)
        }
        try BackupArchive.create(from: work, to: file)
        progress(1)
    }

    /// 内容を調べる（読み込む前の確認用）。
    func inspect(file: URL) throws -> BackupManifest {
        let work = FileManager.default.temporaryDirectory.appending(path: "restore-\(UUID().uuidString)", directoryHint: .isDirectory)
        defer { try? FileManager.default.removeItem(at: work) }
        try BackupArchive.extract(from: file, to: work)
        return try Self.readManifest(in: work)
    }

    /// 読み込む。
    func restore(file: URL, mode: BackupImportMode, progress: @escaping BackupImporter.Progress) throws -> BackupRestoreSummary {
        let work = FileManager.default.temporaryDirectory.appending(path: "restore-\(UUID().uuidString)", directoryHint: .isDirectory)
        defer { try? FileManager.default.removeItem(at: work) }
        try BackupArchive.extract(from: file, to: work)
        progress(0.2)
        let manifest = try Self.readManifest(in: work)
        let photos = work.appending(path: BackupPaths.photosDirectoryName, directoryHint: .isDirectory)
        return try BackupImporter.restore(
            manifest,
            mode: mode,
            loadPhoto: { id in
                try? Data(contentsOf: photos.appending(path: "\(id.uuidString).jpg", directoryHint: .notDirectory))
            },
            makeThumbnail: { data in
                PhotoProcessor.thumbnail(from: data)
            },
            into: modelContext,
            progress: { value in progress(0.2 + value * 0.8) }
        )
    }

    private static func readManifest(in directory: URL) throws -> BackupManifest {
        let url = directory.appending(path: BackupPaths.manifestName, directoryHint: .notDirectory)
        guard let data = try? Data(contentsOf: url) else { throw BackupError.notABackup }
        return try BackupManifest.decode(data)
    }
}
