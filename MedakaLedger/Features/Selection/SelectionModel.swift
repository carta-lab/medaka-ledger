import Foundation
import Observation
import SwiftData

@MainActor
@Observable
final class SelectionModel {
    var date = Date()
    var round: Int
    var criteria: [String] = []
    var kept: Int?
    var culled: Int?
    var destination: CullDestination = .feed
    var separateTank: Tank?
    var note = ""
    var photos: [ProcessedPhoto] = []
    var error: UserFacingError?

    init(cohort: Cohort) {
        round = SelectionPlanner.suggestedRound(existingRounds: (cohort.selections ?? []).map(\.round))
    }

    var canSave: Bool {
        guard (kept ?? 0) + (culled ?? 0) > 0 else { return false }
        return destination != .separateTank || separateTank != nil
    }

    /// 保存できたら true。失敗したら途中の変更を戻して、理由を出す。
    func save(for cohort: Cohort, in context: ModelContext) -> Bool {
        do {
            try SelectionOperations.record(
                for: cohort,
                .init(
                    date: date, round: round, criteria: criteria,
                    kept: kept ?? 0, culled: culled ?? 0,
                    destination: destination,
                    separateTank: destination == .separateTank ? separateTank : nil,
                    note: note, photos: photos
                ),
                in: context
            )
            try context.save()
            return true
        } catch {
            context.rollback()
            self.error = UserFacingError(error)
            return false
        }
    }
}
