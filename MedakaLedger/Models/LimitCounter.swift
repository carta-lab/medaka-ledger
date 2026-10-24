import Foundation
import SwiftData

// Freeの上限の数え方（ARCHITECTURE.md 4.4）。サンプルは数えない。数えられなかったときは0として、保存を止めない。

enum LimitCounter {
    static func tanks(in context: ModelContext) -> Int {
        let descriptor = FetchDescriptor<Tank>(predicate: #Predicate<Tank> { $0.isArchived == false && $0.isSample == false })
        return (try? context.fetchCount(descriptor)) ?? 0
    }

    static func strains(in context: ModelContext) -> Int {
        let descriptor = FetchDescriptor<Strain>(predicate: #Predicate<Strain> { $0.isArchived == false && $0.isSample == false })
        return (try? context.fetchCount(descriptor)) ?? 0
    }

    /// 稼働中（終了日が無い）の親魚セット。
    static func activeBreedingSets(in context: ModelContext) -> Int {
        let descriptor = FetchDescriptor<BreedingSet>(predicate: #Predicate<BreedingSet> { $0.endedAt == nil && $0.isSample == false })
        return (try? context.fetchCount(descriptor)) ?? 0
    }

    /// 同じ付け先（群、容器、系統、選別）に付いている写真。
    static func photos(of owner: PhotoOwner) -> Int {
        owner.photos.filter { !$0.isSample }.count
    }
}
