import Foundation
import Testing
@testable import MedakaLedger

struct SelectionReminderPlannerTests {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Tokyo") ?? .current
        return calendar
    }

    private func date(_ year: Int, _ month: Int, _ day: Int, hour: Int = 12) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour)) ?? .distantPast
    }

    private func input(_ name: String, hatched: Date, done: Set<Int> = []) -> SelectionReminderInput {
        SelectionReminderInput(cohortID: UUID(), name: name, hatchedAt: hatched, doneRounds: done)
    }

    private func plan(_ inputs: [SelectionReminderInput], now: Date = Date(timeIntervalSince1970: 0)) -> [PlannedNotification] {
        SelectionReminderPlanner.notifications(inputs, days: SelectionReminderPlanner.defaultDays, now: now, calendar: calendar)
    }

    @Test func 孵化日から数えた日の朝8時に3回分を知らせる() {
        let result = plan([input("楊貴妃 F1", hatched: date(2027, 5, 1))])
        #expect(result.map(\.fireDate) == [date(2027, 5, 22, hour: 8), date(2027, 6, 19, hour: 8), date(2027, 7, 24, hour: 8)])
    }

    @Test func 記録済みの回は知らせない() {
        let result = plan([input("楊貴妃 F1", hatched: date(2027, 5, 1), done: [1, 3])])
        #expect(result.map(\.fireDate) == [date(2027, 6, 19, hour: 8)])
    }

    @Test func 過ぎた目安日は知らせない() {
        let result = plan([input("楊貴妃 F1", hatched: date(2027, 5, 1))], now: date(2027, 6, 1))
        #expect(result.map(\.fireDate) == [date(2027, 6, 19, hour: 8), date(2027, 7, 24, hour: 8)])
    }

    @Test func 朝8時を過ぎた当日は知らせない() {
        let result = plan([input("楊貴妃 F1", hatched: date(2027, 5, 1))], now: date(2027, 5, 22, hour: 9))
        #expect(result.first?.fireDate == date(2027, 6, 19, hour: 8))
    }

    @Test func 同じ日の群は1件にまとめる() {
        let result = plan([
            input("幹之 F1", hatched: date(2027, 5, 1, hour: 18), done: [2, 3]),
            input("楊貴妃 F1", hatched: date(2027, 5, 1, hour: 6), done: [2, 3]),
        ])
        #expect(result.count == 1)
        #expect(result.first?.kind == .selectionDue(firstName: "楊貴妃 F1", cohortCount: 2, days: 21))
    }

    @Test func 同じ群の2回が同じ日でも群は1つと数える() {
        let result = SelectionReminderPlanner.notifications(
            [input("楊貴妃 F1", hatched: date(2027, 5, 1))],
            days: [30, 30, 84], now: Date(timeIntervalSince1970: 0), calendar: calendar
        )
        #expect(result.first?.kind == .selectionDue(firstName: "楊貴妃 F1", cohortCount: 1, days: 30))
    }

    @Test func 予約は日の近い10件まで() {
        let inputs = (0..<8).map { input("群\($0)", hatched: date(2027, 5, 1 + $0)) }
        let result = plan(inputs)
        #expect(result.count == SelectionReminderPlanner.maxNotifications)
        #expect(result == result.sorted { $0.fireDate < $1.fireDate })
    }

    @Test func 識別子は日ごとに決まる() {
        let result = plan([input("楊貴妃 F1", hatched: date(2027, 5, 1))])
        #expect(result.first?.identifier == "selection-2027-5-22")
    }

    @Test func 設定の日数が範囲外なら既定に戻す() {
        #expect(SelectionReminderPlanner.normalizedDays([]) == SelectionReminderPlanner.defaultDays)
        #expect(SelectionReminderPlanner.normalizedDays([0, 49, 84]) == SelectionReminderPlanner.defaultDays)
        #expect(SelectionReminderPlanner.normalizedDays([21, 49, 366]) == SelectionReminderPlanner.defaultDays)
        #expect(SelectionReminderPlanner.normalizedDays([14, 40, 90]) == [14, 40, 90])
    }

    @Test func 孵化日が年をまたいでも数える() {
        let result = plan([input("楊貴妃 F1", hatched: date(2027, 12, 20), done: [2, 3])])
        #expect(result.first?.fireDate == date(2028, 1, 10, hour: 8))
    }
}
