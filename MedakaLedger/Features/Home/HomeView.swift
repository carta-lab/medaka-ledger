import SwiftData
import SwiftUI

// ホーム（SCREENS.md 2）。今日やることと、注意が要る状態を一画面で見せる。
// 出品中は第4週。増減のクイック操作は後の週。

struct HomeView: View {
    @Environment(AppSettings.self) var settings
    @Environment(Router.self) var router
    @Query(filter: Tank.unarchivedPredicate, sort: Tank.listSort) var tanks: [Tank]
    @Query(CohortEvent.recentDescriptor) var recentEvents: [CohortEvent]
    @Query(EggBatch.recentDescriptor) var recentBatches: [EggBatch]
    @Query(MaintenanceLog.recentDescriptor) var recentLogs: [MaintenanceLog]
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
                recentSection
            }
            .padding(.horizontal, Theme.screenPadding)
            .padding(.bottom, 24)
        }
        .navigationTitle("ホーム")
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
        #if DEBUG
        .sheet(isPresented: $model.isShowingDebugMenu) {
            DebugMenuView()
        }
        #endif
    }

    private func header(isBreedingSeason: Bool) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(verbatim: Date.now.formatted(.dateTime.month().day().weekday()))
                .font(.title2.bold())
            Label(isBreedingSeason ? LocalizedStringKey("産卵期") : LocalizedStringKey("産卵期外"), systemImage: isBreedingSeason ? "sun.max" : "snowflake")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(.top, 8)
    }

    private var gettingStarted: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("まず容器を登録しましょう")
                .font(.headline)
            Text("容器と系統を登録すると、群の記録をつけられます。")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Button("容器を登録する") {
                router.selectedTab = .tanks
            }
            .buttonStyle(LargeButtonStyle())
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

            Text("越冬中の群")
                .font(.headline)
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
            Text("クイック操作")
                .font(.headline)
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
                Button {
                    model.activeSheet = .eggBatch
                } label: {
                    Label("採卵", systemImage: "circle.grid.3x3")
                }
                .buttonStyle(LargeButtonStyle(prominent: false))
                .accessibilityIdentifier("quickEggBatch")
                Button {
                    model.activeSheet = .waterChange
                } label: {
                    Label("水換え", systemImage: "drop")
                }
                .buttonStyle(LargeButtonStyle(prominent: false))
                .accessibilityIdentifier("quickWaterChange")
                Button {
                    model.activeSheet = .photo
                } label: {
                    Label("写真", systemImage: "camera")
                }
                .buttonStyle(LargeButtonStyle(prominent: false))
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
        .buttonStyle(LargeButtonStyle(prominent: false))
        .disabled(true)
    }
}
