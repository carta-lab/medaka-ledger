import Foundation

// 出品文（ARCHITECTURE.md 4.6、PRD.md F11）。雛形の中の差し込み語を、群の情報で置き換える。
// 端末の中の情報だけで作る。通信しない。

struct ListingInput: Equatable, Sendable {
    var breedName: String
    var lineName: String
    var generation: Int
    var count: Int?
    var maleCount: Int?
    var femaleCount: Int?
    var sizeText: String
    var hatchedAt: Date?
    /// 親魚セットの雄側と雌側の系統の表現タグ。入手個体は空。
    var parentTraitTags: [String]
    var placement: Placement?
    /// 設定で入れた、死着保証と注意事項の文。
    var guaranteeText: String
    var noticeText: String
}

enum ListingTextBuilder {
    /// 差し込み語の一覧（ARCHITECTURE.md 4.6）。
    static let placeholders = ["品種", "系統", "世代", "匹数", "雌雄", "サイズ", "孵化時期", "親の表現", "飼育環境", "死着保証", "注意事項"]

    /// 既定の雛形。1行に差し込み語を1つずつ置く（空の項目は行ごと省くため）。
    static let defaultTemplate = """
    【{品種}】{世代}
    系統：{系統}
    匹数：{匹数}
    雌雄：{雌雄}
    サイズ：{サイズ}
    孵化時期：{孵化時期}
    親の表現：{親の表現}
    飼育環境：{飼育環境}
    死着保証：{死着保証}
    注意事項：{注意事項}
    """

    /// 雛形を群の情報で埋める。未入力の差し込み語を含む行は、行ごと省く。差し込み語を含まない行はそのまま残す。
    static func build(template: String, input: ListingInput, calendar: Calendar = .current) -> String {
        let values = values(for: input, calendar: calendar)
        let source = template.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? defaultTemplate : template
        var lines: [String] = []
        for line in source.components(separatedBy: .newlines) {
            let used = usedPlaceholders(in: line)
            if used.isEmpty {
                lines.append(line)
                continue
            }
            if used.contains(where: { (values[$0] ?? "").isEmpty }) { continue }
            var result = line
            for name in used {
                result = result.replacingOccurrences(of: "{\(name)}", with: values[name] ?? "")
            }
            lines.append(result)
        }
        return lines.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// 項目ごとの値。空文字は未入力。
    static func values(for input: ListingInput, calendar: Calendar = .current) -> [String: String] {
        [
            "品種": trimmed(input.breedName),
            "系統": trimmed(input.lineName),
            "世代": input.generation == 0 ? "入手個体" : "F\(input.generation)",
            "匹数": input.count.map { "\($0)匹" } ?? "",
            "雌雄": sexText(male: input.maleCount, female: input.femaleCount),
            "サイズ": trimmed(input.sizeText),
            "孵化時期": input.hatchedAt.map { hatchedText($0, calendar: calendar) } ?? "",
            "親の表現": uniqueJoined(input.parentTraitTags),
            "飼育環境": placementText(input.placement),
            "死着保証": trimmed(input.guaranteeText),
            "注意事項": trimmed(input.noticeText),
        ]
    }

    /// 行の中で使われている差し込み語（雛形にある順、重複なし）。未知の {…} は差し込み語として扱わない。
    static func usedPlaceholders(in line: String) -> [String] {
        var found: [String] = []
        for name in placeholders where line.contains("{\(name)}") {
            found.append(name)
        }
        return found
    }

    /// 雌雄の匹数が両方とも未入力なら空（その行を省く）。片方だけなら、分からない側は「?」。
    static func sexText(male: Int?, female: Int?) -> String {
        guard male != nil || female != nil else { return "" }
        return "雄\(male.map(String.init) ?? "?")・雌\(female.map(String.init) ?? "?")"
    }

    static func hatchedText(_ date: Date, calendar: Calendar) -> String {
        let parts = calendar.dateComponents([.year, .month], from: date)
        return "\(parts.year ?? 0)年\(parts.month ?? 0)月"
    }

    static func placementText(_ placement: Placement?) -> String {
        switch placement {
        case .outdoor: "屋外飼育"
        case .indoor: "室内飼育"
        case nil: ""
        }
    }

    // MARK: - 内部

    private static func trimmed(_ text: String) -> String {
        text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func uniqueJoined(_ tags: [String]) -> String {
        var seen = Set<String>()
        return tags.map(trimmed).filter { !$0.isEmpty && seen.insert($0).inserted }.joined(separator: "・")
    }
}
