import SwiftData
import SwiftUI

// 設定。第2週は「計算」だけ（孵化予定日と水換え警告に使う値。ROADMAP.md 第2週の完了条件を確かめるため）。
// バックアップ、サンプル、Pro、用語の説明などは第4週以降。値を変えると孵化予定日は即時に再計算される（PRD.md F14）。

struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(AppSettings.self) private var settings
    @Environment(NotificationScheduler.self) private var scheduler

    var body: some View {
        @Bindable var settings = settings
        NavigationStack {
            Form {
                Section {
                    LabeledContent("積算温度（℃日）") {
                        TextField("250", value: $settings.degreeDaysToHatch, format: .number)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .accessibilityIdentifier("degreeDaysField")
                    }
                    LabeledContent("既定の水温（℃）") {
                        TextField("25", value: $settings.defaultWaterTempC, format: .number)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .accessibilityIdentifier("defaultTempField")
                    }
                } header: {
                    Text("孵化予定日")
                } footer: {
                    Text("積算温度を水温で割った日数が、採卵日から孵化までの目安です。水温を入れなかったロットは、既定の水温で計算します。")
                }

                Section {
                    Stepper(value: $settings.waterChangeWarningDays, in: 1...120) {
                        LabeledContent("産卵期") {
                            Text(verbatim: String(localized: "\(settings.waterChangeWarningDays.formatted())日"))
                        }
                    }
                    Stepper(value: $settings.winterWaterChangeWarningDays, in: 1...180) {
                        LabeledContent("産卵期外") {
                            Text(verbatim: String(localized: "\(settings.winterWaterChangeWarningDays.formatted())日"))
                        }
                    }
                } header: {
                    Text("水換えの警告")
                } footer: {
                    Text("最後の水換えからこの日数を超えた容器を、ホームで知らせます。")
                }

                Section {
                    ForEach(1...12, id: \.self) { month in
                        monthRow(month)
                    }
                } header: {
                    Text("産卵期の月")
                } footer: {
                    Text("産卵期はホームの並びと水換えの警告日数が変わります。産卵期の最初の月の前月15日に「親魚セットを組みましょう」とお知らせします。")
                }
            }
            .navigationTitle("設定")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("閉じる") { dismiss() }
                }
            }
            .onDisappear {
                // 積算温度、既定の水温、産卵期の月が変わると予定日と通知が変わる
                Task { await scheduler.reschedule(in: modelContext) }
            }
        }
    }

    private func monthRow(_ month: Int) -> some View {
        let isOn = settings.breedingSeasonMonths.contains(month)
        return Button {
            var months = Set(settings.breedingSeasonMonths)
            if isOn { months.remove(month) } else { months.insert(month) }
            settings.breedingSeasonMonths = months.sorted()
        } label: {
            HStack {
                Text(verbatim: String(localized: "\(month.formatted())月"))
                Spacer()
                if isOn {
                    Image(systemName: "checkmark")
                        .foregroundStyle(Theme.accent)
                }
            }
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isOn ? .isSelected : [])
    }
}
