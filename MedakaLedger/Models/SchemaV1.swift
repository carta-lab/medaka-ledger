import Foundation
import SwiftData

// ARCHITECTURE.md 3.2 のモデル。型名と属性名は仕様のまま使う。
// CloudKit互換の制約：リレーションは全てOptional、全属性に既定値、@Attribute(.unique) は使わない。
// 全モデルに isSample を持たせる（DECISIONS.md E）。CohortEvent の createdAt と statusRaw は DECISIONS.md H。

enum SchemaV1: VersionedSchema {
    static var versionIdentifier: Schema.Version { Schema.Version(1, 0, 0) }

    static var models: [any PersistentModel.Type] {
        [
            Tank.self, Strain.self, Cohort.self, CohortEvent.self, BreedingSet.self,
            EggBatch.self, SelectionEvent.self, Sale.self, MaintenanceLog.self, Photo.self,
        ]
    }
}

typealias Tank = SchemaV1.Tank
typealias Strain = SchemaV1.Strain
typealias Cohort = SchemaV1.Cohort
typealias CohortEvent = SchemaV1.CohortEvent
typealias BreedingSet = SchemaV1.BreedingSet
typealias EggBatch = SchemaV1.EggBatch
typealias SelectionEvent = SchemaV1.SelectionEvent
typealias Sale = SchemaV1.Sale
typealias MaintenanceLog = SchemaV1.MaintenanceLog
typealias Photo = SchemaV1.Photo

extension SchemaV1 {
    @Model final class Tank {
        var id: UUID = UUID()
        var name: String = ""                 // 例 "A-1"
        var kindRaw: String = TankKind.other.rawValue
        var capacityLiters: Double? = nil
        var placementRaw: String = Placement.outdoor.rawValue
        var location: String = ""             // 棚、列、場所の自由記述
        var sortOrder: Int = 0
        var note: String = ""
        var isArchived: Bool = false
        var createdAt: Date = Date()
        var isSample: Bool = false

        @Relationship(deleteRule: .nullify, inverse: \Cohort.tank) var cohorts: [Cohort]? = []
        @Relationship(deleteRule: .cascade, inverse: \MaintenanceLog.tank) var logs: [MaintenanceLog]? = []
        @Relationship(deleteRule: .cascade, inverse: \Photo.tank) var photos: [Photo]? = []
        @Relationship(deleteRule: .nullify, inverse: \BreedingSet.tank) var breedingSets: [BreedingSet]? = []
        @Relationship(deleteRule: .nullify, inverse: \EggBatch.container) var eggBatches: [EggBatch]? = []

        init(
            name: String = "",
            kind: TankKind = .other,
            capacityLiters: Double? = nil,
            placement: Placement = .outdoor,
            location: String = "",
            sortOrder: Int = 0,
            note: String = "",
            isSample: Bool = false
        ) {
            self.name = name
            self.kindRaw = kind.rawValue
            self.capacityLiters = capacityLiters
            self.placementRaw = placement.rawValue
            self.location = location
            self.sortOrder = sortOrder
            self.note = note
            self.isSample = isSample
        }
    }

    @Model final class Strain {
        var id: UUID = UUID()
        var breedName: String = ""            // 品種名
        var lineName: String = ""             // 系統名、呼び名（空でもよい）
        var source: String = ""               // 入手元、作出者
        var acquiredAt: Date? = nil
        var traitTags: [String] = []
        var note: String = ""
        var sortOrder: Int = 0
        var isArchived: Bool = false
        var createdAt: Date = Date()
        var isSample: Bool = false

        @Relationship(deleteRule: .nullify, inverse: \Cohort.strain) var cohorts: [Cohort]? = []
        @Relationship(deleteRule: .cascade, inverse: \Photo.strain) var photos: [Photo]? = []
        @Relationship(deleteRule: .nullify, inverse: \BreedingSet.offspringStrain) var offspringBreedingSets: [BreedingSet]? = []
        @Relationship(deleteRule: .nullify, inverse: \Sale.strain) var sales: [Sale]? = []

        var displayName: String { lineName.isEmpty ? breedName : "\(breedName)（\(lineName)）" }

