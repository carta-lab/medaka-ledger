import Foundation
import Observation
import SwiftData

@MainActor
@Observable
final class EggBatchModel {
    let fixedSet: BreedingSet?
    var selectedSet: BreedingSet?
    var collectedAt = Date()
    var eggCount: Int?
    var container: Tank?
    var containerName = ""
    var waterTempText = ""
    var note = ""
    var isShowingResult = false
    var resultMessage = ""
    var error: UserFacingError?

    init(breedingSet: BreedingSet?) {
        fixedSet = breedingSet
    }

    var targetSet: BreedingSet? { fixedSet ?? selectedSet }

    var canSave: Bool { targetSet != nil }

    /// 保存して、孵化予定日を知らせる。許可を求める前には理由を一行で示す（CLAUDE.md）。
    func save(in context: ModelContext, settings: AppSettings, needsAuthorization: Bool) {
        guard let set = targetSet else { return }
        guard NumberParsing.isValidOptional(waterTempText) else {
            error = UserFacingError(message: String(localized: "水温は数字で入れてください。"))
            return
        }
        do {
            let batch = try BreedingOperations.recordEggBatch(
                in: set,
                collectedAt: collectedAt,
                eggCount: eggCount,
                container: container,
                containerName: containerName,
                waterTempC: NumberParsing.double(from: waterTempText),
                note: note,
                context: context
            )
            try context.save()
            var message = BatchPredictionInfo(batch: batch, settings: settings).dateText
            message = String(localized: "孵化予定日：\(message)")
            if needsAuthorization {
                message += "\n" + String(localized: "孵化予定日の朝にお知らせするため、次に通知の許可を求めます。")
            }
            resultMessage = message
            isShowingResult = true
        } catch {
            context.rollback()
            self.error = UserFacingError(error)
        }
    }
}
