import Foundation

// 容器の連続登録で、次の名前の初期値を作る（DECISIONS.md D）。
// 末尾の数字を1増やし、元の桁数を下限にゼロ埋めを保つ。末尾に数字がなければ「-2」を付ける。

enum TankNaming {
    static func nextName(after name: String) -> String {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let digits = trimmed.reversed().prefix { $0.isASCII && $0.isNumber }
        guard !digits.isEmpty else {
            return trimmed.isEmpty ? "" : trimmed + "-2"
        }
        let digitString = String(digits.reversed())
        let prefix = String(trimmed.dropLast(digitString.count))
        guard let number = Int(digitString), number < Int.max else {
            return trimmed + "-2"
        }
        let next = String(number + 1)
        let padding = max(0, digitString.count - next.count)
        return prefix + String(repeating: "0", count: padding) + next
    }
}
