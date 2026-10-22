import Foundation
import Observation
import SwiftData

@MainActor
@Observable
final class BreedingSetDetailModel {
    var isRecordingBatch = false
    var isConfirmingEnd = false
    var isConfirmingDiscard = false
    var hatchingBatch: EggBatch?
    var batchPendingDiscard: EggBatch?
    var error: UserFacingError?

    func end(_ set: BreedingSet, in context: ModelContext) {
        BreedingOperations.end(set, on: Date())
        save(context)
    }

    func askToDiscard(_ batch: EggBatch) {
        batchPendingDiscard = batch
        isConfirmingDiscard = true
    }

    func discard(_ batch: EggBatch, in context: ModelContext) {
        BreedingOperations.discard(batch)
        batchPendingDiscard = nil
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
