import Foundation
import Observation
import SwiftData

// 販売台帳の状態と操作（SCREENS.md 8.1）。

@MainActor
@Observable
final class SalesModel {
    var period: SalesPeriod = .thisMonth
    var isAdding = false
    var editing: Sale?
    var isExporting = false
    var salePendingDeletion: Sale?
    var isConfirmingDeletion = false
    var error: UserFacingError?

    /// 期間で絞った販売と、その月別セクション、集計。
    struct Ledger {
        var records: [SaleRecord]
        var sections: [SalesMonthSection]
        var summary: SalesSummary
    }

    func ledger(for sales: [Sale], now: Date = .now, calendar: Calendar = .current) -> Ledger {
        let all = sales.map(SaleOperations.record(of:))
        let filtered = SalesAggregations.filter(all, period: period, now: now, calendar: calendar)
        return Ledger(
            records: filtered,
            sections: SalesAggregations.monthSections(filtered, calendar: calendar),
            summary: SalesAggregations.summary(filtered)
        )
    }

    /// 状態を次へ進める（出品中から売約、売約から発送済）。
    func advance(_ sale: Sale, in context: ModelContext) {
        guard let next = SaleRules.nextStatus(after: sale.status) else { return }
        SaleOperations.setStatus(sale, to: next)
        save(context)
    }

    func cancel(_ sale: Sale, in context: ModelContext) {
        SaleOperations.setStatus(sale, to: .cancelled)
        save(context)
    }

    func askToDelete(_ sale: Sale) {
        salePendingDeletion = sale
        isConfirmingDeletion = true
    }

    func delete(_ sale: Sale, in context: ModelContext) {
        SaleOperations.delete(sale, in: context)
        salePendingDeletion = nil
        save(context)
    }

    private func save(_ context: ModelContext) {
        do {
            try context.save()
        } catch {
            context.rollback()
            error = UserFacingError(error)
        }
    }
}
