import SwiftUI

// 群の一覧の行と、出来事の文言。

struct CohortSummaryRow: View {
    let cohort: Cohort
    var showsTank: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Text(verbatim: "\(cohort.strainName) \(cohort.generationLabel)")
                    .font(.subheadline.bold())
                if !cohort.isActive {
                    Text(verbatim: cohort.status.label)
                        .font(.caption)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 6)
                        .background(.fill.tertiary, in: .capsule)
                }
            }
            if !cohort.label.isEmpty {
                Text(verbatim: cohort.label).font(.subheadline).foregroundStyle(Theme.muted)
            }
            Text(verbatim: detailText)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 6)
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(.rect)
    }

    private var detailText: String {
        var parts = [cohort.countText, cohort.stage.label]
        if showsTank {
            parts.insert(cohort.tankName, at: 0)
        }
        if let hatchedAt = cohort.hatchedAt {
            parts.append(String(localized: "孵化 \(CohortText.shortDate(hatchedAt))"))
        }
        return parts.joined(separator: "・")
    }
}

struct CohortEventRow: View {
    let event: CohortEvent

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: event.kind.symbolName)
                .foregroundStyle(Theme.accent)
                .frame(width: 24)
            VStack(alignment: .leading, spacing: 6) {
                Text(verbatim: event.kind.label)
                    .font(.subheadline.bold())
                Text(verbatim: CohortEventText.summary(event))
                    .font(.subheadline)
                if !event.note.isEmpty {
                    Text(verbatim: event.note)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer(minLength: 0)
            Text(verbatim: CohortText.date(event.date))
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 6)
    }
}

enum CohortEventText {
    /// タイムラインと最近の記録に出す要点。
    static func summary(_ event: CohortEvent) -> String {
        let amount = CohortText.count(abs(event.countDelta))
        let from = tankName(event.fromTankID, event.fromTankName)
        let to = tankName(event.toTankID, event.toTankName)
        switch event.kind {
        case .created:
            return String(localized: "\(CohortText.count(countAfter(event)))で登録・\(to)")
        case .move:
            return "\(from) → \(to)"
        case .split:
            if event.countDelta < 0 {
                return String(localized: "\(amount)を\(to)へ分けました")
            }
            return String(localized: "\(from)の群から\(amount)を分けて登録")
        case .merge:
            if event.status == .merged {
                return String(localized: "\(to)の群に統合しました")
            }
            return String(localized: "\(from)の群から\(amount)を受け入れました")
        case .countChange:
            let reason = event.reason?.label ?? CountChangeReason.other.label
            if event.reason == .recount {
                return String(localized: "\(reason)：\(CohortText.count(event.previousCount))→\(CohortText.count(countAfter(event)))")
            }
            let sign = event.countDelta >= 0 ? "+" : "−"
            return "\(reason) \(sign)\(amount)"
        case .stageChange:
            let after = event.stage?.label ?? ""
            return "\(event.previousStage.label) → \(after)"
        case .statusChange:
            let after = event.status?.label ?? ""
            return "\(event.previousStatus.label) → \(after)"
        case .note:
            return event.note
        }
    }

    private static func tankName(_ id: UUID?, _ name: String) -> String {
        guard id != nil, !name.isEmpty else { return String(localized: "容器未設定") }
        return name
    }

    /// 出来事の後の匹数。前が未計数なら、計数修正と作成以外は未計数のまま。
    private static func countAfter(_ event: CohortEvent) -> Int? {
        switch event.kind {
        case .created:
            return event.reason == .recount ? event.countDelta : nil
        case .countChange where event.reason == .recount:
            return (event.previousCount ?? 0) + event.countDelta
        default:
            return event.previousCount.map { $0 + event.countDelta }
        }
    }
}

