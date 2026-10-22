import SwiftData
import SwiftUI

// ホームの各枠（孵化予定、育卵中、水換えの期限超え、最近の記録）。

extension HomeView {
    @ViewBuilder
    func hatchDueSection(_ entries: [BatchEntry]) -> some View {
        if !entries.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                Text("孵化予定")
                    .font(.headline)
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
            HStack {
                Text("育卵中")
                    .font(.headline)
                Spacer()
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
            Text("水換えの期限超え")
                .font(.headline)
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

    var recentSection: some View {
        let records = model.recentRecords(events: recentEvents, batches: recentBatches, logs: recentLogs)
        return VStack(alignment: .leading, spacing: 8) {
            Text("最近の記録")
                .font(.headline)
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
