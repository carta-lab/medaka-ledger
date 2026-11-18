import SwiftData
import SwiftUI

// 作業記録シート（SCREENS.md 9）。容器を複数選んで、同じ内容を各容器に保存できる。
// 水温の記録は孵化予定日の計算に使うので、保存後に通知を計画し直す。

struct MaintenanceSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(AppSettings.self) private var settings
    @Environment(NotificationScheduler.self) private var scheduler
    @Query(filter: Tank.unarchivedPredicate, sort: Tank.listSort) private var tanks: [Tank]
    @State private var model: MaintenanceModel

    /// tanks を渡すと最初から選択された状態になる。lockedTank を渡すと容器は固定。
    init(initialTanks: [Tank] = [], kind: MaintenanceKind = .waterChange, isTankLocked: Bool = false) {
        _model = State(initialValue: MaintenanceModel(initialTanks: initialTanks, kind: kind, isTankLocked: isTankLocked))
    }

    var body: some View {
        NavigationStack {
            Form {
                Group {
                    EntryHeading(title: "水辺のお手入れ", subtitle: "容器と作業を選んで、日々の変化を残す。", systemImage: "drop")
                    Section {
                        Picker("種類", selection: $model.kind) {
                            ForEach(MaintenanceKind.allCases, id: \.self) { kind in
                                Text(verbatim: kind.label).tag(kind)
                            }
                        }
                        DatePicker("日付", selection: $model.date, displayedComponents: .date)
                        if model.kind == .waterChange {
                            IntField("割合（％）", value: $model.percent)
                        }
                        TextField(
                            model.kind == .temperature ? LocalizedStringKey("水温（℃、必須）") : LocalizedStringKey("水温（℃、任意）"),
                            text: $model.waterTempText
                        )
                        .keyboardType(.decimalPad)
                        TextField("メモ", text: $model.note, axis: .vertical)
                            .lineLimit(1...4)
                    }

                    Section {
                        if tanks.isEmpty {
                            Text("容器がありません。先に容器を登録しましょう。")
                                .foregroundStyle(.secondary)
                        }
                        ForEach(model.isTankLocked ? model.initialTanks : tanks) { tank in
                            Button {
                                model.toggle(tank)
                            } label: {
                                HStack {
                                    Label(tank.name, systemImage: tank.kind.symbolName)
                                    Spacer()
                                    if model.isSelected(tank) {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundStyle(Theme.accent)
                                    } else {
                                        Image(systemName: "circle")
                                            .foregroundStyle(.secondary)
                                    }
                                }
                                .contentShape(.rect)
                            }
                            .buttonStyle(.plain)
                            .disabled(model.isTankLocked)
                            .accessibilityAddTraits(model.isSelected(tank) ? .isSelected : [])
                        }
                    } header: {
                        Text("容器")
                    } footer: {
                        if !model.isTankLocked {
                            Text("複数の容器を選ぶと、同じ内容を各容器に保存します。")
                        }
                    }
                }
                .ledgerRow()
            }
            .themedBackground()
            .navigationTitle("作業を記録")
            .navigationBarTitleDisplayMode(.inline)
            .bottomSaveBar(isEnabled: model.canSave, identifier: "saveMaintenanceButton") {
                if model.save(in: modelContext) {
                    // 先に閉じて、二重に保存されないようにする。通知の計画し直しは閉じた後で行う
                    let context = modelContext
                    dismiss()
                    Task { await scheduler.reschedule(in: context) }
                }
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") { dismiss() }
                }
            }
            .errorAlert($model.error)
        }
    }
}

