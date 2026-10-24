import Foundation

// めだかの絵の見た目（DECISIONS.md J）。系統の表現タグと品種名から決める。保存せず、都度計算する。
// 絵は目印のイメージで、品種の判定ではない。

struct MedakaLook: Equatable, Sendable {
    enum Shape: Equatable, Sendable {
        /// 細身。
        case standard
        /// 背びれが尻びれと同じように後ろにある。
        case hikari
        /// 丸く短い。
        case daruma
    }

    enum Palette: Equatable, Sendable {
        case orange, vermilion, white, black, yellow, silver, redWhite, tricolor, amber, blue, plain
    }

    var shape: Shape
    var palette: Palette
    var hasSparkle: Bool
    var hasLongFin: Bool

    static let fallback = MedakaLook(shape: .standard, palette: .plain, hasSparkle: false, hasLongFin: false)

    /// 表現タグと品種名をまとめて見る。色は下の順に最初に当たったものを採る。
    static func from(breedName: String, traitTags: [String]) -> MedakaLook {
        let words = traitTags + [breedName]
        func has(_ keywords: [String]) -> Bool {
            words.contains { word in keywords.contains { word.contains($0) } }
        }
        let shape: Shape = if has(["ダルマ"]) {
            .daruma
        } else if has(["ヒカリ", "光体型"]) {
            .hikari
        } else {
            .standard
        }
        // 順に見る。紅白は「白」より先、三色は「紅白」より先に判定する。
        let palette: Palette = if has(["三色", "大和"]) {
            .tricolor
        } else if has(["紅白"]) {
            .redWhite
        } else if has(["楊貴妃", "朱赤"]) {
            .vermilion
        } else if has(["ヒメダカ", "オレンジ"]) {
            .orange
        } else if has(["琥珀"]) {
            .amber
        } else if has(["サファイア", "オーロラ", "青"]) {
            .blue
        } else if has(["黒", "ブラック", "オロチ"]) {
            .black
        } else if has(["幹之", "みゆき", "透明鱗"]) {
            .silver
        } else if has(["黄", "金"]) {
            .yellow
        } else if has(["白"]) {
            .white
        } else {
            .plain
        }
        return MedakaLook(
            shape: shape,
            palette: palette,
            hasSparkle: has(["ラメ"]),
            hasLongFin: has(["ロングフィン"])
        )
    }
}
