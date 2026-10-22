import Foundation
import Observation
import SwiftData

@MainActor
@Observable
final class BreedingSetEditModel {
    var sire: Cohort?
    var dam: Cohort?
    var maleCount: Int? = 1
    var femaleCount: Int? = 2
    var tank: Tank?
    var startedAt = Date()
    var name = ""
    var note = ""
    var movesParents = false
    var error: UserFacingError?

    var canSave: Bool { sire != nil && dam != nil && (maleCount ?? 0) + (femaleCount ?? 0) > 0 }

    /// 容器を選び、親の群のどれかがその容器にいないときだけ、移すかを聞く。
    var canOfferMove: Bool {
        guard let tank else { return false }
        return [sire, dam].compactMap { $0 }.contains { $0.tank?.id != tank.id }
    }

    /// 同系統か交配かで、子の系統についての説明を出す。
    var offspringMessage: String? {
        guard let sire, let dam else { return nil }
        if BreedingOperations.isSameStrain(sire: sire, dam: dam) {
            return String(localized: "子の系統は「\(sire.strainName)」に決まります。")
        }
        return String(localized: "子の系統は最初の孵化記録で決めます。")
    }

    /// 保存できたら true。失敗は利用者向けの文言でアラートに出す。
    func save(in context: ModelContext) -> Bool {
        guard let sire, let dam else { return false }
        do {
            try BreedingOperations.createBreedingSet(
                .init(
                    sire: sire, dam: dam,
                    maleCount: maleCount ?? 0, femaleCount: femaleCount ?? 0,
                    tank: tank, startedAt: startedAt, name: name, note: note,
                    movesParents: movesParents && canOfferMove
                ),
                in: context
            )
            try context.save()
            return true
        } catch {
            // 親の群を1つだけ移した状態などを残さない
            context.rollback()
            self.error = UserFacingError(error)
            return false
        }
    }
}
