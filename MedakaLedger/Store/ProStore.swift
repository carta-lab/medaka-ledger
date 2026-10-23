import Foundation
import Observation

// Proの状態（ARCHITECTURE.md 6、DECISIONS.md G 3-10）。権利の正はStoreKit。UserDefaultsにはキャッシュしない。
// 起動直後は「確認中」で、Pro限定の表示と、Freeの上限による保存の停止は、確認が済むまで判定しない。

@MainActor
@Observable
final class ProStore {
    enum Status: Equatable {
        case checking
        case free
        case pro
    }

    enum Activity: Equatable {
        case idle
        case purchasing
        case restoring
    }

    /// 購入や復元の結果。画面に一度だけ出す。
    enum Outcome: Equatable {
        case purchased
        case pending
        case restored
        case nothingToRestore
        case failed(String)
    }

    private(set) var status: Status = .checking
    private(set) var product: ProProduct?
    private(set) var productError: String?
    private(set) var activity: Activity = .idle
    var outcome: Outcome?

    @ObservationIgnored private let backend: any ProBackend
    @ObservationIgnored private var waiters: [CheckedContinuation<Void, Never>] = []
    @ObservationIgnored private var updatesTask: Task<Void, Never>?

    init(backend: any ProBackend) {
        self.backend = backend
    }

    var isPro: Bool { status == .pro }
    var isChecking: Bool { status == .checking }
    var isBusy: Bool { activity != .idle }

    /// 起動時に1回。権利を確かめ、価格を取り、権利の変化を見張る。
    func start() async {
        guard updatesTask == nil else { return }
        let stream = backend.entitlementUpdates()
        updatesTask = Task { [weak self] in
            for await entitled in stream {
                self?.apply(entitled)
            }
        }
        apply(await backend.hasEntitlement())
        await loadProductIfNeeded()
    }

    /// フォアグラウンドに戻ったとき。返金や別の端末での購入を拾う。
    func refresh() async {
        apply(await backend.hasEntitlement())
    }

    func loadProductIfNeeded() async {
        guard product == nil else { return }
        do {
            product = try await backend.loadProduct()
            productError = nil
        } catch {
            productError = (error as? LocalizedError)?.errorDescription ?? ProStoreError.productUnavailable.errorDescription
        }
    }

    /// 確認が済むまで待つ。Freeの上限で止めるかどうかを決める前に呼ぶ。
    func waitUntilChecked() async {
        guard status == .checking else { return }
        await withCheckedContinuation { continuation in
            waiters.append(continuation)
        }
    }

    /// 購入して、Proになったら true。入力中のデータには触らない。
    @discardableResult
    func purchase() async -> Bool {
        guard !isBusy else { return false }
        activity = .purchasing
        defer { activity = .idle }
        do {
            switch try await backend.purchase() {
            case .purchased:
                apply(await backend.hasEntitlement())
                if isPro {
                    outcome = .purchased
                    return true
                }
                outcome = .failed(ProStoreError.unverified.errorDescription ?? "")
            case .pending:
                outcome = .pending
            case .cancelled:
                break
            }
        } catch {
            outcome = .failed((error as? LocalizedError)?.errorDescription ?? ProStoreError.unknown.errorDescription ?? "")
        }
        return false
    }

    /// 購入を復元して、Proになったら true。
    @discardableResult
    func restore() async -> Bool {
        guard !isBusy else { return false }
        activity = .restoring
        defer { activity = .idle }
        do {
            try await backend.restore()
            apply(await backend.hasEntitlement())
            outcome = isPro ? .restored : .nothingToRestore
            return isPro
        } catch {
            outcome = .failed((error as? LocalizedError)?.errorDescription ?? error.localizedDescription)
            return false
        }
    }

    private func apply(_ entitled: Bool) {
        status = entitled ? .pro : .free
        let pending = waiters
        waiters = []
        for waiter in pending { waiter.resume() }
    }
}
