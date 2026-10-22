import Foundation

// 現在のデータ容量（SCREENS.md 12）。ストアのフォルダの大きさ。写真の本体もここに入る。

enum StorageUsage {
    static func bytes() -> Int64 {
        guard let url = try? ModelStore.storeURL().deletingLastPathComponent() else { return 0 }
        return bytes(in: url)
    }

    static func bytes(in directory: URL) -> Int64 {
        let keys: [URLResourceKey] = [.isRegularFileKey, .fileSizeKey]
        guard let enumerator = FileManager.default.enumerator(at: directory, includingPropertiesForKeys: keys) else { return 0 }
        var total: Int64 = 0
        for case let url as URL in enumerator {
            guard let values = try? url.resourceValues(forKeys: Set(keys)), values.isRegularFile == true else { continue }
            total += Int64(values.fileSize ?? 0)
        }
        return total
    }

    static func text(_ bytes: Int64) -> String {
        ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
    }
}
