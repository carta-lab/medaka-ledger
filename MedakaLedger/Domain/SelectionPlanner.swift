import Foundation

// 選別の記録で、群の匹数をどう変えるかの計画（ARCHITECTURE.md 4.3、PRD.md F5、DECISIONS.md C）。
// 値型だけで計算する。適用は Models/SelectionOperations.swift。

struct SelectionPlan: Equatable, Sendable {
    /// 弾いた分を別容器へ分割するとき、その匹数と移動先。
    var split: (amount: Int, tank: TankRef)?
    /// 分割の後（分割しないときは最初）に、群の匹数を残し数にそろえる操作。変えなくてよいときは nil。
    var adjustment: CountLedger.CountChange?

    static func == (lhs: SelectionPlan, rhs: SelectionPlan) -> Bool {
        lhs.split?.amount == rhs.split?.amount && lhs.split?.tank == rhs.split?.tank && lhs.adjustment == rhs.adjustment
    }
}

enum SelectionPlanner {
    /// 選別の回数。1、2、3、その他は0（DECISIONS.md F）。
    static let otherRound = 0

    /// 回数の初期値：これまでの選別の次。3回までで、それ以降は「その他」。
    static func suggestedRound(existingRounds: [Int]) -> Int {
        let next = existingRounds.filter { (1...3).contains($0) }.max().map { $0 + 1 } ?? 1
        return next <= 3 ? next : otherRound
    }

    /// 匹数が分かっている群は、残し数が今の匹数を超えると止める（増やすなら計数修正を使う）。
    static func plan(
        currentCount: Int?,
        kept: Int,
        culled: Int,
        destination: CullDestination,
        separateTank: TankRef?
    ) throws(LedgerError) -> SelectionPlan {
        guard kept >= 0, culled >= 0, kept + culled > 0 else { throw .invalidAmount }
        if let currentCount, kept > currentCount { throw .exceedsCount(current: currentCount) }

        var plan = SelectionPlan(split: nil, adjustment: nil)
        var countAfterSplit = currentCount

        if destination == .separateTank {
            guard let separateTank, culled > 0 else { throw .invalidAmount }
            if let currentCount, culled > currentCount { throw .exceedsCount(current: currentCount) }
            plan.split = (culled, separateTank)
            countAfterSplit = currentCount.map { $0 - culled }
        }

        if let countAfterSplit {
            let delta = kept - countAfterSplit
            if delta != 0 { plan.adjustment = .adjust(delta) }
        } else {
            plan.adjustment = .recount(kept)
        }
        return plan
    }
}
