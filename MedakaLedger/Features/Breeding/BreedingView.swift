import SwiftUI

// 繁殖タブ。親魚セットと採卵は第2週で作る（DECISIONS.md H）。

struct BreedingView: View {
    var body: some View {
        ContentUnavailableView(
            "親魚セットはまだありません",
            systemImage: "arrow.triangle.branch",
            description: Text("親魚セットと採卵の記録は、次の更新で使えるようになります。")
        )
        .navigationTitle("繁殖")
    }
}
