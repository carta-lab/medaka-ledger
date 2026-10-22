import SwiftData
import SwiftUI

// 容器の並べ替え（DECISIONS.md D）。リスト表示でセクション内だけ並べ替える。
// セクションをまたぐ移動は、容器の編集で置き場所を変える。

struct TankReorderView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query(filter: Tank.unarchivedPredicate, sort: Tank.listSort) private var tanks: [Tank]
    @State private var error: UserFacingError? = nil

    var body: some View {
        let sections = Aggregations.sectionsByLocation(tanks, location: { $0.location }, unsetTitle: String(localized: "場所未設定"))
        NavigationStack {
            List {
                ForEach(Array(sections.enumerated()), id: \.element.id) { index, section in
                    Section {
                        ForEach(section.items) { tank in
                            Label(tank.name, systemImage: tank.kind.symbolName)
                        }
                        .onMove { source, destination in
                            move(in: sections, sectionIndex: index, from: source, to: destination)
                        }
                    } header: {
                        Text(verbatim: section.title)
                    }
                }
            }
            .environment(\.editMode, .constant(.active))
            .navigationTitle("並べ替え")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完了") { dismiss() }
                }
            }
            .safeAreaInset(edge: .bottom) {
                Text("置き場所をまたいで動かすときは、容器の編集で置き場所を変えてください。")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .padding(Theme.screenPadding)
                    .frame(maxWidth: .infinity)
                    .background(.bar)
            }
            .errorAlert($error)
        }
    }

    private func move(in sections: [LocationSection<Tank>], sectionIndex: Int, from source: IndexSet, to destination: Int) {
        let order = Aggregations.reorder(
            sections: sections.map { $0.items.map(\.id) },
            sectionIndex: sectionIndex,
            from: source,
            to: destination
        )
        let tanksByID = Dictionary(uniqueKeysWithValues: tanks.map { ($0.id, $0) })
        for (index, id) in order.enumerated() {
            tanksByID[id]?.sortOrder = index
        }
        do {
            try modelContext.save()
        } catch {
            self.error = UserFacingError(error)
        }
    }
}
