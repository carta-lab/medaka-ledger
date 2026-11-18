import SwiftData
import SwiftUI

// 血統図（SCREENS.md 11、PRD.md F10）。選んだ群を一番下に置き、上へ雄側と雌側の親を世代ごとに並べる木。
// ピンチで拡大縮小、ノードのタップで群詳細へ。Freeは2世代まで、Proは全世代。
// Proの確認が済むまでは、Freeの深さで描く（DECISIONS.md G 3-10）。

struct LineageView: View {
    @Environment(ProStore.self) private var pro
    let cohort: Cohort
    @State private var gate = LimitGate()
    @State private var scale: CGFloat = 1
    @State private var contentSize: CGSize = .zero
    @GestureState private var pinch: CGFloat = 1

    private static let scaleRange: ClosedRange<CGFloat> = 0.4...3
    /// 画面の下に浮かぶタブバーに、選んだ群が隠れないための余白。
    private static let tabBarClearance: CGFloat = 96

    var body: some View {
        let maxDepth = LineageResolver.depthLimit(isPro: pro.isPro)
        let tree = LineageSource.tree(for: cohort, maxDepth: maxDepth)
        let cohorts = LineageSource.cohorts(from: cohort, maxDepth: maxDepth)
        Group {
            if let tree {
                GeometryReader { viewport in
                    ScrollView([.horizontal, .vertical]) {
                        diagram(tree: tree, cohorts: cohorts)
                            // 木が画面より小さいときは、選んだ群を画面の下の中央に置く。大きいときはスクロールする
                            .frame(
                                minWidth: viewport.size.width,
                                minHeight: max(viewport.size.height - Self.tabBarClearance, 0),
                                alignment: .bottom
                            )
                    }
                    .gesture(
                        MagnifyGesture()
                            .updating($pinch) { value, state, _ in state = value.magnification }
                            .onEnded { value in scale = clamp(scale * value.magnification) }
                    )
                }
                .safeAreaInset(edge: .top) {
                    if tree.hasTruncation, pro.isPro {
                        Text(verbatim: String(localized: "世代が多いため、\(tree.depth.formatted())世代前までを表示しています"))
                            .font(.subheadline)
                            .frame(maxWidth: .infinity, minHeight: Theme.minButtonHeight)
                            .background(Theme.surface)
                    } else if tree.hasTruncation, pro.status == .free {
                        Button {
                            gate.present(reason: .feature(.fullLineage))
                        } label: {
                            Label("Proで全世代を表示", systemImage: "lock")
                                .font(.subheadline)
                                .frame(maxWidth: .infinity, minHeight: Theme.minButtonHeight)
                                .background(Theme.surface)
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("lineageProButton")
                    }
                }
            } else {
                ContentUnavailableView("血統を表示できません", systemImage: "exclamationmark.triangle")
            }
        }
        .themedBackground()
        .navigationTitle("血統図")
        .navigationBarTitleDisplayMode(.inline)
        .paywall(gate)
    }

    /// 拡大縮小した大きさの枠に木を入れる。scaleEffect は配置の大きさを変えないので、枠を倍率に合わせて、全体までスクロールできるようにする。
    private func diagram(tree: LineageNode, cohorts: [UUID: Cohort]) -> some View {
        let factor = clamp(scale * pinch)
        return LineageBranch(node: tree, cohorts: cohorts, rootID: cohort.id)
            .fixedSize()
            .onGeometryChange(for: CGSize.self) { $0.size } action: { contentSize = $0 }
            .scaleEffect(factor, anchor: .topLeading)
            .frame(
                width: contentSize == .zero ? nil : contentSize.width * factor,
                height: contentSize == .zero ? nil : contentSize.height * factor,
                alignment: .topLeading
            )
            .padding(Theme.screenPadding)
    }

    private func clamp(_ value: CGFloat) -> CGFloat {
        min(max(value, Self.scaleRange.lowerBound), Self.scaleRange.upperBound)
    }
}

/// 木の一部（ノードと、その上に並ぶ雄側と雌側の親）。自分自身を呼んで祖先へ続ける。
/// 親と子は、家系図のように線でつなぐ。線の位置は、親の枝の幅を測って決める。
private struct LineageBranch: View {
    let node: LineageNode
    let cohorts: [UUID: Cohort]
    let rootID: UUID
    @State private var sireWidth: CGFloat = 0
    @State private var damWidth: CGFloat = 0

    private static let gap: CGFloat = 12

