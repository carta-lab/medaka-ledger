import Foundation
import Testing
@testable import MedakaLedger

struct HatchPredictorTests {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Tokyo") ?? .current
        return calendar
    }

    private func date(_ year: Int, _ month: Int, _ day: Int, hour: Int = 9) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour)) ?? .distantPast
    }

    private func predict(
        collected: Date? = nil,
        lotTemp: Double? = nil,
        daily: [Date: Double] = [:],
        defaultTemp: Double = 25,
        degreeDays: Double = 250
    ) -> HatchPrediction? {
        HatchPredictor.predict(
            collectedAt: collected ?? date(2027, 5, 1),
            lotWaterTempC: lotTemp,
            dailyTemps: daily,
            defaultWaterTempC: defaultTemp,
            degreeDaysToHatch: degreeDays,
            calendar: calendar
        )
    }

    // ROADMAP 第2週の完了条件：25℃で10日後、20℃に変えると13日後。
    @Test func defaultTempOnly() throws {
        let result = try #require(predict())
        #expect(result.date == date(2027, 5, 11, hour: 0))
        #expect(HatchPredictor.daysRemaining(until: result, today: date(2027, 5, 1), calendar: calendar) == 10)
    }

    @Test func changingDefaultTempChangesPrediction() throws {
        let result = try #require(predict(defaultTemp: 20))
        #expect(HatchPredictor.daysRemaining(until: result, today: date(2027, 5, 1), calendar: calendar) == 13)
    }

    @Test func lotTempOverridesDefault() throws {
        let result = try #require(predict(lotTemp: 20, defaultTemp: 25))
        #expect(HatchPredictor.daysRemaining(until: result, today: date(2027, 5, 1), calendar: calendar) == 13)
    }

    @Test func dailyTempOverridesLotTempAndFallsBack() throws {
        // 初日の5日間だけ30℃、残りはロットの水温20℃：150 + 100 = 250 → 5 + 5 = 10日
        var daily: [Date: Double] = [:]
        for offset in 0..<5 {
            daily[date(2027, 5, 1 + offset, hour: 0)] = 30
        }
        let result = try #require(predict(lotTemp: 20, daily: daily))
        #expect(HatchPredictor.daysRemaining(until: result, today: date(2027, 5, 1), calendar: calendar) == 10)
    }

    @Test func rangeIsOneDayEitherSide() throws {
        let result = try #require(predict())
        #expect(result.earliest == date(2027, 5, 10, hour: 0))
        #expect(result.latest == date(2027, 5, 12, hour: 0))
    }

    @Test func degreeDaysSettingIsReflected() throws {
        let result = try #require(predict(degreeDays: 300))
        #expect(HatchPredictor.daysRemaining(until: result, today: date(2027, 5, 1), calendar: calendar) == 12)
    }

    @Test func negativeTempsCountAsZero() throws {
        // 最初の2日は-5℃（0として数える）、残りは25℃：10日分の積算に2日ぶん足りないので12日
        let daily = [date(2027, 5, 1, hour: 0): -5.0, date(2027, 5, 2, hour: 0): -5.0]
        let result = try #require(predict(daily: daily))
        #expect(HatchPredictor.daysRemaining(until: result, today: date(2027, 5, 1), calendar: calendar) == 12)
    }

    @Test func alwaysFreezingGivesNoPrediction() {
        #expect(predict(lotTemp: 0) == nil)
        #expect(predict(defaultTemp: -3) == nil)
    }

    @Test func invalidDegreeDaysGivesNoPrediction() {
        #expect(predict(degreeDays: 0) == nil)
    }

    @Test func crossesMonthAndYearBoundary() throws {
        let result = try #require(predict(collected: date(2026, 12, 28)))
        #expect(result.date == date(2027, 1, 7, hour: 0))
    }

    @Test func pastDueGivesNegativeRemaining() throws {
        let result = try #require(predict())
        #expect(HatchPredictor.daysRemaining(until: result, today: date(2027, 5, 14), calendar: calendar) == -3)
        #expect(HatchPredictor.daysRemaining(until: result, today: date(2027, 5, 11, hour: 23), calendar: calendar) == 0)
    }

    @Test func dailyAveragesMergeSameDay() {
        let readings = [
            TemperatureReading(date: date(2027, 5, 1, hour: 8), tempC: 20),
            TemperatureReading(date: date(2027, 5, 1, hour: 20), tempC: 24),
            TemperatureReading(date: date(2027, 5, 2, hour: 8), tempC: 18),
        ]
        let averages = HatchPredictor.dailyAverages(readings, calendar: calendar)
        #expect(averages[date(2027, 5, 1, hour: 0)] == 22)
        #expect(averages[date(2027, 5, 2, hour: 0)] == 18)
        #expect(averages.count == 2)
    }
}

