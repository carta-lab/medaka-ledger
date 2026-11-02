import Foundation
import Observation
import SwiftData
import UserNotifications

// ローカル通知（SCREENS.md 14、DECISIONS.md G 3-9）。
// 孵化予定日の朝8時と、産卵期の最初の月の前月15日の朝8時、選別の目安日の朝8時。許可は最初の採卵ロットを保存したときに求める。
// 予定日は保存せず都度計算するので、変わりうる操作のたびに予約を全て消して計画し直す。

@MainActor
@Observable
final class NotificationScheduler {
    private let settings: AppSettings
    private let center: UNUserNotificationCenter
    private(set) var status: UNAuthorizationStatus = .notDetermined
    /// 予約の作り直しを1件ずつ順に行うための、直前の作り直し。
    @ObservationIgnored private var previous: Task<Void, Never>?

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
    /// 重なって呼ばれても、直前の作り直しが終わってから計画するので、古い計画の通知は残らない。
    func reschedule(in context: ModelContext, now: Date = .now, calendar: Calendar = .current) async {
        let earlier = previous
        let task = Task {
            await earlier?.value
            await performReschedule(in: context, now: now, calendar: calendar)
        }
        previous = task
        await task.value
    }

    private func performReschedule(in context: ModelContext, now: Date, calendar: Calendar) async {
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
        if settings.selectionReminderEnabled {
            let cohorts = (try? context.fetch(FetchDescriptor<Cohort>(
                predicate: Cohort.activePredicate,
                sortBy: [SortDescriptor(\Cohort.createdAt)]
            ))) ?? []
            let reminders = cohorts.compactMap { cohort -> SelectionReminderInput? in
                guard let hatchedAt = cohort.hatchedAt else { return nil }
                return SelectionReminderInput(
                    cohortID: cohort.id,
                    name: "\(cohort.strain?.breedName ?? "") \(cohort.generationLabel)",
                    hatchedAt: hatchedAt,
                    doneRounds: Set((cohort.selections ?? []).map(\.round))
                )
            }
            planned += SelectionReminderPlanner.notifications(reminders, days: settings.selectionReminderDays, now: now, calendar: calendar)
        }
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
            case let .selectionDue(firstName, cohortCount, days):
                content.title = String(localized: "選別の目安日")
                if cohortCount > 1 {
                    content.body = String(localized: "\(firstName)ほか\(cohortCount - 1)群が、選別の目安日です")
                } else {
                    content.body = String(localized: "\(firstName)は、孵化から\(days)日です。選別の目安日です")
                }
            }
            content.sound = .default
            let components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: item.fireDate)
            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
            try? await center.add(UNNotificationRequest(identifier: item.identifier, content: content, trigger: trigger))
        }
    }
}
