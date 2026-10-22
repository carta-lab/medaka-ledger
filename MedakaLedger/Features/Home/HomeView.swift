import SwiftData
import SwiftUI

// ホームの骨組み（ROADMAP.md 11/7、SCREENS.md 2）。
// 第1週は見出し、クイック操作の枠、水換え期限超えの枠（空）、最近の記録（群の出来事だけ）。

struct HomeView: View {
    @Environment(AppSettings.self) private var settings
    @Environment(Router.self) private var router
    @Query(filter: Tank.unarchivedPredicate, sort: Tank.listSort) private var tanks: [Tank]
    @Query(CohortEvent.recentDescriptor) private var recentEvents: [CohortEvent]
    @Query(filter: Cohort.activePredicate, sort: \Cohort.createdAt) private var activeCohorts: [Cohort]
    @State private var model = HomeModel()

    var body: some View {
        let isBreedingSeason = settings.isBreedingSeason()
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                header(isBreedingSeason: isBreedingSeason)
                if tanks.isEmpty {
                    gettingStarted
                }
                if !isBreedingSeason {
                    wintering
                }
                quickActions
                overdueTanks
                recentRecords
            }
            .padding(.horizontal, Theme.screenPadding)
            .padding(.bottom, 24)
        }
        .navigationTitle("ホーム")
        #if DEBUG
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    model.isShowingDebugMenu = true
                } label: {
                    Label("デバッグ", systemImage: "hammer")
                }
                .accessibilityIdentifier("debugMenuButton")
            }
        }
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
            } label: {
                Label("水温の記録", systemImage: "thermometer.medium")
            }
            .buttonStyle(LargeButtonStyle(prominent: false))
            .disabled(true)

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

    /// クイック操作の枠。各機能を作る週に押せるようにする（DECISIONS.md H）。
    private var quickActions: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("クイック操作")
                .font(.headline)
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
                quickActionButton("採卵", systemImage: "circle.grid.3x3")
                quickActionButton("水換え", systemImage: "drop")
                quickActionButton("写真", systemImage: "camera")
                quickActionButton("増減", systemImage: "plusminus")
            }
        }
    }

    private func quickActionButton(_ title: LocalizedStringKey, systemImage: String) -> some View {
        Button {
        } label: {
            Label(title, systemImage: systemImage)
        }
        .buttonStyle(LargeButtonStyle(prominent: false))
        .disabled(true)
    }

    private var overdueTanks: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("水換えの期限超え")
                .font(.headline)
            Text("期限を超えた容器はありません")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    private var recentRecords: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("最近の記録")
                .font(.headline)
            if recentEvents.isEmpty {
                Text("記録はまだありません")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(recentEvents) { event in
                    if let cohort = event.cohort {
                        NavigationLink(value: Route.cohort(cohort)) {
                            RecentEventRow(event: event, cohort: cohort)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }
}

private struct RecentEventRow: View {
    let event: CohortEvent
    let cohort: Cohort

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: event.kind.symbolName)
                .foregroundStyle(Theme.accent)
                .frame(width: 24)
            VStack(alignment: .leading, spacing: 2) {
                Text(verbatim: "\(cohort.strainName) \(cohort.generationLabel)")
                    .font(.subheadline.bold())
                Text(verbatim: CohortEventText.summary(event))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
            Text(verbatim: CohortText.shortDate(event.date))
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
        .contentShape(.rect)
    }
}
