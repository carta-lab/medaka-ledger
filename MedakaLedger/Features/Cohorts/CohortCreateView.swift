import SwiftData
import SwiftUI

// 群の作成（入手個体、SCREENS.md 5.2）。系統詳細と系統作成の直後から呼ぶ。世代は0で固定。

struct CohortCreateView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(filter: Tank.unarchivedPredicate, sort: Tank.listSort) private var tanks: [Tank]
    @State private var model: CohortCreateModel
    private let isAfterStrainCreation: Bool
    private let onFinish: () -> Void

    init(strain: Strain, isAfterStrainCreation: Bool, onFinish: @escaping () -> Void) {
        _model = State(initialValue: CohortCreateModel(strain: strain, inheritsStrainDate: isAfterStrainCreation))
        self.isAfterStrainCreation = isAfterStrainCreation
        self.onFinish = onFinish
    }

    var body: some View {
        Form {
            Section {
                InfoRow(title: "系統", value: model.strain.displayName)
                InfoRow(title: "世代", value: CohortText.generation(0))
            } footer: {
                if isAfterStrainCreation {
                    Text("続けて、入手した個体を群として登録できます。あとで系統の画面から登録することもできます。")
                }
            }

            Section {
                IntField("匹数（数えていなければ空のまま）", value: $model.count)
                    .accessibilityIdentifier("cohortCountField")
                IntField("うち雄（任意）", value: $model.maleCount)
                IntField("うち雌（任意）", value: $model.femaleCount)
            } header: {
                Text("匹数")
            }

            Section {
                Picker("容器", selection: $model.tank) {
                    Text("容器未設定").tag(Tank?.none)
                    ForEach(tanks) { tank in
                        Text(verbatim: tank.name).tag(Optional(tank))
                    }
                }
                DatePicker("入手日", selection: $model.acquiredAt, displayedComponents: .date)
                Picker("段階", selection: $model.stage) {
                    ForEach(GrowthStage.allCases, id: \.self) { stage in
                        Text(verbatim: stage.label).tag(stage)
                    }
                }
            }

            Section {
                TextField("ラベル（例 親魚候補）", text: $model.label)
                TextField("メモ", text: $model.note, axis: .vertical)
                    .lineLimit(2...6)
            }
        }
        .navigationTitle("入手個体の群を登録")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(isAfterStrainCreation)
        .bottomSaveBar(identifier: "saveCohortButton") { save() }
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button(isAfterStrainCreation ? LocalizedStringKey("あとで") : LocalizedStringKey("キャンセル")) { onFinish() }
            }
        }
        .errorAlert($model.error)
    }

    private func save() {
        do {
            try model.save(in: modelContext)
            onFinish()
        } catch {
            modelContext.rollback()
            model.error = UserFacingError(error)
        }
    }
}
