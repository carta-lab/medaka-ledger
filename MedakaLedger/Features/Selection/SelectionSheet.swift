import SwiftData
import SwiftUI
import UIKit

// 選別記録シート（SCREENS.md 7、PRD.md F5）。保存で群の匹数を残し数に更新する。
// 弾きの行き先が「別容器」なら、弾いた分を新しい群として別の容器へ分割する。

struct SelectionSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query(filter: Tank.unarchivedPredicate, sort: Tank.listSort) private var tanks: [Tank]
    let cohort: Cohort
    @State private var model: SelectionModel

    init(cohort: Cohort) {
        self.cohort = cohort
        _model = State(initialValue: SelectionModel(cohort: cohort))
    }

    var body: some View {
        NavigationStack {
            Form {
                CurrentCohortSection(cohort: cohort)

                Section {
                    DatePicker("日付", selection: $model.date, displayedComponents: .date)
                    Picker("回数", selection: $model.round) {
                        Text(verbatim: SelectionText.round(1)).tag(1)
                        Text(verbatim: SelectionText.round(2)).tag(2)
                        Text(verbatim: SelectionText.round(3)).tag(3)
                        Text(verbatim: SelectionText.round(SelectionPlanner.otherRound)).tag(SelectionPlanner.otherRound)
                    }
                }

                Section("基準") {
                    TraitTagPicker(selected: $model.criteria, candidates: SelectionText.defaultCriteria)
                }

                Section {
                    IntField("残し数", value: $model.kept)
                        .accessibilityIdentifier("selectionKeptField")
                    IntField("弾き数", value: $model.culled)
                        .accessibilityIdentifier("selectionCulledField")
                    Picker("弾きの行き先", selection: $model.destination) {
                        ForEach(CullDestination.allCases, id: \.self) { destination in
                            Text(verbatim: destination.label).tag(destination)
                        }
                    }
                    if model.destination == .separateTank {
                        Picker("移動先の容器", selection: $model.separateTank) {
                            Text("選んでください").tag(Tank?.none)
                            ForEach(tanks.filter { $0.id != cohort.tank?.id }) { tank in
                                Text(verbatim: tank.name).tag(Optional(tank))
                            }
                        }
                    }
                } header: {
                    Text("結果")
                } footer: {
                    Text(verbatim: footer)
                }

                Section {
                    TextField("メモ", text: $model.note, axis: .vertical)
                        .lineLimit(2...6)
                }

                Section("写真") {
                    ForEach(model.photos) { photo in
                        HStack {
                            if let image = UIImage(data: photo.thumbnailData) {
                                Image(uiImage: image)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 56, height: 56)
                                    .clipShape(.rect(cornerRadius: 8))
                            }
                            Spacer()
                            Button(role: .destructive) {
                                model.photos.removeAll { $0.id == photo.id }
                            } label: {
                                Label("外す", systemImage: "minus.circle")
                            }
                            .buttonStyle(.borderless)
                        }
                    }
                    PhotoAdder { model.photos.append(contentsOf: $0) }
                }
            }
            .navigationTitle("選別を記録")
            .navigationBarTitleDisplayMode(.inline)
            .bottomSaveBar(isEnabled: model.canSave, identifier: "saveSelectionButton") {
                if model.save(for: cohort, in: modelContext) { dismiss() }
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") { dismiss() }
                }
            }
            .errorAlert($model.error)
        }
    }

    private var footer: String {
        if model.destination == .separateTank {
            return String(localized: "弾いた分は新しい群になり、選んだ容器へ移ります。残し数は、今の群の匹数になります。")
        }
        return String(localized: "保存すると、この群の匹数が残し数になります。")
    }
}
