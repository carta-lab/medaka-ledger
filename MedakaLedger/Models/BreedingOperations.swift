import Foundation
import SwiftData

// 親魚セット、採卵、孵化の操作（PRD.md F4、DECISIONS.md C、F）。
// 群の匹数を変える部分は CohortOperations を通し、CohortEvent を残す。

enum BreedingOperations {
    enum OperationError: LocalizedError, Equatable {
        case missingParent
        case parentNotActive
        case invalidCount
        case setEnded
        case batchDiscarded
        case tankRequired
        case childStrainRequired
        case invalidBreedName
        case targetCohortNotFromBatch
        case cohort(CohortOperations.OperationError)

        var errorDescription: String? {
            switch self {
            case .missingParent: String(localized: "親の群が見つかりません。")
            case .parentNotActive: String(localized: "飼育中の群を選んでください。")
            case .invalidCount: String(localized: "匹数を確かめてください。")
            case .setEnded: String(localized: "終了した親魚セットには採卵を記録できません。")
            case .batchDiscarded: String(localized: "廃棄したロットには孵化を記録できません。")
            case .tankRequired: String(localized: "針子の容器を選んでください。")
            case .childStrainRequired: String(localized: "子の系統を決めてください。")
            case .invalidBreedName: String(localized: "品種名を入れてください。")
            case .targetCohortNotFromBatch: String(localized: "このロットから生まれた飼育中の群を選んでください。")
            case let .cohort(error): error.errorDescription
            }
        }
    }

    /// 孵化予定日の計算に使う設定値（AppSettings から渡す）。
    struct HatchSettings: Sendable {
        var degreeDaysToHatch: Double
        var defaultWaterTempC: Double
    }

    enum ChildStrainChoice {
        case existing(Strain)
        case createNew(breedName: String, lineName: String)
    }

    struct SetInput {
        var sire: Cohort
        var dam: Cohort
        var maleCount: Int
        var femaleCount: Int
        var tank: Tank?
        var startedAt: Date
        var name: String
        var note: String
        /// 雄と雌の群を親魚セットの容器へ移すか（SCREENS.md 6.2）。
        var movesParents: Bool
    }

    struct HatchInput {
        var hatchedAt: Date
        var hatchedCount: Int?
        /// 新しい群を作るときの針子の容器。既存の群に足すときは使わない。
        var tank: Tank?
        var label: String
        var note: String
        /// 子の系統がまだ決まっていない（交配の最初の孵化）ときの選択。
        var childStrain: ChildStrainChoice?
        /// 2回目以降の孵化で、既存の群に足す場合の群。nil なら新しい群にする。
        var addTo: Cohort?
    }

    // MARK: - 親魚セット

    /// 雄と雌の系統が同じか。同じなら子の系統は親と同じに決まる（DECISIONS.md F）。
    static func isSameStrain(sire: Cohort, dam: Cohort) -> Bool {
        guard let sireStrain = sire.strain, let damStrain = dam.strain else { return false }
        return sireStrain.id == damStrain.id
    }

    /// 交配の子の系統名の初期値「雄の品種×雌の品種」（PRD.md F4）。
    static func defaultChildBreedName(sire: Cohort, dam: Cohort) -> String {
        "\(sire.strain?.breedName ?? "")×\(dam.strain?.breedName ?? "")"
    }

    @discardableResult
    static func createBreedingSet(_ input: SetInput, in context: ModelContext) throws(OperationError) -> BreedingSet {
        guard input.sire.isActive, input.dam.isActive else { throw .parentNotActive }
        guard input.maleCount >= 0, input.femaleCount >= 0, input.maleCount + input.femaleCount > 0 else { throw .invalidCount }

        let set = BreedingSet()
        set.name = input.name.trimmingCharacters(in: .whitespacesAndNewlines)
        set.maleCount = input.maleCount
        set.femaleCount = input.femaleCount
        set.startedAt = input.startedAt
        set.note = input.note.trimmingCharacters(in: .whitespacesAndNewlines)
        set.isSample = input.sire.isSample && input.dam.isSample
        context.insert(set)
        set.sireCohort = input.sire
        set.damCohort = input.dam
        set.tank = input.tank
        // 同系統なら作成時に子の系統を親の系統に決める。交配は最初の孵化まで空のまま（DECISIONS.md F）。
        set.offspringStrain = isSameStrain(sire: input.sire, dam: input.dam) ? input.sire.strain : nil

        if input.movesParents, let tank = input.tank {
            let parents = input.sire.id == input.dam.id ? [input.sire] : [input.sire, input.dam]
            for parent in parents where parent.tank?.id != tank.id {
                do {
                    try CohortOperations.move(parent, to: tank, date: input.startedAt, in: context)
                } catch {
                    throw .cohort(error)
                }
            }
        }
        return set
    }

    static func end(_ set: BreedingSet, on date: Date) {
        set.endedAt = date
    }

    // MARK: - 採卵

