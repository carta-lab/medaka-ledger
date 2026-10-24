import Foundation

// Freeの上限（ARCHITECTURE.md 4.4、PRD.md 7）。数え方と、上限に当たったかの判定。Paywallへの誘導は Features/Paywall。

enum FreeLimits {
    static let tanks = 6
    static let strains = 2
    static let activeBreedingSets = 2
    static let photosPerOwner = 3
    static let lineageDepth = 2

    /// 稼働中の親魚セットの数。終了日が無いもので、サンプルは数えない（DECISIONS.md E、ARCHITECTURE.md 4.4）。
    static func activeBreedingSetCount(endedAts: [Date?], isSamples: [Bool]) -> Int {
        zip(endedAts, isSamples).filter { $0.0 == nil && !$0.1 }.count
    }

    static func canAdd(currentCount: Int, limit: Int, isPro: Bool) -> Bool {
        isPro || currentCount < limit
    }

    /// 保存で上限を確かめる対象。
    enum Kind: Equatable, Hashable, Sendable {
        case tanks
        case strains
        case activeBreedingSets
        case photosPerOwner

        var limit: Int {
            switch self {
            case .tanks: FreeLimits.tanks
            case .strains: FreeLimits.strains
            case .activeBreedingSets: FreeLimits.activeBreedingSets
            case .photosPerOwner: FreeLimits.photosPerOwner
            }
        }
    }

    /// 追加する数を足しても上限に収まるか。Proは常に収まる。
    /// 既存のデータが上限を超えていても、閲覧と編集は止めない。止めるのは新しく足すときだけ。
    static func allows(_ kind: Kind, currentCount: Int, adding: Int = 1, isPro: Bool) -> Bool {
        isPro || currentCount + max(adding, 0) <= kind.limit
    }
}

/// Proの機能（上限ではなく、Freeでは使えないもの。PRD.md 7）。
enum ProFeature: Equatable, Hashable, Sendable {
    case yearlySummary
    case salesCSV
    case listingText
    case fullLineage
}

/// Paywallを開いた理由。冒頭に一行で出す（SCREENS.md 13）。
enum PaywallReason: Equatable, Hashable, Sendable {
    case limit(FreeLimits.Kind)
    case feature(ProFeature)
    /// 設定などから、理由なしで開く。
    case general
}
