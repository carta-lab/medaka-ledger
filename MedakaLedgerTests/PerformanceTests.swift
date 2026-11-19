import Foundation
import SwiftData
import Testing
@testable import MedakaLedger

// 性能の目安（ARCHITECTURE.md 9章）：容器100、群300、採卵500、販売1,000、写真2,000で、一覧の表示が1秒以内。
// 画面の描画は測れないので、一覧が使う取得と集計の時間を測る。時間はCIのログに「性能:」で出す。

@MainActor
struct PerformanceTests {
    private let container: ModelContainer
    private let context: ModelContext
    private let settings = AppSettings(defaults: UserDefaults(suiteName: "performance-\(UUID().uuidString)") ?? .standard)
    private let now = Date(timeIntervalSinceReferenceDate: 800_000_000)

    init() throws {
        container = try ModelStore.makeContainer(inMemory: true)
        context = container.mainContext
        try seed()
    }

    /// 上限に近い大きさのデータ。直接作って速く入れる。
    private func seed() throws {
        func daysAgo(_ days: Int) -> Date { now.addingTimeInterval(-Double(days) * 86_400) }
        var tanks: [Tank] = []
        for index in 0..<100 {
            let tank = Tank(
                name: "T-\(index)", kind: .nvBox, placement: index % 3 == 0 ? .indoor : .outdoor,
                location: "棚\(index % 10)", sortOrder: index
            )
            context.insert(tank)
            tanks.append(tank)
            for log in 0..<5 {
                let entry = MaintenanceLog()
                entry.date = daysAgo(log * 9 + index % 7)
                entry.kind = .waterChange
                context.insert(entry)
                entry.tank = tank
            }
        }
        var strains: [Strain] = []
        for index in 0..<30 {
            let strain = Strain(breedName: "品種\(index)", lineName: "系統\(index)", traitTags: ["ラメ"], sortOrder: index)
            context.insert(strain)
            strains.append(strain)
        }
        var cohorts: [Cohort] = []
        for index in 0..<300 {
            let cohort = Cohort(label: "群\(index)", generation: index % 4, count: 20 + index % 50, stage: .adult)
            context.insert(cohort)
            cohort.strain = strains[index % strains.count]
            cohort.tank = tanks[index % tanks.count]
            cohorts.append(cohort)
            for step in 0..<3 {
                let event = CohortEvent()
                event.date = daysAgo(step * 20)
                event.kind = .note
                context.insert(event)
                event.cohort = cohort
            }
        }
        var sets: [BreedingSet] = []
        for index in 0..<50 {
            let set = BreedingSet()
            set.startedAt = daysAgo(100)
            context.insert(set)
            set.sireCohort = cohorts[index]
            set.damCohort = cohorts[index]
            set.tank = tanks[index]
            sets.append(set)
        }
        for index in 0..<500 {
            let batch = EggBatch()
            batch.collectedAt = daysAgo(index % 20)
            batch.eggCount = 30
            batch.status = index % 5 == 0 ? .incubating : .hatched
            context.insert(batch)
            batch.breedingSet = sets[index % sets.count]
        }
        for index in 0..<1000 {
            let sale = Sale()
            sale.date = daysAgo(index % 400)
            sale.quantity = 1 + index % 3
            sale.unitPrice = 1000
            sale.totalPrice = sale.quantity * 1000
            sale.status = index % 10 == 0 ? .listed : .sold
            sale.breedNameSnapshot = "品種\(index % 30)"
            context.insert(sale)
            sale.cohort = cohorts[index % cohorts.count]
            sale.strain = strains[index % strains.count]
        }
        for index in 0..<2000 {
            let photo = Photo()
            photo.capturedAt = daysAgo(index % 300)
            photo.jpegData = Data(repeating: 1, count: 2_000)
            photo.thumbnailData = Data(repeating: 2, count: 500)
            context.insert(photo)
            photo.cohort = cohorts[index % cohorts.count]
        }
        try context.save()
    }

    /// 共有のCIランナーは負荷でぶれるため、3回測って最も速い値で判定する（毎回遅いなら本当に遅い）。
    private func measure(_ name: String, limit: Double = 1.0, _ work: () throws -> Void) rethrows {
        let clock = ContinuousClock()
        var best = Double.infinity
        for _ in 0..<3 {
            let elapsed = try clock.measure(work)
            let seconds = Double(elapsed.components.seconds) + Double(elapsed.components.attoseconds) / 1e18
            best = min(best, seconds)
        }
        print("性能: \(name) \(String(format: "%.3f", best))秒（3回のうち最速）")
        #expect(best < limit, "\(name)が\(limit)秒を超えました（\(best)秒）")
    }

