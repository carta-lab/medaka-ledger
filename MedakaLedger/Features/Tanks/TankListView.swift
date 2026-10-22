import SwiftData
import SwiftUI

// 容器一覧（SCREENS.md 3.1）。置き場所ごとのセクションに2列のグリッドで並べる。
// 最終水換えからの日数は第2週で足す（DECISIONS.md B）。

struct TankListView: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Query(filter: Tank.unarchivedPredicate, sort: Tank.listSort) private var tanks: [Tank]
    @State private var model = TankListModel()

    var body: some View {
        let sections = model.sections(for: tanks)
        Group {
            if tanks.isEmpty {
                ContentUnavailableView {
                    Label("容器がありません", systemImage: "square.grid.2x2")
                } description: {
                    Text("まず容器を登録しましょう")
                } actions: {
                    Button("容器を登録する") { model.isCreating = true }
                        .buttonStyle(LargeButtonStyle())
                }
            } else if sections.isEmpty {
                ContentUnavailableView.search(text: model.searchText)
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 20) {
                        ForEach(sections) { section in
                            VStack(alignment: .leading, spacing: 8) {
                                Text(verbatim: section.title)
                                    .font(.headline)
                                    .foregroundStyle(section.isUnset ? .secondary : .primary)
                                LazyVGrid(columns: columns, spacing: 12) {
                                    ForEach(section.items) { tank in
                                        NavigationLink(value: Route.tank(tank)) {
                                            TankCard(tank: tank)
                                        }
                                        .buttonStyle(.plain)
                                        .accessibilityIdentifier("tankCard.\(tank.name)")
                                    }
                                }
                            }
                        }
                    }
                    .padding(.horizontal, Theme.screenPadding)
                    .padding(.vertical, 8)
                }
            }
        }
        .navigationTitle("容器")
        .searchable(text: $model.searchText, prompt: Text("容器名・系統名で探す"))
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button {
                        model.isReordering = true
                    } label: {
                        Label("並べ替え", systemImage: "arrow.up.arrow.down")
                    }
                    .disabled(tanks.count < 2)
                    NavigationLink(value: Route.archivedTanks) {
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
                    Label("容器を登録", systemImage: "plus")
                }
                .accessibilityIdentifier("addTankButton")
            }
        }
        .sheet(isPresented: $model.isCreating) {
            TankEditView(tank: nil)
        }
        .sheet(isPresented: $model.isReordering) {
            TankReorderView()
        }
    }

    /// 大きな文字サイズではグリッドを1列にする（DECISIONS.md D）。
    private var columns: [GridItem] {
        if dynamicTypeSize.isAccessibilitySize {
            [GridItem(.flexible())]
        } else {
            [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)]
        }
    }
}

struct TankCard: View {
    @Environment(AppSettings.self) private var settings
    let tank: Tank

    var body: some View {
        let cohorts = tank.activeCohorts
        let water = TankWaterStatus(tank: tank, settings: settings)
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: tank.kind.symbolName)
                    .foregroundStyle(Theme.accent)
                Text(verbatim: tank.name)
                    .font(.headline)
                    .lineLimit(1)
                Spacer(minLength: 0)
                Image(systemName: tank.placement.symbolName)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .accessibilityLabel(Text(verbatim: tank.placement.label))
            }
            if cohorts.isEmpty {
                Text("空き")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(cohorts.prefix(2)) { cohort in
                    Text(verbatim: "\(cohort.strainName) \(cohort.generationLabel) \(cohort.countText)")
                        .font(.subheadline)
                        .lineLimit(2)
                }
                if cohorts.count > 2 {
                    Text("ほか\(String(cohorts.count - 2))群")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer(minLength: 4)
            Label {
                Text(verbatim: water.text)
            } icon: {
                Image(systemName: "drop")
            }
            .font(.caption)
            .foregroundStyle(water.isOverdue ? Theme.warning : .secondary)
            .fontWeight(water.isOverdue ? .bold : .regular)
        }
        .frame(maxWidth: .infinity, minHeight: 88, alignment: .topLeading)
        .cardBackground()
        .contentShape(.rect)
    }
}