    var body: some View {
        VStack(spacing: 0) {
            if node.sire != nil || node.dam != nil {
                HStack(alignment: .bottom, spacing: Self.gap) {
                    parent(node.sire, role: "雄", isSire: true)
                    parent(node.dam, role: "雌", isSire: false)
                }
                LineageConnector(
                    sireWidth: node.sire == nil ? nil : sireWidth,
                    damWidth: node.dam == nil ? nil : damWidth,
                    gap: Self.gap
                )
                .stroke(Theme.accent.opacity(0.5), style: StrokeStyle(lineWidth: 1.5, lineCap: .round, lineJoin: .round))
                .frame(height: 20)
                .accessibilityHidden(true)
            }
            LineageNodeCard(node: node, cohort: cohorts[node.info.id], isRoot: node.info.id == rootID)
        }
    }

    @ViewBuilder
    private func parent(_ parent: LineageNode?, role: LocalizedStringKey, isSire: Bool) -> some View {
        if let parent {
            VStack(spacing: 8) {
                Text(role)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                LineageBranch(node: parent, cohorts: cohorts, rootID: rootID)
            }
            .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { width in
                if isSire { sireWidth = width } else { damWidth = width }
            }
        }
    }
}

/// 雄と雌の親の中心から、子へ下ろす線。親が1匹だけなら、まっすぐ下ろす。
private struct LineageConnector: Shape {
    let sireWidth: CGFloat?
    let damWidth: CGFloat?
    let gap: CGFloat

    func path(in rect: CGRect) -> Path {
        var xs: [CGFloat] = []
        var total: CGFloat = 0
        if let sireWidth {
            xs.append(sireWidth / 2)
            total += sireWidth
        }
        if let damWidth {
            xs.append(total + (sireWidth == nil ? 0 : gap) + damWidth / 2)
            total += (sireWidth == nil ? 0 : gap) + damWidth
        }
        guard let first = xs.first, let last = xs.last else { return Path() }
        let stem = total / 2
        let midY = rect.midY
        var path = Path()
        for x in xs {
            path.move(to: CGPoint(x: rect.minX + x, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.minX + x, y: midY))
        }
        path.move(to: CGPoint(x: rect.minX + first, y: midY))
        path.addLine(to: CGPoint(x: rect.minX + last, y: midY))
        path.move(to: CGPoint(x: rect.minX + stem, y: midY))
        path.addLine(to: CGPoint(x: rect.minX + stem, y: rect.maxY))
        return path
    }
}

/// ノード1つ。系統名、世代、孵化日、代表写真。タップで群詳細へ。
private struct LineageNodeCard: View {
    @ScaledMetric(relativeTo: .caption) private var nodeWidth: CGFloat = 100
    let node: LineageNode
    let cohort: Cohort?
    let isRoot: Bool

    var body: some View {
        // 狭い画面でも横に並べられるよう、縦に積んだ細いノードにする
        let card = VStack(spacing: 8) {
            if let photo = cohort?.coverPhoto {
                PhotoThumbnail(photo: photo, size: 40)
            } else if let strain = cohort?.strain {
                MedakaIcon(look: strain.look, size: 40, showsBackground: false)
            }
            Text(verbatim: node.info.strainName)
                .font(.caption.bold())
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            Text(verbatim: detail)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(12)
        // 祖先を2世代まで出すと4つ並ぶので、狭い画面に収まる幅にする（文字が大きいときは縦に伸びる）
        .frame(width: nodeWidth)
        .background(Theme.surface, in: .rect(cornerRadius: Theme.cornerRadius))
        .overlay {
            // 縁の色は系統の色。交配で色の違う系統が混ざる様子が、図の上で見える
            RoundedRectangle(cornerRadius: Theme.cornerRadius)
                .stroke(isRoot ? Theme.accent : outline, lineWidth: isRoot ? 2 : 1)
        }

        if let cohort {
            NavigationLink(value: Route.cohort(cohort)) { card }
                .buttonStyle(.plain)
        } else {
            card
        }
    }

    private var outline: Color {
        (cohort?.strain?.look.palette ?? .plain).outline
    }

    private var detail: String {
        var lines = [CohortText.generation(node.info.generation)]
        if let hatchedAt = node.info.hatchedAt {
            lines.append(String(localized: "孵化 \(CohortText.shortDate(hatchedAt))"))
        }
        if node.isCycle { lines.append(String(localized: "（循環）")) }
        return lines.joined(separator: "\n")
    }
}

