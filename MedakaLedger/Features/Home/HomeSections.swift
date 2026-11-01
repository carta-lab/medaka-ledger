import SwiftData
import SwiftUI

// ホームの各枠（孵化予定、育卵中、水換えの期限超え、最近の記録）。

extension HomeView {
    @ViewBuilder
    func hatchDueSection(_ entries: [BatchEntry]) -> some View {
        if !entries.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                SectionHeading("孵化予定")
                ForEach(entries) { entry in
                    Button {
                        model.hatchingBatch = entry.batch
                    } label: {
                        EggBatchRow(batch: entry.batch, info: entry.info)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    func incubatingSection(_ entries: [BatchEntry]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionHeading(title: "育卵中") {
                if entries.count > 5 {
                    Button("すべて見る") { router.selectedTab = .breeding }
                        .font(.subheadline)
                }
            }
            if entries.isEmpty {
                Text("育卵中のロットはありません")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            ForEach(entries.prefix(5)) { entry in
                Button {
                    model.hatchingBatch = entry.batch
                } label: {
                    EggBatchRow(batch: entry.batch, info: entry.info)
                }
                .buttonStyle(.plain)
            }
        }
    }

    var overdueSection: some View {
        let overdue = model.overdueTanks(tanks, settings: settings)
        return VStack(alignment: .leading, spacing: 8) {
            SectionHeading("水換えの期限超え")
            if overdue.isEmpty {
                Text("期限を超えた容器はありません")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            ForEach(overdue) { item in
                NavigationLink(value: Route.tank(item.tank)) {
                    HStack {
                        Label(item.tank.name, systemImage: item.tank.kind.symbolName)
                        Spacer()
                        Text(verbatim: String(localized: "\(item.days.formatted())日"))
                            .font(.subheadline.bold())
                            .foregroundStyle(Theme.warning)
                    }
                    .contentShape(.rect)
                }
                .buttonStyle(.plain)
            }
        }
    }

    /// 出品中の販売（SCREENS.md 2）。タップで販売の編集。
    var listedSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionHeading(title: "出品中") {
                if listedSales.count > 5 {
                    Button("すべて見る") { router.selectedTab = .sales }
                        .font(.subheadline)
                }
            }
            if listedSales.isEmpty {
                Text("出品中の販売はありません")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            ForEach(listedSales.prefix(5)) { sale in
                Button {
                    model.editingSale = sale
                } label: {
                    SaleRow(record: SaleOperations.record(of: sale), title: sale.titleText)
                }
                .buttonStyle(.plain)
            }
        }
    }

    var recentSection: some View {
        let records = model.recentRecords(events: recentEvents, batches: recentBatches, logs: recentLogs, sales: recentSales)
        return VStack(alignment: .leading, spacing: 8) {
            SectionHeading("最近の記録")
            if records.isEmpty {
                Text("記録はまだありません")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            ForEach(records) { record in
                if let route = record.route {
                    NavigationLink(value: route) {
                        RecentRecordRow(record: record)
                    }
                    .buttonStyle(.plain)
                } else {
                    RecentRecordRow(record: record)
                }
            }
        }
    }
}

struct RecentRecordRow: View {
    let record: RecentRecord

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: record.symbolName)
                .foregroundStyle(Theme.accent)
                .frame(width: 24)
            VStack(alignment: .leading, spacing: 2) {
                Text(verbatim: record.title)
                    .font(.subheadline.bold())
                Text(verbatim: record.subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
            Text(verbatim: CohortText.shortDate(record.date))
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
        .contentShape(.rect)
    }
}
