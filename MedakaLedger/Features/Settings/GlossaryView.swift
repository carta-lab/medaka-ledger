import SwiftUI

// 用語の簡単な説明（PRD.md F14、docs/DOMAIN.md の用語）。

struct GlossaryView: View {
    private struct Entry: Identifiable {
        let term: String
        let meaning: String
        var id: String { term }
    }

    private var entries: [Entry] {
        [
            Entry(term: String(localized: "品種"), meaning: String(localized: "楊貴妃、幹之、三色のように、見た目の組み合わせに付いた呼び名です。")),
            Entry(term: String(localized: "系統"), meaning: String(localized: "特定の作出者や購入元から入手した血統です。このアプリでは「品種名と入手元や呼び名」で一つの系統にします。")),
            Entry(term: String(localized: "累代（F1、F2）"), meaning: String(localized: "親から子、孫へと世代を重ねることです。入手した世代が「入手」、その子がF1、孫がF2です。")),
            Entry(term: String(localized: "群"), meaning: String(localized: "同じ系統、同じ世代で、同じ容器にいる魚のまとまりです。匹数は概数で記録します。")),
            Entry(term: String(localized: "親魚セット"), meaning: String(localized: "採卵のために組んだ雄と雌の組み合わせです。同じ系統どうしでも、異なる系統の交配でも作れます。")),
            Entry(term: String(localized: "採卵ロット"), meaning: String(localized: "回収した卵のまとまりです。孵化予定日は積算温度から計算します。")),
            Entry(term: String(localized: "積算温度"), meaning: String(localized: "卵が孵化するまでに必要な温度の合計です。水温×日数が約250で孵化するのが目安です。")),
            Entry(term: String(localized: "針子"), meaning: String(localized: "孵化したばかりの、体長5ミリ前後の稚魚です。")),
            Entry(term: String(localized: "稚魚、若魚、成魚"), meaning: String(localized: "針子の次が稚魚、次が若魚、産卵できる大きさになったら成魚です。境目は厳密ではありません。")),
            Entry(term: String(localized: "選別"), meaning: String(localized: "育った子の中から良い個体を残し、残りを弾くことです。残した数と弾いた数を記録します。")),
            Entry(term: String(localized: "弾く"), meaning: String(localized: "選別で残さなかった個体のことです。餌用、格安販売、別容器、処分から行き先を選びます。")),
            Entry(term: String(localized: "産卵期"), meaning: String(localized: "メダカが卵を産む時期です。多くの地域で4月から9月です。設定で月を変えられます。")),
            Entry(term: String(localized: "越冬"), meaning: String(localized: "屋外の容器で冬を越すことです。冬は産卵しないので、水温と生存の確認が中心になります。")),
        ]
    }

    var body: some View {
        List(entries) { entry in
            VStack(alignment: .leading, spacing: 4) {
                Text(verbatim: entry.term)
                    .font(.headline)
                Text(verbatim: entry.meaning)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .padding(.vertical, 2)
            .accessibilityElement(children: .combine)
        }
        .navigationTitle("用語の説明")
        .navigationBarTitleDisplayMode(.inline)
    }
}
