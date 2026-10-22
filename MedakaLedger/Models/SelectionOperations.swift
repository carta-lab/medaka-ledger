import Foundation
import SwiftData

// 選別の記録（PRD.md F5、ARCHITECTURE.md 4.3、DECISIONS.md C）。
// 群の匹数は CohortOperations を通して変え、CohortEvent を残す。弾きの行き先が「別容器」なら、弾いた分を新しい群に分割する。

enum SelectionOperations {
    enum OperationError: LocalizedError, Equatable {
        case ledger(LedgerError)
        case cohort(CohortOperations.OperationError)

        var errorDescription: String? {
            switch self {
            case let .ledger(error): error.message
            case let .cohort(error): error.errorDescription
            }
        }
    }

    struct Input {
        var date: Date
        var round: Int
        var criteria: [String]
        var kept: Int
        var culled: Int
        var destination: CullDestination
        /// 弾きの行き先が「別容器」のときの移動先。
        var separateTank: Tank?
        var note: String
        var photos: [ProcessedPhoto] = []
    }

    struct Result {
        var selection: SelectionEvent
        /// 別容器へ分割したときの、弾いた分の群。
        var culledCohort: Cohort?
    }

    @discardableResult
    static func record(for cohort: Cohort, _ input: Input, in context: ModelContext) throws(OperationError) -> Result {
        guard cohort.isActive else { throw .ledger(.notActive) }
        if input.destination == .separateTank, input.separateTank?.id == cohort.tank?.id {
            throw .ledger(.sameTank)
        }
        let plan: SelectionPlan
        do {
            plan = try SelectionPlanner.plan(
                currentCount: cohort.count,
                kept: input.kept,
                culled: input.culled,
                destination: input.destination,
                separateTank: input.separateTank.map { TankRef(id: $0.id, name: $0.name) }
            )
        } catch {
            throw .ledger(error)
        }

        var culledCohort: Cohort?
        if let split = plan.split, let tank = input.separateTank {
            do {
                culledCohort = try CohortOperations.split(cohort, amount: split.amount, to: tank, date: input.date, in: context)
            } catch {
                throw .cohort(error)
            }
        }
        if let adjustment = plan.adjustment {
            do {
                try CohortOperations.changeCount(cohort, change: adjustment, date: input.date, note: String(localized: "選別"), in: context)
            } catch {
                throw .cohort(error)
            }
        }

        let selection = SelectionEvent()
        selection.date = input.date
        selection.round = input.round
        selection.criteria = input.criteria
        selection.keptCount = input.kept
        selection.culledCount = input.culled
        selection.destination = input.destination
        selection.culledCohortID = culledCohort?.id
        selection.note = input.note.trimmingCharacters(in: .whitespacesAndNewlines)
        selection.isSample = cohort.isSample
        context.insert(selection)
        selection.cohort = cohort
        for photo in input.photos {
            PhotoOperations.add(photo, to: .selection(selection), in: context)
        }
        return Result(selection: selection, culledCohort: culledCohort)
    }

    /// 選別の記録だけを削除する。匹数や分割した群は元に戻らない（戻すときはタイムラインの出来事を削除する）。
    static func delete(_ selection: SelectionEvent, in context: ModelContext) {
        context.delete(selection)
    }
}
