import SwiftUI

// Paywall（SCREENS.md 13）。Freeとの比較表、価格、購入、復元、利用規約とプライバシーポリシー。
// 購入できたら onPurchased を呼ぶ。購入に失敗しても、開いたままの入力は失われない。

struct PaywallView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(ProStore.self) private var pro
    let reason: PaywallReason
    let onPurchased: () -> Void

    /// 利用規約はAppleの標準（EULA）を使う。
    private let termsURL = URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")

    var body: some View {
        NavigationStack {
            List {
                if let message = reason.message {
                    Section {
                        Text(verbatim: message)
                            .font(.headline)
                    }
                }
                Section {
                    Text("Proは買い切りです。購入すると、ずっと使えます。")
                        .font(.subheadline)
                }
                Section("FreeとProの違い") {
                    ForEach(PaywallRow.all) { row in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(verbatim: row.title)
                                .font(.subheadline.bold())
                            HStack(alignment: .firstTextBaseline) {
                                Text("Free")
                                    .font(.caption.bold())
                                    .foregroundStyle(.secondary)
                                Text(verbatim: row.free)
                                    .font(.subheadline)
                            }
                            HStack(alignment: .firstTextBaseline) {
                                Text("Pro")
                                    .font(.caption.bold())
                                    .foregroundStyle(Theme.accent)
                                Text(verbatim: row.pro)
                                    .font(.subheadline)
                            }
                        }
                        .padding(.vertical, 2)
                        .accessibilityElement(children: .combine)
                    }
                }
                Section {
                    if let url = termsURL {
                        Link("利用規約", destination: url)
                    }
                    NavigationLink("プライバシーポリシー") {
                        PrivacyPolicyView()
                    }
                }
            }
            .themedBackground()
            .navigationTitle("Pro")
            .navigationBarTitleDisplayMode(.inline)
            .safeAreaInset(edge: .bottom) { purchaseBar }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("閉じる") { dismiss() }
                }
            }
            .task { await pro.loadProductIfNeeded() }
            .alert(outcomeTitle, isPresented: outcomeBinding) {
                Button("OK") {}
            } message: {
                Text(verbatim: outcomeMessage)
            }
        }
    }

    private var purchaseBar: some View {
        VStack(spacing: 8) {
            if let error = pro.productError, pro.product == nil {
                Text(verbatim: error)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                Button("価格を取得し直す") {
                    Task { await pro.loadProductIfNeeded() }
                }
            }
            Button {
                Task {
                    if await pro.purchase() {
                        dismiss()
                        onPurchased()
                    }
                }
            } label: {
                if pro.activity == .purchasing {
                    ProgressView()
                } else if let product = pro.product {
                    Text(verbatim: String(localized: "Proを購入（\(product.displayPrice)）"))
                } else {
                    Text("Proを購入")
                }
            }
            .buttonStyle(LargeButtonStyle())
            .disabled(pro.product == nil || pro.isBusy || pro.isPro)
            .accessibilityIdentifier("purchaseProButton")
            Button("購入を復元") {
                Task {
                    if await pro.restore() {
                        dismiss()
                        onPurchased()
                    }
                }
            }
            .disabled(pro.isBusy)
            .frame(minHeight: Theme.minButtonHeight)
            .accessibilityIdentifier("restoreProButton")
        }
        .padding(.horizontal, Theme.screenPadding)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity)
        .background(.bar)
    }

    // MARK: - 結果

    private var outcomeBinding: Binding<Bool> {
        Binding(
            get: { shownOutcome != nil },
            set: { if !$0 { pro.outcome = nil } }
        )
    }

    /// 購入と復元に成功したときは画面ごと閉じるので、アラートで知らせるのは続きがあるものだけ。
    private var shownOutcome: ProStore.Outcome? {
        switch pro.outcome {
        case .pending, .nothingToRestore, .failed: pro.outcome
        default: nil
        }
    }

    private var outcomeTitle: String {
        switch shownOutcome {
        case .pending: String(localized: "承認を待っています")
        case .nothingToRestore: String(localized: "復元できる購入がありません")
        case .failed: String(localized: "購入できませんでした")
        default: ""
        }
    }

    private var outcomeMessage: String {
        switch shownOutcome {
        case .pending: String(localized: "家族の承認などが済むと、Proが使えるようになります。")
        case .nothingToRestore: String(localized: "この Apple ID では、Proの購入が見つかりませんでした。")
        case let .failed(message): message
        default: ""
        }
    }
}
