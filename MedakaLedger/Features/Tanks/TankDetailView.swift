import SwiftData
import SwiftUI

// 容器詳細（SCREENS.md 3.3）。今いる群と作業記録の枠。作業記録は第2週で足す。

struct TankDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Bindable var tank: Tank
    @State private var model = TankDetailModel()

    var body: some View {
        let cohorts = tank.activeCohorts
        List {
            Section {
                InfoRow(title: "種類", value: tank.kind.label)
                InfoRow(title: "置き場所", value: placementText)
                if let capacity = tank.capacityLiters {
                    InfoRow(title: "容量", value: "\(NumberParsing.text(from: capacity)) L")
                }
                if !tank.note.isEmpty {
                    Text(verbatim: tank.note)
                        .font(.subheadline)
                }
                if tank.isArchived {
                    Label("アーカイブ済み", systemImage: "archivebox")
                        .foregroundStyle(.secondary)
                }
            }

            Section("今いる群") {
                if cohorts.isEmpty {
                    Text("この容器に群はいません")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(cohorts) { cohort in
                        NavigationLink(value: Route.cohort(cohort)) {
                            CohortSummaryRow(cohort: cohort, showsTank: false)
                        }
                        .swipeActions(edge: .trailing) {
                            Button("移動") { model.movingCohort = cohort }
                                .tint(Theme.accent)
                        }
                    }
                }
            }

            Section("作業記録") {
                Text("作業記録はまだありません")
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle(tank.name)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button {
                        model.isEditing = true
                    } label: {
                        Label("編集", systemImage: "pencil")
                    }
                    if tank.isArchived {
                        Button {
                            model.unarchive(tank, in: modelContext)
                        } label: {
                            Label("アーカイブを解除", systemImage: "tray.and.arrow.up")
                        }
                    } else {
                        Button {
                            model.requestArchive(tank)
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
            TankEditView(tank: tank)
        }
        .sheet(item: $model.movingCohort) { cohort in
            MoveCohortSheet(cohort: cohort)
        }
        .confirmationDialog("この容器をアーカイブしますか", isPresented: $model.isConfirmingArchive, titleVisibility: .visible) {
            Button("アーカイブ") { model.archive(tank, in: modelContext) }
            Button("キャンセル", role: .cancel) {}
        } message: {
            Text("一覧から消えます。過去の記録からはたどれます。")
        }
        .errorAlert($model.error)
    }

    private var placementText: String {
        tank.location.isEmpty ? tank.placement.label : "\(tank.placement.label)・\(tank.location)"
    }
}
