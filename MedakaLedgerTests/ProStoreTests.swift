import Foundation
import Testing
@testable import MedakaLedger

/// テスト用の購入の裏側。結果を自由に決められる。
final class FakeProBackend: ProBackend, @unchecked Sendable {
    private let lock = NSLock()
    private var _entitled = false
    private var _purchaseResult: Result<ProPurchaseResult, any Error> = .success(.purchased)
    private var _restoreEntitles = false
    private var _restoreError: (any Error)?
    private var _productError: (any Error)?
    private var continuation: AsyncStream<Bool>.Continuation?
    private var delay: Duration = .zero

    var entitled: Bool {
        get { lock.withLock { _entitled } }
        set { lock.withLock { _entitled = newValue } }
    }

    func setPurchase(_ result: Result<ProPurchaseResult, any Error>) { lock.withLock { _purchaseResult = result } }
    func setRestore(entitles: Bool, error: (any Error)? = nil) {
        lock.withLock {
            _restoreEntitles = entitles
            _restoreError = error
        }
    }
    func setProductError(_ error: (any Error)?) { lock.withLock { _productError = error } }
    func setDelay(_ value: Duration) { lock.withLock { delay = value } }

    /// 権利の変化を流す（返金や別の端末での購入）。
    func emit(_ entitled: Bool) {
        self.entitled = entitled
        lock.withLock { continuation }?.yield(entitled)
    }

    func loadProduct() async throws -> ProProduct {
        if let error = lock.withLock({ _productError }) { throw error }
        return ProProduct(id: "com.meldcarta.medakaledger.pro", displayPrice: "¥1,200")
    }

    func hasEntitlement() async -> Bool {
        let wait = lock.withLock { delay }
        if wait > .zero { try? await Task.sleep(for: wait) }
        return entitled
    }

    func purchase() async throws -> ProPurchaseResult {
        let result = lock.withLock { _purchaseResult }
        if case .success(.purchased) = result { entitled = true }
        return try result.get()
    }

    func restore() async throws {
        let (entitles, error) = lock.withLock { (_restoreEntitles, _restoreError) }
        if let error { throw error }
        if entitles { entitled = true }
    }

    func entitlementUpdates() -> AsyncStream<Bool> {
        AsyncStream { continuation in
            lock.withLock { self.continuation = continuation }
        }
    }
}

@MainActor
struct ProStoreTests {
    @Test func 起動直後は確認中で確認が済めばFree() async {
        let backend = FakeProBackend()
        let store = ProStore(backend: backend)
        #expect(store.status == .checking)
        #expect(store.isChecking)
        #expect(!store.isPro)
        await store.start()
        #expect(store.status == .free)
        #expect(store.product?.displayPrice == "¥1,200")
    }

    @Test func 購入済みなら起動時にProになる() async {
        let backend = FakeProBackend()
        backend.entitled = true
        let store = ProStore(backend: backend)
        await store.start()
        #expect(store.isPro)
    }

    @Test func 確認が済むまで待てる() async {
        let backend = FakeProBackend()
        backend.setDelay(.milliseconds(150))
        backend.entitled = true
        let store = ProStore(backend: backend)
        let starting = Task { await store.start() }
        await store.waitUntilChecked()
        #expect(store.status == .pro)
        await starting.value
    }

    @Test func 購入に成功するとProになる() async {
        let backend = FakeProBackend()
        let store = ProStore(backend: backend)
        await store.start()
        let result = await store.purchase()
        #expect(result)
        #expect(store.isPro)
        #expect(store.outcome == .purchased)
        #expect(store.activity == .idle)
    }

    @Test func 購入をやめたらFreeのままで何も出さない() async {
        let backend = FakeProBackend()
        backend.setPurchase(.success(.cancelled))
        let store = ProStore(backend: backend)
        await store.start()
        let result = await store.purchase()
        #expect(!result)
        #expect(store.status == .free)
        #expect(store.outcome == nil)
    }

    @Test func 承認待ちはFreeのままで知らせる() async {
        let backend = FakeProBackend()
        backend.setPurchase(.success(.pending))
        let store = ProStore(backend: backend)
        await store.start()
        #expect(!(await store.purchase()))
        #expect(store.status == .free)
        #expect(store.outcome == .pending)
    }

    @Test func 購入に失敗してもFreeのままで理由を出す() async {
        let backend = FakeProBackend()
        backend.setPurchase(.failure(ProStoreError.unknown))
        let store = ProStore(backend: backend)
        await store.start()
        #expect(!(await store.purchase()))
        #expect(store.status == .free)
        #expect(store.outcome == .failed(ProStoreError.unknown.errorDescription ?? ""))
        #expect(store.activity == .idle)
    }

    @Test func 復元で見つかればProになる() async {
        let backend = FakeProBackend()
        backend.setRestore(entitles: true)
        let store = ProStore(backend: backend)
        await store.start()
        #expect(await store.restore())
        #expect(store.isPro)
        #expect(store.outcome == .restored)
    }

    @Test func 復元で見つからなければFreeのまま() async {
        let backend = FakeProBackend()
        let store = ProStore(backend: backend)
        await store.start()
        #expect(!(await store.restore()))
        #expect(store.status == .free)
        #expect(store.outcome == .nothingToRestore)
    }

    @Test func 復元に失敗したら理由を出す() async {
        let backend = FakeProBackend()
        backend.setRestore(entitles: false, error: ProStoreError.unverified)
        let store = ProStore(backend: backend)
        await store.start()
        #expect(!(await store.restore()))
        #expect(store.outcome == .failed(ProStoreError.unverified.errorDescription ?? ""))
    }

    @Test func 返金で権利が無くなればFreeに戻る() async {
        let backend = FakeProBackend()
        backend.entitled = true
        let store = ProStore(backend: backend)
        await store.start()
        #expect(store.isPro)
        backend.emit(false)
        await waitUntil { !store.isPro }
        #expect(store.status == .free)
    }

    @Test func 別の端末での購入はProになる() async {
        let backend = FakeProBackend()
        let store = ProStore(backend: backend)
        await store.start()
        backend.emit(true)
        await waitUntil { store.isPro }
        #expect(store.isPro)
    }

    @Test func フォアグラウンドで権利を確かめ直す() async {
        let backend = FakeProBackend()
        backend.entitled = true
        let store = ProStore(backend: backend)
        await store.start()
        backend.entitled = false
        await store.refresh()
        #expect(store.status == .free)
    }

    @Test func 価格を取れなくても起動できて後で取り直せる() async {
        let backend = FakeProBackend()
        backend.setProductError(ProStoreError.productUnavailable)
        let store = ProStore(backend: backend)
        await store.start()
        #expect(store.status == .free)
        #expect(store.product == nil)
        #expect(store.productError != nil)
        backend.setProductError(nil)
        await store.loadProductIfNeeded()
        #expect(store.product != nil)
        #expect(store.productError == nil)
    }

    private func waitUntil(_ condition: @MainActor () -> Bool) async {
        for _ in 0..<100 where !condition() {
            try? await Task.sleep(for: .milliseconds(20))
        }
    }
}
