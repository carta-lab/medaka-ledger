import SwiftData
import SwiftUI

struct ArchivedTanksView: View {
    @Query(filter: Tank.archivedPredicate, sort: Tank.listSort) private var tanks: [Tank]

    var body: some View {
        Group {
            if tanks.isEmpty {
                ContentUnavailableView("アーカイブ済みの容器はありません", systemImage: "archivebox")
            } else {
                List(tanks) { tank in
                    NavigationLink(value: Route.tank(tank)) {
                        Label(tank.name, systemImage: tank.kind.symbolName)
                    }
                }
            }
        }
        .navigationTitle("アーカイブ済みの容器")
    }
}
