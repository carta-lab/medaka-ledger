import Foundation

// 孵化予定日（ARCHITECTURE.md 4.1、DECISIONS.md F）。保存せず、設定や水温記録が変わるたびに都度計算する。

struct HatchPrediction: Equatable, Sendable {
    /// 予定日（日付の0時）。
    var date: Date
    /// 前後1日の幅。
    var earliest: Date
    var latest: Date
}

struct TemperatureReading: Equatable, Sendable {
    var date: Date
    var tempC: Double
}

enum HatchPredictor {
    /// 水温が0℃以下の日ばかりで終わらないときの打ち切り。これを超えたら予定日を出さない。
    static let maxDays = 365

    /// 採卵日の0時から1日ずつ、その日の容器の水温記録、なければロットの水温、なければ既定水温を足し、
    /// 積算温度に達した日を予定日とする。0℃未満の日は0として数える。
    static func predict(
        collectedAt: Date,
        lotWaterTempC: Double?,
        dailyTemps: [Date: Double],
        defaultWaterTempC: Double,
        degreeDaysToHatch: Double,
        calendar: Calendar
    ) -> HatchPrediction? {
        guard degreeDaysToHatch > 0 else { return nil }
        var accumulated = 0.0
        var day = calendar.startOfDay(for: collectedAt)
        var elapsed = 0
        while accumulated < degreeDaysToHatch {
            guard elapsed < maxDays, let next = calendar.date(byAdding: .day, value: 1, to: day) else { return nil }
            let temp = dailyTemps[day] ?? lotWaterTempC ?? defaultWaterTempC
            accumulated += max(temp, 0)
            day = next
            elapsed += 1
        }
        guard let earliest = calendar.date(byAdding: .day, value: -1, to: day),
              let latest = calendar.date(byAdding: .day, value: 1, to: day)
        else { return nil }
        return HatchPrediction(date: day, earliest: earliest, latest: latest)
    }

    /// 同じ日に複数の記録があれば平均して、日付の0時をキーにした水温にする。
    static func dailyAverages(_ readings: [TemperatureReading], calendar: Calendar) -> [Date: Double] {
        var sums: [Date: (total: Double, count: Int)] = [:]
        for reading in readings {
            let day = calendar.startOfDay(for: reading.date)
            let current = sums[day] ?? (0, 0)
            sums[day] = (current.total + reading.tempC, current.count + 1)
        }
        return sums.mapValues { $0.total / Double($0.count) }
    }

    /// 予定日までの残り日数。今日が予定日なら0、過ぎていれば負。
    static func daysRemaining(until prediction: HatchPrediction, today: Date, calendar: Calendar) -> Int {
        DayCount.days(from: today, to: prediction.date, calendar: calendar)
    }
}
