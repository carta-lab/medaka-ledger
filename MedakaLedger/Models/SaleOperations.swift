import Foundation
import SwiftData

// 販売（PRD.md F6、SCREENS.md 8.2）。群を指定した販売は、確認のうえ群の匹数を減らす。
// 匹数を変える操作は CohortOperations（CountLedger）を通し、群の出来事を残す。

enum SaleOperations {
    enum OperationError: LocalizedError, Equatable {
        case invalidQuantity
        case negativeAmount
        case tooLarge
        case cohort(CohortOperations.OperationError)

        var errorDescription: String? {
            switch self {
            case .invalidQuantity: String(localized: "数量は1以上で入れてください。")
            case .negativeAmount: String(localized: "金額は0円以上で入れてください。")
            case .tooLarge: String(localized: "数量か金額が大きすぎます。数量は100万まで、金額は1兆円までです。")
            case let .cohort(error): error.errorDescription
            }
        }
    }

    /// 入力。cohort を選ぶと系統と世代が入る。strain は群を選ばないときの系統。
    struct Input {
        var date: Date
        var cohort: Cohort?
        var strain: Strain?
        var unit: SaleUnit = .fish
        var quantity: Int = 1
        var unitPrice: Int = 0
        var totalPrice: Int = 0
        var fee: Int = 0
        var shippingCost: Int = 0
        var channel: SaleChannel = .yahooAuction
        var status: SaleStatus = .sold
        var shippedAt: Date?
        var buyerMemo: String = ""
        var note: String = ""
        /// 稚魚まとめで減らす匹数。
        var bundleFishCount: Int?
    }

    /// 群から減らす匹数。群を選んでいないとき、卵のときは0。
    static func fishToDeduct(_ input: Input) -> Int {
        guard input.cohort != nil else { return 0 }
        return SaleRules.fishToDeduct(unit: input.unit, quantity: input.quantity, bundleFishCount: input.bundleFishCount)
    }

    /// 販売を作る。reducesCohort が true で減らす匹数が1以上のときは、先に群の匹数を減らす。
    /// 減らせなければ（匹数を超える、群が飼育中でない）何も作らずに止める。
    @discardableResult
    static func record(_ input: Input, reducesCohort: Bool, in context: ModelContext) throws(OperationError) -> Sale {
        try validate(input)
        let deduct = fishToDeduct(input)
        if reducesCohort, deduct > 0, let cohort = input.cohort {
            do {
                try CohortOperations.changeCount(
                    cohort,
                    change: .decrease(deduct, reason: .other),
                    date: input.date,
                    note: String(localized: "販売（\(input.unit.label)×\(input.quantity.formatted())）"),
                    in: context
                )
            } catch {
                throw .cohort(error)
            }
        }
        let sale = Sale()
        sale.isSample = input.cohort?.isSample ?? input.strain?.isSample ?? false
        context.insert(sale)
        apply(input, to: sale)
        sale.cohort = input.cohort
        sale.strain = input.cohort?.strain ?? input.strain
        snapshot(sale)
        return sale
    }

    /// 販売の内容を直す。群と系統は変えない。群の匹数は変えない。
    static func update(_ sale: Sale, with input: Input) throws(OperationError) {
        try validate(input)
        apply(input, to: sale)
    }

    /// 状態を変える。発送済にするとき、発送日が無ければ今日にする。
    static func setStatus(_ sale: Sale, to status: SaleStatus, today: Date = .now) {
        sale.status = status
        if status == .shipped, sale.shippedAt == nil {
            sale.shippedAt = today
        }
    }

    static func delete(_ sale: Sale, in context: ModelContext) {
        context.delete(sale)
    }

    static func record(of sale: Sale) -> SaleRecord {
        SaleRecord(
            id: sale.id, date: sale.date, status: sale.status, channel: sale.channel, unit: sale.unit,
            quantity: sale.quantity, unitPrice: sale.unitPrice, totalPrice: sale.totalPrice, fee: sale.fee,
            shippingCost: sale.shippingCost, shippedAt: sale.shippedAt, buyerMemo: sale.buyerMemo, note: sale.note,
            breedName: sale.breedNameSnapshot, lineName: sale.lineNameSnapshot, generation: sale.generation
        )
    }

    // MARK: - 内部

    private static func validate(_ input: Input) throws(OperationError) {
        guard input.quantity >= 1 else { throw .invalidQuantity }
        guard input.unitPrice >= 0, input.totalPrice >= 0, input.fee >= 0, input.shippingCost >= 0 else { throw .negativeAmount }
        let amounts = [input.unitPrice, input.totalPrice, input.fee, input.shippingCost]
        guard input.quantity <= SaleRules.maxQuantity, (input.bundleFishCount ?? 0) <= SaleRules.maxQuantity,
              amounts.allSatisfy({ $0 <= SaleRules.maxAmount })
        else { throw .tooLarge }
    }

    private static func apply(_ input: Input, to sale: Sale) {
        sale.date = input.date
        sale.unit = input.unit
        sale.quantity = input.quantity
        sale.unitPrice = input.unitPrice
        sale.totalPrice = input.totalPrice
        sale.fee = input.fee
        sale.shippingCost = input.shippingCost
        sale.channel = input.channel
        sale.status = input.status
        sale.shippedAt = input.shippedAt
        sale.buyerMemo = input.buyerMemo.trimmingCharacters(in: .whitespacesAndNewlines)
        sale.note = input.note.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// 集計とCSV用に、品種名、系統名、世代を販売に写す（DECISIONS.md F）。系統を後から直しても過去の販売は変わらない。
    private static func snapshot(_ sale: Sale) {
        sale.breedNameSnapshot = sale.strain?.breedName ?? ""
        sale.lineNameSnapshot = sale.strain?.lineName ?? ""
        sale.generation = sale.cohort?.generation ?? 0
    }
}
