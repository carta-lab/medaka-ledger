import Foundation
import Observation
import SwiftData

@MainActor
@Observable
final class CohortCreateModel {
    let strain: Strain
    var count: Int?
    var maleCount: Int?
    var femaleCount: Int?
    var tank: Tank?
    var acquiredAt: Date
    var stage: GrowthStage = .adult
    var label = ""
    var note = ""
    var error: UserFacingError?

    init(strain: Strain) {
        self.strain = strain
        acquiredAt = strain.acquiredAt ?? Date()
    }

    func save(in context: ModelContext) throws {
        CohortOperations.createCohort(
            strain: strain,
            tank: tank,
            count: count,
            maleCount: maleCount,
            femaleCount: femaleCount,
            stage: stage,
            generation: 0,
            acquiredAt: acquiredAt,
            label: label.trimmingCharacters(in: .whitespacesAndNewlines),
            note: note.trimmingCharacters(in: .whitespacesAndNewlines),
            date: acquiredAt,
            in: context
        )
        try context.save()
    }
}
