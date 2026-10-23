import Foundation

// Proの購入の裏側（ARCHITECTURE.md 6）。StoreKit 2 の実装は StoreKitBackend、テストでは差し替える。

struct ProProduct: Equatable, Sendable {
    var id: String
    /// 「¥1,200」のように、利用者の店の通貨で整形した価格。
    var displayPrice: String
}

enum ProPurchaseResult: Equatable, Sendable {
    case purchased
    /// 家族の承認待ちなど。まだ解放されない。
    case pending
    case cancelled
}

enum ProStoreError: LocalizedError, Equatable {
    case productUnavailable
    case unverified
    case unknown

    var errorDescription: String? {
        switch self {
        case .productUnavailable: String(localized: "価格を取得できませんでした。通信を確かめて、もう一度お試しください。")
        case .unverified: String(localized: "購入を確認できませんでした。しばらくしてから「購入を復元」をお試しください。")
        case .unknown: String(localized: "購入を完了できませんでした。もう一度お試しください。")
        }
    }
}

protocol ProBackend: Sendable {
    func loadProduct() async throws -> ProProduct
    /// 今の権利。Proを持っていれば true。返金されたものは含まない。
    func hasEntitlement() async -> Bool
    func purchase() async throws -> ProPurchaseResult
    /// App Storeと同期して、購入済みの権利を取り戻す。
    func restore() async throws
    /// 権利が変わるたびに、今の権利を流す（購入、返金、家族共有）。
    func entitlementUpdates() -> AsyncStream<Bool>
}
