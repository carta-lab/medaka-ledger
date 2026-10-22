import Foundation
import Observation
import SwiftData

@MainActor
@Observable
final class TankEditModel {
    let tank: Tank?
    var name: String
    var kind: TankKind
    var capacityText: String
    var placement: Placement
    var location: String
    var note: String
    var lastSavedName = ""
    var isShowingContinuePrompt = false
    var error: UserFacingError?

    init(tank: Tank?) {
        self.tank = tank
        name = tank?.name ?? ""
        kind = tank?.kind ?? .nvBox
        capacityText = NumberParsing.text(from: tank?.capacityLiters)
        placement = tank?.placement ?? .outdoor
        location = tank?.location ?? ""
        note = tank?.note ?? ""
    }

    var isNew: Bool { tank == nil }

    var trimmedName: String { name.trimmingCharacters(in: .whitespacesAndNewlines) }

    var canSave: Bool { !trimmedName.isEmpty }

    func locationSuggestions(from tanks: [Tank]) -> [String] {
        let used = Aggregations.distinct(tanks.map(\.location))
        let input = location.trimmingCharacters(in: .whitespacesAndNewlines)
        if input.isEmpty { return Array(used.prefix(6)) }
        return Aggregations.suggestions(for: input, from: used, limit: 6)
    }

    func save(in context: ModelContext) throws {
        let capacity = NumberParsing.double(from: capacityText)
        let trimmedLocation = location.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedNote = note.trimmingCharacters(in: .whitespacesAndNewlines)

        if let tank {
            tank.name = trimmedName
            tank.kind = kind
            tank.capacityLiters = capacity
            tank.placement = placement
            tank.location = trimmedLocation
            tank.note = trimmedNote
            try context.save()
            return
        }

        let created = Tank(
            name: trimmedName,
            kind: kind,
            capacityLiters: capacity,
            placement: placement,
            location: trimmedLocation,
            sortOrder: try nextSortOrder(in: context),
            note: trimmedNote
        )
        context.insert(created)
        try context.save()
        lastSavedName = trimmedName
        isShowingContinuePrompt = true
    }

    /// 連続登録。種類、容量、置き場所は引き継ぎ、名前は末尾の数字を1増やす（DECISIONS.md D）。
    func prepareNext() {
        name = TankNaming.nextName(after: lastSavedName)
        note = ""
    }

    private func nextSortOrder(in context: ModelContext) throws -> Int {
        var descriptor = FetchDescriptor<Tank>(sortBy: [SortDescriptor(\Tank.sortOrder, order: .reverse)])
        descriptor.fetchLimit = 1
        return (try context.fetch(descriptor).first?.sortOrder ?? -1) + 1
    }
}
