import Foundation
import Testing
@testable import MedakaLedger

struct TankNamingTests {
    @Test(arguments: [
        ("A-1", "A-2"),
        ("A-9", "A-10"),
        ("A-09", "A-10"),
        ("B-007", "B-008"),
        ("棚3", "棚4"),
        ("12", "13"),
        ("099", "100"),
        ("トロ舟", "トロ舟-2"),
        ("  A-1  ", "A-2"),
        ("", ""),
    ])
    func nextName(input: String, expected: String) {
        #expect(TankNaming.nextName(after: input) == expected)
    }
}

struct SeasonTests {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Tokyo") ?? .current
        return calendar
    }

    private func date(_ year: Int, _ month: Int, _ day: Int, hour: Int = 12) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour)) ?? .distantPast
    }

    @Test func breedingSeasonFollowsMonths() {
        let months = [4, 5, 6, 7, 8, 9]
        #expect(Season.isBreedingSeason(on: date(2027, 4, 1), months: months, calendar: calendar))
        #expect(Season.isBreedingSeason(on: date(2027, 9, 30), months: months, calendar: calendar))
        #expect(!Season.isBreedingSeason(on: date(2027, 3, 31), months: months, calendar: calendar))
        #expect(!Season.isBreedingSeason(on: date(2026, 11, 2), months: months, calendar: calendar))
    }

    @Test func waterChangeWarningDaysSwitchesBySeason() {
        let months = [4, 5, 6, 7, 8, 9]
        #expect(Season.waterChangeWarningDays(on: date(2027, 5, 1), months: months, inSeason: 14, offSeason: 45, calendar: calendar) == 14)
        #expect(Season.waterChangeWarningDays(on: date(2027, 1, 1), months: months, inSeason: 14, offSeason: 45, calendar: calendar) == 45)
    }

    @Test func dayCountStartsAtZeroOnTheSameDay() {
        #expect(DayCount.days(from: date(2027, 5, 1, hour: 23), to: date(2027, 5, 1, hour: 1), calendar: calendar) == 0)
        #expect(DayCount.days(from: date(2027, 5, 1, hour: 23), to: date(2027, 5, 2, hour: 1), calendar: calendar) == 1)
        #expect(DayCount.days(from: date(2026, 12, 31), to: date(2027, 1, 10), calendar: calendar) == 10)
    }
}

struct AggregationsTests {
    private struct Item: Equatable {
        var name: String
        var location: String
    }

    @Test func sectionsFollowFirstAppearanceAndPutUnsetLast() {
        let items = [
            Item(name: "A-1", location: "棚A"),
            Item(name: "X", location: " "),
            Item(name: "B-1", location: "棚B"),
            Item(name: "A-2", location: " 棚A "),
            Item(name: "Y", location: ""),
        ]
        let sections = Aggregations.sectionsByLocation(items, location: \.location, unsetTitle: "場所未設定")
        #expect(sections.map(\.title) == ["棚A", "棚B", "場所未設定"])
        #expect(sections[0].items.map(\.name) == ["A-1", "A-2"])
        #expect(sections[2].items.map(\.name) == ["X", "Y"])
        #expect(sections[2].isUnset)
    }

    @Test func distinctTrimsAndKeepsOrder() {
        #expect(Aggregations.distinct(["楊貴妃", " 幹之", "楊貴妃 ", "", "三色"]) == ["楊貴妃", "幹之", "三色"])
    }

    @Test func suggestionsExcludeExactMatch() {
        let names = ["楊貴妃", "楊貴妃ラメ", "幹之", "楊貴妃×幹之"]
        #expect(Aggregations.suggestions(for: "楊貴妃", from: names, limit: 5) == ["楊貴妃ラメ", "楊貴妃×幹之"])
        #expect(Aggregations.suggestions(for: "", from: names, limit: 5).isEmpty)
        #expect(Aggregations.suggestions(for: "幹", from: names, limit: 1) == ["幹之"])
    }

    @Test func tagCandidatesAddUsedTags() {
        let candidates = Aggregations.tagCandidates(defaults: ["ラメ", "体外光"], used: [["ラメ", "スモール"], ["鉄仮面"]])
        #expect(candidates == ["ラメ", "体外光", "スモール", "鉄仮面"])
    }

    @Test func matchesIgnoresCaseAndWidth() {
        #expect(Aggregations.matches(query: "a-1", in: ["Ａ-１"]))
        #expect(Aggregations.matches(query: "幹之", in: ["A-1", "幹之（光体型）"]))
        #expect(!Aggregations.matches(query: "三色", in: ["A-1", "楊貴妃"]))
        #expect(Aggregations.matches(query: "  ", in: []))
    }

    @Test func tallySkipsUncounted() {
        let tally = Aggregations.tally(counts: [10, nil, 5])
        #expect(tally == CohortTally(cohortCount: 3, fishCount: 15, hasUncounted: true))
        #expect(Aggregations.tally(counts: []) == CohortTally(cohortCount: 0, fishCount: 0, hasUncounted: false))
    }

    @Test func groupedByGenerationIsAscending() {
        let groups = Aggregations.groupedByGeneration([2, 0, 1, 0], generation: { $0 })
        #expect(groups.map(\.generation) == [0, 1, 2])
        #expect(groups[0].items == [0, 0])
    }

    @Test func mergeRecentSortsByDate() {
        let base = Date(timeIntervalSince1970: 0)
        let a = [base.addingTimeInterval(10), base.addingTimeInterval(1)]
        let b = [base.addingTimeInterval(5)]
        let merged = Aggregations.mergeRecent([a, b], date: { $0 }, limit: 2)
        #expect(merged == [base.addingTimeInterval(10), base.addingTimeInterval(5)])
    }

    @Test(arguments: [
        (IndexSet(integer: 0), 3, ["b", "c", "a", "d"]),
        (IndexSet(integer: 3), 0, ["d", "a", "b", "c"]),
        (IndexSet(integer: 1), 1, ["a", "b", "c", "d"]),
        (IndexSet(integer: 1), 2, ["a", "b", "c", "d"]),
        (IndexSet([0, 2]), 4, ["b", "d", "a", "c"]),
    ])
    func movedMatchesSwiftUIMove(source: IndexSet, destination: Int, expected: [String]) {
        #expect(Aggregations.moved(["a", "b", "c", "d"], from: source, to: destination) == expected)
    }

    @Test func reorderOnlyTouchesOneSection() {
        let order = Aggregations.reorder(sections: [["a", "b"], ["c", "d", "e"]], sectionIndex: 1, from: IndexSet(integer: 2), to: 0)
        #expect(order == ["a", "b", "e", "c", "d"])
    }
}
