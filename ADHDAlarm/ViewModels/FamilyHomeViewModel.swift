import Foundation
import Observation

/// 家族モードホームの状態管理
@Observable @MainActor
final class FamilyHomeViewModel {

    // MARK: - UI状態

    var selectedTab = 0
    var isLoadingEvents = false
    var shouldShowFirstCompletionBanner = false

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
    private let defaults: UserDefaults

    init(service: FamilyScheduling? = nil, defaults: UserDefaults = .standard) {
        self.service = service ?? FamilyRemoteService.shared
        self.defaults = defaults
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
            // 自分のlinkIdに対応するpairedリンクが存在しない場合は、相手側で解除済みとみなしてローカルを整理する
            let isStillPaired = links.contains { $0.id == linkId && $0.status == "paired" }
            if !isStillPaired {
                appState?.familyChildLinkIds.removeAll { $0 == linkId }
                sentEvents = []
                lastSeen = nil
                sosMessage = nil
                return
            }
            applyFamilyPremiumIfNeeded(links: links)

            // 無料版でも「今日の反応状況」は確認できるよう一覧を取得する
            sentEvents = try await service.fetchSentEvents(linkId: linkId)
            updateFirstCompletionBannerIfNeeded(events: sentEvents)
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

    /// 初回の✓✓到着バナーを閉じる
    func dismissFirstCompletionBanner() {
        shouldShowFirstCompletionBanner = false
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

    /// 無料版で初めて完了反応を受け取ったときだけ案内バナーを表示する
    private func updateFirstCompletionBannerIfNeeded(events: [RemoteEventRecord]) {
        guard appState?.subscriptionTier == .free else {
            shouldShowFirstCompletionBanner = false
            return
        }
        guard !defaults.bool(forKey: Constants.Keys.familyFirstCompletedBannerShown) else {
            shouldShowFirstCompletionBanner = false
            return
        }
        guard events.contains(where: { $0.status == "completed" }) else {
            shouldShowFirstCompletionBanner = false
            return
        }

        defaults.set(true, forKey: Constants.Keys.familyFirstCompletedBannerShown)
        shouldShowFirstCompletionBanner = true
    }

    // refreshTask は @MainActor 隔離のため deinit からは直接参照できない
    // Task は参照が切れた時点で自動キャンセルされるため明示的な cancel は不要
}
