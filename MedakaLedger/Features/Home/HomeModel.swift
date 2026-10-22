import Foundation
import Observation

@MainActor
@Observable
final class HomeModel {
    var isShowingDebugMenu = false

    /// 越冬中の群：屋外の容器にいる飼育中の群（DECISIONS.md E）。
    func winteringCohorts(from activeCohorts: [Cohort]) -> [Cohort] {
        activeCohorts.filter { cohort in
            guard let tank = cohort.tank, !tank.isArchived else { return false }
            return tank.placement == .outdoor
        }
    }
}
