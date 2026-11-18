import SwiftUI

// プライバシーポリシー（PRD.md F14、10章）。アプリの中で読める。
// TODO(要確認): お問い合わせ先と、審査提出に要る公開URL（LAUNCH.md 1章）は第6週までに決める。公開したら、この文面と同じ内容をそのURLに置く。

struct PrivacyPolicyView: View {
    var body: some View {
        List {
            Group {
                section(
                    "記録は端末の中だけ",
                    "容器、系統、群、採卵、選別、販売、作業記録、写真、購入者メモは、この端末の中にだけ保存します。開発者のサーバーには送りません。アカウントもありません。"
                )
                section(
                    "通信",
                    "アプリが通信するのは、Proの購入と復元のときに、Apple（App Store）と行うときだけです。支払いの情報はAppleが扱い、開発者は受け取りません。"
                )
                section(
                    "使わないもの",
                    "利用状況の計測、広告、クラッシュの収集、外部の解析サービスは使いません。"
                )
                section(
                    "カメラと写真",
                    "カメラは、写真を撮るときだけ使います。写真ライブラリは、利用者が選んだ写真を読み込むときと、利用者が「書き出す」を押した写真を保存するときだけ使います。ほかの写真は読みません。"
                )
                section(
                    "通知",
                    "通知は、この端末の中で予約するもの（孵化予定日の朝と、産卵期が始まる前）だけです。外から送られる通知はありません。"
                )
                section(
                    "バックアップと書き出し",
                    "バックアップのファイルとCSVは、利用者が保存先を選びます。バックアップには、購入者メモを含む全ての記録が入ります。保存先の扱いは、利用者が決めてください。"
                )
                section(
                    "削除",
                    "アプリを削除すると、この端末の記録は消えます。書き出したバックアップは消えません。"
                )
            }
            .ledgerRow()
        }
        .themedBackground()
        .navigationTitle("プライバシーポリシー")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func section(_ title: LocalizedStringKey, _ body: LocalizedStringKey) -> some View {
        Section {
            Text(body)
                .font(.subheadline)
        } header: {
            Text(title)
        }
    }
}

