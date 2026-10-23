import Observation
import SwiftData
import SwiftUI

// Freeの上限とPro限定の機能の入口（SCREENS.md 13、ARCHITECTURE.md 4.4）。
// 保存の前に attempt を呼ぶ。上限に収まればそのまま保存し、超えるなら保存せずにPaywallを開く。
// 購入できたら、止めていた保存を続ける。入力中の内容は、シートを開いたままなので失われない。

@MainActor
@Observable
final class LimitGate {
    struct Request: Identifiable {
        let id = UUID()
        let reason: PaywallReason
        let onPurchased: @MainActor () -> Void
    }

    var request: Request?

    /// 数を増やす保存の前に呼ぶ。count は確認が済んでから数える。
    func attempt(
        _ kind: FreeLimits.Kind,
        adding: Int = 1,
        pro: ProStore,
        count: @escaping @MainActor () -> Int,
        action: @escaping @MainActor () -> Void
    ) {
        Task {
            // Proかどうかの確認が済む前に止めない（DECISIONS.md G 3-10）
            await pro.waitUntilChecked()
            if FreeLimits.allows(kind, currentCount: count(), adding: adding, isPro: pro.isPro) {
                action()
            } else {
                request = Request(reason: .limit(kind), onPurchased: action)
            }
        }
    }

    /// Pro限定の機能を使う前に呼ぶ。Proならそのまま実行し、FreeならPaywallを開く。
    func requirePro(_ feature: ProFeature, pro: ProStore, action: @escaping @MainActor () -> Void) {
        Task {
            await pro.waitUntilChecked()
            if pro.isPro {
                action()
            } else {
                request = Request(reason: .feature(feature), onPurchased: action)
            }
        }
    }

    /// 理由なしでPaywallを開く（設定から）。
    func present(reason: PaywallReason = .general, onPurchased: @escaping @MainActor () -> Void = {}) {
        request = Request(reason: reason, onPurchased: onPurchased)
    }

    /// 購入できたとき。シートを閉じてから、止めていた操作を続ける。
    func completePurchase(_ request: Request) {
        self.request = nil
        let continuation = request.onPurchased
        Task { @MainActor in
            continuation()
        }
    }
}

extension View {
    /// LimitGate が開くPaywallのシート。保存の画面ごとに1回だけ付ける。
    func paywall(_ gate: LimitGate) -> some View {
        modifier(PaywallPresentation(gate: gate))
    }
}

private struct PaywallPresentation: ViewModifier {
    @Bindable var gate: LimitGate

    func body(content: Content) -> some View {
        content
            .sheet(item: $gate.request) { request in
                PaywallView(reason: request.reason) {
                    gate.completePurchase(request)
                }
            }
    }
}
