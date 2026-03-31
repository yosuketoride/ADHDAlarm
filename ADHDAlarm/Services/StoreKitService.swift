import Foundation
import StoreKit
import Observation

/// StoreKit 2を使った課金管理
@Observable
final class StoreKitService {

    // MARK: - 状態

    var products: [Product] = []
    var isPurchasing = false
    var errorMessage: String?

    // MARK: - 初期化

    // レビュー指摘: Transaction.updates は無限シーケンスのため、await で直接呼ぶと
    // 呼び出し元の Task を永遠にブロックして後続処理が実行されなくなる（Task Starvation）。
    // 独立した Task に切り出してバックグラウンドで監視させる。
    private var updateListenerTask: Task<Void, Never>?

    /// アプリ起動時に呼ぶ: 商品取得 + トランザクション監視開始
    func start() async {
        await loadProducts()
        updateListenerTask?.cancel()
        updateListenerTask = Task { await listenForTransactions() }
    }

    // MARK: - 商品取得

    func loadProducts() async {
        do {
            products = try await Product.products(for: [
                Constants.ProductID.proMonthly,
                Constants.ProductID.proYearly,
                Constants.ProductID.proLifetime
            ])
            .sorted { $0.price < $1.price }
        } catch {
            errorMessage = "商品情報の取得に失敗しました。"
        }
    }

    // MARK: - 購入

    /// 購入を実行し、成功すれば true を返す
    @discardableResult
    func purchase(_ product: Product) async throws -> Bool {
        isPurchasing = true
        errorMessage = nil
        defer { isPurchasing = false }

        let result = try await product.purchase()
        switch result {
        case .success(let verification):
            let transaction = try checkVerified(verification)
            await transaction.finish()
            return true
        case .pending:
            return false
        case .userCancelled:
            return false
        @unknown default:
            return false
        }
    }

    // MARK: - 購入復元

    func restorePurchases() async throws {
        isPurchasing = true
        errorMessage = nil
        defer { isPurchasing = false }
        try await AppStore.sync()
    }

    // MARK: - エンタイトルメント確認

    /// 現在のトランザクション履歴からPRO状態を確認する
    func checkEntitlement() async -> Bool {
        for await result in Transaction.currentEntitlements {
            guard case .verified(let transaction) = result else { continue }
            if (transaction.productID == Constants.ProductID.proMonthly ||
                transaction.productID == Constants.ProductID.proYearly ||
                transaction.productID == Constants.ProductID.proLifetime),
               transaction.revocationDate == nil {
                return true
            }
        }
        return false
    }

    // MARK: - トランザクション監視（バックグラウンド）

    private func listenForTransactions() async {
        for await result in Transaction.updates {
            guard case .verified(let transaction) = result else { continue }
            await transaction.finish()
        }
    }

    // MARK: - 検証ヘルパー

    private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified:
            throw StoreError.failedVerification
        case .verified(let safe):
            return safe
        }
    }

    enum StoreError: Error {
        case failedVerification
    }
}
