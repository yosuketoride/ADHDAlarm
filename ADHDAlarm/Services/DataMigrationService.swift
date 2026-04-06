import Foundation

/// データモデルバージョン管理・マイグレーションサービス（P-9-6）
/// アプリ起動時に呼び出し、古いデータ構造を現在のバージョンに変換する
final class DataMigrationService {

    /// 現在のデータモデルバージョン
    /// v16リリース = version 2（snoozeCount・isToDo・undoPendingUntil追加）
    static let currentVersion = 2

    private static let versionKey = "dataModelVersion"

    /// 必要であればマイグレーションを実行する
    /// アプリ起動時（ADHDAlarmApp.init内）で呼ぶこと
    static func migrateIfNeeded() {
        let storedVersion = UserDefaults.standard.integer(forKey: versionKey)
        guard storedVersion < currentVersion else { return }

        if storedVersion < 2 {
            migrateToV2()
        }

        UserDefaults.standard.set(currentVersion, forKey: versionKey)
        print("DEBUG: DataMigration → v\(currentVersion) 完了")
    }

    // MARK: - v1 → v2（snoozeCount・isToDo・undoPendingUntil追加）

    private static func migrateToV2() {
        // AlarmEventStore は後方互換デコード対応済み（decodeIfPresent でデフォルト値を補完）。
        // ただし「読み込むだけ」ではディスク上のJSONは古いV1フォーマットのまま残る。
        // レビュー指摘 #5: saveAll() で明示的に書き戻し、次回起動時も正しく読める状態にする。
        let store = AlarmEventStore.shared
        let events = store.loadAll().map { alarm -> AlarmEvent in
            guard alarm.eventEmoji?.isEmpty != false else { return alarm }
            var updated = alarm
            updated.eventEmoji = "📌"
            return updated
        }
        store.saveAll(events)
        print("DEBUG: DataMigration v1 → v2: \(events.count)件のイベントを書き直しました")
    }
}
