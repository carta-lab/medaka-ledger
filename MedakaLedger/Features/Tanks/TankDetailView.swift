import SwiftData
import SwiftUI

// 容器詳細（SCREENS.md 3.3）。今いる群と作業記録の枠。作業記録は第2週で足す。

struct TankDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(AppSettings.self) private var settings
    @Bindable var tank: Tank
    @State private var model = TankDetailModel()

    var body: some View {
        let cohorts = tank.activeCohorts
        let water = TankWaterStatus(tank: tank, settings: settings)
        List {
            Section {
                InfoRow(title: "種類", value: tank.kind.label)
                InfoRow(title: "置き場所", value: placementText)
                LabeledContent("最終水換え") {
                    Text(verbatim: water.text)
                        .foregroundStyle(water.isOverdue ? Theme.warning : .secondary)
                        .fontWeight(water.isOverdue ? .bold : .regular)
                }
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

            Section {
                let logs = tank.recentLogs
                if logs.isEmpty {
                    Text("作業記録はまだありません")
                        .foregroundStyle(.secondary)
                }
                MaintenanceLogRows(logs: Array(logs.prefix(10)))
                if logs.count > 10 {
                    NavigationLink(value: Route.tankLogs(tank)) {
                        Text("すべて見る")
                    }
                }
                Button {
                    model.isRecordingMaintenance = true
                } label: {
                    Label("この容器の記録", systemImage: "plus.circle")
                }
                .accessibilityIdentifier("recordMaintenanceButton")
            } header: {
                Text("作業記録")
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
        .sheet(isPresented: $model.isRecordingMaintenance) {
            MaintenanceSheet(initialTanks: [tank], isTankLocked: true)
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
