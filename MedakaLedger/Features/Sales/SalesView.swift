import SwiftData
import SwiftUI

// 販売タブ（SCREENS.md 8.1）。期間の切り替えと集計、月ごとのセクションに販売の行。
// Proの限定（年別集計、CSV）は第5週で ProStore をつなぐ。それまでは全て使える（DECISIONS.md H）。

struct SalesView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Sale.date, order: .reverse) private var sales: [Sale]
    @State private var model = SalesModel()

    var body: some View {
        let ledger = model.ledger(for: sales)
        let byID = Dictionary(sales.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        Group {
            if sales.isEmpty {
                ContentUnavailableView {
                    Label("販売の記録はまだありません", systemImage: "yensign.circle")
                } description: {
                    Text("最初の販売を記録しましょう")
                } actions: {
                    Button("販売を記録") { model.isAdding = true }
                        .buttonStyle(LargeButtonStyle())
                        .accessibilityIdentifier("addFirstSaleButton")
                }
            } else {
                list(ledger, byID: byID)
            }
        }
        .navigationTitle("販売")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button {
                        model.isAdding = true
                    } label: {
                        Label("販売を記録", systemImage: "plus")
                    }
                    Button {
                        model.isExporting = true
                    } label: {
                        Label("CSVを書き出す", systemImage: "square.and.arrow.up")
                    }
                    .disabled(sales.isEmpty)
                } label: {
                    Label("メニュー", systemImage: "plus.circle")
                }
                .accessibilityIdentifier("salesMenu")
            }
        }
        .sheet(isPresented: $model.isAdding) {
            SaleSheet()
        }
        .sheet(item: $model.editing) { sale in
            SaleSheet(sale: sale)
        }
        .sheet(isPresented: $model.isExporting) {
            SalesExportSheet(records: sales.map(SaleOperations.record(of:)))
        }
        .confirmationDialog(
            "この販売を削除しますか",
            isPresented: $model.isConfirmingDeletion,
            titleVisibility: .visible,
            presenting: model.salePendingDeletion
        ) { sale in
            Button("削除", role: .destructive) { model.delete(sale, in: modelContext) }
            Button("キャンセル", role: .cancel) {}
        } message: { _ in
            Text("記録だけが消えます。群の匹数は元に戻りません。")
        }
        .errorAlert($model.error)
    }

    private func list(_ ledger: SalesModel.Ledger, byID: [UUID: Sale]) -> some View {
        List {
            Section {
                Picker("期間", selection: $model.period) {
                    ForEach(SalesPeriod.allCases, id: \.self) { period in
                        Text(verbatim: period.label).tag(period)
                    }
                }
                .pickerStyle(.segmented)
                .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                SalesSummaryRows(summary: ledger.summary)
            } footer: {
                Text("集計は売約と発送済の販売です。出品中と取消は入りません。")
            }

            if model.period == .all {
                let years = SalesAggregations.yearSummaries(ledger.records, calendar: .current)
                if !years.isEmpty {
                    Section("年別") {
                        ForEach(years) { year in
                            LabeledContent(String(localized: "\(year.year.formatted(.number.grouping(.never)))年")) {
                                VStack(alignment: .trailing) {
                                    Text(verbatim: SaleText.yen(year.summary.revenue))
                                    Text(verbatim: String(localized: "純額 \(SaleText.yen(year.summary.net))"))
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                }
            }

            if ledger.sections.isEmpty {
                Section {
                    Text("この期間の販売はありません。期間を切り替えるか、販売を記録しましょう。")
                        .foregroundStyle(.secondary)
                }
            }

            ForEach(ledger.sections) { section in
                Section {
                    ForEach(section.records) { record in
                        if let sale = byID[record.id] {
                            row(record, sale: sale)
                        }
                    }
                } header: {
                    Text(verbatim: "\(SaleText.month(year: section.year, month: section.month))　\(SaleText.yen(section.summary.revenue))")
                }
            }
        }
        .accessibilityIdentifier("salesList")
    }

    private func row(_ record: SaleRecord, sale: Sale) -> some View {
        Button {
            model.editing = sale
        } label: {
            SaleRow(record: record, title: sale.titleText)
        }
        .buttonStyle(.plain)
        .swipeActions(edge: .leading) {
            if let next = SaleRules.nextStatus(after: sale.status) {
                Button {
                    model.advance(sale, in: modelContext)
                } label: {
                    Text(verbatim: String(localized: "\(next.label)にする"))
                }
                .tint(Theme.accent)
            }
        }
        .swipeActions(edge: .trailing) {
            Button(role: .destructive) {
                model.askToDelete(sale)
            } label: {
                Label("削除", systemImage: "trash")
            }
            if sale.status != .cancelled {
                Button {
                    model.cancel(sale, in: modelContext)
                } label: {
                    Label("取消", systemImage: "xmark.circle")
                }
                .tint(.gray)
            }
        }
    }
}
