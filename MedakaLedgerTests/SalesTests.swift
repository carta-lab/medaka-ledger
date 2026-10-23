import Foundation
import Testing
@testable import MedakaLedger

struct SaleRulesTests {
    @Test func 販売で減らす匹数() {
        #expect(SaleRules.fishToDeduct(unit: .fish, quantity: 3, bundleFishCount: nil) == 3)
        #expect(SaleRules.fishToDeduct(unit: .pair, quantity: 3, bundleFishCount: nil) == 6)
        #expect(SaleRules.fishToDeduct(unit: .trio, quantity: 2, bundleFishCount: nil) == 6)
        #expect(SaleRules.fishToDeduct(unit: .eggs, quantity: 10, bundleFishCount: nil) == 0)
        #expect(SaleRules.fishToDeduct(unit: .fryBundle, quantity: 1, bundleFishCount: 25) == 25)
        #expect(SaleRules.fishToDeduct(unit: .fryBundle, quantity: 1, bundleFishCount: nil) == 0)
    }

    @Test func 合計と純額() {
        #expect(SaleRules.defaultTotal(quantity: 3, unitPrice: 800) == 2400)
        #expect(SaleRules.net(total: 8000, fee: 800, shipping: 1200) == 6000)
        #expect(SaleRules.net(total: 500, fee: 100, shipping: 600) == -200)
    }

    @Test func 集計に入る状態() {
        #expect(SaleRules.countsInTotals(.sold))
        #expect(SaleRules.countsInTotals(.shipped))
        #expect(!SaleRules.countsInTotals(.listed))
        #expect(!SaleRules.countsInTotals(.cancelled))
    }

    @Test func 状態の次() {
        #expect(SaleRules.nextStatus(after: .listed) == .sold)
        #expect(SaleRules.nextStatus(after: .sold) == .shipped)
        #expect(SaleRules.nextStatus(after: .shipped) == nil)
        #expect(SaleRules.nextStatus(after: .cancelled) == nil)
    }
}

struct SaleOverflowTests {
    @Test func 掛け算は桁あふれしない() {
        #expect(SaleRules.defaultTotal(quantity: Int.max, unitPrice: Int.max) == Int.max)
        #expect(SaleRules.fishToDeduct(unit: .pair, quantity: Int.max, bundleFishCount: nil) == Int.max)
        #expect(SaleRules.fishToDeduct(unit: .trio, quantity: Int.max, bundleFishCount: nil) == Int.max)
        #expect(SaleRules.defaultTotal(quantity: 3, unitPrice: 800) == 2400)
    }

    @Test func 純額は桁あふれしない() {
        #expect(SaleRules.net(total: 0, fee: Int.max, shipping: Int.max) == -2 * SaleRules.maxAmount)
        #expect(SaleRules.net(total: Int.max, fee: 0, shipping: 0) == SaleRules.maxAmount)
    }

    @Test func 集計は桁あふれしない() {
        let big = SaleRecord(
            id: UUID(), date: Date(), status: .sold, channel: .other, unit: .fish, quantity: 1, unitPrice: 0,
            totalPrice: Int.max, fee: Int.max, shippingCost: Int.max, shippedAt: nil, buyerMemo: "", note: "",
            breedName: "", lineName: "", generation: 0
        )
        let summary = SalesAggregations.summary([big, big, big])
        #expect(summary.revenue == 3 * SaleRules.maxAmount)
        #expect(summary.count == 3)
    }
}

struct SalesAggregationsTests {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Tokyo") ?? .gmt
        return calendar
    }

    private func date(_ year: Int, _ month: Int, _ day: Int, hour: Int = 12) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour)) ?? .distantPast
    }

    private func record(_ date: Date, total: Int, fee: Int = 0, shipping: Int = 0, status: SaleStatus = .sold) -> SaleRecord {
        SaleRecord(
            id: UUID(), date: date, status: status, channel: .yahooAuction, unit: .fish, quantity: 1, unitPrice: total,
            totalPrice: total, fee: fee, shippingCost: shipping, shippedAt: nil, buyerMemo: "", note: "",
            breedName: "楊貴妃", lineName: "", generation: 1
        )
    }

    @Test func 集計は売約と発送済だけ() {
        let records = [
            record(date(2027, 5, 1), total: 8000, fee: 800, shipping: 1200),
            record(date(2027, 5, 2), total: 3000, status: .shipped),
            record(date(2027, 5, 3), total: 5000, status: .listed),
            record(date(2027, 5, 4), total: 7000, status: .cancelled),
        ]
        let summary = SalesAggregations.summary(records)
        #expect(summary == SalesSummary(count: 2, revenue: 11000, fee: 800, shipping: 1200))
        #expect(summary.net == 9000)
    }

    @Test func 月別は新しい月から行は新しい日から() {
        let records = [
            record(date(2027, 4, 30), total: 100),
            record(date(2027, 5, 1), total: 200),
            record(date(2027, 5, 20), total: 300),
            record(date(2026, 12, 31), total: 400),
        ]
        let sections = SalesAggregations.monthSections(records, calendar: calendar)
        #expect(sections.map(\.id) == [202705, 202704, 202612])
        #expect(sections[0].records.map(\.totalPrice) == [300, 200])
        #expect(sections[0].summary.revenue == 500)
        #expect(sections[2].summary.count == 1)
    }

    @Test func 月の境目は日付で決まる() {
        // 日本時間の5月1日0時台は、UTCでは4月30日。日本の暦で5月に入る
        let early = date(2027, 5, 1, hour: 0)
        let sections = SalesAggregations.monthSections([record(early, total: 100)], calendar: calendar)
        #expect(sections.map(\.id) == [202705])
    }

    @Test func 期間の切り替え() {
        let now = date(2027, 5, 15)
        let records = [
            record(date(2027, 5, 1), total: 1),
            record(date(2027, 4, 30), total: 2),
            record(date(2026, 5, 15), total: 3),
        ]
        #expect(SalesAggregations.filter(records, period: .thisMonth, now: now, calendar: calendar).map(\.totalPrice) == [1])
        #expect(SalesAggregations.filter(records, period: .thisYear, now: now, calendar: calendar).map(\.totalPrice) == [1, 2])
        #expect(SalesAggregations.filter(records, period: .all, now: now, calendar: calendar).count == 3)
    }

    @Test func 開始日と終了日は両端を含む() {
        let records = [
            record(date(2027, 5, 1, hour: 0), total: 1),
            record(date(2027, 5, 31, hour: 23), total: 2),
            record(date(2027, 6, 1, hour: 0), total: 3),
            record(date(2027, 4, 30, hour: 23), total: 4),
        ]
        let result = SalesAggregations.filter(records, from: date(2027, 5, 1, hour: 18), to: date(2027, 5, 31, hour: 6), calendar: calendar)
        #expect(result.map(\.totalPrice) == [1, 2])
    }

    @Test func 年別は新しい年から() {
        let records = [
            record(date(2026, 6, 1), total: 100),
            record(date(2027, 1, 1), total: 200),
            record(date(2027, 2, 1), total: 300, status: .cancelled),
        ]
        let years = SalesAggregations.yearSummaries(records, calendar: calendar)
        #expect(years.map(\.year) == [2027, 2026])
        #expect(years[0].summary.revenue == 200)
    }
}
