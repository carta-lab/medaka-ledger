import SwiftUI

// 群のタイムライン（SCREENS.md 5.1）。出来事、選別、採卵からの孵化を新しい順に出す。
// 最新の出来事と、選別の記録は左にスワイプして削除できる。

struct CohortTimelineSection: View {
    let cohort: Cohort
    let model: CohortDetailModel

    var body: some View {
        Section {
            ForEach(cohort.timelineItems) { item in
                switch item {
                case let .event(event):
                    CohortEventRow(event: event)
                        .swipeActions(edge: .trailing) {
                            if CohortOperations.deletionBlocker(for: event) == nil {
                                Button("削除", role: .destructive) {
                                    model.askToDelete(event)
                                }
                            }
                        }
                case let .selection(selection):
                    SelectionRow(selection: selection)
                        .swipeActions(edge: .trailing) {
                            Button("削除", role: .destructive) {
                                model.askToDelete(selection)
                            }
                        }
                case let .origin(batch):
                    OriginRow(batch: batch)
                }
            }
        } header: {
            Text("タイムライン")
        } footer: {
            Text("最新の記録は左にスワイプして削除できます。匹数と容器が元に戻ります。")
        }
    }
}

private struct SelectionRow: View {
    let selection: SelectionEvent

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "line.3.horizontal.decrease.circle")
                    .foregroundStyle(Theme.accent)
                    .frame(width: 24)
                VStack(alignment: .leading, spacing: 2) {
                    Text("選別")
                        .font(.subheadline.bold())
                    Text(verbatim: selection.summary)
                        .font(.subheadline)
                    if !selection.criteria.isEmpty {
                        Text(verbatim: selection.criteria.joined(separator: "・"))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    if !selection.note.isEmpty {
                        Text(verbatim: selection.note)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer(minLength: 0)
                Text(verbatim: CohortText.date(selection.date))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            let photos = PhotoOwner.selection(selection).photos
            if !photos.isEmpty {
                PhotoGrid(photos: photos)
            }
        }
        .padding(.vertical, 2)
    }
}

private struct OriginRow: View {
    let batch: EggBatch

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "circle.grid.3x3")
                .foregroundStyle(Theme.accent)
                .frame(width: 24)
            VStack(alignment: .leading, spacing: 2) {
                Text("採卵")
                    .font(.subheadline.bold())
                Text(verbatim: batch.breedingSet?.displayName ?? String(localized: "親魚セット未設定"))
                    .font(.subheadline)
                if let eggCount = batch.eggCount {
                    Text(verbatim: String(localized: "卵 \(eggCount.formatted())個"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer(minLength: 0)
            Text(verbatim: CohortText.date(batch.collectedAt))
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 2)
    }
}
