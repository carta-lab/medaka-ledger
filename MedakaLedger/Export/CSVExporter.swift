import Foundation

// CSVの書き出し（ARCHITECTURE.md 5.1、5.2）。UTF-8、BOM付き、CRLF改行。Excelで開ける形にする。

struct CohortRecord: Equatable, Sendable {
    var lineName: String
    var breedName: String
    var generation: Int
    var tankName: String
    var count: Int?
    var stage: GrowthStage
    var hatchedAt: Date?
    var status: CohortStatus
    var note: String
}

enum CSVExporter {
    static let bom = Data([0xEF, 0xBB, 0xBF])
    static let lineBreak = "\r\n"

    static let salesHeader = ["日付", "状態", "販路", "品種", "系統", "世代", "単位", "数量", "単価", "合計", "手数料", "送料", "純額", "発送日", "購入者メモ", "メモ"]
    static let cohortsHeader = ["系統", "品種", "世代", "容器", "匹数", "段階", "孵化日", "日齢", "状態", "メモ"]

    /// カンマ、引用符、改行を含む値は二重引用符で囲み、引用符は重ねる。
    /// "\r\n" は Character としては1文字なので、Unicodeスカラーで調べる。
    static func escape(_ field: String) -> String {
        let needsQuoting = field.unicodeScalars.contains { $0 == "," || $0 == "\"" || $0 == "\n" || $0 == "\r" }
        guard needsQuoting else { return field }
        return "\"" + field.replacingOccurrences(of: "\"", with: "\"\"") + "\""
    }

    static func line(_ fields: [String]) -> String {
        fields.map(escape).joined(separator: ",")
    }

    /// 2027-05-20 の形。
    static func isoDate(_ date: Date, calendar: Calendar) -> String {
        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", parts.year ?? 0, parts.month ?? 0, parts.day ?? 0)
    }

    static func generationLabel(_ generation: Int) -> String {
        generation == 0 ? "入手" : "F\(generation)"
    }

    /// 販売CSV。日付の古い順で、同じ日付なら入力の順。
    static func salesCSV(_ records: [SaleRecord], calendar: Calendar) -> Data {
        let sorted = records.enumerated()
            .sorted { lhs, rhs in
                if lhs.element.date != rhs.element.date { return lhs.element.date < rhs.element.date }
                return lhs.offset < rhs.offset
            }
            .map(\.element)
        var lines = [line(salesHeader)]
        for record in sorted {
            lines.append(line([
                isoDate(record.date, calendar: calendar),
                record.status.label,
                record.channel.label,
                record.breedName,
                record.lineName,
                generationLabel(record.generation),
                record.unit.label,
                String(record.quantity),
                String(record.unitPrice),
                String(record.totalPrice),
                String(record.fee),
                String(record.shippingCost),
                String(record.net),
                record.shippedAt.map { isoDate($0, calendar: calendar) } ?? "",
                record.buyerMemo,
                record.note,
            ]))
        }
        return encode(lines)
    }

    /// 群CSV。匹数が未計数のときと、孵化日が無いときの日齢は空にする。
    static func cohortsCSV(_ cohorts: [CohortRecord], now: Date, calendar: Calendar) -> Data {
        var lines = [line(cohortsHeader)]
        for cohort in cohorts {
            lines.append(line([
                cohort.lineName,
                cohort.breedName,
                generationLabel(cohort.generation),
                cohort.tankName,
                cohort.count.map(String.init) ?? "",
                cohort.stage.label,
                cohort.hatchedAt.map { isoDate($0, calendar: calendar) } ?? "",
                cohort.hatchedAt.map { String(DayCount.days(from: $0, to: now, calendar: calendar)) } ?? "",
                cohort.status.label,
                cohort.note,
            ]))
        }
        return encode(lines)
    }

    private static func encode(_ lines: [String]) -> Data {
        var data = bom
        data.append(Data((lines.joined(separator: lineBreak) + lineBreak).utf8))
        return data
    }
}
