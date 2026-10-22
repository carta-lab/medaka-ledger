import SwiftData
import SwiftUI

// 群に対する操作のシート（SCREENS.md 5.1）。匹数を変える操作は CohortOperations を通す。

/// シートの共通の枠。保存とキャンセル、日付、エラー表示。
struct OperationForm<Content: View>: View {
    private let title: LocalizedStringKey
    private let canSave: Bool
    private let onSave: () throws -> Void
    private let content: () -> Content
    @Environment(\.dismiss) private var dismiss
    @State private var error: UserFacingError? = nil

    init(title: LocalizedStringKey, canSave: Bool, onSave: @escaping () throws -> Void, @ViewBuilder content: @escaping () -> Content) {
        self.title = title
        self.canSave = canSave
        self.onSave = onSave
        self.content = content
    }

    var body: some View {
        NavigationStack {
            Form {
                content()
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        do {
                            try onSave()
                            dismiss()
                        } catch {
                            self.error = UserFacingError(error)
                        }
                    }
                    .disabled(!canSave)
                    .accessibilityIdentifier("saveOperationButton")
                }
            }
            .errorAlert($error)
        }
    }
}

struct CurrentCohortSection: View {
    let cohort: Cohort

    var body: some View {
        Section {
            InfoRow(title: "群", value: "\(cohort.strainName) \(cohort.generationLabel)")
            InfoRow(title: "今の匹数", value: cohort.countText)
            InfoRow(title: "今の容器", value: cohort.tankName)
        }
    }
}

// MARK: - 移動

struct MoveCohortSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Query(filter: Tank.unarchivedPredicate, sort: Tank.listSort) private var tanks: [Tank]
    let cohort: Cohort
    @State private var destination: Tank? = nil
    @State private var date = Date()

    var body: some View {
        let candidates = tanks.filter { $0.id != cohort.tank?.id }
        OperationForm(title: "移動", canSave: destination != nil) {
            guard let destination else { return }
            try CohortOperations.move(cohort, to: destination, date: date, in: modelContext)
            try modelContext.save()
        } content: {
            CurrentCohortSection(cohort: cohort)
            Section("移動先の容器") {
                if candidates.isEmpty {
                    Text("移動先の容器がありません。先に容器を登録しましょう。")
                        .foregroundStyle(.secondary)
                }
                ForEach(candidates) { tank in
                    TankChoiceRow(tank: tank, isSelected: destination?.id == tank.id) {
                        destination = tank
                    }
                }
            }
            Section {
                DatePicker("日付", selection: $date, displayedComponents: .date)
            }
        }
    }
}

private struct TankChoiceRow: View {
    let tank: Tank
    let isSelected: Bool
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            HStack {
                Label(tank.name, systemImage: tank.kind.symbolName)
                Spacer()
                if !tank.location.isEmpty {
                    Text(verbatim: tank.location)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                if isSelected {
                    Image(systemName: "checkmark")
                        .foregroundStyle(Theme.accent)
                }
            }
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

// MARK: - 分割

struct SplitCohortSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Query(filter: Tank.unarchivedPredicate, sort: Tank.listSort) private var tanks: [Tank]
    let cohort: Cohort
    @State private var amount: Int? = nil
    @State private var destination: Tank? = nil
    @State private var label = ""
    @State private var date = Date()

    var body: some View {
        let candidates = tanks.filter { $0.id != cohort.tank?.id }
        OperationForm(title: "分割", canSave: (amount ?? 0) > 0 && destination != nil) {
            guard let amount, let destination else { return }
            try CohortOperations.split(cohort, amount: amount, to: destination, label: label, date: date, in: modelContext)
            try modelContext.save()
        } content: {
            CurrentCohortSection(cohort: cohort)
            Section {
                IntField("分ける匹数", value: $amount)
                    .accessibilityIdentifier("splitAmountField")
                TextField("新しい群のラベル（任意）", text: $label)
            } footer: {
                Text("分けた分は新しい群になり、別の容器へ移ります。")
            }
            Section("移動先の容器") {
                if candidates.isEmpty {
                    Text("移動先の容器がありません。先に容器を登録しましょう。")
                        .foregroundStyle(.secondary)
                }
                ForEach(candidates) { tank in
                    TankChoiceRow(tank: tank, isSelected: destination?.id == tank.id) {
                        destination = tank
                    }
                }
            }
            Section {
                DatePicker("日付", selection: $date, displayedComponents: .date)
            }
        }
    }
}
