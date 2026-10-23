import Foundation
import Testing
@testable import MedakaLedger

struct ListingTextBuilderTests {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Tokyo") ?? .gmt
        return calendar
    }

    private func input(
        line: String = "〇〇めだか春購入",
        generation: Int = 1,
        count: Int? = 30,
        male: Int? = 12,
        female: Int? = 18,
        size: String = "1.5〜2cm",
        hatched: Date? = nil,
        parentTags: [String] = ["朱赤", "ラメ"],
        placement: Placement? = .outdoor,
        guarantee: String = "",
        notice: String = ""
    ) -> ListingInput {
        ListingInput(
            breedName: "楊貴妃", lineName: line, generation: generation, count: count, maleCount: male, femaleCount: female,
            sizeText: size, hatchedAt: hatched ?? calendar.date(from: DateComponents(year: 2027, month: 5, day: 20, hour: 12)),
            parentTraitTags: parentTags, placement: placement, guaranteeText: guarantee, noticeText: notice
        )
    }

    @Test func 全て入っていれば全ての行が出る() {
        let text = ListingTextBuilder.build(
            template: ListingTextBuilder.defaultTemplate,
            input: input(guarantee: "到着後24時間以内にご連絡ください", notice: "水合わせをお願いします"),
            calendar: calendar
        )
        #expect(text == """
        【楊貴妃】F1
        系統：〇〇めだか春購入
        匹数：30匹
        雌雄：雄12・雌18
        サイズ：1.5〜2cm
        孵化時期：2027年5月
        親の表現：朱赤・ラメ
        飼育環境：屋外飼育
        死着保証：到着後24時間以内にご連絡ください
        注意事項：水合わせをお願いします
        """)
    }

    @Test func 雌雄が未入力ならその行を省く() {
        let text = ListingTextBuilder.build(template: ListingTextBuilder.defaultTemplate, input: input(male: nil, female: nil), calendar: calendar)
        #expect(!text.contains("雌雄"))
        #expect(text.contains("匹数：30匹"))
    }

    @Test func 片方だけの雌雄は分からない側を疑問符にする() {
        #expect(ListingTextBuilder.sexText(male: 3, female: nil) == "雄3・雌?")
        #expect(ListingTextBuilder.sexText(male: nil, female: 5) == "雄?・雌5")
        #expect(ListingTextBuilder.sexText(male: 0, female: 0) == "雄0・雌0")
    }

    @Test func 未入力の項目は行ごと省く() {
        let text = ListingTextBuilder.build(
            template: ListingTextBuilder.defaultTemplate,
            input: input(line: "  ", count: nil, size: "", parentTags: [], placement: nil),
            calendar: calendar
        )
        for omitted in ["系統", "匹数", "サイズ", "親の表現", "飼育環境", "死着保証", "注意事項"] {
            #expect(!text.contains(omitted + "："))
        }
        #expect(text.contains("【楊貴妃】F1"))
        #expect(text.contains("孵化時期：2027年5月"))
    }

    @Test func 入手個体の世代と孵化日なし() {
        var acquired = input(generation: 0)
        acquired.hatchedAt = nil
        let text = ListingTextBuilder.build(template: ListingTextBuilder.defaultTemplate, input: acquired, calendar: calendar)
        #expect(text.hasPrefix("【楊貴妃】入手個体"))
        #expect(!text.contains("孵化時期"))
    }

    @Test func 室内飼育と親の表現の重複を除く() {
        let text = ListingTextBuilder.build(
            template: "{飼育環境}\n{親の表現}",
            input: input(parentTags: ["朱赤", "ラメ", "朱赤", " "], placement: .indoor),
            calendar: calendar
        )
        #expect(text == "室内飼育\n朱赤・ラメ")
    }

    @Test func 差し込み語の無い行はそのまま残す() {
        let text = ListingTextBuilder.build(template: "ご覧いただきありがとうございます。\n{品種}の{世代}です。\n\nよろしくお願いします。", input: input(), calendar: calendar)
        #expect(text == "ご覧いただきありがとうございます。\n楊貴妃のF1です。\n\nよろしくお願いします。")
    }

    @Test func 一行に複数の差し込み語があり一つでも空なら行ごと省く() {
        let text = ListingTextBuilder.build(template: "{品種} {系統}\n{世代}", input: input(line: ""), calendar: calendar)
        #expect(text == "F1")
    }

    @Test func 空の雛形は既定の雛形を使う() {
        let text = ListingTextBuilder.build(template: "  \n ", input: input(), calendar: calendar)
        #expect(text.hasPrefix("【楊貴妃】F1"))
    }

    @Test func 未知の波括弧はそのまま残す() {
        let text = ListingTextBuilder.build(template: "{未知}です\n{品種}", input: input(), calendar: calendar)
        #expect(text == "{未知}です\n楊貴妃")
    }

    @Test func 孵化時期は日本時間の年月() {
        // UTCでは4月30日15時、日本では5月1日0時
        let edge = Date(timeIntervalSince1970: 1_809_000_000)
        let parts = calendar.dateComponents([.year, .month], from: edge)
        #expect(ListingTextBuilder.hatchedText(edge, calendar: calendar) == "\(parts.year ?? 0)年\(parts.month ?? 0)月")
    }
}

struct FreeLimitKindTests {
    @Test func 上限の境界() {
        #expect(FreeLimits.allows(.tanks, currentCount: 5, isPro: false))
        #expect(!FreeLimits.allows(.tanks, currentCount: 6, isPro: false))
        #expect(FreeLimits.allows(.strains, currentCount: 1, isPro: false))
        #expect(!FreeLimits.allows(.strains, currentCount: 2, isPro: false))
        #expect(!FreeLimits.allows(.activeBreedingSets, currentCount: 2, isPro: false))
    }

    @Test func 写真は追加する枚数を足して数える() {
        #expect(FreeLimits.allows(.photosPerOwner, currentCount: 1, adding: 2, isPro: false))
        #expect(!FreeLimits.allows(.photosPerOwner, currentCount: 1, adding: 3, isPro: false))
        #expect(FreeLimits.allows(.photosPerOwner, currentCount: 0, adding: 3, isPro: false))
    }

    @Test func Proは上限なし() {
        #expect(FreeLimits.allows(.tanks, currentCount: 500, isPro: true))
        #expect(FreeLimits.allows(.photosPerOwner, currentCount: 500, adding: 50, isPro: true))
    }
}
