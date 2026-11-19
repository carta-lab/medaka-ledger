import SwiftUI

/// 集計値は既存 SalesAggregations から受け取る。出品中・取消の扱いも変えない。
@MainActor
struct SalesOverview: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    let summary: SalesSummary

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 8) {
                Text("売上").font(.subheadline).foregroundStyle(Theme.muted)
                Text(verbatim: SaleText.yen(summary.revenue))
                    .font(Typeface.heading(40, relativeTo: .largeTitle))
                    .foregroundStyle(Theme.accent)
                    .monospacedDigit()
                    .fixedSize(horizontal: false, vertical: true)
                Text(verbatim: String(localized: "\(summary.count.formatted())件"))
                    .font(.caption).foregroundStyle(Theme.muted)
            }
            Rectangle().fill(Theme.rule).frame(height: 1)
            let layout = dynamicTypeSize.isAccessibilitySize
                ? AnyLayout(VStackLayout(alignment: .leading, spacing: 16))
                : AnyLayout(HStackLayout(alignment: .top, spacing: 16))
            layout {
                amount("手数料", summary.fee)
                amount("送料", summary.shipping)
                amount("純額", summary.net)
            }
        }
        .padding(.vertical, 8)
        .accessibilityElement(children: .combine)
    }

    private func amount(_ title: LocalizedStringKey, _ amount: Int) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(.caption).foregroundStyle(Theme.muted)
            Text(verbatim: SaleText.yen(amount)).font(Typeface.heading(18, relativeTo: .headline)).monospacedDigit()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
