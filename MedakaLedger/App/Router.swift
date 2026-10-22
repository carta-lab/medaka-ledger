import SwiftUI

enum AppTab: Hashable {
    case home, tanks, strains, breeding, sales
}

@MainActor
@Observable
final class Router {
    var selectedTab: AppTab = .home
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
