import SwiftData
import SwiftUI

// 系統一覧（SCREENS.md 4.1）。並びは手動だけ（DECISIONS.md D）。代表写真は第3週。

struct StrainListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(filter: Strain.unarchivedPredicate, sort: Strain.listSort) private var strains: [Strain]
    @State private var model = StrainListModel()

    var body: some View {
        Group {
            if strains.isEmpty {
                ContentUnavailableView {
                    Label("系統がありません", systemImage: "list.bullet.rectangle")
                } description: {
                    Text("まず系統を登録しましょう")
                } actions: {
                    Button("系統を登録する") { model.isCreating = true }
                        .buttonStyle(LargeButtonStyle())
                }
            } else {
                List {
                    ForEach(strains) { strain in
                        NavigationLink(value: Route.strain(strain)) {
                            StrainRow(strain: strain)
                        }
                        .accessibilityIdentifier("strainRow.\(strain.breedName)")
                    }
                    .onMove { source, destination in
                        model.move(strains, from: source, to: destination, in: modelContext)
                    }
                }
            }
        }
        .themedBackground()
        .navigationTitle("系統")
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                if strains.count > 1 {
                    EditButton()
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    NavigationLink(value: Route.archivedStrains) {
                        Label("アーカイブ済みを表示", systemImage: "archivebox")
                    }
                } label: {
                    Label("メニュー", systemImage: "ellipsis.circle")
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    model.isCreating = true
                } label: {
                    Label("系統を登録", systemImage: "plus")
                }
            }
        }
        .sheet(isPresented: $model.isCreating) {
            StrainEditView(strain: nil)
        }
        .errorAlert($model.error)
    }
}

struct StrainRow: View {
    let strain: Strain

    var body: some View {
        let tally = Aggregations.tally(counts: strain.activeCohorts.map(\.count))
        HStack(spacing: 12) {
            if let photo = strain.coverPhoto {
                PhotoThumbnail(photo: photo, size: 48)
            } else {
                MedakaIcon(look: strain.look, size: 48)
            }
            rowText(strain: strain, tally: tally)
        }
        .padding(.vertical, 2)
    }

    private func rowText(strain: Strain, tally: CohortTally) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(verbatim: strain.displayName)
                .font(.headline)
            if !strain.traitTags.isEmpty {
                Text(verbatim: strain.traitTags.prefix(5).joined(separator: "・"))
                    .font(.subheadline)
                    .foregroundStyle(Theme.accent)
                    .lineLimit(1)
            }
            Text(verbatim: StrainText.tally(tally))
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 2)
    }
}

enum StrainText {
    static func tally(_ tally: CohortTally) -> String {
        guard tally.cohortCount > 0 else { return String(localized: "飼育中の群はありません") }
        let cohorts = tally.cohortCount.formatted()
        let fish = tally.fishCount.formatted()
        if tally.hasUncounted {
            return String(localized: "飼育中の群 \(cohorts)・\(fish)匹＋未計数")
        }
        return String(localized: "飼育中の群 \(cohorts)・\(fish)匹")
    }
}
