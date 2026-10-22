import Foundation

// 列挙値の表示名（DECISIONS.md 付録2）とアイコン（付録1）。

extension TankKind {
    var label: String {
        switch self {
        case .nvBox: String(localized: "NVボックス")
        case .toroBune: String(localized: "トロ舟")
        case .styrofoam: String(localized: "発泡スチロール")
        case .plaBune: String(localized: "プラ舟")
        case .waterLilyPot: String(localized: "睡蓮鉢")
        case .aquarium: String(localized: "水槽")
        case .cup: String(localized: "カップ（採卵用など）")
        case .other: String(localized: "その他")
        }
    }

    var symbolName: String {
        switch self {
        case .nvBox: "shippingbox"
        case .toroBune: "rectangle.roundedbottom"
        case .styrofoam: "cube"
        case .plaBune: "tray"
        case .waterLilyPot: "circle.bottomhalf.filled"
        case .aquarium: "rectangle.split.3x1"
        case .cup: "cup.and.saucer"
        case .other: "square.dashed"
        }
    }
}

extension Placement {
    var label: String {
        switch self {
        case .outdoor: String(localized: "屋外")
        case .indoor: String(localized: "室内")
        }
    }

    var symbolName: String {
        switch self {
        case .outdoor: "sun.max"
        case .indoor: "house"
        }
    }
}

extension GrowthStage {
    var label: String {
        switch self {
        case .hatchling: String(localized: "針子")
        case .fry: String(localized: "稚魚")
        case .young: String(localized: "若魚")
        case .adult: String(localized: "成魚")
        }
    }
}

extension CohortStatus {
    var label: String {
        switch self {
        case .active: String(localized: "飼育中")
        case .soldOut: String(localized: "完売")
        case .merged: String(localized: "統合済み")
        case .lost: String(localized: "全滅")
        case .archived: String(localized: "アーカイブ")
        }
    }
}

extension CohortEventKind {
    var label: String {
        switch self {
        case .created: String(localized: "登録")
        case .move: String(localized: "移動")
        case .split: String(localized: "分割")
        case .merge: String(localized: "統合")
        case .countChange: String(localized: "増減")
        case .stageChange: String(localized: "段階の変更")
        case .statusChange: String(localized: "状態の変更")
        case .note: String(localized: "メモ")
        }
    }

    var symbolName: String {
        switch self {
        case .created: "plus.circle"
        case .move: "arrow.right.circle"
        case .split: "arrow.triangle.branch"
        case .merge: "arrow.triangle.merge"
        case .countChange: "plusminus.circle"
        case .stageChange: "chart.line.uptrend.xyaxis"
        case .statusChange: "flag.circle"
        case .note: "note.text"
        }
    }
}

extension CountChangeReason {
    var label: String {
        switch self {
        case .death: String(localized: "死亡")
        case .jumpedOut: String(localized: "飛び出し")
        case .givenAway: String(localized: "譲渡")
        case .recount: String(localized: "計数修正")
        case .other: String(localized: "その他")
        }
    }
}

extension EggBatchStatus {
    var label: String {
        switch self {
        case .incubating: String(localized: "育卵中")
        case .hatched: String(localized: "孵化")
        case .discarded: String(localized: "廃棄")
        }
    }
}

extension CullDestination {
    var label: String {
        switch self {
        case .feed: String(localized: "餌用")
        case .cheapSale: String(localized: "格安販売")
        case .separateTank: String(localized: "別容器")
        case .dispose: String(localized: "処分")
        }
    }
}

extension SaleUnit {
    var label: String {
        switch self {
        case .fish: String(localized: "匹")
        case .pair: String(localized: "ペア")
        case .trio: String(localized: "トリオ")
        case .eggs: String(localized: "卵")
        case .fryBundle: String(localized: "稚魚まとめ")
        }
    }
}

extension SaleChannel {
    var label: String {
        switch self {
        case .yahooAuction: String(localized: "ヤフオク")
        case .ownShop: String(localized: "自店")
        case .event: String(localized: "イベント")
        case .consignment: String(localized: "委託")
        case .direct: String(localized: "直接")
        case .other: String(localized: "その他")
        }
    }
}

extension SaleStatus {
    var label: String {
        switch self {
        case .listed: String(localized: "出品中")
        case .sold: String(localized: "売約")
        case .shipped: String(localized: "発送済")
        case .cancelled: String(localized: "取消")
        }
    }
}

extension MaintenanceKind {
    var label: String {
        switch self {
        case .waterChange: String(localized: "水換え")
        case .topUp: String(localized: "足し水")
        case .cleaning: String(localized: "掃除")
        case .medication: String(localized: "薬浴")
        case .temperature: String(localized: "水温")
        case .other: String(localized: "その他")
        }
    }
}

extension LedgerError {
    /// 利用者向けの文言（DECISIONS.md C）。
    var message: String {
        switch self {
        case .notActive:
            String(localized: "飼育中でない群は操作できません。")
        case .invalidAmount:
            String(localized: "数を確かめてください。")
        case let .exceedsCount(current):
            String(localized: "現在の匹数（\(current.formatted())匹）を超えています。数え直す場合は計数修正を使ってください。")
        case .sameTank:
            String(localized: "今と同じ容器です。")
        case .sameStage:
            String(localized: "今と同じ段階です。")
        case .sameStatus:
            String(localized: "今と同じ状態です。")
        case let .cannotMerge(blocker):
            blocker.message
        case .notLatest, .partnerNotLatest:
            String(localized: "後の記録があるため削除できません。計数修正か移動で直してください。")
        case .cannotDeleteCreation:
            String(localized: "登録の記録は削除できません。群ごと削除してください。")
        }
    }
}

extension MergeBlocker {
    var message: String {
        switch self {
        case .sameCohort: String(localized: "同じ群どうしは統合できません。")
        case .notActive: String(localized: "飼育中の群どうしだけ統合できます。")
        case .differentStrain: String(localized: "同じ系統の群どうしだけ統合できます。")
        case .differentGeneration: String(localized: "同じ世代の群どうしだけ統合できます。")
        case .differentParents: String(localized: "同じ親魚セットから生まれた群どうし、または入手個体どうしだけ統合できます。")
        }
    }
}
