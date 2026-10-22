import SwiftData
import SwiftUI

// 容器の作業記録の行。誤って記録した水換えや水温を、確認つきで削除できる（削除は確認を出す。CLAUDE.md）。
// 削除すると最終水換え日と警告、孵化予定日の計算に反映されるので、通知も計画し直す。

struct MaintenanceLogRows: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(NotificationScheduler.self) private var scheduler
    let logs: [MaintenanceLog]
    @State private var pending: MaintenanceLog? = nil
    @State private var isConfirming = false
    @State private var error: UserFacingError? = nil

    var body: some View {
        Group {
            ForEach(logs) { log in
                HStack {
                    Text(verbatim: log.summary)
                    if !log.note.isEmpty {
                        Text(verbatim: log.note)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                    Spacer()
                    Text(verbatim: CohortText.date(log.date))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .swipeActions(edge: .trailing) {
                    Button("削除", role: .destructive) {
                        pending = log
                        isConfirming = true
                    }
                }
            }
        }
        .confirmationDialog("この記録を削除しますか", isPresented: $isConfirming, titleVisibility: .visible, presenting: pending) { log in
            Button("削除", role: .destructive) { delete(log) }
            Button("キャンセル", role: .cancel) {}
        } message: { _ in
            Text("最終水換えの日と、孵化予定日の計算に反映されます。")
        }
        .errorAlert($error)
    }

    private func delete(_ log: MaintenanceLog) {
        modelContext.delete(log)
        do {
            try modelContext.save()
        } catch {
            modelContext.rollback()
            self.error = UserFacingError(error, title: String(localized: "削除できませんでした"))
            return
        }
        pending = nil
        let context = modelContext
        Task { await scheduler.reschedule(in: context) }
    }
}

/// 容器の作業記録をすべて見る画面（SCREENS.md 3.3）。
struct TankLogsView: View {
    @Bindable var tank: Tank

    var body: some View {
        List {
            let logs = tank.recentLogs
            if logs.isEmpty {
                Text("作業記録はまだありません")
                    .foregroundStyle(.secondary)
            }
            MaintenanceLogRows(logs: logs)
        }
        .navigationTitle(Text(verbatim: String(localized: "\(tank.name)の作業記録")))
        .navigationBarTitleDisplayMode(.inline)
    }
}
