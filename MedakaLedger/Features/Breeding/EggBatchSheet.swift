import SwiftData
import SwiftUI

// 採卵記録シート（SCREENS.md 6.4）。親魚セットを選んで保存するだけで記録できる（ホームのクイック操作から）。
// 保存後に孵化予定日を表示する。通知の許可は最初のロットを保存したときに求める。

struct EggBatchSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(AppSettings.self) private var settings
    @Environment(NotificationScheduler.self) private var scheduler
    @Query(filter: BreedingSet.activePredicate, sort: \BreedingSet.startedAt, order: .reverse) private var activeSets: [BreedingSet]
    @Query(filter: Tank.unarchivedPredicate, sort: Tank.listSort) private var tanks: [Tank]
    @State private var model: EggBatchModel

    /// set を渡すと親魚セットは固定。nil なら稼働中の親魚セットから選ぶ。
    init(breedingSet: BreedingSet? = nil) {
        _model = State(initialValue: EggBatchModel(breedingSet: breedingSet))
    }

    var body: some View {
        NavigationStack {
            Form {
                Group {
                    EntryHeading(title: "採卵の記録", subtitle: "今日の卵を、次の世代につなげる。", systemImage: "circle.dotted")
                    setSection
                    Section {
                        DatePicker("採卵日", selection: $model.collectedAt, displayedComponents: .date)
                        IntField("卵の数（概数、任意）", value: $model.eggCount)
                    }
                    Section {
                        Picker("育卵容器", selection: $model.container) {
                            Text("カップ名を入力").tag(Tank?.none)
                            ForEach(tanks) { tank in
                                Text(verbatim: tank.name).tag(Optional(tank))
                            }
                        }
                        if model.container == nil {
                            TextField("カップ名（任意）", text: $model.containerName)
                        }
                        TextField(
                            "水温（任意。空なら\(settings.defaultWaterTempC.formatted())℃）",
                            text: $model.waterTempText
                        )
                        .keyboardType(.decimalPad)
                    } footer: {
                        Text("容器に水温を記録していると、その日ごとの水温で孵化予定日を計算します。")
                    }
                    Section {
                        TextField("メモ", text: $model.note, axis: .vertical)
                            .lineLimit(2...6)
                    }
                }
                .ledgerRow()
            }
            .themedBackground()
            .navigationTitle("採卵を記録")
            .navigationBarTitleDisplayMode(.inline)
            .bottomSaveBar(isEnabled: model.canSave, identifier: "saveEggBatchButton") {
                model.save(in: modelContext, settings: settings, needsAuthorization: scheduler.needsAuthorizationPrompt)
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") { dismiss() }
                }
            }
            .alert("採卵を記録しました", isPresented: $model.isShowingResult) {
                Button("OK") {
                    Task {
                        await scheduler.requestAuthorizationIfNeeded()
                        await scheduler.reschedule(in: modelContext)
                        dismiss()
                    }
                }
            } message: {
                Text(verbatim: model.resultMessage)
            }
            .errorAlert($model.error)
            .task { await scheduler.refreshStatus() }
        }
    }

    @ViewBuilder
    private var setSection: some View {
        Section {
            if let fixed = model.fixedSet {
                InfoRow(title: "親魚セット", value: fixed.displayName)
            } else if activeSets.isEmpty {
                Text("稼働中の親魚セットがありません。先に繁殖タブで親魚セットを組みましょう。")
                    .foregroundStyle(.secondary)
            } else {
                Picker("親魚セット", selection: $model.selectedSet) {
                    Text("選んでください").tag(BreedingSet?.none)
                    ForEach(activeSets) { set in
                        Text(verbatim: set.displayName).tag(Optional(set))
                    }
                }
                .accessibilityIdentifier("eggBatchSetPicker")
            }
        }
    }
}

