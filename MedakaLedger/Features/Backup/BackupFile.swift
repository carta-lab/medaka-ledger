import SwiftUI
import UniformTypeIdentifiers

// バックアップのファイルの型（ARCHITECTURE.md 5.3）。Info.plist の UTExportedTypeDeclarations（project.yml）と同じ識別子にする。

extension UTType {
    static let medakaBackup = UTType(exportedAs: "com.meldcarta.medakaledger.backup", conformingTo: .data)
}

/// 作成済みのバックアップのファイルを fileExporter に渡すための入れ物。
struct BackupFileDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.medakaBackup] }
    static var writableContentTypes: [UTType] { [.medakaBackup] }

    var url: URL?

    init(url: URL? = nil) {
        self.url = url
    }

    init(configuration: ReadConfiguration) throws {
        url = nil
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        guard let url else { throw BackupError.archiveFailed }
        return try FileWrapper(url: url, options: .immediate)
    }
}