        init(
            breedName: String = "",
            lineName: String = "",
            source: String = "",
            acquiredAt: Date? = nil,
            traitTags: [String] = [],
            note: String = "",
            sortOrder: Int = 0,
            isSample: Bool = false
        ) {
            self.breedName = breedName
            self.lineName = lineName
            self.source = source
            self.acquiredAt = acquiredAt
            self.traitTags = traitTags
            self.note = note
            self.sortOrder = sortOrder
            self.isSample = isSample
        }
    }

    @Model final class Cohort {
        var id: UUID = UUID()
        var label: String = ""                // 任意の呼び名。例 "2027春 1番"
        var generation: Int = 0               // 0 は入手個体。表示は "入手"、1以降は "F1"
        var count: Int? = nil                 // 概数。nil は未計数、0 は0匹
        var maleCount: Int? = nil
        var femaleCount: Int? = nil
        var stageRaw: String = GrowthStage.adult.rawValue
        var statusRaw: String = CohortStatus.active.rawValue
        var hatchedAt: Date? = nil            // アプリ内で孵化した群は必須
        var acquiredAt: Date? = nil           // 入手個体の入手日
        var sizeText: String = ""             // 例 "1.5〜2cm"。出品文の {サイズ}
        var note: String = ""
        var createdAt: Date = Date()
        var isSample: Bool = false

        var strain: Strain? = nil
        var tank: Tank? = nil
        var originBatch: EggBatch? = nil      // この群を生んだ採卵ロット。入手個体は nil

        @Relationship(deleteRule: .cascade, inverse: \CohortEvent.cohort) var events: [CohortEvent]? = []
        @Relationship(deleteRule: .cascade, inverse: \SelectionEvent.cohort) var selections: [SelectionEvent]? = []
        @Relationship(deleteRule: .nullify, inverse: \Sale.cohort) var sales: [Sale]? = []
        @Relationship(deleteRule: .cascade, inverse: \Photo.cohort) var photos: [Photo]? = []
        @Relationship(deleteRule: .nullify, inverse: \BreedingSet.sireCohort) var asSire: [BreedingSet]? = []
        @Relationship(deleteRule: .nullify, inverse: \BreedingSet.damCohort) var asDam: [BreedingSet]? = []

        init(
            label: String = "",
            generation: Int = 0,
            count: Int? = nil,
            maleCount: Int? = nil,
            femaleCount: Int? = nil,
            stage: GrowthStage = .adult,
            hatchedAt: Date? = nil,
            acquiredAt: Date? = nil,
            sizeText: String = "",
            note: String = "",
            isSample: Bool = false
        ) {
            self.label = label
            self.generation = generation
            self.count = count
            self.maleCount = maleCount
            self.femaleCount = femaleCount
            self.stageRaw = stage.rawValue
            self.hatchedAt = hatchedAt
            self.acquiredAt = acquiredAt
            self.sizeText = sizeText
            self.note = note
            self.isSample = isSample
        }
    }

    @Model final class CohortEvent {
        var id: UUID = UUID()
        var date: Date = Date()
        var kindRaw: String = CohortEventKind.note.rawValue
        var countDelta: Int = 0               // 増減。分割元はマイナス
        var reasonRaw: String = ""            // CountChangeReason
        var fromTankID: UUID? = nil
        var fromTankName: String = ""
        var toTankID: UUID? = nil
        var toTankName: String = ""
        var relatedCohortID: UUID? = nil      // 分割先、統合元
        var stageRaw: String = ""             // stageChange のとき、変更後の段階
        var previousCount: Int? = nil         // 削除で元に戻すための値
        var previousStageRaw: String = ""
        var previousStatusRaw: String = ""
        var statusRaw: String = ""            // statusChange のとき、変更後の状態
        var createdAt: Date = Date()          // 保存日時。「最新の出来事」の判定に使う
        var note: String = ""
        var isSample: Bool = false
        var cohort: Cohort? = nil

        init() {}
    }

    @Model final class BreedingSet {
        var id: UUID = UUID()
        var name: String = ""                 // 空なら "雄の系統 × 雌の系統 開始年月" を表示
        var maleCount: Int = 1
        var femaleCount: Int = 2
        var startedAt: Date = Date()
        var endedAt: Date? = nil
        var note: String = ""
        var isSample: Bool = false

