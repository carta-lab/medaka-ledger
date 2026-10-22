import Foundation

// 販売の計算（PRD.md F6、SCREENS.md 8.2、DECISIONS.md F）。

enum SaleRules {
    /// 入力の上限。これを超える数量と金額は保存しない。計算が桁あふれしないための余裕もある。
    static let maxQuantity = 1_000_000
    static let maxAmount = 1_000_000_000_000

    /// 桁あふれしない掛け算。あふれたら Int.max（0以上の入力で使う）。
    static func multiplied(_ lhs: Int, _ rhs: Int) -> Int {
        let result = lhs.multipliedReportingOverflow(by: rhs)
        return result.overflow ? Int.max : result.partialValue
    }

    /// 集計や純額の計算で桁あふれしないよう、金額を ±上限 に収める。
    static func clamped(_ amount: Int) -> Int {
        min(max(amount, -maxAmount), maxAmount)
    }

    /// 販売で群から減らす匹数。匹は数量、ペアは2×数量、トリオは3×数量。
    /// 稚魚まとめは入力された匹数。卵は群の匹数を減らさない（DECISIONS.md F）。
    static func fishToDeduct(unit: SaleUnit, quantity: Int, bundleFishCount: Int?) -> Int {
        switch unit {
        case .fish: quantity
        case .pair: multiplied(quantity, 2)
        case .trio: multiplied(quantity, 3)
        case .eggs: 0
        case .fryBundle: bundleFishCount ?? 0
        }
    }

    /// 合計の既定値は数量×単価。
    static func defaultTotal(quantity: Int, unitPrice: Int) -> Int {
        multiplied(quantity, unitPrice)
    }

    /// 純額は合計から手数料と送料を引いた額。
    static func net(total: Int, fee: Int, shipping: Int) -> Int {
        clamped(total) - clamped(fee) - clamped(shipping)
    }

    /// 集計に入れる状態。出品中はまだ売れておらず、取消は売れなかったので入れない（DECISIONS.md H）。
    static func countsInTotals(_ status: SaleStatus) -> Bool {
        status == .sold || status == .shipped
    }

    /// 行のスワイプで進められる次の状態。出品中は売約へ、売約は発送済へ（SCREENS.md 8.1）。
    static func nextStatus(after status: SaleStatus) -> SaleStatus? {
        switch status {
        case .listed: .sold
        case .sold: .shipped
        case .shipped, .cancelled: nil
        }
    }
}
