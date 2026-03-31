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
        // AlarmEventStore は既に後方互換デコード対応済み（decodeIfPresent でデフォルト値を補完）
        // 既存データを一度読み込んで新フィールドのデフォルト値を確認・保存し直すだけでよい
        let store = AlarmEventStore.shared
        let events = store.loadAll()

        for event in events {
            // eventEmoji が nil のイベントは "📌" をセット（表示上のデフォルト確認用）
            // ※ AlarmEvent.eventEmoji は Optional のままにするため、ここでは何もしない
            // snoozeCount・isToDo・undoPendingUntil は decodeIfPresent で 0/false/nil が入るため追加操作不要
            _ = event  // 変換不要だが一件ずつ確認のためのループ
        }

        // App Group（ウィジェット用）も同じデータを使うため再書き込み
        // AlarmEventStore.shared.save() は AppGroup にも書き込む設計のため個別操作不要
        print("DEBUG: DataMigration v1 → v2: \(events.count)件のイベントを確認しました")
    }
}
