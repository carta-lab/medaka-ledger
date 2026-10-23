import Foundation
import Observation
import UIKit

// 出品文の画面の状態（SCREENS.md 8.3）。群を選ぶと本文を組み立てる。行ごとに消せて、残った行をコピーする。

@MainActor
@Observable
final class ListingModel {
    var cohort: Cohort?
    /// 消した行（組み立てた行の番号）。群を変えたら戻す。
    private(set) var removedLines: Set<Int> = []
    var didCopy = false

    init(cohort: Cohort?) {
        self.cohort = cohort
    }

    func lines(settings: AppSettings) -> [String] {
        guard let cohort else { return [] }
        let text = ListingTextBuilder.build(
            template: settings.effectiveListingTemplate,
            input: ListingSource.input(for: cohort, settings: settings)
        )
        return text.components(separatedBy: "\n")
    }

    func select(_ cohort: Cohort?) {
        self.cohort = cohort
        removedLines = []
        didCopy = false
    }

    func remove(_ index: Int) {
        removedLines.insert(index)
        didCopy = false
    }

    func restoreAll() {
        removedLines = []
        didCopy = false
    }

    /// 消していない行をつないだ本文。
    func body(settings: AppSettings) -> String {
        lines(settings: settings).enumerated()
            .filter { !removedLines.contains($0.offset) }
            .map(\.element)
            .joined(separator: "\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    func copy(settings: AppSettings) {
        UIPasteboard.general.string = body(settings: settings)
        didCopy = true
    }
}
