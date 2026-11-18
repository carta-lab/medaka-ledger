import SwiftData
import SwiftUI

struct ArchivedStrainsView: View {
    @Query(filter: Strain.archivedPredicate, sort: Strain.listSort) private var strains: [Strain]

    var body: some View {
        Group {
            if strains.isEmpty {
                ContentUnavailableView("アーカイブ済みの系統はありません", systemImage: "archivebox")
            } else {
                List(strains) { strain in
                    Group {
                        NavigationLink(value: Route.strain(strain)) {
                            StrainRow(strain: strain)
                        }
                    }
                    .ledgerRow()
                }
            }
        }
        .themedBackground()
        .navigationTitle("アーカイブ済みの系統")
    }
}

