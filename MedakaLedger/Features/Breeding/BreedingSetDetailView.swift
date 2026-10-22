import SwiftData
import SwiftUI

// 親魚セット詳細（SCREENS.md 6.3）。雄と雌の群、容器、期間、採卵ロットの一覧。

struct BreedingSetDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(AppSettings.self) private var settings
    @Environment(NotificationScheduler.self) private var scheduler
    @Bindable var breedingSet: BreedingSet
    @State private var model = BreedingSetDetailModel()

    var body: some View {
        if breedingSet.isDeleted {
            ContentUnavailableView("この親魚セットは削除されました", systemImage: "trash")
        } else {
            content
        }
    }

    private var content: some View {
        List {
            Section("親") {
                parentRow("雄", cohort: breedingSet.sireCohort)
                parentRow("雌", cohort: breedingSet.damCohort)
                InfoRow(title: "雄雌の匹数", value: String(localized: "雄\(breedingSet.maleCount.formatted())・雌\(breedingSet.femaleCount.formatted())"))
                InfoRow(title: "容器", value: breedingSet.tank?.name ?? String(localized: "容器未設定"))
                InfoRow(title: "期間", value: periodText)
                InfoRow(title: "子の系統", value: breedingSet.offspringStrain?.displayName ?? String(localized: "最初の孵化記録で決めます"))
                if !breedingSet.note.isEmpty {
                    Text(verbatim: breedingSet.note)
                        .font(.subheadline)
                }
            }

            Section {
                let entries = BatchPredictionInfo.sortedByRemaining(breedingSet.sortedBatches, settings: settings)
                if entries.isEmpty {
                    Text("採卵ロットはまだありません")
                        .foregroundStyle(.secondary)
                }
                ForEach(entries) { entry in
                    batchRow(entry.batch, info: entry.info)
                }
            } header: {
                Text("採卵ロット")
            }

            if breedingSet.isActive {
                Section {
                    Button {
                        model.isRecordingBatch = true
                    } label: {
                        Label("採卵を記録", systemImage: "plus.circle")
                    }
                    .accessibilityIdentifier("recordEggBatchButton")
                    Button(role: .destructive) {
                        model.isConfirmingEnd = true
                    } label: {
                        Label("終了する", systemImage: "stop.circle")
                    }
                }
            }
        }
        .navigationTitle(breedingSet.displayName)
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $model.isRecordingBatch) {
            EggBatchSheet(breedingSet: breedingSet)
        }
        .sheet(item: $model.hatchingBatch) { batch in
            HatchSheet(batch: batch)
        }
        .confirmationDialog("この親魚セットを終了しますか", isPresented: $model.isConfirmingEnd, titleVisibility: .visible) {
            Button("今日で終了") { model.end(breedingSet, in: modelContext) }
            Button("キャンセル", role: .cancel) {}
        } message: {
            Text("終了すると、新しい採卵は記録できません。過去の記録は残ります。")
        }
        .confirmationDialog(
            "このロットを廃棄しますか",
            isPresented: $model.isConfirmingDiscard,
            titleVisibility: .visible,
            presenting: model.batchPendingDiscard
        ) { batch in
            Button("廃棄", role: .destructive) {
                model.discard(batch, in: modelContext)
                Task { await scheduler.reschedule(in: modelContext) }
            }
            Button("キャンセル", role: .cancel) {}
        } message: { _ in
            Text("孵化予定の通知も止まります。")
        }
        .errorAlert($model.error)
    }

    @ViewBuilder
    private func parentRow(_ title: LocalizedStringKey, cohort: Cohort?) -> some View {
        if let cohort {
            NavigationLink(value: Route.cohort(cohort)) {
                LabeledContent(title) {
                    Text(verbatim: "\(cohort.strainName) \(cohort.generationLabel)")
                }
            }
        } else {
            InfoRow(title: title, value: String(localized: "削除された群"))
        }
    }

    @ViewBuilder
    private func batchRow(_ batch: EggBatch, info: BatchPredictionInfo) -> some View {
        if batch.status == .incubating {
            Button {
                model.hatchingBatch = batch
            } label: {
                EggBatchRow(batch: batch, info: info)
            }
            .buttonStyle(.plain)
            .swipeActions(edge: .trailing) {
                Button("廃棄", role: .destructive) { model.askToDiscard(batch) }
            }
        } else {
            EggBatchRow(batch: batch, info: info)
        }
    }

    private var periodText: String {
        let start = CohortText.date(breedingSet.startedAt)
        guard let endedAt = breedingSet.endedAt else { return String(localized: "\(start)から") }
        return String(localized: "\(start)〜\(CohortText.date(endedAt))")
    }
}
