import SwiftData
import SwiftUI

// 販売記録シート（SCREENS.md 8.2）。群を選ぶと系統と世代が入り、保存のときに群の匹数を減らすか確認する。

struct SaleSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query(filter: Cohort.activePredicate, sort: \Cohort.createdAt) private var cohorts: [Cohort]
    @Query(filter: Strain.unarchivedPredicate, sort: Strain.listSort) private var strains: [Strain]
    @State private var model: SaleFormModel

    init(cohort: Cohort? = nil, sale: Sale? = nil) {
        _model = State(initialValue: SaleFormModel(cohort: cohort, sale: sale))
    }

    var body: some View {
        NavigationStack {
            Form {
                targetSection
                itemSection
                amountSection
                statusSection
                memoSection
            }
            .navigationTitle(model.isEditing ? "販売の編集" : "販売を記録")
            .navigationBarTitleDisplayMode(.inline)
            .bottomSaveBar(isEnabled: model.canSave, identifier: "saveSaleButton") {
                if model.save(in: modelContext) { dismiss() }
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") { dismiss() }
                }
            }
            .confirmationDialog("群の匹数を減らしますか", isPresented: $model.isAskingToReduce, titleVisibility: .visible) {
                Button("減らす") {
                    if model.save(reducesCohort: true, in: modelContext) { dismiss() }
                }
                Button("減らさない") {
                    if model.save(reducesCohort: false, in: modelContext) { dismiss() }
                }
                Button("キャンセル", role: .cancel) {}
            } message: {
                Text(verbatim: model.reduceMessage)
            }
            .confirmationDialog("この群を終了しますか", isPresented: $model.isAskingToEnd, titleVisibility: .visible) {
                Button("完売") {
                    model.end(as: .soldOut, in: modelContext)
                    dismiss()
                }
                Button("そのまま") { dismiss() }
            } message: {
                Text("匹数が0になりました。")
            }
            .errorAlert($model.error)
        }
    }

    // MARK: - 対象

    private var targetSection: some View {
        Section {
            DatePicker("日付", selection: $model.date, displayedComponents: .date)
            if model.isEditing {
                InfoRow(title: "対象", value: model.editing?.titleText ?? "")
            } else {
                Picker("群", selection: $model.cohort) {
                    Text("なし").tag(Cohort?.none)
                    ForEach(cohorts) { cohort in
                        Text(verbatim: "\(cohort.strainName) \(cohort.generationLabel)・\(cohort.tankName)・\(cohort.countText)")
                            .tag(Optional(cohort))
                    }
                }
                .pickerStyle(.navigationLink)
                .accessibilityIdentifier("saleCohortPicker")
                .onChange(of: model.cohort) { _, cohort in
                    if let strain = cohort?.strain { model.strain = strain }
                }
                if model.cohort == nil {
                    Picker("系統", selection: $model.strain) {
                        Text("なし").tag(Strain?.none)
                        ForEach(strains) { strain in
                            Text(verbatim: strain.displayName).tag(Optional(strain))
                        }
                    }
                    .pickerStyle(.navigationLink)
                }
            }
        } footer: {
            if !model.isEditing {
                Text("群を選ぶと、系統と世代が入ります。群を選ばない販売は、系統だけ選べます。")
            }
        }
    }

    // MARK: - 商品

    private var itemSection: some View {
        Section {
            Picker("単位", selection: $model.unit) {
                ForEach(SaleUnit.allCases, id: \.self) { unit in
                    Text(verbatim: unit.label).tag(unit)
                }
            }
            amountField("数量", placeholder: "1", value: $model.quantity)
                .accessibilityIdentifier("saleQuantityField")
            if model.unit == .fryBundle, !model.isEditing, model.cohort != nil {
                amountField("群から減らす匹数", placeholder: "0", value: $model.bundleFishCount)
            }
        } footer: {
            if !model.isEditing, model.cohort != nil {
                Text(verbatim: reduceHint)
            }
        }
    }

    private var reduceHint: String {
        switch model.unit {
        case .fish: String(localized: "数量の分だけ、群の匹数を減らします。")
        case .pair: String(localized: "ペアは1組を2匹として、群の匹数を減らします。")
        case .trio: String(localized: "トリオは1組を3匹として、群の匹数を減らします。")
        case .eggs: String(localized: "卵は群の匹数を減らしません。")
        case .fryBundle: String(localized: "稚魚まとめは、入れた匹数だけ群の匹数を減らします。")
        }
    }

    // MARK: - 金額

    private var amountSection: some View {
        Section {
            amountField("単価（円）", placeholder: "0", value: $model.unitPrice)
                .accessibilityIdentifier("saleUnitPriceField")
            amountField("合計（円）", placeholder: model.autoTotal.formatted(.number.grouping(.never)), value: $model.manualTotal)
            amountField("手数料（円）", placeholder: "0", value: $model.fee)
            amountField("送料（円）", placeholder: "0", value: $model.shippingCost)
            InfoRow(title: "純額", value: SaleText.yen(model.net))
        } footer: {
            Text("合計が空のときは、数量×単価で計算します。値引きなどで違うときは、合計に入れてください。")
        }
    }

    // MARK: - 状態

    private var statusSection: some View {
        Section {
            Picker("販路", selection: $model.channel) {
                ForEach(SaleChannel.allCases, id: \.self) { channel in
                    Text(verbatim: channel.label).tag(channel)
                }
            }
            Picker("状態", selection: $model.status) {
                ForEach(SaleStatus.allCases, id: \.self) { status in
                    Text(verbatim: status.label).tag(status)
                }
            }
            Toggle("発送日を入れる", isOn: $model.hasShippedAt)
            if model.hasShippedAt || model.status == .shipped {
                DatePicker("発送日", selection: $model.shippedAt, displayedComponents: .date)
            }
        }
    }

    private var memoSection: some View {
        Section {
            TextField("購入者メモ", text: $model.buyerMemo, axis: .vertical)
                .lineLimit(1...3)
            TextField("メモ", text: $model.note, axis: .vertical)
                .lineLimit(1...4)
        } footer: {
            Text("購入者メモは、この端末とバックアップにだけ保存されます。")
        }
    }

    /// 項目名を左に残し、数字を右に置く入力欄。入力しても何の欄か分かる。
    private func amountField(_ title: LocalizedStringKey, placeholder: String, value: Binding<Int?>) -> some View {
        LabeledContent(title) {
            IntField(LocalizedStringKey(placeholder), value: value)
                .multilineTextAlignment(.trailing)
        }
    }
}
