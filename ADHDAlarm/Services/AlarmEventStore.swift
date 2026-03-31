import Foundation
import WidgetKit

/// AlarmEventのマッピング（eventKitID ⇔ alarmKitID）を永続化するストア
/// App Groupコンテナに保存してウィジェットとも共有する
final class AlarmEventStore {

    static let shared = AlarmEventStore()

    private let storageKey = Constants.Keys.alarmEventMappings

    // レビュー指摘 #3: オンメモリキャッシュ
    // save/find のたびにディスクI/Oが走るのを防ぐ。persist時に即座に同期更新する。
    private var inMemoryCache: [AlarmEvent]?

    // レビュー指摘 #3: WidgetCenter更新をデバウンスするタスク
    // SyncEngineループ内で複数件保存しても、Widgetへのリクエストを1秒後の1回にまとめる。
    // WidgetKitのクオータ枯渇とWatchdog Timeoutを防ぐ。
    private var widgetReloadTask: Task<Void, Never>?

    /// 保存先URL
    /// Phase 6でWidgetターゲットを追加しApp Groupエンタイトルメントを設定したら
    /// App Groupコンテナに切り替える
    private var resolvedURL: URL {
        // App Groupエンタイトルメントが設定済みであればApp Groupを使う（Widget共有）
        if let appGroupURL = FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: Constants.appGroupID) {
            return appGroupURL.appendingPathComponent("alarm_events.json")
        }
        // 未設定の場合はDocumentsディレクトリを使う（Phase 6まではこちら）
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return docs.appendingPathComponent("alarm_events.json")
    }

    // MARK: - CRUD

    /// 全AlarmEventを取得する（キャッシュ優先）
    func loadAll() -> [AlarmEvent] {
        if let cache = inMemoryCache { return cache }
        guard let data = try? Data(contentsOf: resolvedURL) else {
            inMemoryCache = []
            return []
        }
        let loaded = (try? JSONDecoder().decode([AlarmEvent].self, from: data)) ?? []
        inMemoryCache = loaded
        return loaded
    }

    /// キャッシュを破棄して次回 loadAll() でディスクから再読み込みさせる
    func invalidateCache() {
        inMemoryCache = nil
    }

    /// AlarmEventを保存・上書きする（idで一致するものを置換、なければ追加）
    func save(_ alarm: AlarmEvent) {
        var all = loadAll()
        if let idx = all.firstIndex(where: { $0.id == alarm.id }) {
            all[idx] = alarm
        } else {
            all.append(alarm)
        }
        persist(all)
    }

    /// 複数のAlarmEventをまとめて保存する
    func saveAll(_ alarms: [AlarmEvent]) {
        persist(alarms)
    }

    /// 指定IDのAlarmEventを取得する
    func find(id: UUID) -> AlarmEvent? {
        loadAll().first { $0.id == id }
    }

    /// eventKitIdentifierでAlarmEventを検索する
    func find(eventKitIdentifier: String) -> AlarmEvent? {
        loadAll().first { $0.eventKitIdentifier == eventKitIdentifier }
    }

    /// remoteEventIdでAlarmEventを検索する（家族リモートスケジュールのロールバック用）
    func find(remoteEventId: String) -> AlarmEvent? {
        loadAll().first { $0.remoteEventId == remoteEventId }
    }

    /// alarmKitIdentifierでAlarmEventを検索する
    /// 単一IDと配列IDの両方を検索する（ジャストアラームなど複数登録時に対応）
    func find(alarmKitID: UUID) -> AlarmEvent? {
        loadAll().first {
            $0.alarmKitIdentifier == alarmKitID ||
            $0.alarmKitIdentifiers.contains(alarmKitID)
        }
    }

    /// 指定IDのAlarmEventを削除する
    func delete(id: UUID) {
        var all = loadAll()
        all.removeAll { $0.id == id }
        persist(all)
    }

    // MARK: - Private

    private func persist(_ alarms: [AlarmEvent]) {
        inMemoryCache = alarms  // キャッシュを先に更新（次回 loadAll() でディスクI/O不要）
        guard let data = try? JSONEncoder().encode(alarms) else { return }
        try? data.write(to: resolvedURL, options: .atomic)
        scheduleWidgetReload()
    }

    /// WidgetCenter への更新リクエストを1秒デバウンスする
    /// 連続保存時に複数回呼ばれても最後の1回だけ実際にリロードする
    private func scheduleWidgetReload() {
        widgetReloadTask?.cancel()
        widgetReloadTask = Task {
            try? await Task.sleep(for: .seconds(1))
            guard !Task.isCancelled else { return }
            WidgetCenter.shared.reloadAllTimelines()
        }
    }
}
