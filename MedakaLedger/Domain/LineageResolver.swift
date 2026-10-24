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

    /// 木のノードの数の上限。雄と雌に同じ群を使った累代は、世代ごとに枝が倍になる。
    /// 20世代だと200万を超えて画面が固まるので、収まる深さまでで止める（DECISIONS.md H 第5週）。
    static let defaultNodeBudget = 300

    /// root から maxDepth 世代前までの祖先をたどる。ただし、ノードの数が nodeBudget に収まる深さまで。
    /// 循環の判定は、いまたどっている経路の上だけで行う。雄側と雌側に同じ群が出てもよい（同系統の累代）。
    static func resolve(root: UUID, maxDepth: Int, nodeBudget: Int = defaultNodeBudget, lookup: (UUID) -> LineageCohortInfo?) -> LineageNode? {
        let limit = min(max(maxDepth, 0), absoluteMaxDepth)
        let depth = fittingDepth(root: root, limit: limit, nodeBudget: nodeBudget, lookup: lookup)
        return build(id: root, level: 0, limit: depth, path: [], lookup: lookup)
    }

    /// ノードの数が nodeBudget 以下になる、いちばん深い世代数（limit まで、最低1）。
    /// 同じ群を雄と雌の両方に使うと枝が重複するので、重複を含めて数える。循環は数えない（多めに見積もる）。
    static func fittingDepth(root: UUID, limit: Int, nodeBudget: Int, lookup: (UUID) -> LineageCohortInfo?) -> Int {
        guard limit > 1 else { return max(limit, 0) }
        struct Key: Hashable {
            var id: UUID
            var remaining: Int
        }
        var memo: [Key: Int] = [:]
        func count(_ id: UUID, _ remaining: Int) -> Int {
            guard let info = lookup(id) else { return 0 }
            let key = Key(id: id, remaining: remaining)
            if let cached = memo[key] { return cached }
            var total = 1
            if remaining > 0 {
                total += info.sireID.map { count($0, remaining - 1) } ?? 0
                total += info.damID.map { count($0, remaining - 1) } ?? 0
            }
            memo[key] = total
            return total
        }
        for depth in stride(from: limit, through: 1, by: -1) where count(root, depth) <= nodeBudget {
            return depth
        }
        return 1
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
