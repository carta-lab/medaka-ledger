import SwiftData
import SwiftUI

// 増減と段階の変更のシート（SCREENS.md 5.1）。

// MARK: - 増減

struct CountChangeSheet: View {
    enum Direction: Hashable { case increase, decrease }

    @Environment(\.modelContext) private var modelContext
    let cohort: Cohort
    @State private var reason: CountChangeReason = .death
    @State private var amount: Int? = nil
    @State private var newCount: Int? = nil
    @State private var direction: Direction = .decrease
    @State private var date = Date()
    @State private var note = ""

    var body: some View {
        OperationForm(title: "増減", canSave: canSave) {
            try CohortOperations.changeCount(cohort, change: change(), date: date, note: note, in: modelContext)
            try modelContext.save()
        } content: {
            CurrentCohortSection(cohort: cohort)
            Section {
                Picker("理由", selection: $reason) {
                    ForEach(CountChangeReason.allCases, id: \.self) { reason in
                        Text(verbatim: reason.label).tag(reason)
                    }
                }
                switch reason {
                case .recount:
                    IntField("数え直した匹数", value: $newCount)
                case .other:
                    Picker("増減", selection: $direction) {
                        Text("減らす").tag(Direction.decrease)
                        Text("増やす").tag(Direction.increase)
                    }
                    .pickerStyle(.segmented)
                    IntField("匹数", value: $amount)
                default:
                    IntField("減った匹数", value: $amount)
                }
            } footer: {
                if cohort.count == nil && reason != .recount {
                    Text("この群は未計数なので、匹数は未計数のまま記録だけ残ります。")
                }
            }
            Section {
                DatePicker("日付", selection: $date, displayedComponents: .date)
                TextField("メモ", text: $note)
            }
        }
    }

    private var canSave: Bool {
        reason == .recount ? newCount != nil : (amount ?? 0) > 0
    }

    private func change() -> CountLedger.CountChange {
        switch reason {
        case .recount:
            return .recount(newCount ?? 0)
        case .other:
            let value = amount ?? 0
            return .adjust(direction == .increase ? value : -value)
        default:
            return .decrease(amount ?? 0, reason: reason)
        }
    }
}

// MARK: - 段階の変更

struct StageChangeSheet: View {
    @Environment(\.modelContext) private var modelContext
    let cohort: Cohort
    @State private var stage: GrowthStage? = nil
    @State private var date = Date()

    var body: some View {
        OperationForm(title: "段階の変更", canSave: stage != nil && stage != cohort.stage) {
            guard let stage else { return }
            try CohortOperations.changeStage(cohort, to: stage, date: date, in: modelContext)
            try modelContext.save()
        } content: {
            Section {
                ForEach(GrowthStage.allCases, id: \.self) { option in
                    Button {
                        stage = option
                    } label: {
                        HStack {
                            Text(verbatim: option.label)
                            if option == cohort.stage {
                                Text("今")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            if option == stage {
                                Image(systemName: "checkmark")
                                    .foregroundStyle(Theme.accent)
                            }
                        }
                        .contentShape(.rect)
                    }
                    .buttonStyle(.plain)
                }
            }
            Section {
                DatePicker("日付", selection: $date, displayedComponents: .date)
            }
        }
    }
}
