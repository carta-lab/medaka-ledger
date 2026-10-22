import Foundation

// 血統（ARCHITECTURE.md 4.2、DECISIONS.md F）。群から親魚セットをたどり、雄側と雌側の祖先を木にする。
// 値型だけで計算する。SwiftDataからの読み出しは Models/LineageSource.swift。

struct LineageCohortInfo: Equatable, Sendable {
    var id: UUID
    var strainName: String
    var generation: Int
    var hatchedAt: Date?
    /// この群を生んだ親魚セットの雄と雌の群。入手個体は nil。
    var sireID: UUID?
    var damID: UUID?
}

/// 木の1つのノード。自分自身を含む構造なので、変更しないクラスにしている。
final class LineageNode: Sendable {
    let info: LineageCohortInfo
    let sire: LineageNode?
    let dam: LineageNode?
    /// 深さの上限で、親がいるのに先をたどらなかった。
    let isTruncated: Bool
    /// 経路上に同じ群が現れたので打ち切った（循環データ）。
    let isCycle: Bool

    init(info: LineageCohortInfo, sire: LineageNode? = nil, dam: LineageNode? = nil, isTruncated: Bool = false, isCycle: Bool = false) {
        self.info = info
        self.sire = sire
        self.dam = dam
        self.isTruncated = isTruncated
        self.isCycle = isCycle
    }

    /// 根を深さ0として、いちばん深い祖先の深さ。
    var depth: Int {
        1 + max(sire?.depth ?? -1, dam?.depth ?? -1)
    }

    /// 木のどこかが深さの上限で切れているか。
    var hasTruncation: Bool {
        isTruncated || (sire?.hasTruncation ?? false) || (dam?.hasTruncation ?? false)
    }
}

enum LineageResolver {
    /// 深さの上限の絶対値。Proで「無制限」でも、壊れたデータで止まらないようにする。
    static let absoluteMaxDepth = 20

    /// 祖先の世代数の上限。Freeは2、Proは無制限（ARCHITECTURE.md 4.4）。
    static func depthLimit(isPro: Bool) -> Int {
        isPro ? absoluteMaxDepth : FreeLimits.lineageDepth
    }

    /// root から maxDepth 世代前までの祖先をたどる。
    /// 循環の判定は、いまたどっている経路の上だけで行う。雄側と雌側に同じ群が出てもよい（同系統の累代）。
    static func resolve(root: UUID, maxDepth: Int, lookup: (UUID) -> LineageCohortInfo?) -> LineageNode? {
        let limit = min(max(maxDepth, 0), absoluteMaxDepth)
        return build(id: root, level: 0, limit: limit, path: [], lookup: lookup)
    }

    private static func build(id: UUID, level: Int, limit: Int, path: [UUID], lookup: (UUID) -> LineageCohortInfo?) -> LineageNode? {
        guard let info = lookup(id) else { return nil }
        if path.contains(id) {
            return LineageNode(info: info, isCycle: true)
        }
        let hasParents = info.sireID != nil || info.damID != nil
        guard hasParents else { return LineageNode(info: info) }
        if level >= limit {
            return LineageNode(info: info, isTruncated: true)
        }
        let next = path + [id]
        let sire = info.sireID.flatMap { build(id: $0, level: level + 1, limit: limit, path: next, lookup: lookup) }
        let dam = info.damID.flatMap { build(id: $0, level: level + 1, limit: limit, path: next, lookup: lookup) }
        return LineageNode(info: info, sire: sire, dam: dam)
    }
}
