import Foundation
import Observation
import SwiftData

@MainActor
@Observable
final class MaintenanceModel {
    let initialTanks: [Tank]
    let isTankLocked: Bool
    var selectedIDs: Set<UUID>
    var kind: MaintenanceKind
    var date = Date()
    /// 水換えの割合の初期値は50%（SCREENS.md 9）。
    var percent: Int? = 50
    var waterTempText = ""
    var note = ""
    var error: UserFacingError?
    private var knownTanks: [UUID: Tank]

    init(initialTanks: [Tank], kind: MaintenanceKind, isTankLocked: Bool) {
        self.initialTanks = initialTanks
        self.isTankLocked = isTankLocked
        self.kind = kind
        selectedIDs = Set(initialTanks.map(\.id))
        knownTanks = Dictionary(uniqueKeysWithValues: initialTanks.map { ($0.id, $0) })
    }

    var canSave: Bool {
        guard !selectedIDs.isEmpty else { return false }
        if kind == .temperature { return NumberParsing.double(from: waterTempText) != nil }
        return true
    }

    func isSelected(_ tank: Tank) -> Bool { selectedIDs.contains(tank.id) }

    func toggle(_ tank: Tank) {
        knownTanks[tank.id] = tank
        if selectedIDs.contains(tank.id) {
            selectedIDs.remove(tank.id)
        } else {
            selectedIDs.insert(tank.id)
        }
    }

    /// 保存できたら true。
    func save(in context: ModelContext) -> Bool {
        let tanks = selectedIDs.compactMap { knownTanks[$0] }.sorted { $0.sortOrder < $1.sortOrder }
        do {
            try MaintenanceOperations.record(
                on: tanks,
                kind: kind,
                date: date,
                percent: percent,
                waterTempC: NumberParsing.double(from: waterTempText),
                note: note,
                in: context
            )
            try context.save()
            return true
        } catch {
            self.error = UserFacingError(error)
            return false
        }
    }
}
