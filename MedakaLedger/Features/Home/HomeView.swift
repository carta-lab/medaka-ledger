import SwiftData
import SwiftUI

// ホーム（SCREENS.md 2）。今日やることと、注意が要る状態を一画面で見せる。
// 増減のクイック操作は後の週。

struct HomeView: View {
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
            VStack(alignment: .leading, spacing: 24) {
                header(isBreedingSeason: isBreedingSeason)
                if tanks.isEmpty {
                    gettingStarted
                }
                if isBreedingSeason {
                    quickActions
                    hatchDueSection(model.hatchDue(from: entries))
                    incubatingSection(entries)
                } else {
                    wintering
                    quickActions
                }
                overdueSection
                listedSection
                recentSection
            }
            .padding(.horizontal, Theme.screenPadding)
            .padding(.bottom, 24)
        }
        .themedBackground()
        .navigationTitle("ホーム")
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

    /// 産卵期外は見出しの直後に水温の記録と越冬中の群を出す（DECISIONS.md E）。
    private var wintering: some View {
        let cohorts = model.winteringCohorts(from: activeCohorts)
        return VStack(alignment: .leading, spacing: 12) {
            Button {
                model.activeSheet = .temperature
            } label: {
                Label("水温の記録", systemImage: "thermometer.medium")
            }
            .buttonStyle(LargeButtonStyle(prominent: false))
            .accessibilityIdentifier("temperatureButton")

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
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
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
                disabledQuickAction("増減", systemImage: "plusminus")
            }
        }
    }

    private func disabledQuickAction(_ title: LocalizedStringKey, systemImage: String) -> some View {
        Button {
        } label: {
            Label(title, systemImage: systemImage)
        }
        .buttonStyle(InkActionStyle())
        .disabled(true)
    }
}
