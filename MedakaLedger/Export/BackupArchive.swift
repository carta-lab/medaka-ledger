import AppleArchive
import Foundation
import System

// バックアップのファイル化（ARCHITECTURE.md 5.3）。manifest.json と photos/ のフォルダを、Apple Archive（LZFSE）の1ファイルにまとめる。

enum BackupArchive {
    static let manifestName = "manifest.json"
    static let photosDirectoryName = "photos"
    /// 拡張子と型の識別子（ARCHITECTURE.md 5.3）。
    static let fileExtension = "medakabackup"

    /// directory の中身をまとめて file に書く。
    static func create(from directory: URL, to file: URL) throws {
        try? FileManager.default.removeItem(at: file)
        guard
            let writeStream = ArchiveByteStream.fileStream(
                path: FilePath(file.path), mode: .writeOnly, options: [.create, .truncate], permissions: FilePermissions(rawValue: 0o644)
            )
        else { throw BackupError.archiveFailed }
        defer { try? writeStream.close() }
        guard let compressStream = ArchiveByteStream.compressionStream(using: .lzfse, writingTo: writeStream) else { throw BackupError.archiveFailed }
        defer { try? compressStream.close() }
        guard let encodeStream = ArchiveStream.encodeStream(writingTo: compressStream) else { throw BackupError.archiveFailed }
        defer { try? encodeStream.close() }
        guard let keySet = ArchiveHeader.FieldKeySet("TYP,PAT,LNK,DEV,DAT,UID,GID,MOD,FLG,MTM,BTM,CTM") else { throw BackupError.archiveFailed }
        try encodeStream.writeDirectoryContents(archiveFrom: FilePath(directory.path), keySet: keySet)
    }

    /// file を directory に展開する。manifest.json と photos/ の外へ書こうとするエントリ（絶対パス、..）は取り込まない。
    static func extract(from file: URL, to directory: URL) throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        guard
            let readStream = ArchiveByteStream.fileStream(path: FilePath(file.path), mode: .readOnly, options: [], permissions: [])
        else { throw BackupError.notABackup }
        defer { try? readStream.close() }
        guard let decompressStream = ArchiveByteStream.decompressionStream(readingFrom: readStream) else { throw BackupError.notABackup }
        defer { try? decompressStream.close() }
        guard let decodeStream = ArchiveStream.decodeStream(readingFrom: decompressStream) else { throw BackupError.notABackup }
        defer { try? decodeStream.close() }
        guard
            let extractStream = ArchiveStream.extractStream(
                extractingTo: FilePath(directory.path),
                selectUsing: { message, path, _ in
                    guard message == .extractBegin else { return .ok }
                    return isSafeEntry(path.string) ? .ok : .cancel
                },
                flags: [.ignoreOperationNotPermitted]
            )
        else { throw BackupError.archiveFailed }
        defer { try? extractStream.close() }
        do {
            _ = try ArchiveStream.process(readingFrom: decodeStream, writingTo: extractStream)
        } catch {
            throw BackupError.notABackup
        }
    }

    /// 展開してよい相対パスか。manifest.json と photos/ の下だけ。
    static func isSafeEntry(_ path: String) -> Bool {
        guard !path.hasPrefix("/") else { return false }
        let parts = path.split(separator: "/", omittingEmptySubsequences: true).map(String.init)
        guard let first = parts.first, !parts.contains(".."), !parts.contains(".") else { return false }
        return first == manifestName || first == photosDirectoryName
    }
}
