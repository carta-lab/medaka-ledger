import Foundation
import StoreKit

// StoreKit 2 の実装（ARCHITECTURE.md 6）。非消耗型1点。通信するのはStoreKitだけ（CLAUDE.md）。

struct StoreKitBackend: ProBackend {
    /// 確定（LAUNCH.md 1章）。
    static let productID = "com.meldcarta.medakaledger.pro"

    func loadProduct() async throws -> ProProduct {
        let product = try await storeProduct()
        return ProProduct(id: product.id, displayPrice: product.displayPrice)
    }

    func hasEntitlement() async -> Bool {
        for await result in Transaction.currentEntitlements {
            if case let .verified(transaction) = result,
               transaction.productID == Self.productID,
               transaction.revocationDate == nil {
                return true
            }
        }
        return false
    }

    func purchase() async throws -> ProPurchaseResult {
        let product = try await storeProduct()
        switch try await product.purchase() {
        case let .success(verification):
            switch verification {
            case let .verified(transaction):
                await transaction.finish()
                return .purchased
            case .unverified:
                throw ProStoreError.unverified
            }
        case .pending:
            return .pending
        case .userCancelled:
            return .cancelled
        @unknown default:
            throw ProStoreError.unknown
        }
    }

    func restore() async throws {
        try await AppStore.sync()
    }

    func entitlementUpdates() -> AsyncStream<Bool> {
        AsyncStream { continuation in
            let task = Task {
                for await result in Transaction.updates {
                    if case let .verified(transaction) = result {
                        await transaction.finish()
                    }
                    continuation.yield(await hasEntitlement())
                }
                continuation.finish()
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    private func storeProduct() async throws -> Product {
        guard let product = try await Product.products(for: [Self.productID]).first else {
            throw ProStoreError.productUnavailable
        }
        return product
    }
}
