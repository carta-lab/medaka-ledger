import SwiftData
import SwiftUI

// 繁殖タブ（SCREENS.md 6.1）。育卵中のロット、稼働中の親魚セット、終了した親魚セット。

struct BreedingView: View {
    @Environment(AppSettings.self) private var settings
    @Query(filter: BreedingSet.activePredicate, sort: \BreedingSet.startedAt, order: .reverse) private var activeSets: [BreedingSet]
    @Query(filter: BreedingSet.endedPredicate, sort: \BreedingSet.startedAt, order: .reverse) private var endedSets: [BreedingSet]
    @Query(filter: EggBatch.incubatingPredicate, sort: \EggBatch.collectedAt) private var incubating: [EggBatch]
    @State private var model = BreedingListModel()

    var body: some View {
        Group {
            if activeSets.isEmpty && endedSets.isEmpty {
                ContentUnavailableView {
                    Label("親魚セットがありません", systemImage: "arrow.triangle.branch")
                } description: {
                    Text("まず親魚セットを組みましょう")
                } actions: {
                    Button("親魚セットを組む") { model.isCreating = true }
                        .buttonStyle(LargeButtonStyle())
                        .accessibilityIdentifier("createBreedingSetButton")
                }
            } else {
                List {
                    incubatingSection
                    if !activeSets.isEmpty {
                        Section("稼働中") {
                            ForEach(activeSets) { set in row(set) }
                        }
                    }
                    if !endedSets.isEmpty {
                        Section("終了") {
                            ForEach(endedSets) { set in row(set) }
                        }
                    }
                }
            }
        }
        .navigationTitle("繁殖")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    model.isCreating = true
                } label: {
                    Label("親魚セットを組む", systemImage: "plus")
                }
                .accessibilityIdentifier("addBreedingSetButton")
            }
        }
        .sheet(isPresented: $model.isCreating) {
            BreedingSetEditView()
        }
        .sheet(item: $model.hatchingBatch) { batch in
            HatchSheet(batch: batch)
        }
    }

    @ViewBuilder
    private var incubatingSection: some View {
        let entries = BatchPredictionInfo.sortedByRemaining(incubating, settings: settings)
        if !entries.isEmpty {
            Section("育卵中のロット") {
                ForEach(entries) { entry in
                    Button {
                        model.hatchingBatch = entry.batch
                    } label: {
                        EggBatchRow(batch: entry.batch, info: entry.info)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func row(_ set: BreedingSet) -> some View {
        NavigationLink(value: Route.breedingSet(set)) {
            BreedingSetRow(set: set)
        }
        .accessibilityIdentifier("breedingSetRow")
    }
}

struct BreedingSetRow: View {
    let set: BreedingSet

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(verbatim: set.displayName)
                .font(.headline)
            Text(verbatim: detail)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 2)
    }

    private var detail: String {
        var parts = [
            set.tank?.name ?? String(localized: "容器未設定"),
            String(localized: "雄\(set.maleCount.formatted())・雌\(set.femaleCount.formatted())"),
            String(localized: "開始 \(CohortText.shortDate(set.startedAt))"),
        ]
        let incubating = set.incubatingBatches.count
        if incubating > 0 {
            parts.append(String(localized: "育卵中 \(incubating.formatted())"))
        }
        return parts.joined(separator: "・")
    }
}
