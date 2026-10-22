import Foundation
import SwiftData

// ストアの作成。保存先はApp Groupのコンテナ（DECISIONS.md A）。
// App Groupが使えない場合、シミュレータとDebugビルドでは Application Support に保存する（DECISIONS.md H）。

enum ModelStore {
    static let appGroupID = "group.com.meldcarta.medakaledger"
    static let storeFileName = "MedakaLedger.store"

    enum StoreError: LocalizedError {
        case appGroupUnavailable

        var errorDescription: String? {
            switch self {
            case .appGroupUnavailable:
                String(localized: "データの保存場所を用意できませんでした。アプリを入れ直してもうまくいかない場合はお問い合わせください。")
            }
        }
    }

    static var schema: Schema { Schema(versionedSchema: SchemaV1.self) }

    static func makeContainer(inMemory: Bool = false) throws -> ModelContainer {
        let configuration: ModelConfiguration
        if inMemory {
            configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        } else {
            let url = try storeURL()
            configuration = ModelConfiguration(schema: schema, url: url, cloudKitDatabase: .none)
        }
        return try ModelContainer(for: schema, migrationPlan: MedakaMigrationPlan.self, configurations: [configuration])
    }

    static func storeURL() throws -> URL {
        let directory = try storeDirectory()
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory.appending(path: storeFileName, directoryHint: .notDirectory)
    }

    private static func storeDirectory() throws -> URL {
        if let group = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupID) {
            return group.appending(path: "Library/Application Support", directoryHint: .isDirectory)
        }
        #if DEBUG || targetEnvironment(simulator)
        return URL.applicationSupportDirectory
        #else
        throw StoreError.appGroupUnavailable
        #endif
    }
}
