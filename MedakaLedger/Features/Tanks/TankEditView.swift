import SwiftData
import SwiftUI

// 容器の作成と編集（SCREENS.md 3.2）。作成では保存後に「続けて登録」を出す。
// 写真は第3週（DECISIONS.md B）。

struct TankEditView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(ProStore.self) private var pro
    @State private var gate = LimitGate()
    @Query(filter: Tank.unarchivedPredicate, sort: Tank.listSort) private var tanks: [Tank]
    @State private var model: TankEditModel
    @FocusState private var isNameFocused: Bool

    init(tank: Tank?) {
        _model = State(initialValue: TankEditModel(tank: tank))
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("名前（例 A-1）", text: $model.name)
                        .focused($isNameFocused)
                        .accessibilityIdentifier("tankNameField")
                    Picker("種類", selection: $model.kind) {
                        ForEach(TankKind.allCases, id: \.self) { kind in
                            Label(kind.label, systemImage: kind.symbolName).tag(kind)
                        }
                    }
                    TextField("容量（リットル）", text: $model.capacityText)
                        .keyboardType(.decimalPad)
                }
                Section("置き場所") {
                    Picker("屋外か室内か", selection: $model.placement) {
                        ForEach(Placement.allCases, id: \.self) { placement in
                            Text(verbatim: placement.label).tag(placement)
                        }
                    }
                    .pickerStyle(.segmented)
                    TextField("棚、列など（例 棚A）", text: $model.location)
                    SuggestionChips(suggestions: model.locationSuggestions(from: tanks)) { location in
                        model.location = location
                    }
                }
                Section("メモ") {
                    TextField("メモ", text: $model.note, axis: .vertical)
                        .lineLimit(2...6)
                }
            }
            .navigationTitle(model.isNew ? "容器を登録" : "容器を編集")
            .navigationBarTitleDisplayMode(.inline)
            .bottomSaveBar(isEnabled: model.canSave, identifier: "saveTankButton") { save() }
            .paywall(gate)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") { dismiss() }
                }
            }
            .alert(
                Text("「\(model.lastSavedName)」を登録しました"),
                isPresented: $model.isShowingContinuePrompt
            ) {
                Button("続けて登録") {
                    model.prepareNext()
                    isNameFocused = true
                }
                Button("閉じる", role: .cancel) { dismiss() }
            } message: {
                Text("次の名前は「\(TankNaming.nextName(after: model.lastSavedName))」で始めます。")
            }
            .errorAlert($model.error)
            .onAppear {
                if model.isNew { isNameFocused = true }
            }
        }
    }

    /// 新しい容器は、Freeの上限を確かめてから保存する（ARCHITECTURE.md 4.4）。編集は上限に関わらない。
    private func save() {
        if model.isNew {
            gate.attempt(.tanks, pro: pro, count: { LimitCounter.tanks(in: modelContext) }) { performSave() }
        } else {
            performSave()
        }
    }

    private func performSave() {
        do {
            try model.save(in: modelContext)
            // 作成は「続けて登録」の確認を出すので、ここでは閉じない
            if !model.isNew {
                dismiss()
            }
        } catch {
            modelContext.rollback()
            model.error = UserFacingError(error)
        }
    }
}
