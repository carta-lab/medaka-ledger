import SwiftData
import SwiftUI

// 孵化記録シート（SCREENS.md 6.5）。針子の容器を決めて、世代と系統を引き継いだ群を作る。
// 交配で子の系統が未定なら、ここで決める。2回目以降は既存の群に足すか、新しい群にするかを選べる。

struct HatchSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(NotificationScheduler.self) private var scheduler
    @Query(filter: Tank.unarchivedPredicate, sort: Tank.listSort) private var tanks: [Tank]
    @Query(filter: Strain.unarchivedPredicate, sort: Strain.listSort) private var strains: [Strain]
    @State private var model: HatchModel

    init(batch: EggBatch) {
        _model = State(initialValue: HatchModel(batch: batch))
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    InfoRow(title: "ロット", value: model.batch.title)
                    DatePicker("孵化日", selection: $model.hatchedAt, displayedComponents: .date)
                    IntField("孵化数（概数、任意）", value: $model.hatchedCount)
                }

                if model.needsChildStrain {
                    childStrainSection
                }

                if !model.existingCohorts.isEmpty {
                    Section {
                        Picker("記録の先", selection: $model.addTo) {
                            Text("新しい群にする").tag(Cohort?.none)
                            ForEach(model.existingCohorts) { cohort in
                                Text(verbatim: "\(cohort.generationLabel) \(cohort.label)・\(cohort.countText)")
                                    .tag(Optional(cohort))
                            }
                        }
                    } footer: {
                        Text("早く孵った分と遅れた分は、同じ群に足すこともできます。")
                    }
                }

                if model.addTo == nil {
                    Section {
                        Picker("容器", selection: $model.tank) {
                            Text("選んでください").tag(Tank?.none)
                            ForEach(tanks) { tank in
                                Text(verbatim: tank.name).tag(Optional(tank))
                            }
                        }
                        .accessibilityIdentifier("hatchTankPicker")
                        TextField("ラベル（任意）", text: $model.label)
                    } header: {
                        Text("針子の容器")
                    } footer: {
                        Text("針子の容器を選ぶと保存できます。")
                    }
                }

                Section {
                    TextField("メモ", text: $model.note, axis: .vertical)
                        .lineLimit(2...6)
                }
            }
            .navigationTitle("孵化を記録")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        if model.save(in: modelContext) {
                            // 先に閉じて、二重に保存されないようにする。通知の計画し直しは閉じた後で行う
                            let context = modelContext
                            dismiss()
                            Task { await scheduler.reschedule(in: context) }
                        }
                    }
                    .disabled(!model.canSave)
                    .accessibilityIdentifier("saveHatchButton")
                }
            }
            .errorAlert($model.error)
        }
    }

    private var childStrainSection: some View {
        Section {
            Picker("子の系統", selection: $model.strainMode) {
                Text("新しい系統").tag(HatchModel.StrainMode.createNew)
                Text("既存の系統").tag(HatchModel.StrainMode.existing)
            }
            .pickerStyle(.segmented)
            switch model.strainMode {
            case .createNew:
                TextField("品種名", text: $model.newBreedName)
                TextField("系統名（任意）", text: $model.newLineName)
            case .existing:
                Picker("系統", selection: $model.existingStrain) {
                    Text("選んでください").tag(Strain?.none)
                    ForEach(strains) { strain in
                        Text(verbatim: strain.displayName).tag(Optional(strain))
                    }
                }
            }
        } header: {
            Text("子の系統")
        } footer: {
            Text("雄と雌の系統が違うので、子の系統をここで決めます。")
        }
    }
}
