import Foundation

// 販売の集計（PRD.md F6、SCREENS.md 8.1）。SwiftDataのモデルから値型に写して計算する。

struct SaleRecord: Equatable, Sendable, Identifiable {
    var id: UUID
    var date: Date
    var status: SaleStatus
    var channel: SaleChannel
    var unit: SaleUnit
    var quantity: Int
    var unitPrice: Int
    var totalPrice: Int
    var fee: Int
    var shippingCost: Int
    var shippedAt: Date?
    var buyerMemo: String
    var note: String
    var breedName: String
    var lineName: String
    var generation: Int

    var net: Int { SaleRules.net(total: totalPrice, fee: fee, shipping: shippingCost) }
}

struct SalesSummary: Equatable, Sendable {
    var count = 0
    var revenue = 0
    var fee = 0
    var shipping = 0
    var net: Int { revenue - fee - shipping }
}

struct SalesMonthSection: Identifiable, Equatable, Sendable {
    var year: Int
    var month: Int
    var records: [SaleRecord]
    var summary: SalesSummary
    var id: Int { year * 100 + month }
}

struct SalesYearSummary: Identifiable, Equatable, Sendable {
    var year: Int
    var summary: SalesSummary
    var id: Int { year }
}

enum SalesPeriod: String, CaseIterable, Sendable {
    case thisMonth, thisYear, all
}

enum SalesAggregations {
    /// 売約と発送済だけを合計する。出品中と取消は入れない。
    static func summary(_ records: [SaleRecord]) -> SalesSummary {
        records.filter { SaleRules.countsInTotals($0.status) }.reduce(into: SalesSummary()) { result, record in
            result.count += 1
            result.revenue += SaleRules.clamped(record.totalPrice)
            result.fee += SaleRules.clamped(record.fee)
            result.shipping += SaleRules.clamped(record.shippingCost)
        }
    }

    /// 期間で絞る。今月と今年は now を含む月と年。
    static func filter(_ records: [SaleRecord], period: SalesPeriod, now: Date, calendar: Calendar) -> [SaleRecord] {
        switch period {
        case .all:
            return records
        case .thisMonth:
            return records.filter { calendar.isDate($0.date, equalTo: now, toGranularity: .month) }
        case .thisYear:
            return records.filter { calendar.isDate($0.date, equalTo: now, toGranularity: .year) }
        }
    }

    /// 開始日と終了日（どちらも含む）で絞る。日単位でそろえる。
    static func filter(_ records: [SaleRecord], from start: Date, to end: Date, calendar: Calendar) -> [SaleRecord] {
        let first = calendar.startOfDay(for: start)
        let last = calendar.startOfDay(for: end)
        return records.filter {
            let day = calendar.startOfDay(for: $0.date)
            return day >= first && day <= last
        }
    }

    /// 月ごとのセクション。新しい月から。行は日付の新しい順で、同じ日付なら入力の順を保つ。
    static func monthSections(_ records: [SaleRecord], calendar: Calendar) -> [SalesMonthSection] {
        let sorted = records.enumerated()
            .sorted { lhs, rhs in
                if lhs.element.date != rhs.element.date { return lhs.element.date > rhs.element.date }
                return lhs.offset < rhs.offset
            }
            .map(\.element)
        var sections: [SalesMonthSection] = []
        for record in sorted {
            let parts = calendar.dateComponents([.year, .month], from: record.date)
            let year = parts.year ?? 0
            let month = parts.month ?? 0
            if let index = sections.firstIndex(where: { $0.year == year && $0.month == month }) {
                sections[index].records.append(record)
            } else {
                sections.append(SalesMonthSection(year: year, month: month, records: [record], summary: SalesSummary()))
            }
        }
        for index in sections.indices {
            sections[index].summary = summary(sections[index].records)
        }
        return sections
    }

    /// 年別の集計。新しい年から（Proの機能。PRD.md 7章）。
    static func yearSummaries(_ records: [SaleRecord], calendar: Calendar) -> [SalesYearSummary] {
        Dictionary(grouping: records) { calendar.component(.year, from: $0.date) }
            .map { SalesYearSummary(year: $0.key, summary: summary($0.value)) }
            .sorted { $0.year > $1.year }
    }
}
