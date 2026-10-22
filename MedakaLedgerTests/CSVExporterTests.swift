import Foundation
import Testing
@testable import MedakaLedger

struct CSVExporterTests {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Tokyo") ?? .gmt
        return calendar
    }

    private func date(_ year: Int, _ month: Int, _ day: Int) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day, hour: 12)) ?? .distantPast
    }

    private func text(_ data: Data) -> String {
        String(decoding: data.dropFirst(3), as: UTF8.self)
    }

    private func sale(date: Date, buyerMemo: String = "", note: String = "") -> SaleRecord {
        SaleRecord(
            id: UUID(), date: date, status: .sold, channel: .yahooAuction, unit: .pair, quantity: 1, unitPrice: 8000,
            totalPrice: 8000, fee: 800, shippingCost: 1200, shippedAt: nil, buyerMemo: buyerMemo, note: note,
            breedName: "楊貴妃", lineName: "〇〇めだか", generation: 1
        )
    }

    @Test func カンマと引用符と改行のエスケープ() {
        #expect(CSVExporter.escape("普通") == "普通")
        #expect(CSVExporter.escape("a,b") == "\"a,b\"")
        #expect(CSVExporter.escape("彼は\"良い\"と言った") == "\"彼は\"\"良い\"\"と言った\"")
        #expect(CSVExporter.escape("1行目\n2行目") == "\"1行目\n2行目\"")
        #expect(CSVExporter.escape("1行目\r\n2行目") == "\"1行目\r\n2行目\"")
        #expect(CSVExporter.escape("") == "")
    }

    @Test func BOMとCRLFとヘッダー() {
        let data = CSVExporter.salesCSV([], calendar: calendar)
        #expect(Array(data.prefix(3)) == [0xEF, 0xBB, 0xBF])
        #expect(text(data) == "日付,状態,販路,品種,系統,世代,単位,数量,単価,合計,手数料,送料,純額,発送日,購入者メモ,メモ\r\n")
    }

    @Test func 販売の行は仕様の列の順() {
        let record = sale(date: date(2027, 5, 20))
        let csv = text(CSVExporter.salesCSV([record], calendar: calendar))
        let lines = csv.components(separatedBy: "\r\n")
        #expect(lines[1] == "2027-05-20,売約,ヤフオク,楊貴妃,〇〇めだか,F1,ペア,1,8000,8000,800,1200,6000,,,")
        #expect(lines[2] == "")
    }

    @Test func 発送日と日本語とカンマを含む値() {
        var record = sale(date: date(2027, 5, 20), buyerMemo: "山田, 太郎様", note: "「初回」\n同梱あり")
        record.shippedAt = date(2027, 5, 22)
        let csv = text(CSVExporter.salesCSV([record], calendar: calendar))
        #expect(csv.contains(",2027-05-22,\"山田, 太郎様\",\"「初回」\n同梱あり\"\r\n"))
    }

    @Test func 販売は日付の古い順() {
        let csv = text(CSVExporter.salesCSV([sale(date: date(2027, 6, 1)), sale(date: date(2027, 5, 1))], calendar: calendar))
        let lines = csv.components(separatedBy: "\r\n")
        #expect(lines[1].hasPrefix("2027-05-01"))
        #expect(lines[2].hasPrefix("2027-06-01"))
    }

    @Test func 群CSVの未計数と日齢() {
        let hatched = CohortRecord(
            lineName: "〇〇めだか", breedName: "楊貴妃", generation: 2, tankName: "A-1", count: 30, stage: .young,
            hatchedAt: date(2027, 5, 1), status: .active, note: ""
        )
        let acquired = CohortRecord(
            lineName: "", breedName: "幹之", generation: 0, tankName: "", count: nil, stage: .adult,
            hatchedAt: nil, status: .soldOut, note: "メモ,あり"
        )
        let csv = text(CSVExporter.cohortsCSV([hatched, acquired], now: date(2027, 5, 11), calendar: calendar))
        let lines = csv.components(separatedBy: "\r\n")
        #expect(lines[0] == "系統,品種,世代,容器,匹数,段階,孵化日,日齢,状態,メモ")
        #expect(lines[1] == "〇〇めだか,楊貴妃,F2,A-1,30,若魚,2027-05-01,10,飼育中,")
        #expect(lines[2] == ",幹之,入手,,,成魚,,,完売,\"メモ,あり\"")
    }
}
