import Foundation

// Freeの上限（ARCHITECTURE.md 4.4、PRD.md 7）。第2週は数え方だけ。Paywallへの誘導は第5週。

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
}
