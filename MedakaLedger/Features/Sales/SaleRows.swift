import SwiftUI

// 販売台帳の行と集計の表示（SCREENS.md 8.1）。

struct SaleRow: View {
    let record: SaleRecord
    let title: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline) {
                Text(verbatim: title)
                    .font(.headline)
                Spacer(minLength: 8)
                SaleStatusBadge(status: record.status)
            }
            HStack(alignment: .firstTextBaseline) {
                Text(verbatim: "\(CohortText.shortDate(record.date))　\(SaleText.quantity(unit: record.unit, quantity: record.quantity))　\(record.channel.label)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Spacer(minLength: 8)
                Text(verbatim: SaleText.yen(record.totalPrice))
                    .font(.subheadline.bold())
            }
        }
        .padding(.vertical, 2)
        .accessibilityElement(children: .combine)
    }
}

struct SaleStatusBadge: View {
    let status: SaleStatus

    var body: some View {
        Text(verbatim: status.label)
            .font(.caption.bold())
            .padding(.horizontal, 8)
            .padding(.vertical, 2)
            .foregroundStyle(foreground)
            .background(background, in: .capsule)
    }

    private var foreground: Color {
        switch status {
        case .listed: Theme.caution
        case .sold: Theme.accent
        case .shipped: Theme.done
        case .cancelled: .secondary
        }
    }

    private var background: Color {
        foreground.opacity(0.15)
    }
}

/// 売上、手数料、送料、純額、件数。
struct SalesSummaryRows: View {
    let summary: SalesSummary

    var body: some View {
        InfoRow(title: "売上", value: SaleText.yen(summary.revenue))
        InfoRow(title: "手数料", value: SaleText.yen(summary.fee))
        InfoRow(title: "送料", value: SaleText.yen(summary.shipping))
        LabeledContent("純額") {
            Text(verbatim: SaleText.yen(summary.net))
                .font(Typeface.heading(19, relativeTo: .headline))
                .monospacedDigit()
        }
        InfoRow(title: "件数", value: String(localized: "\(summary.count.formatted())件"))
    }
}

extension SalesPeriod {
    var label: String {
        switch self {
        case .thisMonth: String(localized: "今月")
        case .thisYear: String(localized: "今年")
        case .all: String(localized: "全期間")
        }
    }
}
