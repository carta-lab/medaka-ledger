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
                LedgerEmptyState(title: "容器がありません", message: "まず容器を登録しましょう",
                                 systemImage: "square.grid.2x2", actionTitle: "容器を登録する") {
                    model.isCreating = true
                }
            } else if sections.isEmpty {
                ContentUnavailableView.search(text: model.searchText)
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 24) {
                        LedgerIntro(title: "飼育容器", subtitle: "水辺の様子を、置き場所ごとに。",
                                    systemImage: "square.grid.2x2",
                                    summary: String(localized: "\(tanks.count.formatted())個の容器"))
                        ForEach(sections) { section in
                            VStack(alignment: .leading, spacing: 8) {
                                Text(verbatim: section.title)
                                    .font(.subheadline.weight(.medium))
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
        .themedBackground()
        .navigationTitle("容器")
        .navigationBarTitleDisplayMode(.inline)
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
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                LedgerSymbol(systemImage: tank.kind.symbolName)
                Spacer(minLength: 4)
                Image(systemName: tank.placement.symbolName)
                    .font(.caption)
                    .foregroundStyle(Theme.muted)
                    .accessibilityLabel(Text(verbatim: tank.placement.label))
            }
            Text(verbatim: tank.name)
                .font(.title3.weight(.medium))
                .fixedSize(horizontal: false, vertical: true)
            if cohorts.isEmpty {
                Text("空き").font(.subheadline).foregroundStyle(Theme.muted)
            } else {
                ForEach(cohorts.prefix(2)) { cohort in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(verbatim: cohort.strainName).font(.subheadline)
                        Text(verbatim: "\(cohort.generationLabel) · \(cohort.countText)")
                            .font(.caption).foregroundStyle(Theme.muted)
                    }
                }
                if cohorts.count > 2 {
                    Text("ほか\(String(cohorts.count - 2))群")
                        .font(.caption).foregroundStyle(Theme.muted)
                }
            }
            Spacer(minLength: 0)
            Rectangle().fill(Theme.rule).frame(height: 1)
            Label {
                Text(verbatim: water.text)
            } icon: {
                Image(systemName: water.isOverdue ? "exclamationmark.circle" : "drop")
            }
            .font(.caption)
            .foregroundStyle(water.isOverdue ? Theme.warning : Theme.muted)
        }
        .frame(maxWidth: .infinity, minHeight: 180, alignment: .topLeading)
        .cardBackground()
        .contentShape(.rect)
        .accessibilityElement(children: .combine)
    }
}
