import Foundation
import SwiftData

// 作業記録（PRD.md F7、SCREENS.md 9）。複数の容器に同じ内容をまとめて保存できる。

enum MaintenanceOperations {
    enum OperationError: LocalizedError, Equatable {
        case noTank
        case temperatureRequired
        case invalidPercent

        var errorDescription: String? {
            switch self {
            case .noTank: String(localized: "容器を選んでください。")
            case .temperatureRequired: String(localized: "水温を入れてください。")
            case .invalidPercent: String(localized: "割合は1から100の間で入れてください。")
            }
        }
    }

    /// 選んだ容器それぞれに、同じ内容の記録を1件ずつ作る。
    @discardableResult
    static func record(
        on tanks: [Tank],
        kind: MaintenanceKind,
        date: Date,
        percent: Int?,
        waterTempC: Double?,
        note: String,
        in context: ModelContext
    ) throws(OperationError) -> [MaintenanceLog] {
        guard !tanks.isEmpty else { throw .noTank }
        if kind == .temperature, waterTempC == nil { throw .temperatureRequired }
        if kind == .waterChange, let percent, !(1...100).contains(percent) { throw .invalidPercent }

        var created: [MaintenanceLog] = []
        for tank in tanks {
            let log = MaintenanceLog()
            log.date = date
            log.kind = kind
            log.percent = kind == .waterChange ? percent : nil
            log.waterTempC = waterTempC
            log.note = note.trimmingCharacters(in: .whitespacesAndNewlines)
            log.isSample = tank.isSample
            context.insert(log)
            log.tank = tank
            created.append(log)
        }
        return created
    }
}
