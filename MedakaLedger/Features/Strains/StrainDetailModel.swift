import Foundation
import Observation
import SwiftData

@MainActor
@Observable
final class StrainDetailModel {
    var isEditing = false
    var isAddingCohort = false
    var isConfirmingArchive = false
    var showsEndedCohorts = false
    var error: UserFacingError?

    func visibleCohorts(of strain: Strain) -> [Cohort] {
        let cohorts = strain.cohorts ?? []
        return showsEndedCohorts ? cohorts : cohorts.filter(\.isActive)
    }

    func endedCount(of strain: Strain) -> Int {
        (strain.cohorts ?? []).filter { !$0.isActive }.count
    }

    /// 系統は稼働中の群がいてもアーカイブできるが、確認を出す（DECISIONS.md D）。
    func archiveMessage(for strain: Strain) -> String {
        let active = strain.activeCohorts.count
        if active > 0 {
            return String(localized: "飼育中の群が\(active.formatted())つあります。一覧から消えますが、群と過去の記録は残ります。")
        }
        return String(localized: "一覧から消えます。過去の記録からはたどれます。")
    }

    func archive(_ strain: Strain, in context: ModelContext) {
        strain.isArchived = true
        save(context)
    }

    func unarchive(_ strain: Strain, in context: ModelContext) {
        strain.isArchived = false
        save(context)
    }

    private func save(_ context: ModelContext) {
        do {
            try context.save()
        } catch {
            self.error = UserFacingError(error)
        }
    }
}
