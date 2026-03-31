import Foundation
import StoreKit
import Observation

/// ペイウォール画面の状態管理
@Observable
final class PaywallViewModel {

    var successMessage: String?
    var errorMessage: String?
    var isLoading = false

    private let storeKit: StoreKitService
    private let appState: AppState

    init(storeKit: StoreKitService, appState: AppState) {
        self.storeKit = storeKit
        self.appState = appState
    }

    var products: [Product] { storeKit.products }
    var isPurchasing: Bool   { storeKit.isPurchasing }

    // MARK: - 商品ロード

    /// 未ロードの場合のみ商品一覧を取得する
    func loadIfNeeded() async {
        guard products.isEmpty && !isLoading else { return }
        isLoading = true
        await storeKit.loadProducts()
        isLoading = false
        if products.isEmpty {
            errorMessage = "価格情報を取得できませんでした。インターネット接続を確認してください。"
        }
    }

    // MARK: - 購入

    func purchase(_ product: Product) async {
        errorMessage = nil
        do {
            let success = try await storeKit.purchase(product)
            if success {
                appState.subscriptionTier = .pro
                successMessage = "PROプランへのアップグレードが完了しました！"
            }
        } catch {
            // レビュー指摘 #4: ユーザーが認証画面で「キャンセル」を押した場合も catch に来る。
            // StoreKit 2 の userCancelled はユーザーの意思的操作なのでエラー表示しない。
            if case StoreKitError.userCancelled = error { return }
            errorMessage = "購入に失敗しました。しばらくしてからお試しください。"
        }
    }

    // MARK: - 購入復元

    func restorePurchases() async {
        errorMessage = nil
        do {
            try await storeKit.restorePurchases()
            let isPro = await storeKit.checkEntitlement()
            if isPro {
                appState.subscriptionTier = .pro
                successMessage = "購入を復元しました！"
            } else {
                errorMessage = "復元できる購入履歴が見つかりませんでした。"
            }
        } catch {
            errorMessage = "購入の復元に失敗しました。"
        }
    }
}
