import Foundation

/// AlarmEventのマッピング（eventKitID ⇔ alarmKitID）を永続化するストア
/// App Groupコンテナに保存してウィジェットとも共有する
final class AlarmEventStore {

    static let shared = AlarmEventStore()

    private let storageKey = Constants.Keys.alarmEventMappings

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

    /// 全AlarmEventを取得する
    func loadAll() -> [AlarmEvent] {
        guard let data = try? Data(contentsOf: resolvedURL) else { return [] }
        return (try? JSONDecoder().decode([AlarmEvent].self, from: data)) ?? []
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
        guard let data = try? JSONEncoder().encode(alarms) else { return }
        try? data.write(to: resolvedURL, options: .atomic)
    }
}
