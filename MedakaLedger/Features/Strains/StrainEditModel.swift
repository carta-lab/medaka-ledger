import Foundation
import Observation
import SwiftData

@MainActor
@Observable
final class StrainEditModel {
    let strain: Strain?
    var breedName: String
    var lineName: String
    var source: String
    var hasAcquiredAt: Bool
    var acquiredAt: Date
    var traitTags: [String]
    var note: String
    /// 作成した系統。入れると入手個体の群の登録へ進む。
    var createdStrain: Strain?
    var error: UserFacingError?

    init(strain: Strain?) {
        self.strain = strain
        breedName = strain?.breedName ?? ""
        lineName = strain?.lineName ?? ""
        source = strain?.source ?? ""
        hasAcquiredAt = strain == nil || strain?.acquiredAt != nil
        acquiredAt = strain?.acquiredAt ?? Date()
        traitTags = strain?.traitTags ?? []
        note = strain?.note ?? ""
    }

    var isNew: Bool { strain == nil }

    var canSave: Bool { !trim(breedName).isEmpty }

    /// 品種名の補完。アーカイブ済みの系統も含め、重複を除いて出す（DECISIONS.md D）。
    func breedSuggestions(from strains: [Strain]) -> [String] {
        Aggregations.suggestions(for: breedName, from: strains.map(\.breedName), limit: 6)
    }

    func save(in context: ModelContext) throws {
        let target: Strain
        if let strain {
            target = strain
        } else {
            target = Strain(sortOrder: try nextSortOrder(in: context))
            context.insert(target)
        }
        target.breedName = trim(breedName)
        target.lineName = trim(lineName)
        target.source = trim(source)
        target.acquiredAt = hasAcquiredAt ? acquiredAt : nil
        target.traitTags = traitTags
        target.note = trim(note)
        try context.save()
        if isNew {
            createdStrain = target
        }
    }

    private func trim(_ text: String) -> String {
        text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func nextSortOrder(in context: ModelContext) throws -> Int {
        var descriptor = FetchDescriptor<Strain>(sortBy: [SortDescriptor(\Strain.sortOrder, order: .reverse)])
        descriptor.fetchLimit = 1
        return (try context.fetch(descriptor).first?.sortOrder ?? -1) + 1
    }
}
