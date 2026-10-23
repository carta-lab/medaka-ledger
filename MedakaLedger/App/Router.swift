import SwiftUI

enum AppTab: Hashable {
    case home, tanks, strains, breeding, sales
}

@MainActor
@Observable
final class Router {
    var selectedTab: AppTab = .home
    /// バックアップを読み込んだあとに増やす。全ての画面を作り直し、消えたデータを開いたままの画面を残さない。
    var dataEpoch = 0
    /// 初回の案内を出す。起動時に、案内が済んでいなければ真にする。
    var showsOnboarding = false
}

/// 画面の遷移先。各タブの NavigationStack で routeDestinations() を付けて使う。
enum Route: Hashable {
    case tank(Tank)
    case tankLogs(Tank)
    case strain(Strain)
    case cohort(Cohort)
    case lineage(Cohort)
    case breedingSet(BreedingSet)
    case archivedTanks
    case archivedStrains
}

extension View {
    func routeDestinations() -> some View {
        navigationDestination(for: Route.self) { route in
            RouteDestination(route: route)
        }
    }
}

private struct RouteDestination: View {
    let route: Route

    var body: some View {
        switch route {
        case let .tank(tank): TankDetailView(tank: tank)
        case let .tankLogs(tank): TankLogsView(tank: tank)
        case let .strain(strain): StrainDetailView(strain: strain)
        case let .cohort(cohort): CohortDetailView(cohort: cohort)
        case let .lineage(cohort): LineageView(cohort: cohort)
        case let .breedingSet(set): BreedingSetDetailView(breedingSet: set)
        case .archivedTanks: ArchivedTanksView()
        case .archivedStrains: ArchivedStrainsView()
        }
    }
}
