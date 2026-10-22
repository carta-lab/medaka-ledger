import SwiftData
import SwiftUI

// 親魚セットの作成（SCREENS.md 6.2）。雄と雌の群、匹数、容器、開始日。
// 子の系統は、同系統なら親と同じに決まり、交配なら最初の孵化記録で決める（DECISIONS.md F）。

struct BreedingSetEditView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query(filter: Cohort.activePredicate, sort: \Cohort.createdAt) private var cohorts: [Cohort]
    @Query(filter: Tank.unarchivedPredicate, sort: Tank.listSort) private var tanks: [Tank]
    @State private var model = BreedingSetEditModel()

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    cohortPicker("雄の群", selection: $model.sire)
                    cohortPicker("雌の群", selection: $model.dam)
                } footer: {
                    Text("同じ群を雄と雌の両方に選べます。")
                }

                Section("匹数") {
                    IntField("雄の匹数", value: $model.maleCount)
                    IntField("雌の匹数", value: $model.femaleCount)
                }

                Section {
                    Picker("容器", selection: $model.tank) {
                        Text("容器未設定").tag(Tank?.none)
                        ForEach(tanks) { tank in
                            Text(verbatim: tank.name).tag(Optional(tank))
                        }
                    }
                    if model.canOfferMove {
                        Toggle("雄と雌の群をこの容器へ移す", isOn: $model.movesParents)
                    }
                    DatePicker("開始日", selection: $model.startedAt, displayedComponents: .date)
                }

                Section {
                    TextField("名前（空なら自動）", text: $model.name)
                    TextField("メモ", text: $model.note, axis: .vertical)
                        .lineLimit(2...6)
                }

                if let message = model.offspringMessage {
                    Section("子の系統") {
                        Text(verbatim: message)
                            .font(.subheadline)
                    }
                }
            }
            .navigationTitle("親魚セットを組む")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        if model.save(in: modelContext) { dismiss() }
                    }
                    .disabled(!model.canSave)
                    .accessibilityIdentifier("saveBreedingSetButton")
                }
            }
            .errorAlert($model.error)
        }
    }

    private func cohortPicker(_ title: LocalizedStringKey, selection: Binding<Cohort?>) -> some View {
        Picker(title, selection: selection) {
            Text("選んでください").tag(Cohort?.none)
            ForEach(cohorts) { cohort in
                Text(verbatim: "\(cohort.strainName) \(cohort.generationLabel)・\(cohort.tankName)・\(cohort.countText)")
                    .tag(Optional(cohort))
            }
        }
    }
}
