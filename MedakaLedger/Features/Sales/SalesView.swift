import SwiftData
import SwiftUI

// 販売タブ（SCREENS.md 8.1）。期間の切り替えと集計、月ごとのセクションに販売の行。
// Proの限定は、年別の集計、CSVの書き出し、出品文。確認が済むまでは出さない（DECISIONS.md G 3-10）。

struct SalesView: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.modelContext) private var modelContext
    @Environment(ProStore.self) private var pro
    @Query(sort: \Sale.date, order: .reverse) private var sales: [Sale]
    @State private var model = SalesModel()
    @State private var gate = LimitGate()

    var body: some View {
        let ledger = model.ledger(for: sales)
        let byID = Dictionary(sales.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        Group {
            if sales.isEmpty {
                LedgerEmptyState(title: "販売の記録はまだありません", message: "最初の販売を記録しましょう",
                                 systemImage: "yensign", actionTitle: "販売を記録",
                                 actionIdentifier: "addFirstSaleButton") {
                    model.isAdding = true
                }
            } else {
                list(ledger, byID: byID)
            }
        }
        .themedBackground()
        .navigationTitle("販売")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { model.isAdding = true } label: {
                    Label("販売を記録", systemImage: "plus")
                }
                .accessibilityIdentifier("addSaleButton")
            }
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button {
                        model.isAdding = true
                    } label: {
                        Label("販売を記録", systemImage: "plus")
                    }
                    .accessibilityIdentifier("addSaleMenuItem")
                    Button {
                        gate.requirePro(.salesCSV, pro: pro) { model.isExporting = true }
                    } label: {
                        Label("CSVを書き出す", systemImage: pro.isPro ? "square.and.arrow.up" : "lock")
                    }
                    .disabled(sales.isEmpty)
                    Button {
                        gate.requirePro(.listingText, pro: pro) { model.isShowingListing = true }
                    } label: {
                        Label("出品文を作る", systemImage: pro.isPro ? "text.badge.plus" : "lock")
                    }
                    .accessibilityIdentifier("listingMenuItem")
                } label: {
                    Label("メニュー", systemImage: "ellipsis.circle")
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
        .sheet(isPresented: $model.isShowingListing) {
            ListingSheet()
        }
        .paywall(gate)
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
            Group {
                EntryHeading(title: "販売台帳", subtitle: "育てた先の記録を、ひと目で。",
                             systemImage: "yensign")
                Section {
                    if dynamicTypeSize.isAccessibilitySize {
                        periodPicker.pickerStyle(.menu)
                    } else {
                        periodPicker.pickerStyle(.segmented)
                    }
                    SalesOverview(summary: ledger.summary)
                } footer: {
                    Text("集計は売約と発送済の販売です。出品中と取消は入りません。")
                }

                if model.period == .all, pro.status == .free {
                    Section {
                        Button {
                            gate.present(reason: .feature(.yearlySummary))
                        } label: {
                            Label("年別の集計はProで見られます", systemImage: "lock")
                        }
                        .accessibilityIdentifier("yearlySummaryProButton")
                    }
                }

                if model.period == .all, pro.isPro {
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
            .ledgerRow()
        }
        .accessibilityIdentifier("salesList")
    }

    private var periodPicker: some View {
        Picker("期間", selection: $model.period) {
            ForEach(SalesPeriod.allCases, id: \.self) { period in
                Text(verbatim: period.label).tag(period)
            }
        }
        .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
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
                .tint(.secondary)
            }
        }
    }
}

