import SwiftUI

// 採卵ロットの孵化予定日の表示と一覧の行（PRD.md F4、SCREENS.md 6.3）。

/// 採卵ロットと、その孵化予定日の情報。一覧の1行。
struct BatchEntry: Identifiable {
    let batch: EggBatch
    let info: BatchPredictionInfo
    var id: UUID { batch.id }
}

struct BatchPredictionInfo {
    let prediction: HatchPrediction?
    let remainingDays: Int?

    @MainActor
    init(batch: EggBatch, settings: AppSettings, now: Date = .now, calendar: Calendar = .current) {
        let hatchSettings = BreedingOperations.HatchSettings(
            degreeDaysToHatch: settings.degreeDaysToHatch,
            defaultWaterTempC: settings.defaultWaterTempC
        )
        let prediction = BreedingOperations.prediction(for: batch, settings: hatchSettings, calendar: calendar)
        self.prediction = prediction
        self.remainingDays = prediction.map { HatchPredictor.daysRemaining(until: $0, today: now, calendar: calendar) }
    }

    /// 予定日を過ぎたロットは目立たせる（PRD.md F4）。
    var isOverdue: Bool { (remainingDays ?? 0) < 0 }

    var dateText: String {
        guard let prediction else { return String(localized: "孵化予定日を計算できません") }
        return String(localized: "\(CohortText.shortDate(prediction.date))ごろ（±1日）")
    }

    var remainingText: String {
        guard let remainingDays else { return "" }
        if remainingDays == 0 { return String(localized: "今日") }
        if remainingDays > 0 { return String(localized: "あと\(remainingDays.formatted())日") }
        return String(localized: "\((-remainingDays).formatted())日過ぎ")
    }

    /// 残り日数の少ない順に並べる。計算できないロットは最後。
    @MainActor
    static func sortedByRemaining(_ batches: [EggBatch], settings: AppSettings, now: Date = .now) -> [BatchEntry] {
        batches
            .map { BatchEntry(batch: $0, info: BatchPredictionInfo(batch: $0, settings: settings, now: now)) }
            .sorted { lhs, rhs in
                switch (lhs.info.remainingDays, rhs.info.remainingDays) {
                case let (l?, r?): l < r
                case (_?, nil): true
                default: false
                }
            }
    }
}

struct EggBatchRow: View {
    let batch: EggBatch
    let info: BatchPredictionInfo

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .firstTextBaseline, spacing: 12) {
                    title
                    Spacer(minLength: 8)
                    status
                }
                VStack(alignment: .leading, spacing: 8) {
                    title
                    status
                }
            }
            Text(verbatim: detail)
                .font(.subheadline)
                .foregroundStyle(Theme.muted)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.vertical, 6)
        .frame(maxWidth: .infinity, minHeight: Theme.minButtonHeight, alignment: .leading)
        .contentShape(.rect)
        .accessibilityElement(children: .combine)
    }

    private var title: some View {
        Text(verbatim: batch.title).font(.subheadline.weight(.medium))
    }

    private var status: some View {
        LedgerStatus(
            text: batch.status == .incubating ? info.remainingText : batch.status.label,
            color: info.isOverdue && batch.status == .incubating ? Theme.warning : Theme.accent,
            systemImage: batch.status == .incubating ? "circle.dotted" : "checkmark"
        )
    }

    private var detail: String {
        switch batch.status {
        case .incubating:
            return [eggText, info.dateText].compactMap { $0 }.joined(separator: "・")
        case .hatched:
            var parts: [String] = []
            if let hatchedAt = batch.hatchedAt {
                parts.append(String(localized: "孵化 \(CohortText.shortDate(hatchedAt))"))
            }
            if let hatchedCount = batch.hatchedCount {
                parts.append(CohortText.count(hatchedCount))
            }
            return parts.joined(separator: "・")
        case .discarded:
            return eggText ?? ""
        }
    }

    private var eggText: String? {
        batch.eggCount.map { String(localized: "卵 \($0.formatted())個") }
    }
}

