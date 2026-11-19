import SwiftData
import SwiftUI

// 容器一覧（SCREENS.md 3.1）。置き場所ごとのセクションに2列のグリッドで並べる。
// 最終水換えからの日数は第2週で足す（DECISIONS.md B）。

struct TankListView: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Query(filter: Tank.unarchivedPredicate, sort: Tank.listSort) private var tanks: [Tank]
    @State private var model = TankListModel()
    @State private var collapsedSections: Set<String> = []

    var body: some View {
        let sections = model.sections(for: tanks)
        Group {
            if tanks.isEmpty {
                LedgerEmptyState(title: "容器がありません", message: "まず容器を登録しましょう",
                                 systemImage: "square.grid.2x2", actionTitle: "容器を登録する",
                                 actionIdentifier: "addFirstTankButton") {
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
                            let isCollapsed = collapsedSections.contains(section.id)
                            VStack(alignment: .leading, spacing: 12) {
                                Button {
                                    if isCollapsed {
                                        collapsedSections.remove(section.id)
                                    } else {
                                        collapsedSections.insert(section.id)
                                    }
                                } label: {
                                    HStack {
                                        Text(verbatim: section.title)
                                            .font(Typeface.heading(20, relativeTo: .title3))
                                            .foregroundStyle(section.isUnset ? Theme.muted : Theme.ink)
                                        Spacer(minLength: 8)
                                        Image(systemName: isCollapsed ? "chevron.down" : "chevron.up")
                                            .font(.footnote.weight(.semibold))
                                            .foregroundStyle(Theme.muted)
                                    }
                                    .padding(.bottom, 8)
                                    .overlay(alignment: .bottom) {
                                        Rectangle().fill(Theme.rule).frame(height: 1)
                                    }
                                    .frame(minHeight: 44)
                                    .contentShape(.rect)
                                }
                                .buttonStyle(.plain)
                                .accessibilityAddTraits(.isHeader)
                                .accessibilityValue(isCollapsed ? Text("閉じています") : Text("開いています"))
                                if !isCollapsed {
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
        VStack(spacing: 8) {
            TankSketch(isRound: tank.kind.isRound)
                .frame(width: 64, height: 40)
                .accessibilityHidden(true)
            Text(verbatim: tank.name)
                .font(Typeface.heading(22, relativeTo: .title3))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            if let first = cohorts.first {
                Text(verbatim: first.strainName)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(Theme.accent)
                    .lineLimit(1)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 4)
                    .background(Theme.pill, in: .capsule)
                Text(verbatim: cohortLine(cohorts))
                    .font(.caption)
                    .foregroundStyle(Theme.muted)
                    .lineLimit(1)
            } else {
                Text("空き")
                    .font(.subheadline)
                    .foregroundStyle(Theme.muted)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 4)
                    .background(Theme.rule.opacity(0.6), in: .capsule)
            }
            Rectangle().fill(Theme.rule).frame(height: 1).padding(.top, 2)
            VStack(spacing: 6) {
                infoRow(icon: water.isOverdue ? "exclamationmark.circle" : "calendar", title: "最終水換え",
                        value: lastWaterChangeText, isWarning: water.isOverdue)
                if let temp = tank.latestWaterTemp {
                    infoRow(icon: "water.waves", title: "水温",
                            value: String(localized: "\(temp.formatted(.number.precision(.fractionLength(1))))℃"), isWarning: false)
                }
            }
        }
        .frame(maxWidth: .infinity, minHeight: 88, alignment: .top)
        .cardBackground()
        .overlay(alignment: .topTrailing) {
            Image(systemName: tank.placement.symbolName)
                .font(.caption)
                .foregroundStyle(Theme.muted)
                .padding(12)
                .accessibilityLabel(Text(verbatim: tank.placement.label))
        }
        .contentShape(.rect)
        .accessibilityElement(children: .combine)
        .accessibilityHint(Text(verbatim: water.text))
    }

    private var lastWaterChangeText: String {
        guard let date = tank.lastWaterChange else { return String(localized: "記録なし") }
        return date.formatted(.dateTime.month().day())
    }

    private func cohortLine(_ cohorts: [Cohort]) -> String {
        guard let first = cohorts.first else { return "" }
        let base = "\(first.generationLabel) · \(first.countText)"
        return cohorts.count > 1 ? base + String(localized: "　ほか\(String(cohorts.count - 1))群") : base
    }

    private func infoRow(icon: String, title: LocalizedStringKey, value: String, isWarning: Bool) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.caption2)
                .foregroundStyle(isWarning ? Theme.warning : Theme.muted)
                .frame(width: 14)
            Text(title)
                .font(.caption2)
                .foregroundStyle(Theme.muted)
                .lineLimit(1)
            Spacer(minLength: 2)
            Text(verbatim: value)
                .font(.caption2.weight(isWarning ? .bold : .regular))
                .foregroundStyle(isWarning ? Theme.warning : Theme.ink)
                .lineLimit(1)
        }
    }
}

/// 容器の線画。角の丸い箱か、丸い鉢。水面の波を一本引く。
private struct TankSketch: View {
    let isRound: Bool

    var body: some View {
        ZStack {
            if isRound {
                Ellipse().stroke(Theme.accent, lineWidth: 2)
                    .frame(width: 60, height: 22)
                    .offset(y: -8)
                BowlBottom().stroke(Theme.accent, lineWidth: 2)
                    .frame(width: 60, height: 22)
                    .offset(y: 3)
            } else {
                RoundedRectangle(cornerRadius: 5).stroke(Theme.accent, lineWidth: 2)
                    .frame(width: 60, height: 12)
                    .offset(y: -12)
                BoxBody().stroke(Theme.accent, style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
                    .frame(width: 60, height: 28)
                    .offset(y: 4)
            }
            WaterWave().stroke(Theme.accent.opacity(0.5), style: StrokeStyle(lineWidth: 1.5, lineCap: .round))
                .frame(width: 36, height: 8)
                .offset(y: 2)
        }
    }
}

private struct BoxBody: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX + 4, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.minX + 8, y: rect.maxY - 2))
        path.addQuadCurve(to: CGPoint(x: rect.minX + 18, y: rect.maxY), control: CGPoint(x: rect.minX + 9, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.maxX - 18, y: rect.maxY))
        path.addQuadCurve(to: CGPoint(x: rect.maxX - 8, y: rect.maxY - 2), control: CGPoint(x: rect.maxX - 9, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.maxX - 4, y: rect.minY))
        return path
    }
}

private struct BowlBottom: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addQuadCurve(to: CGPoint(x: rect.maxX, y: rect.minY), control: CGPoint(x: rect.midX, y: rect.maxY * 1.9))
        return path
    }
}

private struct WaterWave: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.midY))
        path.addCurve(to: CGPoint(x: rect.maxX, y: rect.midY),
                      control1: CGPoint(x: rect.minX + rect.width * 0.25, y: rect.minY - rect.height * 0.3),
                      control2: CGPoint(x: rect.minX + rect.width * 0.5, y: rect.maxY + rect.height * 0.3))
        return path
    }
}

extension TankKind {
    /// 丸い容器の絵で描く種類。
    var isRound: Bool {
        switch self {
        case .waterLilyPot, .cup: true
        default: false
        }
    }
}
