import AppleArchive
import Foundation
import System

// バックアップのファイル化（ARCHITECTURE.md 5.3）。manifest.json と photos/ のフォルダを、Apple Archive（LZFSE）の1ファイルにまとめる。

enum BackupArchive {
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
        // 展開先として、同じ場所を指す別の書き方（/var と /private/var）も許す
        let roots = [directory.path, directory.resolvingSymlinksInPath().path, "/private" + directory.path]
        let rejected = RejectedEntry()
        guard
            let extractStream = ArchiveStream.extractStream(
                extractingTo: FilePath(directory.path),
                selectUsing: { message, path, _ in
                    guard message == .extractBegin else { return .ok }
                    if BackupPaths.isSafeEntry(path.string, extractingTo: roots) { return .ok }
                    rejected.path = path.string
                    return .cancel
                },
                flags: [.ignoreOperationNotPermitted]
            )
        else { throw BackupError.archiveFailed }
        defer { try? extractStream.close() }
        do {
            _ = try ArchiveStream.process(readingFrom: decodeStream, writingTo: extractStream)
        } catch {
            if let path = rejected.path { throw BackupError.unsafeEntry(path) }
            throw BackupError.unreadable(String(describing: error))
        }
        if let path = rejected.path { throw BackupError.unsafeEntry(path) }
    }
}

/// 展開を断ったエントリの記録。展開の途中で別のスレッドから書かれ、終わってから読む。
private final class RejectedEntry: @unchecked Sendable {
    private let lock = NSLock()
    private var value: String?

    var path: String? {
        get { lock.withLock { value } }
        set { lock.withLock { value = newValue } }
    }
}
