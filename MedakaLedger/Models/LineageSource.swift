import Foundation

// SwiftDataの群から、LineageResolver に渡す値を作る（ARCHITECTURE.md 4.2）。
// 群から originBatch.breedingSet をたどり、雄の群と雌の群へさかのぼる。

enum LineageSource {
    /// root から maxDepth 世代前までの祖先の情報を、浅い順に集めて木にする。
    static func tree(for root: Cohort, maxDepth: Int) -> LineageNode? {
        var cohorts: [UUID: Cohort] = [root.id: root]
        var infos: [UUID: LineageCohortInfo] = [:]
        var frontier = [root]
        var level = 0
        while !frontier.isEmpty, level <= min(max(maxDepth, 0), LineageResolver.absoluteMaxDepth) {
            var next: [Cohort] = []
            for cohort in frontier where infos[cohort.id] == nil {
                let set = cohort.originBatch?.breedingSet
                infos[cohort.id] = LineageCohortInfo(
                    id: cohort.id,
                    strainName: cohort.strainName,
                    generation: cohort.generation,
                    hatchedAt: cohort.hatchedAt,
                    sireID: set?.sireCohort?.id,
                    damID: set?.damCohort?.id
                )
                for parent in [set?.sireCohort, set?.damCohort].compactMap({ $0 }) where cohorts[parent.id] == nil {
                    cohorts[parent.id] = parent
                    next.append(parent)
                }
            }
            frontier = next
            level += 1
        }
        return LineageResolver.resolve(root: root.id, maxDepth: maxDepth) { infos[$0] }
    }

    /// ノードの群。タップで群詳細へ移るために使う。
    static func cohort(id: UUID, in root: Cohort) -> Cohort? {
        var seen = Set<UUID>()
        var stack = [root]
        while let current = stack.popLast() {
            if current.id == id { return current }
            guard seen.insert(current.id).inserted else { continue }
            let set = current.originBatch?.breedingSet
            stack.append(contentsOf: [set?.sireCohort, set?.damCohort].compactMap { $0 })
        }
        return nil
    }
}
