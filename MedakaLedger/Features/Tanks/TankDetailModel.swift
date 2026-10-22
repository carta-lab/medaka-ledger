import Foundation
import Observation
import SwiftData

@MainActor
@Observable
final class TankDetailModel {
    var isEditing = false
    var isConfirmingArchive = false
    var movingCohort: Cohort?
    var error: UserFacingError?

    /// 稼働中の群がいる容器はアーカイブできない（DECISIONS.md D）。
    func requestArchive(_ tank: Tank) {
        if tank.activeCohorts.isEmpty {
            isConfirmingArchive = true
        } else {
            error = UserFacingError(
                title: String(localized: "アーカイブできません"),
                message: String(localized: "先に群を移動してください。")
            )
        }
    }

    func archive(_ tank: Tank, in context: ModelContext) {
        tank.isArchived = true
        save(context)
    }

    func unarchive(_ tank: Tank, in context: ModelContext) {
        tank.isArchived = false
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
