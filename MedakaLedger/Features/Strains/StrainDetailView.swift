import SwiftData
import SwiftUI

// 系統詳細（SCREENS.md 4.3）。「群」「血統図」「写真」「販売」の切り替え。

struct StrainDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Bindable var strain: Strain
    @State private var model = StrainDetailModel()

    var body: some View {
        let cohorts = model.visibleCohorts(of: strain)
        List {
            Section {
                if !strain.traitTags.isEmpty {
                    Text(verbatim: strain.traitTags.joined(separator: "・"))
                        .foregroundStyle(Theme.accent)
                }
                if !strain.source.isEmpty {
                    InfoRow(title: "入手元", value: strain.source)
                }
                if let acquiredAt = strain.acquiredAt {
                    InfoRow(title: "入手日", value: CohortText.date(acquiredAt))
                }
                if !strain.note.isEmpty {
                    Text(verbatim: strain.note)
                        .font(.subheadline)
                }
                if strain.isArchived {
                    Label("アーカイブ済み", systemImage: "archivebox")
                        .foregroundStyle(.secondary)
                }
            }

            Section {
                Picker("表示", selection: $model.tab) {
                    ForEach(StrainDetailModel.Tab.allCases) { tab in
                        Text(tab.title).tag(tab)
                    }
                }
                .pickerStyle(.segmented)
                .accessibilityIdentifier("strainTabPicker")
            }

            switch model.tab {
            case .cohorts:
                cohortsContent(cohorts)
            case .lineage:
                lineageContent
            case .photos:
                photosContent
            case .sales:
                salesContent
            }
        }
        .navigationTitle(strain.displayName)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button {
                        model.isEditing = true
                    } label: {
                        Label("編集", systemImage: "pencil")
                    }
                    if strain.isArchived {
                        Button {
                            model.unarchive(strain, in: modelContext)
                        } label: {
                            Label("アーカイブを解除", systemImage: "tray.and.arrow.up")
                        }
                    } else {
                        Button {
                            model.isConfirmingArchive = true
                        } label: {
                            Label("アーカイブ", systemImage: "archivebox")
                        }
                    }
                } label: {
                    Label("メニュー", systemImage: "ellipsis.circle")
                }
            }
        }
        .sheet(isPresented: $model.isEditing) {
            StrainEditView(strain: strain)
        }
        .sheet(item: $model.editingSale) { sale in
            SaleSheet(sale: sale)
        }
        .sheet(isPresented: $model.isAddingCohort) {
            NavigationStack {
                CohortCreateView(strain: strain, isAfterStrainCreation: false) {
                    model.isAddingCohort = false
                }
            }
        }
        .confirmationDialog("この系統をアーカイブしますか", isPresented: $model.isConfirmingArchive, titleVisibility: .visible) {
            Button("アーカイブ") { model.archive(strain, in: modelContext) }
            Button("キャンセル", role: .cancel) {}
        } message: {
            Text(verbatim: model.archiveMessage(for: strain))
        }
        .errorAlert($model.error)
    }

    @ViewBuilder
    private func cohortsContent(_ cohorts: [Cohort]) -> some View {
        if cohorts.isEmpty {
            Section("群") {
                Text("この系統の群はまだありません")
                    .foregroundStyle(.secondary)
                addCohortButton
            }
        } else {
            ForEach(Aggregations.groupedByGeneration(cohorts, generation: { $0.generation })) { group in
                Section {
                    ForEach(group.items.sorted { $0.createdAt < $1.createdAt }) { cohort in
                        NavigationLink(value: Route.cohort(cohort)) {
                            CohortSummaryRow(cohort: cohort, showsTank: true)
                        }
                        .accessibilityIdentifier("cohortRow.\(cohort.id.uuidString)")
                    }
                } header: {
                    Text(verbatim: generationHeader(group.generation, cohorts: group.items))
                }
            }
            Section {
                addCohortButton
                if model.endedCount(of: strain) > 0 {
                    Toggle("終了した群も表示", isOn: $model.showsEndedCohorts)
                }
            }
        }
    }

    /// 血統図を見る群を選ぶ。世代の大きい（新しい）群から。
    @ViewBuilder
    private var lineageContent: some View {
        let cohorts = (strain.cohorts ?? []).sorted {
            $0.generation != $1.generation ? $0.generation > $1.generation : $0.createdAt > $1.createdAt
        }
        Section {
            if cohorts.isEmpty {
                Text("この系統の群はまだありません")
                    .foregroundStyle(.secondary)
            }
            ForEach(cohorts) { cohort in
                NavigationLink(value: Route.lineage(cohort)) {
                    CohortSummaryRow(cohort: cohort, showsTank: true)
                }
                .accessibilityIdentifier("lineageRow")
            }
        } header: {
            Text("血統図を見る群")
        } footer: {
            Text("群を選ぶと、親魚セットをたどって、雄側と雌側の祖先を木で表示します。")
        }
    }

    /// 系統の写真と、群の写真を世代順に（PRD.md F9）。
    @ViewBuilder
    private var photosContent: some View {
        PhotoSection(owner: .strain(strain))
        let groups = Aggregations.groupedByGeneration(strain.cohorts ?? [], generation: { $0.generation })
        ForEach(groups) { group in
            let photos = group.items.flatMap { PhotoOwner.cohort($0).photos }.sorted { $0.capturedAt < $1.capturedAt }
            if !photos.isEmpty {
                Section {
                    PhotoGrid(photos: photos)
                        .padding(.vertical, 4)
                } header: {
                    Text(verbatim: CohortText.generation(group.generation))
                }
            }
        }
    }

    /// この系統の売上の累計と販売の一覧（SCREENS.md 4.3）。
    @ViewBuilder
    private var salesContent: some View {
        let sales = (strain.sales ?? []).sorted { $0.date > $1.date }
        if sales.isEmpty {
            Section("販売") {
                Text("この系統の販売はまだありません。群の詳細の「販売」から記録できます。")
                    .foregroundStyle(.secondary)
            }
        } else {
            Section("売上の累計") {
                SalesSummaryRows(summary: SalesAggregations.summary(sales.map(SaleOperations.record(of:))))
            }
            Section("販売") {
                ForEach(sales) { sale in
                    Button {
                        model.editingSale = sale
                    } label: {
                        SaleRow(record: SaleOperations.record(of: sale), title: sale.titleText)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var addCohortButton: some View {
        Button {
            model.isAddingCohort = true
        } label: {
            Label("入手個体の群を登録", systemImage: "plus.circle")
        }
    }

    private func generationHeader(_ generation: Int, cohorts: [Cohort]) -> String {
        let tally = Aggregations.tally(counts: cohorts.filter(\.isActive).map(\.count))
        var header = "\(CohortText.generation(generation))　\(StrainText.tally(tally))"
        // 世代ごとの選別の累計（PRD.md F5）
        let totals = cohorts.reduce((kept: 0, culled: 0, count: 0)) { partial, cohort in
            let selection = cohort.selectionTotals
            return (partial.kept + selection.kept, partial.culled + selection.culled, partial.count + (cohort.selections ?? []).count)
        }
        if totals.count > 0 {
            header += "　" + String(localized: "選別 残し\(totals.kept.formatted())・弾き\(totals.culled.formatted())")
        }
        return header
    }
}
