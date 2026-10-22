import Foundation

// 写真の縮小と代表写真の選び方（PRD.md F9、DECISIONS.md F）。画像の処理そのものは Features/Photos/PhotoProcessor.swift。

enum PhotoRules {
    /// 保存時の長辺（ピクセル）。
    static let maxLongSide = 1600
    /// サムネイルの長辺。一覧ではこれだけを読む（CLAUDE.md）。
    static let thumbnailLongSide = 320
    /// 1枚あたりの目安（バイト）。
    static let byteBudget = 500 * 1024
    /// JPEGの品質。目安に収まるまで、上から順に試す。
    static let jpegQualities: [Double] = [0.8, 0.7, 0.6, 0.5, 0.4]

    /// 長辺が maxLongSide を超えるときだけ縮小した大きさ。縮小のみで、拡大はしない。
    static func fittedSize(width: Int, height: Int, maxLongSide: Int) -> (width: Int, height: Int) {
        guard width > 0, height > 0, maxLongSide > 0 else { return (max(width, 0), max(height, 0)) }
        let longSide = max(width, height)
        guard longSide > maxLongSide else { return (width, height) }
        let scale = Double(maxLongSide) / Double(longSide)
        return (max(1, Int((Double(width) * scale).rounded())), max(1, Int((Double(height) * scale).rounded())))
    }

    /// 代表写真：代表に設定した写真、なければ撮影日の最も古い写真。
    static func coverID(of photos: [(id: UUID, capturedAt: Date, isCover: Bool)]) -> UUID? {
        if let cover = photos.first(where: { $0.isCover }) { return cover.id }
        return photos.min { $0.capturedAt < $1.capturedAt }?.id
    }
}
