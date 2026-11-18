import SwiftData
import SwiftUI

// 設定（SCREENS.md 12）。計算、出品文の雛形、バックアップと書き出し、サンプルデータ、Pro、用語の説明、プライバシーポリシー。
// 値を変えると孵化予定日は即時に再計算される（PRD.md F14）。

struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(NotificationScheduler.self) private var scheduler
    @State private var gate = LimitGate()
    @State private var backup = BackupModel()
    @State private var usage: Int64?

    var body: some View {
        NavigationStack {
            Form {
                Group {
                    EntryHeading(title: "わたしの台帳", subtitle: "記録を守り、飼育に合わせて整える。", systemImage: "slider.horizontal.3")
                    ProSection(gate: gate)
                    BackupSection(model: backup, usage: usage)
                    Section {
                        NavigationLink {
                            CultivationSettingsView()
                        } label: {
                            Label("飼育と通知の設定", systemImage: "leaf")
                        }
                        .accessibilityIdentifier("cultivationSettingsLink")
                    } footer: {
                        Text("孵化予定日、水換え、産卵期、選別の通知を設定します。")
                    }
                    ListingSettingsSection(gate: gate)

                    SampleDataSection()

                    AboutSection()
                }
                .ledgerRow()
            }
            .themedBackground()
            .navigationTitle("設定")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("閉じる") { dismiss() }
                }
            }
            .paywall(gate)
            .modifier(BackupPresentations(model: backup) {
                Task { await refreshUsage() }
            })
            .fileExporter(isPresented: $backup.isExportingCSV, document: backup.csvDocument, contentType: .commaSeparatedText, defaultFilename: String(localized: "群の一覧")) { result in
                backup.csvFinished(result)
            }
            .task { await refreshUsage() }
            .onDisappear {
                // 積算温度、既定の水温、産卵期の月が変わると予定日と通知が変わる
                Task { await scheduler.reschedule(in: modelContext) }
            }
        }
    }

    private func refreshUsage() async {
        usage = await Task.detached { StorageUsage.bytes() }.value
    }
}
