import SwiftData
import SwiftUI

// 群詳細（SCREENS.md 5.1）。見出し、要約、操作ボタン、タイムライン。
// 操作は移動、分割、増減、選別、販売、段階の変更、統合、出来事の削除、群の削除。

struct CohortDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(ProStore.self) private var pro
    @Bindable var cohort: Cohort
    @State private var model = CohortDetailModel()
    @State private var gate = LimitGate()

    var body: some View {
        if cohort.isDeleted {
            ContentUnavailableView("この群は削除されました", systemImage: "trash")
        } else {
            content
        }
    }

    private var content: some View {
        List {
            summarySection
            if cohort.isActive {
                actionSection
            }
            Section("親") {
                Text(cohort.originBatch == nil ? LocalizedStringKey("入手個体") : LocalizedStringKey("親魚セットから孵化"))
                    .foregroundStyle(.secondary)
            }
            PhotoSection(owner: .cohort(cohort))
            CohortTimelineSection(cohort: cohort, model: model)
        }
        .navigationTitle(cohort.strainName)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button {
                        model.open(.merge, cohort: cohort)
                    } label: {
                        Label("統合", systemImage: "arrow.triangle.merge")
                    }
                    .disabled(!cohort.isActive)
                    Button {
                        model.open(.stage, cohort: cohort)
                    } label: {
                        Label("段階の変更", systemImage: "chart.line.uptrend.xyaxis")
                    }
                    .disabled(!cohort.isActive)
                    Button {
                        gate.requirePro(.listingText, pro: pro) { model.open(.listing, cohort: cohort) }
                    } label: {
                        Label("出品文を作る", systemImage: pro.isPro ? "text.badge.plus" : "lock")
                    }
                    NavigationLink(value: Route.lineage(cohort)) {
                        Label("血統図", systemImage: "list.bullet.indent")
                    }
                    Button {
                        model.open(.edit, cohort: cohort)
                    } label: {
                        Label("編集", systemImage: "pencil")
                    }
                    Divider()
                    if CohortOperations.isUsedByBreedingSet(cohort) {
                        // 親魚セットに使われた群は削除できず、アーカイブだけ（DECISIONS.md C）
                        Button {
                            model.end(cohort, as: .archived, in: modelContext)
                        } label: {
                            Label("アーカイブ", systemImage: "archivebox")
                        }
                        .disabled(cohort.status == .archived)
                    } else {
                        Button(role: .destructive) {
                            model.isConfirmingCohortDeletion = true
                        } label: {
                            Label("群を削除", systemImage: "trash")
                        }
                    }
                } label: {
                    Label("メニュー", systemImage: "ellipsis.circle")
                }
            }
        }
        .sheet(item: $model.activeSheet, onDismiss: { model.sheetDismissed(cohort: cohort) }) { sheet in
            switch sheet {
            case .move: MoveCohortSheet(cohort: cohort)
            case .split: SplitCohortSheet(cohort: cohort)
            case .count: CountChangeSheet(cohort: cohort)
            case .selection: SelectionSheet(cohort: cohort)
            case .sale: SaleSheet(cohort: cohort)
            case .stage: StageChangeSheet(cohort: cohort)
            case .merge: MergeCohortSheet(cohort: cohort)
            case .edit: CohortEditView(cohort: cohort)
            case .listing: ListingSheet(cohort: cohort)
            }
        }
        .confirmationDialog("この群を終了しますか", isPresented: $model.isAskingToEnd, titleVisibility: .visible) {
            Button("完売") { model.end(cohort, as: .soldOut, in: modelContext) }
            Button("全滅") { model.end(cohort, as: .lost, in: modelContext) }
            Button("そのまま", role: .cancel) {}
        } message: {
            Text("匹数が0になりました。")
        }
        .confirmationDialog(
            "この記録を削除しますか",
            isPresented: $model.isConfirmingEventDeletion,
            titleVisibility: .visible,
            presenting: model.eventPendingDeletion
        ) { event in
            Button("削除", role: .destructive) {
                model.delete(event, in: modelContext)
                // 分割先の群で分割を取り消すと、この群そのものが消える
                if cohort.isDeleted { dismiss() }
            }
            Button("キャンセル", role: .cancel) {}
        } message: { event in
            Text(verbatim: model.deletionMessage(for: event))
        }
        .confirmationDialog(
            "この選別の記録を削除しますか",
            isPresented: $model.isConfirmingSelectionDeletion,
            titleVisibility: .visible,
            presenting: model.selectionPendingDeletion
        ) { selection in
            Button("削除", role: .destructive) { model.delete(selection, in: modelContext) }
            Button("キャンセル", role: .cancel) {}
        } message: { _ in
            Text("記録だけが消えます。匹数と、分けた群は元に戻りません。")
        }
        .alert("この群を削除しますか", isPresented: $model.isConfirmingCohortDeletion) {
            Button("削除", role: .destructive) {
                if model.deleteCohort(cohort, in: modelContext) {
                    dismiss()
                }
            }
            Button("キャンセル", role: .cancel) {}
        } message: {
            Text("群のタイムラインもすべて消えます。元に戻せません。")
        }
        .errorAlert($model.error)
        .paywall(gate)
    }

    private var summarySection: some View {
        Section {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text(verbatim: cohort.generationLabel)
                        .font(.title2.bold())
                    if !cohort.label.isEmpty {
                        Text(verbatim: cohort.label)
                            .font(.title3)
                    }
                    Spacer(minLength: 0)
                    if !cohort.isActive {
                        Text(verbatim: cohort.status.label)
                            .font(.subheadline.bold())
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(.fill.tertiary, in: .capsule)
                    }
                }
                Text(verbatim: cohort.countText)
                    .font(.largeTitle.bold())
                    .accessibilityIdentifier("cohortCount")
                if let sex = cohort.sexText {
                    Text(verbatim: sex)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.vertical, 4)
            InfoRow(title: "容器", value: cohort.tankName)
            InfoRow(title: "段階", value: cohort.stage.label)
            if let hatchedAt = cohort.hatchedAt {
                InfoRow(title: "孵化日", value: model.hatchedText(hatchedAt))
            } else if let acquiredAt = cohort.acquiredAt {
                InfoRow(title: "入手日", value: model.acquiredText(acquiredAt))
            }
            if !cohort.sizeText.isEmpty {
                InfoRow(title: "サイズ", value: cohort.sizeText)
            }
            if !cohort.note.isEmpty {
                Text(verbatim: cohort.note)
                    .font(.subheadline)
            }
        }
    }

    private var actionSection: some View {
        Section {
            VStack(spacing: 8) {
                HStack(spacing: 8) {
                    actionButton("移動", systemImage: "arrow.right", sheet: .move)
                    actionButton("分割", systemImage: "arrow.triangle.branch", sheet: .split)
                }
                HStack(spacing: 8) {
                    actionButton("増減", systemImage: "plusminus", sheet: .count)
                    actionButton("選別", systemImage: "line.3.horizontal.decrease.circle", sheet: .selection)
                }
                actionButton("販売", systemImage: "yensign.circle", sheet: .sale)
            }
            .listRowInsets(EdgeInsets(top: 8, leading: 8, bottom: 8, trailing: 8))
        }
    }

    private func actionButton(_ title: LocalizedStringKey, systemImage: String, sheet: CohortDetailModel.Sheet) -> some View {
        Button {
            model.open(sheet, cohort: cohort)
        } label: {
            VStack(spacing: 4) {
                Image(systemName: systemImage)
                Text(title)
                    .font(.subheadline)
            }
        }
        .buttonStyle(LargeButtonStyle(prominent: false))
        .accessibilityIdentifier("cohortAction.\(sheet.rawValue)")
    }
}
