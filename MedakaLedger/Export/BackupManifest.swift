import Foundation

// バックアップの manifest.json（ARCHITECTURE.md 5.3）。
// SwiftDataの属性をそのままキーにし、リレーションはIDで表す。日付はJSONEncoderの既定（2001-01-01 UTCからの秒数）で、往復しても値が変わらない。
// 写真の本体は photos/<photoID>.jpg に置き、manifest には説明と付け先だけを入れる。

struct BackupManifest: Codable, Equatable, Sendable {
    /// 読み込める manifest の版。形を変えるときは上げ、古い版を変換する処理を足す。
    static let currentSchemaVersion = 1

    var schemaVersion: Int = BackupManifest.currentSchemaVersion
    var exportedAt: Date
    var appVersion: String
    /// 写真の本体を含むか。含まない軽量版は「追記」でだけ読み込める。
    var includesPhotos: Bool
    var tanks: [TankRecord] = []
    var strains: [StrainRecord] = []
    var cohorts: [CohortRecord] = []
    var cohortEvents: [CohortEventRecord] = []
    var breedingSets: [BreedingSetRecord] = []
    var eggBatches: [EggBatchRecord] = []
    var selectionEvents: [SelectionEventRecord] = []
    var sales: [SaleBackupRecord] = []
    var maintenanceLogs: [MaintenanceLogRecord] = []
    var photos: [PhotoRecord] = []

    struct TankRecord: Codable, Equatable, Sendable {
        var id: UUID
        var name: String
        var kindRaw: String
        var capacityLiters: Double?
        var placementRaw: String
        var location: String
        var sortOrder: Int
        var note: String
        var isArchived: Bool
        var createdAt: Date
        var isSample: Bool
    }

    struct StrainRecord: Codable, Equatable, Sendable {
        var id: UUID
        var breedName: String
        var lineName: String
        var source: String
        var acquiredAt: Date?
        var traitTags: [String]
        var note: String
        var sortOrder: Int
        var isArchived: Bool
        var createdAt: Date
        var isSample: Bool
    }

    struct CohortRecord: Codable, Equatable, Sendable {
        var id: UUID
        var label: String
        var generation: Int
        var count: Int?
        var maleCount: Int?
        var femaleCount: Int?
        var stageRaw: String
        var statusRaw: String
        var hatchedAt: Date?
        var acquiredAt: Date?
        var sizeText: String
        var note: String
        var createdAt: Date
        var isSample: Bool
        var strainID: UUID?
        var tankID: UUID?
        var originBatchID: UUID?
    }

    struct CohortEventRecord: Codable, Equatable, Sendable {
        var id: UUID
        var date: Date
        var kindRaw: String
        var countDelta: Int
        var reasonRaw: String
        var fromTankID: UUID?
        var fromTankName: String
        var toTankID: UUID?
        var toTankName: String
        var relatedCohortID: UUID?
        var stageRaw: String
        var previousCount: Int?
        var previousStageRaw: String
        var previousStatusRaw: String
        var statusRaw: String
        var createdAt: Date
        var note: String
        var isSample: Bool
        var cohortID: UUID?
    }

    struct BreedingSetRecord: Codable, Equatable, Sendable {
        var id: UUID
        var name: String
        var maleCount: Int
        var femaleCount: Int
        var startedAt: Date
        var endedAt: Date?
        var note: String
        var isSample: Bool
        var sireCohortID: UUID?
        var damCohortID: UUID?
        var tankID: UUID?
        var offspringStrainID: UUID?
    }

    struct EggBatchRecord: Codable, Equatable, Sendable {
        var id: UUID
        var collectedAt: Date
        var eggCount: Int?
        var containerName: String
        var waterTempC: Double?
        var statusRaw: String
        var hatchedAt: Date?
        var hatchedCount: Int?
        var note: String
        var isSample: Bool
        var breedingSetID: UUID?
        var containerID: UUID?
    }

    struct SelectionEventRecord: Codable, Equatable, Sendable {
        var id: UUID
        var date: Date
        var round: Int
        var criteria: [String]
        var keptCount: Int
        var culledCount: Int
        var cullDestinationRaw: String
        var culledCohortID: UUID?
        var note: String
        var isSample: Bool
        var cohortID: UUID?
    }

    struct SaleBackupRecord: Codable, Equatable, Sendable {
        var id: UUID
        var date: Date
        var unitRaw: String
        var quantity: Int
        var unitPrice: Int
        var totalPrice: Int
        var fee: Int
        var shippingCost: Int
        var channelRaw: String
        var statusRaw: String
        var shippedAt: Date?
        var buyerMemo: String
        var note: String
        var breedNameSnapshot: String
        var lineNameSnapshot: String
        var generation: Int
        var isSample: Bool
        var cohortID: UUID?
        var strainID: UUID?
    }

