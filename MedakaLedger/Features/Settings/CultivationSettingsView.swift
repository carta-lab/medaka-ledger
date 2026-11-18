import SwiftData
import SwiftUI

/// 計算・季節・通知を一つの設定先にまとめる。保存キーと既定値は AppSettings のまま。
@MainActor
struct CultivationSettingsView: View {
    @ScaledMetric(relativeTo: .body) private var monthColumnWidth: CGFloat = 76
    @Environment(AppSettings.self) private var settings
    @Environment(NotificationScheduler.self) private var scheduler
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        @Bindable var settings = settings
        Form {
            Group {
                EntryHeading(title: "飼育と通知", subtitle: "育ち方に合わせて、記録の目安を整える。", systemImage: "slider.horizontal.3")
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
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: monthColumnWidth), spacing: 8)], spacing: 8) {
                        ForEach(1...12, id: \.self) { month in monthRow(month) }
                    }
                } header: {
                    Text("産卵期の月")
                } footer: {
                    Text("産卵期はホームの並びと水換えの警告日数が変わります。産卵期の最初の月の前月15日に「親魚セットを組みましょう」とお知らせします。")
                }

                selectionReminderSection(settings: settings)

            }
            .ledgerRow()
        }
        .themedBackground()
        .navigationTitle("飼育と通知の設定")
        .navigationBarTitleDisplayMode(.inline)
        .onDisappear {
            Task { await scheduler.reschedule(in: modelContext) }
        }
    }

    /// 選別の目安日の通知。孵化日から数えた日数は目安で、群の育ち方に合わせて変えられる（DECISIONS.md K）。
    @ViewBuilder
    private func selectionReminderSection(settings: AppSettings) -> some View {
        @Bindable var settings = settings
        Section {
            Toggle("選別の目安日を知らせる", isOn: $settings.selectionReminderEnabled)
                .accessibilityIdentifier("selectionReminderToggle")
            if settings.selectionReminderEnabled {
                ForEach(0..<3, id: \.self) { index in
                    Stepper {
                        LabeledContent(String(localized: "\(index + 1)回目")) {
                            Text(verbatim: String(localized: "孵化から\(settings.selectionReminderDays[index].formatted())日"))
                        }
                    } onIncrement: {
                        changeReminderDay(index, by: 1, settings: settings)
                    } onDecrement: {
                        changeReminderDay(index, by: -1, settings: settings)
                    }
                }
            }
        } header: {
            Text("選別の目安日")
        } footer: {
            Text("孵化日から数えたこの日数の朝8時に、選別を記録していない群を知らせます。日数は目安で、育ち方によって変わります。過ぎた目安日は知らせません。")
        }
    }

    private func changeReminderDay(_ index: Int, by step: Int, settings: AppSettings) {
        var days = settings.selectionReminderDays
        days[index] = min(max(days[index] + step, SelectionReminderPlanner.dayRange.lowerBound), SelectionReminderPlanner.dayRange.upperBound)
        settings.selectionReminderDays = days
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
            .padding(.horizontal, 10)
            .frame(minHeight: Theme.minButtonHeight)
            .background(isOn ? Theme.wash : Theme.background, in: .rect(cornerRadius: 6))
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isOn ? .isSelected : [])
    }
}
