import SwiftData
import SwiftUI

// 系統の作成と編集（SCREENS.md 4.2）。作成直後に入手個体の群の登録を出す。

struct StrainEditView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Strain.createdAt, order: .reverse) private var allStrains: [Strain]
    @State private var model: StrainEditModel

    init(strain: Strain?) {
        _model = State(initialValue: StrainEditModel(strain: strain))
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("品種名（例 楊貴妃）", text: $model.breedName)
                        .accessibilityIdentifier("breedNameField")
                    SuggestionChips(suggestions: model.breedSuggestions(from: allStrains)) { name in
                        model.breedName = name
                    }
                    TextField("系統名・呼び名（任意）", text: $model.lineName)
                    TextField("入手元・作出者", text: $model.source)
                } footer: {
                    Text("品種名を入れると保存できます。系統名は「〇〇めだか2026春購入」のように、同じ品種の中で見分ける呼び名です。")
                }

                Section {
                    Toggle("入手日を記録する", isOn: $model.hasAcquiredAt)
                    if model.hasAcquiredAt {
                        DatePicker("入手日", selection: $model.acquiredAt, displayedComponents: .date)
                    }
                }

                Section("表現タグ") {
                    TraitTagPicker(
                        selected: $model.traitTags,
                        candidates: Aggregations.tagCandidates(defaults: TraitTagCatalog.defaults, used: allStrains.map(\.traitTags))
                    )
                }

                Section("メモ") {
                    TextField("メモ", text: $model.note, axis: .vertical)
                        .lineLimit(2...6)
                }
            }
            .navigationTitle(model.isNew ? "系統を登録" : "系統を編集")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") { save() }
                        .disabled(!model.canSave)
                }
            }
            .navigationDestination(item: $model.createdStrain) { strain in
                CohortCreateView(strain: strain, isAfterStrainCreation: true) {
                    dismiss()
                }
            }
            .errorAlert($model.error)
        }
    }

    private func save() {
        do {
            try model.save(in: modelContext)
            if !model.isNew {
                dismiss()
            }
        } catch {
            modelContext.rollback()
            model.error = UserFacingError(error)
        }
    }
}

/// 表現タグの選択。候補から複数選び、自由入力も足せる（PRD.md F2）。
struct TraitTagPicker: View {
    @Binding var selected: [String]
    let candidates: [String]
    @State private var customTag = ""

    var body: some View {
        let options = Aggregations.distinct(candidates + selected)
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 96), spacing: 8)], alignment: .leading, spacing: 8) {
            ForEach(options, id: \.self) { tag in
                let isOn = selected.contains(tag)
                Button {
                    toggle(tag)
                } label: {
                    Text(verbatim: tag)
                        .font(.subheadline)
                        .lineLimit(1)
                        .frame(maxWidth: .infinity, minHeight: 36)
                        .foregroundStyle(isOn ? Color.white : Color.primary)
                        .background(isOn ? AnyShapeStyle(Theme.accent) : AnyShapeStyle(.fill.tertiary), in: .capsule)
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(isOn ? .isSelected : [])
            }
        }
        .padding(.vertical, 4)
        HStack {
            TextField("タグを入力", text: $customTag)
                .onSubmit(addCustomTag)
            Button("追加", action: addCustomTag)
                .disabled(customTag.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
    }

    private func toggle(_ tag: String) {
        if let index = selected.firstIndex(of: tag) {
            selected.remove(at: index)
        } else {
            selected.append(tag)
        }
    }

    private func addCustomTag() {
        let tag = customTag.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !tag.isEmpty else { return }
        if !selected.contains(tag) {
            selected.append(tag)
        }
        customTag = ""
    }
}
