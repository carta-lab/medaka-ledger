import Foundation
import Observation
import SwiftData
import UserNotifications

// ローカル通知（SCREENS.md 14、DECISIONS.md G 3-9）。
// 孵化予定日の朝8時と、産卵期の最初の月の前月15日の朝8時。許可は最初の採卵ロットを保存したときに求める。
// 予定日は保存せず都度計算するので、変わりうる操作のたびに予約を全て消して計画し直す。

@MainActor
@Observable
final class NotificationScheduler {
    private let settings: AppSettings
    private let center: UNUserNotificationCenter
    private(set) var status: UNAuthorizationStatus = .notDetermined

    init(settings: AppSettings, center: UNUserNotificationCenter = .current()) {
        self.settings = settings
        self.center = center
    }

    /// 許可をまだ求めていないか。求める前に、理由を一行で示す（CLAUDE.md）。
    var needsAuthorizationPrompt: Bool { status == .notDetermined }

    func refreshStatus() async {
        status = await center.notificationSettings().authorizationStatus
    }

    func requestAuthorizationIfNeeded() async {
        await refreshStatus()
        guard status == .notDetermined else { return }
        _ = try? await center.requestAuthorization(options: [.alert, .sound])
        await refreshStatus()
    }

    /// 起動時、フォアグラウンド復帰時、採卵ロット、水温記録、設定値の変更時に呼ぶ。
    func reschedule(in context: ModelContext, now: Date = .now, calendar: Calendar = .current) async {
        await refreshStatus()
        center.removeAllPendingNotificationRequests()
        guard status == .authorized || status == .provisional else { return }

        let hatchSettings = BreedingOperations.HatchSettings(
            degreeDaysToHatch: settings.degreeDaysToHatch,
            defaultWaterTempC: settings.defaultWaterTempC
        )
        let batches = (try? context.fetch(FetchDescriptor<EggBatch>(
            predicate: EggBatch.incubatingPredicate,
            sortBy: [SortDescriptor(\EggBatch.collectedAt)]
        ))) ?? []
        let inputs = batches.compactMap { batch -> HatchNotificationInput? in
            guard let prediction = BreedingOperations.prediction(for: batch, settings: hatchSettings, calendar: calendar) else { return nil }
            return HatchNotificationInput(batchID: batch.id, name: batch.title, predictedDate: prediction.date)
        }

        var planned = NotificationPlanner.hatchNotifications(inputs, now: now, calendar: calendar)
        if let season = NotificationPlanner.seasonStartNotification(now: now, months: settings.breedingSeasonMonths, calendar: calendar) {
            planned.append(season)
        }
        for item in planned {
            let content = UNMutableNotificationContent()
            switch item.kind {
            case let .hatch(name):
                content.title = String(localized: "孵化予定")
                content.body = String(localized: "\(name)のロットが今日孵化予定です")
            case .seasonStart:
                content.title = String(localized: "産卵期が近づいています")
                content.body = String(localized: "親魚セットを組みましょう")
            }
            content.sound = .default
            let components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: item.fireDate)
            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
            try? await center.add(UNNotificationRequest(identifier: item.identifier, content: content, trigger: trigger))
        }
    }
}
