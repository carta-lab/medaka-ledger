import Foundation
import Observation
import SwiftData

// 販売記録シートの状態と保存（SCREENS.md 8.2）。

@MainActor
@Observable
final class SaleFormModel {
    let editing: Sale?
    var date = Date()
    var cohort: Cohort?
    var strain: Strain?
    var unit: SaleUnit = .fish
    var quantity: Int? = 1
    var unitPrice: Int?
    /// 空のときは数量×単価で自動計算する。
    var manualTotal: Int?
    var fee: Int?
    var shippingCost: Int?
    var channel: SaleChannel = .yahooAuction
    var status: SaleStatus = .sold
    var hasShippedAt = false
    var shippedAt = Date()
    var buyerMemo = ""
    var note = ""
    /// 稚魚まとめで群から減らす匹数。
    var bundleFishCount: Int?

    var error: UserFacingError?
    var isAskingToReduce = false
    var isAskingToEnd = false
    private(set) var savedCohort: Cohort?

    init(cohort: Cohort? = nil, sale: Sale? = nil) {
        editing = sale
        if let sale {
            date = sale.date
            self.cohort = sale.cohort
            strain = sale.strain
            unit = sale.unit
            quantity = sale.quantity
            unitPrice = sale.unitPrice
            manualTotal = sale.totalPrice == sale.quantity * sale.unitPrice ? nil : sale.totalPrice
            fee = sale.fee == 0 ? nil : sale.fee
            shippingCost = sale.shippingCost == 0 ? nil : sale.shippingCost
            channel = sale.channel
            status = sale.status
            hasShippedAt = sale.shippedAt != nil
            shippedAt = sale.shippedAt ?? Date()
            buyerMemo = sale.buyerMemo
            note = sale.note
        } else {
            self.cohort = cohort
            strain = cohort?.strain
        }
    }

    var isEditing: Bool { editing != nil }

    var autoTotal: Int {
        SaleRules.defaultTotal(quantity: quantity ?? 0, unitPrice: unitPrice ?? 0)
    }

    var total: Int { manualTotal ?? autoTotal }

    var net: Int { SaleRules.net(total: total, fee: fee ?? 0, shipping: shippingCost ?? 0) }

    /// 群から減らす匹数。
    var fishToDeduct: Int { SaleOperations.fishToDeduct(input()) }

    /// 群を選んだ稚魚まとめは、減らす匹数が要る。
    var canSave: Bool {
        guard (quantity ?? 0) >= 1 else { return false }
        if !isEditing, cohort != nil, unit == .fryBundle, (bundleFishCount ?? 0) < 1 { return false }
        return true
    }

    /// 新しい販売で、匹数を減らす確認が要るか。
    var needsReduceConfirmation: Bool {
        !isEditing && cohort != nil && fishToDeduct > 0
    }

    /// 確認のメッセージ。未計数の群は匹数が変わらない。
    var reduceMessage: String {
        guard let cohort else { return "" }
        let name = "\(cohort.strainName) \(cohort.generationLabel)"
        guard let count = cohort.count else {
            return String(localized: "「\(name)」は未計数なので、記録だけが残ります。")
        }
        let deduct = fishToDeduct
        return String(localized: "「\(name)」を\(count.formatted())匹から\(max(count - deduct, 0).formatted())匹にします。")
    }

    func input() -> SaleOperations.Input {
        SaleOperations.Input(
            date: date,
            cohort: cohort,
            strain: strain,
            unit: unit,
            quantity: quantity ?? 0,
            unitPrice: unitPrice ?? 0,
            totalPrice: total,
            fee: fee ?? 0,
            shippingCost: shippingCost ?? 0,
            channel: channel,
            status: status,
            shippedAt: hasShippedAt || status == .shipped ? shippedAt : nil,
            buyerMemo: buyerMemo,
            note: note,
            bundleFishCount: unit == .fryBundle ? bundleFishCount : nil
        )
    }

    /// 保存の入口。減らす確認が要るときは確認を出し、要らなければそのまま保存する。
    /// 保存できて閉じてよいときは true。
    func save(in context: ModelContext) -> Bool {
        if needsReduceConfirmation {
            isAskingToReduce = true
            return false
        }
        return perform(reducesCohort: false, in: context)
    }

    /// 確認の結果を受けて保存する。
    func save(reducesCohort: Bool, in context: ModelContext) -> Bool {
        perform(reducesCohort: reducesCohort, in: context)
    }

    /// 終了できたら true。失敗したら理由をアラートに出し、シートは開いたままにする。
    func end(as status: CohortStatus, in context: ModelContext) -> Bool {
        guard let savedCohort else { return true }
        do {
            try CohortOperations.changeStatus(savedCohort, to: status, date: Date(), in: context)
            try context.save()
            return true
        } catch {
            context.rollback()
            self.error = UserFacingError(error)
            return false
        }
    }

    private func perform(reducesCohort: Bool, in context: ModelContext) -> Bool {
        let before = cohort?.count
        do {
            if let editing {
                try SaleOperations.update(editing, with: input())
            } else {
                try SaleOperations.record(input(), reducesCohort: reducesCohort, in: context)
            }
            try context.save()
        } catch {
            // 途中まで適用された変更（匹数の減少）を残さない
            context.rollback()
            self.error = UserFacingError(error)
            return false
        }
        // 匹数が0になったら「この群を終了しますか」（DECISIONS.md C）。保存は済んでいるので、答えるまでシートを閉じない
        if reducesCohort, let cohort, cohort.isActive, cohort.count == 0, before != 0 {
            savedCohort = cohort
            isAskingToEnd = true
            return false
        }
        return true
    }
}
