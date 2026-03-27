import Foundation

/// 家族リモートスケジュール設定（子が親の予定を代行登録する機能）のプロトコル
protocol FamilyScheduling: Sendable {

    // MARK: - デバイス登録・認証

    /// 匿名認証でデバイスを登録し、デバイスIDを返す
    func ensureDeviceRegistered() async throws -> String

    /// APNsデバイストークンをSupabaseに保存（UPSERT）
    func updateDeviceToken(_ token: String) async throws

    // MARK: - 家族ペアリング（親側）

    /// ペアリングコードを生成して返す（親が最初に実行）
    func generateFamilyCode() async throws -> (linkId: String, code: String)

    /// ペアリング状態の変化を監視する（Realtimeストリーム）
    func listenToFamilyLinkStatus(linkId: String) -> AsyncStream<String>

    /// ペアリングを解除する
    func unlinkFamily(linkId: String) async throws

    // MARK: - 家族ペアリング（子側）

    /// ペアリングコードでリンクに参加し、linkIdを返す
    func joinFamily(code: String) async throws -> String

    // MARK: - リモート予定（子側）

    /// 親への予定を作成・送信する
    func createRemoteEvent(_ event: RemoteEventPayload) async throws

    /// 送信した予定をキャンセルする
    func cancelRemoteEvent(id: String) async throws

    /// 子が送信した予定の一覧を取得する
    func fetchSentEvents(linkId: String) async throws -> [RemoteEventRecord]

    // MARK: - リモート予定（親側）

    /// 未同期の予定を取得する（pending）
    func fetchPendingEvents() async throws -> [RemoteEventRecord]

    /// キャンセルされた予定を取得する（cancelled）
    func fetchCancelledEvents() async throws -> [RemoteEventRecord]

    /// 予定を同期済みにマークする
    func markEventSynced(id: String) async throws

    /// 予定をロールバック済みにマークする
    func markEventRolledBack(id: String) async throws

    /// 新しい予定の到着をリアルタイムで監視する
    func listenToNewEvents() -> AsyncStream<RemoteEventRecord>

    // MARK: - 状態確認

    /// 自分のデバイスIDを返す（登録済みの場合のみ）
    var currentDeviceId: String? { get }

    /// 自分がペアリング済みの家族リンク一覧を取得する
    func fetchMyFamilyLinks() async throws -> [FamilyLinkRecord]
}
