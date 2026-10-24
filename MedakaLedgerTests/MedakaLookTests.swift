import Testing
@testable import MedakaLedger

struct MedakaLookTests {
    @Test func タグが無ければ既定の見た目() {
        #expect(MedakaLook.from(breedName: "", traitTags: []) == .fallback)
        #expect(MedakaLook.from(breedName: "名前だけ", traitTags: []) == .fallback)
    }

    @Test func 品種名から色を決める() {
        #expect(MedakaLook.from(breedName: "楊貴妃", traitTags: []).palette == .vermilion)
        #expect(MedakaLook.from(breedName: "幹之", traitTags: []).palette == .silver)
        #expect(MedakaLook.from(breedName: "ブラックダイヤ", traitTags: []).palette == .black)
        #expect(MedakaLook.from(breedName: "ヒメダカ", traitTags: []).palette == .orange)
    }

    @Test func 三色と紅白は白や赤より先に判定する() {
        #expect(MedakaLook.from(breedName: "三色", traitTags: []).palette == .tricolor)
        #expect(MedakaLook.from(breedName: "", traitTags: ["紅白"]).palette == .redWhite)
        #expect(MedakaLook.from(breedName: "", traitTags: ["白"]).palette == .white)
    }

    @Test func 体型はタグから決める() {
        #expect(MedakaLook.from(breedName: "", traitTags: ["ヒカリ体型"]).shape == .hikari)
        #expect(MedakaLook.from(breedName: "", traitTags: ["ダルマ"]).shape == .daruma)
        #expect(MedakaLook.from(breedName: "", traitTags: ["半ダルマ"]).shape == .daruma)
        #expect(MedakaLook.from(breedName: "", traitTags: ["体外光"]).shape == .standard)
    }

    @Test func ラメとロングフィンは足し合わせる() {
        let look = MedakaLook.from(breedName: "楊貴妃", traitTags: ["黒ラメ", "ロングフィン", "ダルマ"])
        #expect(look.hasSparkle)
        #expect(look.hasLongFin)
        #expect(look.shape == .daruma)
        #expect(look.palette == .vermilion)
    }
}
