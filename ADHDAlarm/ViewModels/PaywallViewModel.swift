import Foundation
import StoreKit
import Observation

/// ペイウォール画面の状態管理
@Observable
@MainActor
final class PaywallViewModel {

    var successMessage: String?
    var errorMessage: String?
    var isLoading = false

    private var storeKit: StoreKitService?
    private var appState: AppState?
    /// PRO購入後にfamily_linksへ伝播するサービス（ペアリング済みの場合のみ使用）
    private var familyService: FamilyScheduling

    init(storeKit: StoreKitService? = nil, appState: AppState? = nil,
         familyService: FamilyScheduling? = nil) {
        self.storeKit = storeKit
        self.appState = appState
        self.familyService = familyService ?? FamilyRemoteService.shared
    }

    var products: [Product] { storeKit?.products ?? [] }
    var isPurchasing: Bool   { storeKit?.isPurchasing ?? false }

    func bindIfNeeded(storeKit: StoreKitService, appState: AppState) {
        if self.storeKit == nil {
            self.storeKit = storeKit
        }
        if self.appState == nil {
            self.appState = appState
        }
    }

    // MARK: - 商品ロード

    /// 未ロードの場合のみ商品一覧を取得する
    func loadIfNeeded() async {
        guard let storeKit else { return }
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
        guard let storeKit, let appState else { return }
        errorMessage = nil
        do {
            let success = try await storeKit.purchase(product)
            if success {
                appState.subscriptionTier = .pro
                successMessage = "PROプランへのアップグレードが完了しました！"
                // ペアリング済み家族リンクにPROを伝播（1契約で全員PRO扱い）
                let service = familyService
                Task { try? await service.updatePremiumStatus(isPro: true) }
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
        guard let storeKit, let appState else { return }
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
