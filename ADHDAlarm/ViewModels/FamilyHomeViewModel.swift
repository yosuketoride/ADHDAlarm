import Foundation
import Observation

/// 家族モードホームの状態管理
@Observable @MainActor
final class FamilyHomeViewModel {

    // MARK: - UI状態

    var selectedTab = 0
    var isLoadingEvents = false

    // MARK: - ダッシュボードデータ

    /// 家族が送信した予定一覧（Supabaseから取得・PRO限定）
    var sentEvents: [RemoteEventRecord] = []
    /// 当事者の最終確認時刻（暫定: Supabase last_seen に対応するまでnil）
    var lastSeen: Date? = nil
    /// SOSメッセージ（nil = SOS未発生）
    var sosMessage: String? = nil

    // MARK: - 依存

    private let service: FamilyScheduling
    /// isPro判定・PRO伝播反映のためにAppStateを参照する
    private var appState: AppState?

    init(service: FamilyScheduling? = nil) {
        self.service = service ?? FamilyRemoteService.shared
    }

    /// AppStateをバインドする（初回のみ有効）
    func bindAppStateIfNeeded(_ appState: AppState) {
        guard self.appState == nil else { return }
        self.appState = appState
    }

    // MARK: - データ取得

    /// 送信済み予定を取得する
    func loadEvents(linkId: String) async {
        isLoadingEvents = true
        defer { isLoadingEvents = false }
        do {
            _ = try await service.ensureDeviceRegistered()

            // リンク情報からis_premiumを読み込みAppStateに反映（1契約で全員PRO扱い）
            let links = try await service.fetchMyFamilyLinks()
            applyFamilyPremiumIfNeeded(links: links)

            // 予定取得はPROのみ（Freeはダッシュボードに表示しないのでAPIコスト節約）
            if appState?.subscriptionTier == .pro {
                sentEvents = try await service.fetchSentEvents(linkId: linkId)
            } else {
                sentEvents = []
            }
            lastSeen = try? await service.fetchLastSeen(linkId: linkId)
        } catch {
            // 接続エラーは静かに無視（ダッシュボードがゼロ件のまま表示される）
            lastSeen = nil
        }
    }

    /// pull-to-refresh
    func refresh(linkId: String) async {
        await loadEvents(linkId: linkId)
    }

    // MARK: - Private

    /// ペアリングリンクのis_premiumを確認してAppStateに反映する
    /// （ペア内いずれかがPROを契約した場合、このデバイスにもPROを適用）
    private func applyFamilyPremiumIfNeeded(links: [FamilyLinkRecord]) {
        // すでにPROなら何もしない
        guard appState?.subscriptionTier != .pro else { return }
        if links.contains(where: { $0.isPremium }) {
            appState?.subscriptionTier = .pro
        }
    }

    // refreshTask は @MainActor 隔離のため deinit からは直接参照できない
    // Task は参照が切れた時点で自動キャンセルされるため明示的な cancel は不要
}
