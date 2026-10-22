import SwiftData
import SwiftUI

// 系統詳細（SCREENS.md 4.3）。第1週は「群」タブだけ（DECISIONS.md B）。

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

    private var addCohortButton: some View {
        Button {
            model.isAddingCohort = true
        } label: {
            Label("入手個体の群を登録", systemImage: "plus.circle")
        }
    }

    private func generationHeader(_ generation: Int, cohorts: [Cohort]) -> String {
        let tally = Aggregations.tally(counts: cohorts.filter(\.isActive).map(\.count))
        return "\(CohortText.generation(generation))　\(StrainText.tally(tally))"
    }
}
