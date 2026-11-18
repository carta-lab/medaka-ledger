import SwiftData
import SwiftUI

/// 既存の増減処理への入口。CountLedger と、0匹になった際の確認をそのまま使う。
@MainActor
struct QuickCountSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(filter: Cohort.activePredicate, sort: \Cohort.createdAt) private var cohorts: [Cohort]
    @State private var selected: Cohort?
    @State private var lastSelected: Cohort?
    @State private var detail = CohortDetailModel()

    var body: some View {
        NavigationStack {
            List {
                Group {
                    EntryHeading(title: "増減を記録", subtitle: "匹数を記録する群を選んでください。", systemImage: "plusminus")
                    if cohorts.isEmpty {
                        Text("飼育中の群はありません。系統の詳細から、入手個体の群を登録しましょう。")
                            .foregroundStyle(Theme.muted)
                    }
                    ForEach(cohorts) { cohort in
                        Button {
                            detail.open(.count, cohort: cohort)
                            lastSelected = cohort
                            selected = cohort
                        } label: {
                            CohortSummaryRow(cohort: cohort, showsTank: true)
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("quickCountRow.\(cohort.id.uuidString)")
                    }
                }
                .ledgerRow()
            }
            .themedBackground()
            .navigationTitle("増減")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("閉じる") { dismiss() }
                }
            }
            .sheet(item: $selected, onDismiss: {
                if let lastSelected { detail.sheetDismissed(cohort: lastSelected) }
                detail.activeSheet = nil
            }) { cohort in
                CountChangeSheet(cohort: cohort)
            }
            .confirmationDialog("この群を終了しますか", isPresented: $detail.isAskingToEnd, titleVisibility: .visible) {
                if let lastSelected {
                    Button("完売") { detail.end(lastSelected, as: .soldOut, in: modelContext) }
                    Button("全滅") { detail.end(lastSelected, as: .lost, in: modelContext) }
                }
                Button("そのまま", role: .cancel) {}
            } message: {
                Text("匹数が0になりました。")
            }
            .errorAlert($detail.error)
        }
    }
}
