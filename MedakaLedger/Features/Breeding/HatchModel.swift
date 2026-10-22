import Foundation
import Observation
import SwiftData

@MainActor
@Observable
final class HatchModel {
    enum StrainMode: Hashable { case createNew, existing }

    let batch: EggBatch
    var hatchedAt = Date()
    var hatchedCount: Int?
    var tank: Tank?
    var label = ""
    var note = ""
    var addTo: Cohort?
    var strainMode: StrainMode = .createNew
    var newBreedName: String
    var newLineName = ""
    var existingStrain: Strain?
    var error: UserFacingError?

    init(batch: EggBatch) {
        self.batch = batch
        if let sire = batch.breedingSet?.sireCohort, let dam = batch.breedingSet?.damCohort {
            newBreedName = BreedingOperations.defaultChildBreedName(sire: sire, dam: dam)
        } else {
            newBreedName = ""
        }
    }

    /// 交配で、まだ子の系統が決まっていないとき。
    var needsChildStrain: Bool { batch.breedingSet?.offspringStrain == nil }

    /// このロットから既に生まれた、飼育中の群。2回目以降の孵化で足す先の候補。
    var existingCohorts: [Cohort] {
        (batch.resultCohorts ?? []).filter(\.isActive).sorted { $0.createdAt < $1.createdAt }
    }

    var canSave: Bool {
        guard addTo != nil || tank != nil else { return false }
        guard addTo == nil, needsChildStrain else { return true }
        switch strainMode {
        case .createNew: return !newBreedName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        case .existing: return existingStrain != nil
        }
    }

    /// 保存できたら true。
    func save(in context: ModelContext) -> Bool {
        let choice: BreedingOperations.ChildStrainChoice?
        if needsChildStrain, addTo == nil {
            switch strainMode {
            case .createNew:
                choice = .createNew(breedName: newBreedName, lineName: newLineName)
            case .existing:
                choice = existingStrain.map { .existing($0) }
            }
        } else {
            choice = nil
        }
        do {
            try BreedingOperations.recordHatch(
                of: batch,
                .init(hatchedAt: hatchedAt, hatchedCount: hatchedCount, tank: tank, label: label, note: note, childStrain: choice, addTo: addTo),
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