    @discardableResult
    static func recordEggBatch(
        in set: BreedingSet,
        collectedAt: Date,
        eggCount: Int?,
        container: Tank?,
        containerName: String,
        waterTempC: Double?,
        note: String,
        context: ModelContext
    ) throws(OperationError) -> EggBatch {
        guard set.isActive else { throw .setEnded }
        if let eggCount, eggCount < 0 { throw .invalidCount }

        let batch = EggBatch()
        batch.collectedAt = collectedAt
        batch.eggCount = eggCount
        batch.containerName = containerName.trimmingCharacters(in: .whitespacesAndNewlines)
        batch.waterTempC = waterTempC
        batch.note = note.trimmingCharacters(in: .whitespacesAndNewlines)
        batch.isSample = set.isSample
        context.insert(batch)
        batch.breedingSet = set
        batch.container = container
        return batch
    }

    static func discard(_ batch: EggBatch) {
        batch.status = .discarded
    }

    // MARK: - 孵化

    /// 孵化を記録して、世代と系統を引き継いだ群を作る（または既存の群に足す）。
    @discardableResult
    static func recordHatch(of batch: EggBatch, _ input: HatchInput, in context: ModelContext) throws(OperationError) -> Cohort {
        guard batch.status != .discarded else { throw .batchDiscarded }
        guard let set = batch.breedingSet, let sire = set.sireCohort, let dam = set.damCohort else { throw .missingParent }
        if let count = input.hatchedCount, count < 0 { throw .invalidCount }

        let cohort: Cohort
        if let target = input.addTo {
            guard target.isActive, (batch.resultCohorts ?? []).contains(where: { $0.id == target.id }) else {
                throw .targetCohortNotFromBatch
            }
            if let count = input.hatchedCount, count > 0 {
                do {
                    try CohortOperations.changeCount(target, change: .adjust(count), date: input.hatchedAt, note: String(localized: "孵化"), in: context)
                } catch {
                    throw .cohort(error)
                }
            }
            cohort = target
        } else {
            guard let tank = input.tank else { throw .tankRequired }
            let strain = try childStrain(of: set, choice: input.childStrain, in: context)
            let generation = isSameStrain(sire: sire, dam: dam) ? max(sire.generation, dam.generation) + 1 : 1
            cohort = CohortOperations.createCohort(
                strain: strain,
                tank: tank,
                count: input.hatchedCount,
                stage: .hatchling,
                generation: generation,
                hatchedAt: input.hatchedAt,
                label: input.label.trimmingCharacters(in: .whitespacesAndNewlines),
                note: input.note.trimmingCharacters(in: .whitespacesAndNewlines),
                date: input.hatchedAt,
                isSample: set.isSample,
                in: context
            )
            cohort.originBatch = batch
        }

        batch.status = .hatched
        batch.hatchedAt = input.hatchedAt
        if let count = input.hatchedCount {
            batch.hatchedCount = (batch.hatchedCount ?? 0) + count
        }
        return cohort
    }

    // MARK: - 孵化予定日

    /// ロットの孵化予定日。容器に記録された日別の水温を使う（PRD.md F4、F7）。
    static func prediction(for batch: EggBatch, settings: HatchSettings, calendar: Calendar) -> HatchPrediction? {
        let readings = (batch.container?.logs ?? [])
            .filter { $0.kind == .temperature }
            .compactMap { log in log.waterTempC.map { TemperatureReading(date: log.date, tempC: $0) } }
        return HatchPredictor.predict(
            collectedAt: batch.collectedAt,
            lotWaterTempC: batch.waterTempC,
            dailyTemps: HatchPredictor.dailyAverages(readings, calendar: calendar),
            defaultWaterTempC: settings.defaultWaterTempC,
            degreeDaysToHatch: settings.degreeDaysToHatch,
            calendar: calendar
        )
    }

    // MARK: - Private

    private static func childStrain(of set: BreedingSet, choice: ChildStrainChoice?, in context: ModelContext) throws(OperationError) -> Strain {
        if let decided = set.offspringStrain { return decided }
        guard let choice else { throw .childStrainRequired }
        let strain: Strain
        switch choice {
        case let .existing(existing):
            strain = existing
        case let .createNew(breedName, lineName):
            let trimmed = breedName.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { throw .invalidBreedName }
            strain = Strain(
                breedName: trimmed,
                lineName: lineName.trimmingCharacters(in: .whitespacesAndNewlines),
                sortOrder: nextStrainSortOrder(in: context),
                isSample: set.isSample
            )
            context.insert(strain)
        }
        set.offspringStrain = strain
        return strain
    }

    private static func nextStrainSortOrder(in context: ModelContext) -> Int {
        var descriptor = FetchDescriptor<Strain>(sortBy: [SortDescriptor(\Strain.sortOrder, order: .reverse)])
        descriptor.fetchLimit = 1
        return ((try? context.fetch(descriptor))?.first?.sortOrder ?? -1) + 1
    }
}
