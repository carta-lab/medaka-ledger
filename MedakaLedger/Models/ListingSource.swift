import Foundation

// 群から出品文の入力を作る（ARCHITECTURE.md 4.6）。

enum ListingSource {
    @MainActor
    static func input(for cohort: Cohort, settings: AppSettings) -> ListingInput {
        ListingInput(
            breedName: cohort.strain?.breedName ?? "",
            lineName: cohort.strain?.lineName ?? "",
            generation: cohort.generation,
            count: cohort.count,
            maleCount: cohort.maleCount,
            femaleCount: cohort.femaleCount,
            sizeText: cohort.sizeText,
            hatchedAt: cohort.hatchedAt,
            parentTraitTags: parentTraitTags(of: cohort),
            placement: cohort.tank?.placement,
            guaranteeText: settings.listingGuaranteeText,
            noticeText: settings.listingNoticeText
        )
    }

    /// 親の表現。この群を生んだ親魚セットの、雄と雌の系統の表現タグ。入手個体は空。
    static func parentTraitTags(of cohort: Cohort) -> [String] {
        guard let set = cohort.originBatch?.breedingSet else { return [] }
        return (set.sireCohort?.strain?.traitTags ?? []) + (set.damCohort?.strain?.traitTags ?? [])
    }
}
