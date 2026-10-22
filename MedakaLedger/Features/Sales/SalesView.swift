import SwiftUI

// 販売タブ。販売台帳は第4週で作る（DECISIONS.md H）。

struct SalesView: View {
    var body: some View {
        ContentUnavailableView(
            "販売の記録はまだありません",
            systemImage: "yensign.circle",
            description: Text("販売台帳は、次の更新で使えるようになります。")
        )
        .navigationTitle("販売")
    }
}
