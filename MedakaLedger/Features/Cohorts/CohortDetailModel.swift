import Foundation
import Observation
import SwiftData

@MainActor
@Observable
final class CohortDetailModel {
    enum Sheet: String, Identifiable {
        case move, split, count, stage, merge, edit
        var id: String { rawValue }
    }

    var activeSheet: Sheet?
    var isAskingToEnd = false
    var isConfirmingCohortDeletion = false
    var eventPendingDeletion: CohortEvent?
    var isConfirmingEventDeletion = false
    var error: UserFacingError?
    private var countBeforeSheet: Int?

    func open(_ sheet: Sheet, cohort: Cohort) {
        countBeforeSheet = cohort.count
        activeSheet = sheet
    }

    /// 操作で匹数が0になったら「この群を終了しますか（完売、全滅、そのまま）」を出す（DECISIONS.md C）。
    func sheetDismissed(cohort: Cohort) {
        defer { countBeforeSheet = nil }
        guard cohort.isActive, cohort.count == 0, countBeforeSheet != 0 else { return }
        isAskingToEnd = true
    }

    func end(_ cohort: Cohort, as status: CohortStatus, in context: ModelContext) {
        perform(context) { () throws(CohortOperations.OperationError) in
            try CohortOperations.changeStatus(cohort, to: status, date: Date(), in: context)
        }
    }

    func askToDelete(_ event: CohortEvent) {
        eventPendingDeletion = event
        isConfirmingEventDeletion = true
    }

    func deletionMessage(for event: CohortEvent) -> String {
        switch event.kind {
        case .split:
            event.countDelta < 0
                ? String(localized: "分けた先の群も消え、匹数が元に戻ります。")
                : String(localized: "この群は消え、分けた元の群の匹数が元に戻ります。")
        case .merge:
            String(localized: "統合を取り消し、両方の群を元に戻します。")
        case .move:
            String(localized: "移動前の容器に戻します。")
        default:
            String(localized: "匹数、段階、状態を記録の前に戻します。")
        }
    }

    func delete(_ event: CohortEvent, in context: ModelContext) {
        perform(context) { () throws(CohortOperations.OperationError) in
            try CohortOperations.deleteEvent(event, in: context)
        }
        eventPendingDeletion = nil
    }

    func deleteCohort(_ cohort: Cohort, in context: ModelContext) {
        CohortOperations.deleteCohort(cohort, in: context)
        do {
            try context.save()
        } catch {
            self.error = UserFacingError(error, title: String(localized: "削除できませんでした"))
        }
    }

    func hatchedText(_ date: Date) -> String {
        let days = DayCount.days(from: date, to: Date(), calendar: .current)
        return String(localized: "\(CohortText.date(date))（\(days.formatted())日目）")
    }

    func acquiredText(_ date: Date) -> String {
        let days = DayCount.days(from: date, to: Date(), calendar: .current)
        return String(localized: "\(CohortText.date(date))（入手から\(days.formatted())日）")
    }

    private func perform(_ context: ModelContext, _ body: () throws(CohortOperations.OperationError) -> Void) {
        do {
            try body()
            try context.save()
        } catch {
            self.error = UserFacingError(error)
        }
    }
}
