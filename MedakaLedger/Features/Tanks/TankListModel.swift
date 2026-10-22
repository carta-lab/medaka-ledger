import Foundation
import Observation

@MainActor
@Observable
final class TankListModel {
    var searchText = ""
    var isCreating = false
    var isReordering = false

    /// 検索で絞り込んでから置き場所ごとに分ける。系統名は今いる群からたどる（DECISIONS.md G 3-3）。
    func sections(for tanks: [Tank]) -> [LocationSection<Tank>] {
        let filtered = tanks.filter { tank in
            Aggregations.matches(query: searchText, in: [tank.name] + tank.activeCohorts.flatMap { cohort in
                [cohort.strain?.breedName ?? "", cohort.strain?.lineName ?? "", cohort.label]
            })
        }
        return Aggregations.sectionsByLocation(filtered, location: { $0.location }, unsetTitle: String(localized: "場所未設定"))
    }
}