        var sireCohort: Cohort? = nil         // 雄側の群
        var damCohort: Cohort? = nil          // 雌側の群。sire と同じ群でもよい
        var tank: Tank? = nil
        var offspringStrain: Strain? = nil    // 子の系統。同系統なら親と同じ、交配なら最初の孵化で決める

        @Relationship(deleteRule: .cascade, inverse: \EggBatch.breedingSet) var eggBatches: [EggBatch]? = []

        var isActive: Bool { endedAt == nil }

        init() {}
    }

    @Model final class EggBatch {
        var id: UUID = UUID()
        var collectedAt: Date = Date()        // 採卵日
        var eggCount: Int? = nil
        var containerName: String = ""        // 採卵カップ名など。容器登録がなくてもよい
        var waterTempC: Double? = nil
        var statusRaw: String = EggBatchStatus.incubating.rawValue
        var hatchedAt: Date? = nil
        var hatchedCount: Int? = nil
        var note: String = ""
        var isSample: Bool = false

        var breedingSet: BreedingSet? = nil
        var container: Tank? = nil            // 登録済み容器で育卵する場合

        @Relationship(deleteRule: .nullify, inverse: \Cohort.originBatch) var resultCohorts: [Cohort]? = []

        init() {}
    }

    @Model final class SelectionEvent {
        var id: UUID = UUID()
        var date: Date = Date()
        var round: Int = 1                    // 1、2、3。その他は0
        var criteria: [String] = []           // "体型" "色" "ラメ" "体外光" "ヒレ" ほか自由入力
        var keptCount: Int = 0
        var culledCount: Int = 0
        var cullDestinationRaw: String = CullDestination.feed.rawValue
        var culledCohortID: UUID? = nil       // 別容器へ分割したときの群
        var note: String = ""
        var isSample: Bool = false

        var cohort: Cohort? = nil
        @Relationship(deleteRule: .cascade, inverse: \Photo.selection) var photos: [Photo]? = []

        init() {}
    }

    @Model final class Sale {
        var id: UUID = UUID()
        var date: Date = Date()
        var unitRaw: String = SaleUnit.fish.rawValue
        var quantity: Int = 1
        var unitPrice: Int = 0                // 円
        var totalPrice: Int = 0               // 円。既定は quantity × unitPrice、上書き可
        var fee: Int = 0                      // 販売手数料
        var shippingCost: Int = 0
        var channelRaw: String = SaleChannel.yahooAuction.rawValue
        var statusRaw: String = SaleStatus.sold.rawValue
        var shippedAt: Date? = nil
        var buyerMemo: String = ""            // 端末内にだけ保存される
        var note: String = ""
        var breedNameSnapshot: String = ""    // 集計とCSV用のスナップショット
        var lineNameSnapshot: String = ""
        var generation: Int = 0
        var isSample: Bool = false

        var cohort: Cohort? = nil
        var strain: Strain? = nil

        var net: Int { totalPrice - fee - shippingCost }

        init() {}
    }

    @Model final class MaintenanceLog {
        var id: UUID = UUID()
        var date: Date = Date()
        var kindRaw: String = MaintenanceKind.waterChange.rawValue
        var percent: Int? = nil               // 水換えの割合
        var waterTempC: Double? = nil
        var note: String = ""
        var isSample: Bool = false
        var tank: Tank? = nil

        init() {}
    }

    @Model final class Photo {
        var id: UUID = UUID()
        var capturedAt: Date = Date()
        var caption: String = ""
        @Attribute(.externalStorage) var jpegData: Data = Data()       // 長辺1600px、品質0.8
        @Attribute(.externalStorage) var thumbnailData: Data = Data()  // 長辺320px
        var isCover: Bool = false             // 代表写真。未設定なら最も古い写真を使う
        var isSample: Bool = false

        var cohort: Cohort? = nil
        var tank: Tank? = nil
        var strain: Strain? = nil
        var selection: SelectionEvent? = nil

        init() {}
    }
}

enum MedakaMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] { [SchemaV1.self] }
    static var stages: [MigrationStage] { [] }
}
