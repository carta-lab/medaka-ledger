import Foundation

// Paywallの文言（SCREENS.md 13）。冒頭の理由と、FreeとProの比較表。

extension PaywallReason {
    /// 冒頭に一行で出す理由。理由なしなら nil。
    var message: String? {
        switch self {
        case .general:
            nil
        case let .limit(kind):
            switch kind {
            case .tanks: String(localized: "容器は\(FreeLimits.tanks.formatted())個まで登録できます。")
            case .strains: String(localized: "系統は\(FreeLimits.strains.formatted())本まで登録できます。")
            case .activeBreedingSets: String(localized: "稼働中の親魚セットは\(FreeLimits.activeBreedingSets.formatted())つまで組めます。")
            case .photosPerOwner: String(localized: "写真は1か所に\(FreeLimits.photosPerOwner.formatted())枚まで付けられます。")
            }
        case let .feature(feature):
            switch feature {
            case .yearlySummary: String(localized: "年別の集計は、Proの機能です。")
            case .salesCSV: String(localized: "販売のCSV書き出しは、Proの機能です。")
            case .listingText: String(localized: "出品文は、Proの機能です。")
            case .fullLineage: String(localized: "血統図の全世代の表示は、Proの機能です。")
            }
        }
    }
}

struct PaywallRow: Identifiable {
    let title: String
    let free: String
    let pro: String
    var id: String { title }

    /// 比較表（PRD.md 7）。
    static var all: [PaywallRow] {
        [
            PaywallRow(title: String(localized: "容器"), free: String(localized: "\(FreeLimits.tanks.formatted())個まで"), pro: String(localized: "無制限")),
            PaywallRow(title: String(localized: "系統"), free: String(localized: "\(FreeLimits.strains.formatted())本まで"), pro: String(localized: "無制限")),
            PaywallRow(title: String(localized: "稼働中の親魚セット"), free: String(localized: "\(FreeLimits.activeBreedingSets.formatted())つまで"), pro: String(localized: "無制限")),
            PaywallRow(title: String(localized: "写真"), free: String(localized: "1か所に\(FreeLimits.photosPerOwner.formatted())枚まで"), pro: String(localized: "無制限")),
            PaywallRow(title: String(localized: "血統図"), free: String(localized: "\(FreeLimits.lineageDepth.formatted())世代まで"), pro: String(localized: "全世代")),
            PaywallRow(title: String(localized: "販売台帳"), free: String(localized: "記録と月別の集計"), pro: String(localized: "年別の集計とCSV書き出し")),
            PaywallRow(title: String(localized: "出品文"), free: String(localized: "使えません"), pro: String(localized: "使えます")),
            PaywallRow(title: String(localized: "バックアップ"), free: String(localized: "使えます"), pro: String(localized: "使えます")),
        ]
    }
}