    struct MaintenanceLogRecord: Codable, Equatable, Sendable {
        var id: UUID
        var date: Date
        var kindRaw: String
        var percent: Int?
        var waterTempC: Double?
        var note: String
        var isSample: Bool
        var tankID: UUID?
    }

    struct PhotoRecord: Codable, Equatable, Sendable {
        var id: UUID
        var capturedAt: Date
        var caption: String
        var isCover: Bool
        var isSample: Bool
        var cohortID: UUID?
        var tankID: UUID?
        var strainID: UUID?
        var selectionID: UUID?
    }

    /// 件数の一覧（読み込み前の確認に出す）。
    var counts: Counts {
        Counts(
            tanks: tanks.count, strains: strains.count, cohorts: cohorts.count, sales: sales.count,
            photos: photos.count, others: cohortEvents.count + breedingSets.count + eggBatches.count + selectionEvents.count + maintenanceLogs.count
        )
    }

    struct Counts: Equatable, Sendable {
        var tanks: Int
        var strains: Int
        var cohorts: Int
        var sales: Int
        var photos: Int
        var others: Int
    }
}

enum BackupError: LocalizedError, Equatable {
    case notABackup
    /// 読めなかった理由（調べるための文字列。画面には出さない）。
    case unreadable(String)
    /// 展開してよい場所の外を指すエントリ。
    case unsafeEntry(String)
    case unsupportedVersion(Int)
    case lightweightCannotReplace
    case archiveFailed
    case cancelled

    var errorDescription: String? {
        switch self {
        case .notABackup, .unreadable:
            String(localized: "めだか台帳のバックアップとして読めませんでした。")
        case .unsafeEntry:
            String(localized: "このファイルには、読み込めない場所を指す項目が含まれています。")
        case let .unsupportedVersion(version):
            String(localized: "このバックアップは新しい版のアプリで作られています（版\(version.formatted())）。アプリを更新してから読み込んでください。")
        case .lightweightCannotReplace:
            String(localized: "写真を含まないバックアップは、置き換えでは読み込めません。追記を選んでください。")
        case .archiveFailed:
            String(localized: "バックアップのファイルを作れませんでした。空き容量を確かめてください。")
        case .cancelled:
            String(localized: "中止しました。")
        }
    }
}

extension BackupManifest {
    static func encode(_ manifest: BackupManifest) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(manifest)
    }

    /// manifest.json を読み、版を確かめる。読めない、または未知の版は拒否する。
    static func decode(_ data: Data) throws(BackupError) -> BackupManifest {
        struct Header: Decodable { var schemaVersion: Int }
        let header: Header
        do {
            header = try JSONDecoder().decode(Header.self, from: data)
        } catch {
            throw .notABackup
        }
        guard header.schemaVersion >= 1 else { throw .notABackup }
        guard header.schemaVersion <= currentSchemaVersion else { throw .unsupportedVersion(header.schemaVersion) }
        // 将来の版は、ここで schemaVersion ごとの型に読んでから現在の型へ変換する
        do {
            return try JSONDecoder().decode(BackupManifest.self, from: data)
        } catch {
            throw .unreadable(String(describing: error))
        }
    }
}

/// バックアップのファイルの中の配置。
enum BackupPaths {
    static let manifestName = "manifest.json"
    static let photosDirectoryName = "photos"
    /// 拡張子（ARCHITECTURE.md 5.3）。
    static let fileExtension = "medakabackup"

    /// 展開してよい相対パスか。manifest.json と photos/ の下だけ。絶対パスと、.. を含むものは取り込まない。
    /// 先頭の「./」と、展開先そのもの（空、「.」）は許す。
    static func isSafeEntry(_ path: String) -> Bool {
        guard !path.hasPrefix("/") else { return false }
        let parts = path.split(separator: "/", omittingEmptySubsequences: true).map(String.init).filter { $0 != "." }
        if parts.isEmpty { return true }
        guard !parts.contains("..") else { return false }
        return parts[0] == manifestName || parts[0] == photosDirectoryName
    }

    /// 展開先 roots のどれかを頭に付けた絶対パスのとき、その下の相対パスに直してから判定する。
    static func isSafeEntry(_ path: String, extractingTo roots: [String]) -> Bool {
        if path.hasPrefix("/") {
            for root in roots where !root.isEmpty {
                let prefix = root.hasSuffix("/") ? root : root + "/"
                if path == root { return true }
                if path.hasPrefix(prefix) { return isSafeEntry(String(path.dropFirst(prefix.count))) }
            }
            return false
        }
        return isSafeEntry(path)
    }
}
