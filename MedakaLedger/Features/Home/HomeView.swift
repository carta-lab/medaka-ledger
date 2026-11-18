import SwiftData
import SwiftUI

// ホーム（SCREENS.md 2）。今日やることと、注意が要る状態を一画面で見せる。
// v2 は静かな水景と、既存の記録への入口を一枚にまとめる。

struct HomeView: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(AppSettings.self) var settings
    @Environment(Router.self) var router
    @Query(filter: Tank.unarchivedPredicate, sort: Tank.listSort) var tanks: [Tank]
    @Query(CohortEvent.recentDescriptor) var recentEvents: [CohortEvent]
    @Query(EggBatch.recentDescriptor) var recentBatches: [EggBatch]
    @Query(MaintenanceLog.recentDescriptor) var recentLogs: [MaintenanceLog]
    @Query(Sale.recentDescriptor) var recentSales: [Sale]
    @Query(filter: Sale.listedPredicate, sort: \Sale.date, order: .reverse) var listedSales: [Sale]
    @Query(filter: Cohort.activePredicate, sort: \Cohort.createdAt) var activeCohorts: [Cohort]
    @Query(filter: EggBatch.incubatingPredicate, sort: \EggBatch.collectedAt) var incubating: [EggBatch]
    @State var model = HomeModel()

    var body: some View {
        let isBreedingSeason = settings.isBreedingSeason()
        let entries = BatchPredictionInfo.sortedByRemaining(incubating, settings: settings)
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                header(isBreedingSeason: isBreedingSeason)
                if tanks.isEmpty {
                    gettingStarted
                }
                if !isBreedingSeason { temperatureAction }
                quickActions
                if isBreedingSeason {
                    hatchDueSection(model.hatchDue(from: entries))
                    incubatingSection(entries)
                } else {
                    wintering
                }
                overdueSection
                listedSection
                recentSection
            }
            .padding(.horizontal, Theme.screenPadding)
            .padding(.bottom, 24)
        }
        .themedBackground()
        .navigationTitle("めだか台帳")
        // 日付の見出しを主役にするため、画面の名前は小さく出す
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    model.activeSheet = .settings
                } label: {
                    Label("設定", systemImage: "gearshape")
                }
                .accessibilityIdentifier("settingsButton")
            }
            #if DEBUG
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    model.isShowingDebugMenu = true
                } label: {
                    Label("デバッグ", systemImage: "hammer")
                }
                .accessibilityIdentifier("debugMenuButton")
            }
            #endif
        }
        .sheet(item: $model.activeSheet) { sheet in
            switch sheet {
            case .eggBatch: EggBatchSheet()
            case .waterChange: MaintenanceSheet(kind: .waterChange)
            case .temperature: MaintenanceSheet(kind: .temperature)
            case .photo: QuickPhotoSheet()
            case .settings: SettingsView()
            case .count: QuickCountSheet()
            }
        }
        .sheet(item: $model.hatchingBatch) { batch in
            HatchSheet(batch: batch)
        }
        .sheet(item: $model.editingSale) { sale in
            SaleSheet(sale: sale)
        }
        #if DEBUG
        .sheet(isPresented: $model.isShowingDebugMenu) {
            DebugMenuView()
        }
        #endif
    }

    private func header(isBreedingSeason: Bool) -> some View {
        VStack(spacing: 12) {
            HomeHero(isBreedingSeason: isBreedingSeason)
            HomeLedgerSummary(
                tankCount: tanks.count,
                tally: Aggregations.tally(counts: activeCohorts.map(\.count)),
                incubatingCount: incubating.count
            )
        }
        .padding(.top, 8)
    }

    private var gettingStarted: some View {
        VStack(alignment: .leading, spacing: 12) {
            MedakaIcon(look: MedakaLook(shape: .standard, palette: .orange, hasSparkle: false, hasLongFin: false), size: 56)
            Text("まず容器を登録しましょう")
                .font(Typeface.heading(19, relativeTo: .headline))
            Text("容器と系統を登録すると、群の記録をつけられます。")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Button("容器を登録する") {
                router.selectedTab = .tanks
            }
            .buttonStyle(LargeButtonStyle())
            Button("最初の案内をもう一度見る") {
                router.showsOnboarding = true
            }
            .frame(minHeight: Theme.minButtonHeight)
            .accessibilityIdentifier("resumeOnboardingButton")
        }
        .cardBackground()
    }

    private var temperatureAction: some View {
        Button {
            model.activeSheet = .temperature
        } label: {
            Label("水温の記録", systemImage: "thermometer.medium")
        }
        .buttonStyle(LargeButtonStyle(prominent: false))
        .accessibilityIdentifier("temperatureButton")
    }

    /// 産卵期外は水温の入口を上に出し、屋外の飼育中の群をまとめる。
    private var wintering: some View {
        let cohorts = model.winteringCohorts(from: activeCohorts)
        return VStack(alignment: .leading, spacing: 12) {
            SectionHeading("越冬中の群")
            if cohorts.isEmpty {
                Text("屋外の容器にいる群はありません")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(cohorts) { cohort in
                    NavigationLink(value: Route.cohort(cohort)) {
                        CohortSummaryRow(cohort: cohort, showsTank: true)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var quickActions: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeading("記録する")
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12),
                                     count: dynamicTypeSize.isAccessibilitySize ? 1 : 2), spacing: 12) {
                Button {
                    model.activeSheet = .eggBatch
                } label: {
                    Label("採卵", systemImage: "circle.grid.3x3")
                }
                .buttonStyle(InkActionStyle())
                .accessibilityIdentifier("quickEggBatch")
                Button {
                    model.activeSheet = .waterChange
                } label: {
                    Label("水換え", systemImage: "drop")
                }
                .buttonStyle(InkActionStyle())
                .accessibilityIdentifier("quickWaterChange")
                Button {
                    model.activeSheet = .photo
                } label: {
                    Label("写真", systemImage: "camera")
                }
                .buttonStyle(InkActionStyle())
                .accessibilityIdentifier("quickPhoto")
                Button {
                    model.activeSheet = .count
                } label: {
                    Label("増減", systemImage: "plusminus")
                }
                .buttonStyle(InkActionStyle())
                .accessibilityIdentifier("quickCount")
            }
        }
    }
}
