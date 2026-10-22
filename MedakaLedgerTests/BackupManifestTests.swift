import Foundation
import Testing
@testable import MedakaLedger

struct BackupManifestTests {
    private func sample() -> BackupManifest {
        var manifest = BackupManifest(exportedAt: Date(timeIntervalSinceReferenceDate: 800_000_000.123456), appVersion: "0.1.0", includesPhotos: true)
        let tankID = UUID()
        manifest.tanks = [
            .init(
                id: tankID, name: "A-1", kindRaw: "nvBox", capacityLiters: 22.5, placementRaw: "outdoor", location: "棚A",
                sortOrder: 0, note: "メモ,\"引用\"\n改行", isArchived: false, createdAt: Date(timeIntervalSinceReferenceDate: 700_000_000.987654), isSample: false
            ),
        ]
        manifest.maintenanceLogs = [
            .init(id: UUID(), date: Date(timeIntervalSinceReferenceDate: 700_000_001.5), kindRaw: "temperature", percent: nil, waterTempC: 24.3, note: "", isSample: true, tankID: tankID),
        ]
        return manifest
    }

    @Test func 書き出しと読み込みで値が変わらない() throws {
        let manifest = sample()
        let decoded = try BackupManifest.decode(BackupManifest.encode(manifest))
        #expect(decoded == manifest)
    }

    @Test func 未知の新しい版は拒否する() throws {
        var manifest = sample()
        manifest.schemaVersion = BackupManifest.currentSchemaVersion + 1
        let data = try BackupManifest.encode(manifest)
        #expect(throws: BackupError.unsupportedVersion(BackupManifest.currentSchemaVersion + 1)) {
            try BackupManifest.decode(data)
        }
    }

    @Test func 版が0以下やJSONでないものは拒否する() throws {
        var manifest = sample()
        manifest.schemaVersion = 0
        let zero = try BackupManifest.encode(manifest)
        #expect(throws: BackupError.notABackup) { try BackupManifest.decode(zero) }
        #expect(throws: BackupError.notABackup) { try BackupManifest.decode(Data("これはバックアップではありません".utf8)) }
        #expect(throws: BackupError.notABackup) { try BackupManifest.decode(Data("{}".utf8)) }
    }

    @Test func 版は合っていても中身が壊れていれば拒否する() {
        #expect(throws: BackupError.notABackup) { try BackupManifest.decode(Data("{\"schemaVersion\":1}".utf8)) }
    }

    @Test func 件数() {
        var manifest = sample()
        manifest.sales = []
        let counts = manifest.counts
        #expect(counts.tanks == 1)
        #expect(counts.others == 1)
        #expect(counts.photos == 0)
    }

    @Test func 展開してよいパス() {
        #expect(BackupPaths.isSafeEntry("manifest.json"))
        #expect(BackupPaths.isSafeEntry("photos"))
        #expect(BackupPaths.isSafeEntry("photos/ABC.jpg"))
        #expect(!BackupPaths.isSafeEntry("../evil"))
        #expect(!BackupPaths.isSafeEntry("photos/../../evil"))
        #expect(!BackupPaths.isSafeEntry("/etc/passwd"))
        #expect(!BackupPaths.isSafeEntry("other.txt"))
        #expect(!BackupPaths.isSafeEntry("./manifest.json"))
        #expect(!BackupPaths.isSafeEntry(""))
    }
}
