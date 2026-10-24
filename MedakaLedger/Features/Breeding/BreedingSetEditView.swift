import SwiftData
import SwiftUI

// 親魚セットの作成（SCREENS.md 6.2）。雄と雌の群、匹数、容器、開始日。
// 子の系統は、同系統なら親と同じに決まり、交配なら最初の孵化記録で決める（DECISIONS.md F）。

struct BreedingSetEditView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(ProStore.self) private var pro
    @State private var gate = LimitGate()
    @Query(filter: Cohort.activePredicate, sort: \Cohort.createdAt) private var cohorts: [Cohort]
    @Query(filter: Tank.unarchivedPredicate, sort: Tank.listSort) private var tanks: [Tank]
    @State private var model = BreedingSetEditModel()
    @State private var strainFilter: Strain? = nil

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("系統で絞り込む", selection: $strainFilter) {
                        Text("すべての系統").tag(Strain?.none)
                        ForEach(strainsOfCohorts) { strain in
                            Text(verbatim: strain.displayName).tag(Optional(strain))
                        }
                    }
                    cohortPicker("雄の群", selection: $model.sire)
                    cohortPicker("雌の群", selection: $model.dam)
                } footer: {
                    Text("雄の群と雌の群を選ぶと保存できます。同じ群を雄と雌の両方に選べます。")
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
            .themedBackground()
            .navigationTitle("親魚セットを組む")
            .navigationBarTitleDisplayMode(.inline)
            .bottomSaveBar(isEnabled: model.canSave, identifier: "saveBreedingSetButton") {
                gate.attempt(.activeBreedingSets, pro: pro, count: { LimitCounter.activeBreedingSets(in: modelContext) }) {
                    if model.save(in: modelContext) { dismiss() }
                }
            }
            .paywall(gate)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") { dismiss() }
                }
            }
            .errorAlert($model.error)
        }
    }

    /// 飼育中の群がいる系統（重複なし）。
    private var strainsOfCohorts: [Strain] {
        var seen = Set<UUID>()
        return cohorts.compactMap(\.strain).filter { seen.insert($0.id).inserted }
    }

    /// 系統で絞り込んだ群。選択済みの群は、絞り込みの外でも選択肢に残す。
    private func visibleCohorts(keeping selected: Cohort?) -> [Cohort] {
        guard let strainFilter else { return cohorts }
        return cohorts.filter { $0.strain?.id == strainFilter.id || $0.id == selected?.id }
    }

    private func cohortPicker(_ title: LocalizedStringKey, selection: Binding<Cohort?>) -> some View {
        Picker(title, selection: selection) {
            Text("選んでください").tag(Cohort?.none)
            ForEach(visibleCohorts(keeping: selection.wrappedValue)) { cohort in
                Text(verbatim: "\(cohort.strainName) \(cohort.generationLabel)・\(cohort.tankName)・\(cohort.countText)")
                    .tag(Optional(cohort))
            }
        }
    }
}
