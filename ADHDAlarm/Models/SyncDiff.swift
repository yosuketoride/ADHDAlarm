import Foundation

/// SyncEngineが算出する差分の種類
enum SyncDiff {
    /// EventKitとAlarmKitが一致している → 処理不要
    case matched(AlarmEvent)

    /// EventKit側でfieDateが変更された → AlarmKit再スケジュール + 音声ファイル再生成
    case mismatch(current: AlarmEvent, newFireDate: Date)

    /// EventKitから予定が削除されたが、AlarmKitにアラームが残っている → アラームキャンセル
    /// AlarmEvent全体を渡すことで alarmKitIdentifiers（複数）を漏れなくキャンセルできる（レビュー指摘 #2）
    case orphanedAlarm(AlarmEvent)

    /// AlarmKitからアラームが消えたが、EventKitに予定が残っている → 再スケジュール
    case orphanedEvent(AlarmEvent)
}
