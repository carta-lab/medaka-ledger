import SwiftData
import SwiftUI

// 統合と編集のシート（SCREENS.md 5.1）。

// MARK: - 統合

struct MergeCohortSheet: View {
    @Environment(\.modelContext) private var modelContext
    let cohort: Cohort
    @State private var selected: Cohort? = nil
    @State private var date = Date()

    var body: some View {
        let candidates = CohortOperations.mergeCandidates(for: cohort, in: modelContext)
        OperationForm(title: "統合", canSave: selected != nil) {
            guard let selected else { return }
            try CohortOperations.merge(selected, into: cohort, date: date, in: modelContext)
            try modelContext.save()
        } content: {
            CurrentCohortSection(cohort: cohort)
            Section {
                if candidates.isEmpty {
                    Text("統合できる群がありません。")
                        .foregroundStyle(.secondary)
                }
                ForEach(candidates) { candidate in
                    Button {
                        selected = candidate
                    } label: {
                        HStack {
                            CohortSummaryRow(cohort: candidate, showsTank: true)
                            if selected?.id == candidate.id {
                                Image(systemName: "checkmark")
                                    .foregroundStyle(Theme.accent)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                }
            } header: {
                Text("この群にまとめる群")
            } footer: {
                Text("同じ系統・同じ世代で、同じ親魚セットから生まれた群（または入手個体どうし）だけ統合できます。容器と段階はこの群のものを残し、孵化日は早いほうを残します。")
            }
            Section {
                DatePicker("日付", selection: $date, displayedComponents: .date)
            }
        }
    }
}

// MARK: - 編集

/// 群の編集。匹数は増減と計数修正で変えるので、ここでは扱わない（CLAUDE.md）。
struct CohortEditView: View {
    @Environment(\.modelContext) private var modelContext
    let cohort: Cohort
    @State private var label: String
    @State private var maleCount: Int? = nil
    @State private var femaleCount: Int? = nil
    @State private var sizeText: String
    @State private var note: String

    init(cohort: Cohort) {
        self.cohort = cohort
        _label = State(initialValue: cohort.label)
        _maleCount = State(initialValue: cohort.maleCount)
        _femaleCount = State(initialValue: cohort.femaleCount)
        _sizeText = State(initialValue: cohort.sizeText)
        _note = State(initialValue: cohort.note)
    }

    var body: some View {
        OperationForm(title: "群を編集", canSave: true) {
            cohort.label = label.trimmingCharacters(in: .whitespacesAndNewlines)
            cohort.maleCount = maleCount
            cohort.femaleCount = femaleCount
            cohort.sizeText = sizeText.trimmingCharacters(in: .whitespacesAndNewlines)
            cohort.note = note.trimmingCharacters(in: .whitespacesAndNewlines)
            try modelContext.save()
        } content: {
            Section {
                TextField("ラベル", text: $label)
                TextField("サイズ（例 1.5〜2cm）", text: $sizeText)
            }
            Section {
                IntField("うち雄", value: $maleCount)
                IntField("うち雌", value: $femaleCount)
            } header: {
                Text("雌雄の内訳")
            } footer: {
                Text("雌雄の内訳は分割や増減で自動では変わりません。ここで直してください。")
            }
            Section("メモ") {
                TextField("メモ", text: $note, axis: .vertical)
                    .lineLimit(2...6)
            }
        }
    }
}
