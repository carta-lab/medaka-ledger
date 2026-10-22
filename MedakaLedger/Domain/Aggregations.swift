import Foundation

// 述語で表せない集計と、関係をまたぐ検索（DECISIONS.md G 3-3）。
// 述語で絞れるところまで絞って取得した結果を、ここでアプリ内で計算する。

struct LocationSection<Item>: Identifiable {
    var title: String
    var isUnset: Bool
    var items: [Item]
    var id: String { isUnset ? "\u{0}unset" : title }
}

struct CohortTally: Equatable, Sendable {
    var cohortCount: Int
    var fishCount: Int
    var hasUncounted: Bool
}

enum TraitTagCatalog {
    /// 表現タグの候補（DECISIONS.md D）。
    static let defaults = [
        "ラメ", "黒ラメ", "体外光", "三色", "紅白", "錦", "朱赤", "黄", "白", "黒",
        "琥珀", "オーロラ", "サファイア", "ブラックリム", "透明鱗", "ヒカリ体型", "ダルマ", "半ダルマ", "ロングフィン",
    ]
}

enum Aggregations {
    /// 置き場所の文字列（前後の空白を除いて完全一致）でセクションに分ける。
    /// セクションの順は各セクションの先頭の項目の順。空は最後に置く（DECISIONS.md D、H）。
    static func sectionsByLocation<Item>(_ items: [Item], location: (Item) -> String, unsetTitle: String) -> [LocationSection<Item>] {
        var sections: [LocationSection<Item>] = []
        var indexByTitle: [String: Int] = [:]
        var unset: [Item] = []
        for item in items {
            let title = location(item).trimmingCharacters(in: .whitespacesAndNewlines)
            if title.isEmpty {
                unset.append(item)
            } else if let index = indexByTitle[title] {
                sections[index].items.append(item)
            } else {
                indexByTitle[title] = sections.count
                sections.append(LocationSection(title: title, isUnset: false, items: [item]))
            }
        }
        if !unset.isEmpty {
            sections.append(LocationSection(title: unsetTitle, isUnset: true, items: unset))
        }
        return sections
    }

    /// 空白を除き、重複を除いた一覧。最初に現れた順を保つ。
    static func distinct(_ values: [String]) -> [String] {
        var seen = Set<String>()
        var result: [String] = []
        for value in values {
            let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty, seen.insert(trimmed).inserted else { continue }
            result.append(trimmed)
        }
        return result
    }

    /// 入力中の文字を含む候補。入力と完全に一致するものは出さない。
    static func suggestions(for input: String, from candidates: [String], limit: Int) -> [String] {
        let query = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return [] }
        return distinct(candidates)
            .filter { $0 != query && contains($0, query) }
            .prefix(limit)
            .map { $0 }
    }

    /// 表現タグの候補。既定の候補に、登録済みの系統で使われたタグを足す（DECISIONS.md D）。
    static func tagCandidates(defaults: [String], used: [[String]]) -> [String] {
        distinct(defaults + used.flatMap { $0 })
    }

    /// 検索語がどれかの文字列に含まれるか。大文字小文字と全角半角を区別しない。
    static func matches(query: String, in texts: [String]) -> Bool {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return true }
        return texts.contains { contains($0, trimmed) }
    }

    /// 群の数と合計匹数。未計数の群は匹数の合計に入れず、hasUncounted で知らせる。
    static func tally(counts: [Int?]) -> CohortTally {
        CohortTally(
            cohortCount: counts.count,
            fishCount: counts.reduce(0) { $0 + ($1 ?? 0) },
            hasUncounted: counts.contains { $0 == nil }
        )
    }

    /// 世代ごとにまとめる。世代の小さい順。
    static func groupedByGeneration<Item>(_ items: [Item], generation: (Item) -> Int) -> [(generation: Int, items: [Item])] {
        Dictionary(grouping: items, by: generation)
            .sorted { $0.key < $1.key }
            .map { (generation: $0.key, items: $0.value) }
    }

    /// 種類ごとに取得した最新の記録を、日付の新しい順に混ぜて limit 件にする（DECISIONS.md E）。
    static func mergeRecent<Item>(_ lists: [[Item]], date: (Item) -> Date, limit: Int) -> [Item] {
        lists.flatMap { $0 }
            .sorted { date($0) > date($1) }
            .prefix(limit)
            .map { $0 }
    }

    /// セクション内の並べ替えを、全体の並び順に反映する。返り値は全体の新しい並び。
    static func reorder<ID: Equatable>(sections: [[ID]], sectionIndex: Int, from source: IndexSet, to destination: Int) -> [ID] {
        var result = sections
        guard result.indices.contains(sectionIndex) else { return sections.flatMap { $0 } }
        result[sectionIndex] = moved(result[sectionIndex], from: source, to: destination)
        return result.flatMap { $0 }
    }

    /// Array.move(fromOffsets:toOffset:) と同じ結果を返す（SwiftUIに依存しない版）。
    static func moved<Element>(_ array: [Element], from source: IndexSet, to destination: Int) -> [Element] {
        let moving = source.filter { array.indices.contains($0) }.map { array[$0] }
        var remaining: [Element] = []
        var insertAt = destination
        for (index, element) in array.enumerated() {
            if source.contains(index) {
                if index < destination { insertAt -= 1 }
            } else {
                remaining.append(element)
            }
        }
        insertAt = min(max(insertAt, 0), remaining.count)
        remaining.insert(contentsOf: moving, at: insertAt)
        return remaining
    }

    private static func contains(_ text: String, _ query: String) -> Bool {
        text.range(of: query, options: [.caseInsensitive, .widthInsensitive, .diacriticInsensitive]) != nil
    }
}
