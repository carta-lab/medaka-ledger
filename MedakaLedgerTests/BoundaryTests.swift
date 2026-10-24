import Foundation
import Testing
@testable import MedakaLedger

// 日付の境界とゼロ、巨大な値の扱い（ROADMAP.md 第6週）。

struct BoundaryTests {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Tokyo") ?? .current
        return calendar
    }

    private func date(_ year: Int, _ month: Int, _ day: Int, hour: Int = 0, minute: Int = 0) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour, minute: minute)) ?? .distantPast
    }

    @Test func 深夜をまたぐと1日と数える() {
        let days = DayCount.days(from: date(2027, 5, 1, hour: 23, minute: 59), to: date(2027, 5, 2, hour: 0, minute: 1), calendar: calendar)
        #expect(days == 1)
    }

    @Test func 同じ日なら時刻が離れていても0日() {
        let days = DayCount.days(from: date(2027, 5, 1, hour: 0, minute: 0), to: date(2027, 5, 1, hour: 23, minute: 59), calendar: calendar)
        #expect(days == 0)
    }

    @Test func 月末と年またぎを正しく数える() {
        #expect(DayCount.days(from: date(2027, 1, 31), to: date(2027, 3, 1), calendar: calendar) == 29)
        #expect(DayCount.days(from: date(2027, 12, 31), to: date(2028, 1, 1), calendar: calendar) == 1)
        #expect(DayCount.days(from: date(2028, 2, 28), to: date(2028, 3, 1), calendar: calendar) == 2)
    }

    @Test func 産卵期の月が年をまたいでも判定できる() {
        let months = [11, 12, 1, 2]
        #expect(Season.isBreedingSeason(on: date(2027, 12, 31, hour: 23, minute: 59), months: months, calendar: calendar))
        #expect(Season.isBreedingSeason(on: date(2028, 1, 1), months: months, calendar: calendar))
        #expect(!Season.isBreedingSeason(on: date(2028, 3, 1), months: months, calendar: calendar))
        #expect(!Season.isBreedingSeason(on: date(2027, 5, 1), months: [], calendar: calendar))
    }

    @Test func 水換えの記録が未来でも警告しない() {
        let days = MaintenanceRules.daysSinceLastWaterChange(lastWaterChange: date(2027, 5, 10), today: date(2027, 5, 1), calendar: calendar)
        #expect(days == -9)
        #expect(!MaintenanceRules.isOverdue(daysSince: days, warningDays: 0))
        #expect(!MaintenanceRules.isOverdue(daysSince: nil, warningDays: 0))
    }

    @Test func 孵化予定は年をまたいで出る() {
        let prediction = HatchPredictor.predict(
            collectedAt: date(2027, 12, 28, hour: 23, minute: 30),
            lotWaterTempC: nil,
            dailyTemps: [:],
            defaultWaterTempC: 25,
            degreeDaysToHatch: 250,
            calendar: calendar
        )
        #expect(prediction?.date == date(2028, 1, 7))
    }

    @Test func 水温が0度以下の日ばかりなら予定日を出さない() {
        let prediction = HatchPredictor.predict(
            collectedAt: date(2027, 1, 1),
            lotWaterTempC: -5,
            dailyTemps: [:],
            defaultWaterTempC: 25,
            degreeDaysToHatch: 250,
            calendar: calendar
        )
        #expect(prediction == nil)
    }

    @Test func 積算温度が0以下なら予定日を出さない() {
        for degreeDays in [0.0, -1.0] {
            let prediction = HatchPredictor.predict(
                collectedAt: date(2027, 5, 1), lotWaterTempC: nil, dailyTemps: [:],
                defaultWaterTempC: 25, degreeDaysToHatch: degreeDays, calendar: calendar
            )
            #expect(prediction == nil)
        }
    }

    @Test func 積算温度が巨大でも止まる() {
        let prediction = HatchPredictor.predict(
            collectedAt: date(2027, 5, 1), lotWaterTempC: nil, dailyTemps: [:],
            defaultWaterTempC: 25, degreeDaysToHatch: 1e12, calendar: calendar
        )
        #expect(prediction == nil)
    }
}
