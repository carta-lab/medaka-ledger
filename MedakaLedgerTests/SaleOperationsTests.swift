import Foundation
import SwiftData
import Testing
@testable import MedakaLedger

@MainActor
struct SaleOperationsTests {
    private let container: ModelContainer
    private let context: ModelContext
    private let day = Date(timeIntervalSince1970: 1_800_000_000)

    init() throws {
        container = try ModelStore.makeContainer(inMemory: true)
        context = container.mainContext
    }

    private func makeCohort(count: Int? = 30, generation: Int = 1) -> Cohort {
        let tank = Tank(name: "A-1", kind: .nvBox)
        let strain = Strain(breedName: "楊貴妃", lineName: "〇〇めだか")
        context.insert(tank)
        context.insert(strain)
        return CohortOperations.createCohort(strain: strain, tank: tank, count: count, stage: .adult, generation: generation, acquiredAt: day, date: day, in: context)
    }

    private func input(cohort: Cohort?, unit: SaleUnit = .fish, quantity: Int = 1, unitPrice: Int = 1000, bundle: Int? = nil) -> SaleOperations.Input {
        .init(
            date: day, cohort: cohort, unit: unit, quantity: quantity, unitPrice: unitPrice,
            totalPrice: quantity * unitPrice, status: .sold, bundleFishCount: bundle
        )
    }

    @Test func 群を指定して減らすと匹数と出来事が残る() throws {
        let cohort = makeCohort(count: 30)
        let sale = try SaleOperations.record(input(cohort: cohort, unit: .pair, quantity: 3), reducesCohort: true, in: context)
        #expect(cohort.count == 24)
        #expect(cohort.timeline.first?.countDelta == -6)
        #expect(sale.cohort?.id == cohort.id)
        #expect(sale.breedNameSnapshot == "楊貴妃")
        #expect(sale.lineNameSnapshot == "〇〇めだか")
        #expect(sale.generation == 1)
        #expect(sale.strain?.breedName == "楊貴妃")
    }

    @Test func 減らさない選択では匹数も出来事も変わらない() throws {
        let cohort = makeCohort(count: 30)
        let eventCount = cohort.events?.count
        try SaleOperations.record(input(cohort: cohort, quantity: 5), reducesCohort: false, in: context)
        #expect(cohort.count == 30)
        #expect(cohort.events?.count == eventCount)
    }

    @Test func 卵は匹数を減らさない() throws {
        let cohort = makeCohort(count: 30)
        try SaleOperations.record(input(cohort: cohort, unit: .eggs, quantity: 10), reducesCohort: true, in: context)
        #expect(cohort.count == 30)
    }

    @Test func 稚魚まとめは入力した匹数を減らす() throws {
        let cohort = makeCohort(count: 100)
        try SaleOperations.record(input(cohort: cohort, unit: .fryBundle, quantity: 1, bundle: 25), reducesCohort: true, in: context)
        #expect(cohort.count == 75)
    }

    @Test func 匹数を超える販売は何も作らずに止める() throws {
        let cohort = makeCohort(count: 3)
        #expect(throws: SaleOperations.OperationError.cohort(.ledger(.exceedsCount(current: 3)))) {
            try SaleOperations.record(input(cohort: cohort, quantity: 4), reducesCohort: true, in: context)
        }
        #expect(cohort.count == 3)
        #expect(try context.fetch(FetchDescriptor<Sale>()).isEmpty)
    }

    @Test func 未計数の群は匹数が変わらず記録だけ残る() throws {
        let cohort = makeCohort(count: nil)
        try SaleOperations.record(input(cohort: cohort, quantity: 2), reducesCohort: true, in: context)
        #expect(cohort.count == nil)
        #expect(try context.fetch(FetchDescriptor<Sale>()).count == 1)
    }

    @Test func 数量と金額の検証() {
        let cohort = makeCohort()
        #expect(throws: SaleOperations.OperationError.invalidQuantity) {
            try SaleOperations.record(input(cohort: cohort, quantity: 0), reducesCohort: false, in: context)
        }
        var negative = input(cohort: cohort)
        negative.fee = -1
        #expect(throws: SaleOperations.OperationError.negativeAmount) {
            try SaleOperations.record(negative, reducesCohort: false, in: context)
        }
    }

    @Test func 群を選ばない販売は系統だけを写す() throws {
        let strain = Strain(breedName: "幹之", lineName: "")
        context.insert(strain)
        var plain = input(cohort: nil)
        plain.strain = strain
        let sale = try SaleOperations.record(plain, reducesCohort: true, in: context)
        #expect(sale.breedNameSnapshot == "幹之")
        #expect(sale.generation == 0)
        #expect(sale.cohort == nil)
    }

    @Test func 発送済にすると発送日が入る() throws {
        let sale = try SaleOperations.record(input(cohort: nil), reducesCohort: false, in: context)
        #expect(sale.shippedAt == nil)
        SaleOperations.setStatus(sale, to: .shipped, today: day)
        #expect(sale.status == .shipped)
        #expect(sale.shippedAt == day)
    }

    @Test func 編集しても群の匹数は変わらない() throws {
        let cohort = makeCohort(count: 30)
        let sale = try SaleOperations.record(input(cohort: cohort, quantity: 2), reducesCohort: true, in: context)
        var edited = input(cohort: cohort, quantity: 5)
        edited.note = "  メモ  "
        try SaleOperations.update(sale, with: edited)
        #expect(cohort.count == 28)
        #expect(sale.quantity == 5)
        #expect(sale.note == "メモ")
    }

    @Test func サンプルの群への販売はサンプル() throws {
        let cohort = makeCohort()
        cohort.isSample = true
        let sale = try SaleOperations.record(input(cohort: cohort), reducesCohort: false, in: context)
        #expect(sale.isSample)
    }
}
