import SwiftData
import SwiftUI

@main
struct MedakaLedgerApp: App {
    @State private var settings = AppSettings()
    @State private var router = Router()
    private let containerResult: Result<ModelContainer, any Error>

    init() {
        let launch = LaunchOptions.current
        let result = Result { try ModelStore.makeContainer(inMemory: launch.usesInMemoryStore) }
        if launch.seedsSampleData, case let .success(container) = result {
            // UIテストのスクリーンショット用。画面より先に同期で入れる。
            try? SampleDataSeeder.seed(into: container.mainContext)
        }
        containerResult = result
    }

    var body: some Scene {
        WindowGroup {
            switch containerResult {
            case let .success(container):
                RootView()
                    .modelContainer(container)
                    .environment(settings)
                    .environment(router)
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

    static var current: LaunchOptions {
        let arguments = ProcessInfo.processInfo.arguments
        let isUITest = arguments.contains("-uiTestSampleData")
        return LaunchOptions(usesInMemoryStore: isUITest, seedsSampleData: isUITest)
    }
}

struct RootView: View {
    @Environment(Router.self) private var router

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
