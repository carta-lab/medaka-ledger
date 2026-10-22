import SwiftData
import SwiftUI

// 血統図（SCREENS.md 11、PRD.md F10）。選んだ群を一番下に置き、上へ雄側と雌側の親を世代ごとに並べる木。
// ピンチで拡大縮小、ノードのタップで群詳細へ。Freeは2世代まで。

struct LineageView: View {
    let cohort: Cohort
    /// TODO(要確認): Proの権利は第5週のProStoreで決まる。それまではFreeの上限（2世代）で表示する。
    private let isPro = false
    @State private var scale: CGFloat = 1
    @GestureState private var pinch: CGFloat = 1

    var body: some View {
        let maxDepth = LineageResolver.depthLimit(isPro: isPro)
        let tree = LineageSource.tree(for: cohort, maxDepth: maxDepth)
        let cohorts = LineageSource.cohorts(from: cohort, maxDepth: maxDepth)
        Group {
            if let tree {
                ScrollView([.horizontal, .vertical]) {
                    LineageBranch(node: tree, cohorts: cohorts, rootID: cohort.id)
                        .padding(Theme.screenPadding)
                        .scaleEffect(min(max(scale * pinch, 0.4), 3), anchor: .center)
                        .frame(maxWidth: .infinity)
                }
                .gesture(
                    MagnifyGesture()
                        .updating($pinch) { value, state, _ in state = value.magnification }
                        .onEnded { value in scale = min(max(scale * value.magnification, 0.4), 3) }
                )
                .safeAreaInset(edge: .top) {
                    if tree.hasTruncation {
                        Label("Proで全世代を表示", systemImage: "lock")
                            .font(.subheadline)
                            .padding(8)
                            .frame(maxWidth: .infinity)
                            .background(.bar)
                    }
                }
            } else {
                ContentUnavailableView("血統を表示できません", systemImage: "exclamationmark.triangle")
            }
        }
        .navigationTitle("血統図")
        .navigationBarTitleDisplayMode(.inline)
    }
}

/// 木の一部（ノードと、その上に並ぶ雄側と雌側の親）。自分自身を呼んで祖先へ続ける。
private struct LineageBranch: View {
    let node: LineageNode
    let cohorts: [UUID: Cohort]
    let rootID: UUID

    var body: some View {
        VStack(spacing: 6) {
            if node.sire != nil || node.dam != nil {
                HStack(alignment: .bottom, spacing: 16) {
                    parent(node.sire, role: "雄")
                    parent(node.dam, role: "雌")
                }
                Image(systemName: "arrow.down")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .accessibilityHidden(true)
            }
            LineageNodeCard(node: node, cohort: cohorts[node.info.id], isRoot: node.info.id == rootID)
        }
    }

    @ViewBuilder
    private func parent(_ parent: LineageNode?, role: LocalizedStringKey) -> some View {
        if let parent {
            VStack(spacing: 4) {
                Text(role)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                LineageBranch(node: parent, cohorts: cohorts, rootID: rootID)
            }
        }
    }
}

/// ノード1つ。系統名、世代、孵化日、代表写真。タップで群詳細へ。
private struct LineageNodeCard: View {
    let node: LineageNode
    let cohort: Cohort?
    let isRoot: Bool

    var body: some View {
        let card = HStack(spacing: 8) {
            if let photo = cohort?.coverPhoto {
                PhotoThumbnail(photo: photo, size: 40)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(verbatim: node.info.strainName)
                    .font(.subheadline.bold())
                    .lineLimit(2)
                Text(verbatim: detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(10)
        .frame(minWidth: 120, maxWidth: 200, alignment: .leading)
        .background(.fill.quaternary, in: .rect(cornerRadius: Theme.cornerRadius))
        .overlay {
            RoundedRectangle(cornerRadius: Theme.cornerRadius)
                .stroke(isRoot ? Theme.accent : .clear, lineWidth: 2)
        }

        if let cohort {
            NavigationLink(value: Route.cohort(cohort)) { card }
                .buttonStyle(.plain)
        } else {
            card
        }
    }

    private var detail: String {
        var parts = [CohortText.generation(node.info.generation)]
        if let hatchedAt = node.info.hatchedAt {
            parts.append(String(localized: "孵化 \(CohortText.shortDate(hatchedAt))"))
        }
        if node.isCycle { parts.append(String(localized: "（循環）")) }
        return parts.joined(separator: "・")
    }
}