    @Test func 容器一覧() throws {
        measure("容器一覧") {
            let tanks = (try? context.fetch(FetchDescriptor<Tank>(predicate: Tank.unarchivedPredicate, sortBy: Tank.listSort))) ?? []
            let sections = TankListModel().sections(for: tanks)
            for tank in sections.flatMap(\.items) {
                _ = Aggregations.tally(counts: tank.activeCohorts.map(\.count))
                _ = tank.lastWaterChange
                _ = tank.coverPhoto
            }
            #expect(tanks.count == 100)
        }
    }

    @Test func 系統一覧() throws {
        measure("系統一覧") {
            let strains = (try? context.fetch(FetchDescriptor<Strain>(predicate: Strain.unarchivedPredicate, sortBy: Strain.listSort))) ?? []
            for strain in strains {
                _ = Aggregations.tally(counts: strain.activeCohorts.map(\.count))
                _ = strain.coverPhoto
            }
            #expect(strains.count == 30)
        }
    }

    @Test func 系統詳細の世代ごとの群() throws {
        let strain = try #require(try context.fetch(FetchDescriptor<Strain>(sortBy: Strain.listSort)).first)
        measure("系統詳細") {
            let groups = Aggregations.groupedByGeneration(strain.cohorts ?? [], generation: { $0.generation })
            for group in groups {
                for cohort in group.items {
                    _ = cohort.selectionTotals
                    _ = cohort.coverPhoto
                }
            }
            #expect(!groups.isEmpty)
        }
    }

    @Test func 繁殖() throws {
        measure("繁殖") {
            let incubating = (try? context.fetch(FetchDescriptor<EggBatch>(predicate: EggBatch.incubatingPredicate, sortBy: [SortDescriptor(\EggBatch.collectedAt)]))) ?? []
            let entries = BatchPredictionInfo.sortedByRemaining(incubating, settings: settings)
            #expect(entries.count == 100)
        }
    }

    @Test func 販売台帳() throws {
        measure("販売台帳") {
            let sales = (try? context.fetch(FetchDescriptor<Sale>(sortBy: [SortDescriptor(\Sale.date, order: .reverse)]))) ?? []
            let model = SalesModel()
            model.period = .all
            let ledger = model.ledger(for: sales, now: now)
            _ = SalesAggregations.yearSummaries(ledger.records, calendar: .current)
            #expect(ledger.records.count == 1000)
        }
    }

    @Test func ホーム() throws {
        measure("ホーム") {
            let model = HomeModel()
            let tanks = (try? context.fetch(FetchDescriptor<Tank>(predicate: Tank.unarchivedPredicate, sortBy: Tank.listSort))) ?? []
            _ = model.overdueTanks(tanks, settings: settings, now: now)
            let active = (try? context.fetch(FetchDescriptor<Cohort>(predicate: Cohort.activePredicate, sortBy: [SortDescriptor(\Cohort.createdAt)]))) ?? []
            _ = model.winteringCohorts(from: active)
            let events = (try? context.fetch(CohortEvent.recentDescriptor)) ?? []
            let batches = (try? context.fetch(EggBatch.recentDescriptor)) ?? []
            let logs = (try? context.fetch(MaintenanceLog.recentDescriptor)) ?? []
            let sales = (try? context.fetch(Sale.recentDescriptor)) ?? []
            _ = model.recentRecords(events: events, batches: batches, logs: logs, sales: sales)
            #expect(active.count == 300)
        }
    }

    @Test func バックアップの書き出しは写真2000枚でも終わる() throws {
        let directory = FileManager.default.temporaryDirectory.appending(path: "perf-backup-\(UUID().uuidString)", directoryHint: .isDirectory)
        defer { try? FileManager.default.removeItem(at: directory) }
        measure("バックアップの書き出し", limit: 20) {
            try? BackupExporter.write(from: context, includesPhotos: true, appVersion: "1.0", to: directory, progress: { _ in })
        }
        let photos = try FileManager.default.contentsOfDirectory(atPath: directory.appending(path: "photos").path)
        #expect(photos.count == 2000)
    }
}
