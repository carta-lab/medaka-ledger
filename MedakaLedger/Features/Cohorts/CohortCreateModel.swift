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

    /// 系統を作った直後は系統の入手日を引き継ぎ、それ以外は今日を初期値にする（CLAUDE.md：日付の初期値は今日）。
    init(strain: Strain, inheritsStrainDate: Bool) {
        self.strain = strain
        acquiredAt = inheritsStrainDate ? (strain.acquiredAt ?? Date()) : Date()
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
