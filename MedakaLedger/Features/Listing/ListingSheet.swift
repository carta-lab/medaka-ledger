import SwiftData
import SwiftUI

// 出品文（SCREENS.md 8.3、PRD.md F11）。群を選ぶと本文を組み立てて表示し、行ごとに消し、コピーする。
// 端末の中の情報だけで作る。通信しない。Pro限定（呼び出し側で確かめる）。

struct ListingSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppSettings.self) private var settings
    @Query(filter: Cohort.activePredicate, sort: \Cohort.createdAt) private var cohorts: [Cohort]
    @State private var model: ListingModel

    init(cohort: Cohort? = nil) {
        _model = State(initialValue: ListingModel(cohort: cohort))
    }

    var body: some View {
        @Bindable var model = model
        let lines = model.lines(settings: settings)
        NavigationStack {
            Form {
                Group {
                    EntryHeading(title: "出品文", subtitle: "記録から文を組み立て、必要な行を選ぶ。", systemImage: "text.alignleft")
                    Section {
                        Picker("群", selection: $model.cohort) {
                            Text("選んでください").tag(Cohort?.none)
                            ForEach(cohorts) { cohort in
                                Text(verbatim: "\(cohort.strainName) \(cohort.generationLabel)・\(cohort.tankName)")
                                    .tag(Optional(cohort))
                            }
                        }
                        .pickerStyle(.navigationLink)
                        .accessibilityIdentifier("listingCohortPicker")
                    } footer: {
                        if model.cohort == nil {
                            Text("群を選ぶと、出品文を組み立てます。")
                        }
                    }

                    if !lines.isEmpty {
                        Section {
                            ForEach(Array(lines.enumerated()), id: \.offset) { index, line in
                                if !model.removedLines.contains(index) {
                                    HStack(alignment: .firstTextBaseline) {
                                        Text(verbatim: line.isEmpty ? " " : line)
                                        Spacer(minLength: 8)
                                        Button {
                                            model.remove(index)
                                        } label: {
                                            Label("この行を消す", systemImage: "minus.circle")
                                                .labelStyle(.iconOnly)
                                        }
                                        .buttonStyle(.borderless)
                                        .accessibilityLabel(Text(verbatim: String(localized: "「\(line)」の行を消す")))
                                    }
                                }
                            }
                            if !model.removedLines.isEmpty {
                                Button("消した行を戻す") { model.restoreAll() }
                            }
                        } header: {
                            Text("出品文")
                        } footer: {
                            Text("情報が入っていない項目は、行ごと省いています。雛形は設定で変えられます。")
                        }
                    }
                }
                .ledgerRow()
            }
            .themedBackground()
            .navigationTitle("出品文")
            .navigationBarTitleDisplayMode(.inline)
            .bottomSaveBar(
                model.didCopy ? "コピーしました" : "コピー",
                isEnabled: model.cohort != nil && !model.body(settings: settings).isEmpty,
                identifier: "copyListingButton"
            ) {
                model.copy(settings: settings)
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("閉じる") { dismiss() }
                }
            }
        }
    }
}

