import Foundation

// 販売の計算（PRD.md F6、SCREENS.md 8.2、DECISIONS.md F）。

enum SaleRules {
    /// 販売で群から減らす匹数。匹は数量、ペアは2×数量、トリオは3×数量。
    /// 稚魚まとめは入力された匹数。卵は群の匹数を減らさない（DECISIONS.md F）。
    static func fishToDeduct(unit: SaleUnit, quantity: Int, bundleFishCount: Int?) -> Int {
        switch unit {
        case .fish: quantity
        case .pair: quantity * 2
        case .trio: quantity * 3
        case .eggs: 0
        case .fryBundle: bundleFishCount ?? 0
        }
    }

    /// 合計の既定値は数量×単価。
    static func defaultTotal(quantity: Int, unitPrice: Int) -> Int {
        quantity * unitPrice
    }

    /// 純額は合計から手数料と送料を引いた額。
    static func net(total: Int, fee: Int, shipping: Int) -> Int {
        total - fee - shipping
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
