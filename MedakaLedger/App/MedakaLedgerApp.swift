import SwiftData
import SwiftUI

@main
struct MedakaLedgerApp: App {
    @State private var settings: AppSettings
    @State private var router: Router
    @State private var scheduler: NotificationScheduler
    @State private var pro: ProStore
    private let containerResult: Result<ModelContainer, any Error>

    init() {
        let settings = AppSettings()
        _settings = State(initialValue: settings)
        let router = Router()
        router.showsOnboarding = !settings.hasCompletedOnboarding
        _router = State(initialValue: router)
        _scheduler = State(initialValue: NotificationScheduler(settings: settings))
        let launch = LaunchOptions.current
        _pro = State(initialValue: ProStore(backend: Self.makeBackend(launch)))
        let result = Result { try ModelStore.makeContainer(inMemory: launch.usesInMemoryStore) }
        if launch.seedsSampleData, case let .success(container) = result {
            // UIテストのスクリーンショット用。画面より先に同期で入れる。
            try? SampleDataSeeder.seed(into: container.mainContext)
        }
        containerResult = result
    }

    private static func makeBackend(_ launch: LaunchOptions) -> any ProBackend {
        #if DEBUG
        // UIテストは、StoreKitに触れずに、決まった結果を返す裏側を使う
        if launch.isUITest { return UITestProBackend(entitled: launch.grantsPro) }
        #endif
        return StoreKitBackend()
    }

    var body: some Scene {
        WindowGroup {
            switch containerResult {
            case let .success(container):
                RootView()
                    .modelContainer(container)
                    .environment(settings)
                    .environment(router)
                    .environment(scheduler)
                    .environment(pro)
            case let .failure(error):
                StoreErrorView(error: error)
            }
        }
    }
}

/// 起動引数。UIテストは -uiTestSampleData でサンプルを入れたメモリ上のストアを使う（ARCHITECTURE.md 8）。
struct LaunchOptions {
    var usesInMemoryStore: Bool
    var seedsSampleData: Bool
    var isUITest: Bool
    /// -uiTestPro：Proを持った状態で起動する（UIテストのスクリーンショット用）。
    var grantsPro: Bool

    static var current: LaunchOptions {
        let arguments = ProcessInfo.processInfo.arguments
        let seeds = arguments.contains("-uiTestSampleData")
        // -uiTestEmpty：サンプルなしの空のストア（初回の案内のスクリーンショット用）
        let isUITest = seeds || arguments.contains("-uiTestEmpty")
        return LaunchOptions(
            usesInMemoryStore: isUITest,
            seedsSampleData: seeds,
            isUITest: isUITest,
            grantsPro: arguments.contains("-uiTestPro")
        )
    }
}

#if DEBUG
/// UIテスト用の購入の裏側。価格を返し、購入はしない。
struct UITestProBackend: ProBackend {
    let entitled: Bool

    func loadProduct() async throws -> ProProduct {
        ProProduct(id: StoreKitBackend.productID, displayPrice: "¥1,200")
    }

    func hasEntitlement() async -> Bool { entitled }
    func purchase() async throws -> ProPurchaseResult { .cancelled }
    func restore() async throws {}
    func entitlementUpdates() -> AsyncStream<Bool> { AsyncStream { $0.finish() } }
}
#endif

struct RootView: View {
    /// 案内の容器の名前の初期値のために、今ある容器の名前を取る。
    private func existingTankNames() -> [String] {
        ((try? modelContext.fetch(FetchDescriptor<Tank>(sortBy: Tank.listSort))) ?? []).map(\.name)
    }

    @Environment(Router.self) private var router
    @Environment(NotificationScheduler.self) private var scheduler
    @Environment(ProStore.self) private var pro
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        @Bindable var router = router
        TabView(selection: $router.selectedTab) {
            Tab("ホーム", systemImage: "house", value: AppTab.home) {
                NavigationStack { HomeView().routeDestinations() }
            }
            Tab("容器", systemImage: "square.grid.2x2", value: AppTab.tanks) {
                NavigationStack { TankListView().routeDestinations() }
            }
            Tab("系統", systemImage: "list.bullet.rectangle", value: AppTab.strains) {
                NavigationStack { StrainListView().routeDestinations() }
            }
            Tab("繁殖", systemImage: "arrow.triangle.branch", value: AppTab.breeding) {
                NavigationStack { BreedingView().routeDestinations() }
            }
            Tab("販売", systemImage: "yensign.circle", value: AppTab.sales) {
                NavigationStack { SalesView().routeDestinations() }
            }
        }
        .id(router.dataEpoch)
        .fullScreenCover(isPresented: $router.showsOnboarding) {
            OnboardingView(existingTankNames: existingTankNames())
        }
        // 起動時とフォアグラウンドに戻ったとき、孵化予定の通知を計画し直す
        .task(id: scenePhase) {
            if scenePhase == .active {
                await scheduler.reschedule(in: modelContext)
                // Proの権利を確かめ直す。返金や別の端末での購入を拾う（PRD.md F13）
                await pro.start()
                await pro.refresh()
            }
        }
    }
}

/// ストアを開けなかったときの画面。強制終了せずに理由を出す（CLAUDE.md）。
struct StoreErrorView: View {
    let error: any Error

    var body: some View {
        ContentUnavailableView {
            Label("データを開けませんでした", systemImage: "exclamationmark.triangle")
        } description: {
            Text(verbatim: error.localizedDescription)
        }
    }
}