struct NotificationPlannerTests {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Tokyo") ?? .current
        return calendar
    }

    private func date(_ year: Int, _ month: Int, _ day: Int, hour: Int = 0) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour)) ?? .distantPast
    }

    @Test func hatchNotificationsFireAtEightInTheMorning() {
        let id = UUID()
        let planned = NotificationPlanner.hatchNotifications(
            [HatchNotificationInput(batchID: id, name: "A", predictedDate: date(2027, 5, 11))],
            now: date(2027, 5, 1, hour: 9),
            calendar: calendar
        )
        #expect(planned.count == 1)
        #expect(planned[0].fireDate == date(2027, 5, 11, hour: 8))
        #expect(planned[0].identifier == "hatch-\(id.uuidString)")
        #expect(planned[0].kind == .hatch(name: "A"))
    }

    @Test func pastNotificationsAreSkipped() {
        let planned = NotificationPlanner.hatchNotifications(
            [
                HatchNotificationInput(batchID: UUID(), name: "past", predictedDate: date(2027, 5, 1)),
                HatchNotificationInput(batchID: UUID(), name: "today-after-eight", predictedDate: date(2027, 5, 11)),
                HatchNotificationInput(batchID: UUID(), name: "future", predictedDate: date(2027, 5, 12)),
            ],
            now: date(2027, 5, 11, hour: 9),
            calendar: calendar
        )
        #expect(planned.map(\.kind) == [.hatch(name: "future")])
    }

    @Test func atMostFiftyNearestAreScheduled() {
        let inputs = (0..<60).map { offset in
            HatchNotificationInput(batchID: UUID(), name: "\(offset)", predictedDate: date(2027, 6, 1).addingTimeInterval(Double(60 - offset) * 86_400))
        }
        let planned = NotificationPlanner.hatchNotifications(inputs, now: date(2027, 5, 1), calendar: calendar)
        #expect(planned.count == 50)
        #expect(planned.first?.kind == .hatch(name: "59"))
        #expect(planned.map(\.fireDate) == planned.map(\.fireDate).sorted())
    }

    @Test func seasonStartIsFifteenthOfPreviousMonth() {
        let planned = NotificationPlanner.seasonStartNotification(now: date(2026, 11, 2), months: [4, 5, 6, 7, 8, 9], calendar: calendar)
        #expect(planned?.fireDate == date(2027, 3, 15, hour: 8))
        #expect(planned?.kind == .seasonStart)
    }

    @Test func seasonStartRollsToNextYearAfterItPassed() {
        let planned = NotificationPlanner.seasonStartNotification(now: date(2027, 3, 16), months: [4, 5, 6, 7, 8, 9], calendar: calendar)
        #expect(planned?.fireDate == date(2028, 3, 15, hour: 8))
    }

    @Test func seasonStartingInJanuaryNotifiesInDecember() {
        let planned = NotificationPlanner.seasonStartNotification(now: date(2027, 1, 5), months: [1, 2, 3], calendar: calendar)
        #expect(planned?.fireDate == date(2027, 12, 15, hour: 8))
    }

    @Test func seasonWrappingTheYearStartsAtItsFirstMonth() {
        let planned = NotificationPlanner.seasonStartNotification(now: date(2027, 1, 5), months: [11, 12, 1, 2], calendar: calendar)
        #expect(planned?.fireDate == date(2027, 10, 15, hour: 8))
    }

    @Test func noSeasonStartForEmptyOrYearRoundSeason() {
        #expect(NotificationPlanner.seasonStartNotification(now: date(2027, 1, 5), months: [], calendar: calendar) == nil)
        #expect(NotificationPlanner.seasonStartNotification(now: date(2027, 1, 5), months: Array(1...12), calendar: calendar) == nil)
    }
}

struct FreeLimitsAndMaintenanceTests {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Tokyo") ?? .current
        return calendar
    }

    @Test func activeBreedingSetCountIgnoresEndedAndSample() {
        let ended = Date(timeIntervalSince1970: 1)
        #expect(FreeLimits.activeBreedingSetCount(endedAts: [nil, ended, nil, nil], isSamples: [false, false, true, false]) == 2)
        #expect(FreeLimits.activeBreedingSetCount(endedAts: [], isSamples: []) == 0)
    }

    @Test func canAddHonoursLimitAndPro() {
        #expect(FreeLimits.canAdd(currentCount: 1, limit: 2, isPro: false))
        #expect(!FreeLimits.canAdd(currentCount: 2, limit: 2, isPro: false))
        #expect(FreeLimits.canAdd(currentCount: 99, limit: 2, isPro: true))
    }

    @Test func overdueIsStrictlyAfterWarningDays() {
        #expect(!MaintenanceRules.isOverdue(daysSince: 14, warningDays: 14))
        #expect(MaintenanceRules.isOverdue(daysSince: 15, warningDays: 14))
        #expect(!MaintenanceRules.isOverdue(daysSince: nil, warningDays: 14))
    }

    @Test func daysSinceLastWaterChange() {
        let last = calendar.date(from: DateComponents(year: 2027, month: 5, day: 1, hour: 23)) ?? .distantPast
        let today = calendar.date(from: DateComponents(year: 2027, month: 5, day: 15, hour: 1)) ?? .distantPast
        #expect(MaintenanceRules.daysSinceLastWaterChange(lastWaterChange: last, today: today, calendar: calendar) == 14)
        #expect(MaintenanceRules.daysSinceLastWaterChange(lastWaterChange: nil, today: today, calendar: calendar) == nil)
    }
}
