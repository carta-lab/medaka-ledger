import Foundation

// 群のタイムライン（SCREENS.md 5.1）。出来事、選別、採卵からの孵化を、日付の新しい順に並べる。
// 販売は第4週で足す。

enum TimelineItem: Identifiable {
    case event(CohortEvent)
    case selection(SelectionEvent)
    /// この群を生んだ採卵ロット。入手個体には無い。
    case origin(EggBatch)

    var id: String {
        switch self {
        case let .event(event): "event-\(event.id.uuidString)"
        case let .selection(selection): "selection-\(selection.id.uuidString)"
        case let .origin(batch): "origin-\(batch.id.uuidString)"
        }
    }

    var date: Date {
        switch self {
        case let .event(event): event.date
        case let .selection(selection): selection.date
        case let .origin(batch): batch.collectedAt
        }
    }

    /// 同じ日付での並び。保存の新しいものを上に。採卵は最も古いので最後。
    fileprivate var tieBreaker: Date {
        switch self {
        case let .event(event): event.createdAt
        case .selection: Date.distantPast.addingTimeInterval(1)
        case .origin: Date.distantPast
        }
    }
}

extension SchemaV1.Cohort {
    var timelineItems: [TimelineItem] {
        var items: [TimelineItem] = (events ?? []).map { .event($0) }
        items += (selections ?? []).map { .selection($0) }
        if let originBatch { items.append(.origin(originBatch)) }
        return items.sorted { lhs, rhs in
            if lhs.date != rhs.date { return lhs.date > rhs.date }
            return lhs.tieBreaker > rhs.tieBreaker
        }
    }

    /// 選別の残し数と弾き数の合計（系統詳細の世代の見出し。PRD.md F5）。
    var selectionTotals: (kept: Int, culled: Int) {
        (selections ?? []).reduce((0, 0)) { ($0.0 + $1.keptCount, $0.1 + $1.culledCount) }
    }

    var coverPhoto: Photo? { PhotoOperations.cover(of: photos ?? []) }
}

extension SchemaV1.SelectionEvent {
    var destination: CullDestination {
        get { CullDestination(rawValue: cullDestinationRaw) ?? .feed }
        set { cullDestinationRaw = newValue.rawValue }
    }

    /// 「1回目」「2回目」「3回目」「その他」。
    var roundLabel: String { SelectionText.round(round) }

    var summary: String {
        String(localized: "\(roundLabel)：残し\(keptCount.formatted())・弾き\(culledCount.formatted())（\(destination.label)）")
    }
}

extension SchemaV1.Tank {
    var coverPhoto: Photo? { PhotoOperations.cover(of: photos ?? []) }
}

extension SchemaV1.Strain {
    /// 代表写真：系統の写真、なければ群の代表写真のうち最も古いもの。
    var coverPhoto: Photo? {
        if let own = PhotoOperations.cover(of: photos ?? []) { return own }
        return (cohorts ?? [])
            .compactMap(\.coverPhoto)
            .min { $0.capturedAt < $1.capturedAt }
    }
}

enum SelectionText {
    static func round(_ round: Int) -> String {
        switch round {
        case 1: String(localized: "1回目")
        case 2: String(localized: "2回目")
        case 3: String(localized: "3回目")
        default: String(localized: "その他")
        }
    }

    /// 選別の基準の候補（PRD.md F5）。自由入力も加えられる。
    static let defaultCriteria = ["体型", "色", "ラメ", "体外光", "ヒレ", "その他"]
}
