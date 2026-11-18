import SwiftUI

// 販売台帳の行と集計の表示（SCREENS.md 8.1）。

struct SaleRow: View {
    let record: SaleRecord
    let title: String

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            Text(verbatim: CohortText.shortDate(record.date))
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .frame(minWidth: 52, alignment: .leading)
            VStack(alignment: .leading, spacing: 2) {
                Text(verbatim: title)
                    .font(.headline)
                    .lineLimit(2)
                HStack(spacing: 6) {
                    Text(verbatim: "\(SaleText.quantity(unit: record.unit, quantity: record.quantity))　\(record.channel.label)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    SaleStatusBadge(status: record.status)
                }
            }
            Spacer(minLength: 8)
            Text(verbatim: SaleText.yen(record.totalPrice))
                .font(.headline)
                .monospacedDigit()
            Image(systemName: "chevron.right")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 4)
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
/// 売上を大きく、手数料、送料、純額を下に並べる集計の札。
struct SalesSummaryCard: View {
    let summary: SalesSummary

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text("売上")
                    .font(Typeface.heading(17, relativeTo: .headline))
                Spacer(minLength: 8)
                Text(verbatim: String(localized: "\(summary.count.formatted())件"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Text(verbatim: SaleText.yen(summary.revenue))
                .font(Typeface.heading(40, relativeTo: .largeTitle))
                .foregroundStyle(Theme.accent)
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            Rectangle().fill(Theme.rule).frame(height: 1)
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .top, spacing: 0) {
                    figure("手数料", summary.fee)
                    divider
                    figure("送料", summary.shipping)
                    divider
                    figure("純額", summary.net)
                }
                VStack(alignment: .leading, spacing: 8) {
                    figure("手数料", summary.fee)
                    figure("送料", summary.shipping)
                    figure("純額", summary.net)
                }
            }
        }
        .cardBackground()
        .accessibilityElement(children: .combine)
    }

    private var divider: some View {
        Rectangle().fill(Theme.rule).frame(width: 1).padding(.vertical, 2)
    }

    private func figure(_ title: LocalizedStringKey, _ amount: Int) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(verbatim: SaleText.yen(amount))
                .font(Typeface.heading(18, relativeTo: .headline))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .padding(.horizontal, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

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
