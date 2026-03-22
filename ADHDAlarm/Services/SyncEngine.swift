import Foundation

/// EventKit ⇔ AlarmKit の差分同期エンジン
///
/// 呼び出しタイミング:
/// - アプリがフォアグラウンドに戻るたびに（scenePhase == .active）
/// - ウィジェットのTimeline更新時（ベストエフォート）
///
/// 同期対象: アプリ作成イベントのみ（notesマーカーで識別）
/// 他カレンダーのイベントは一切触らない
final class SyncEngine {

    // MARK: - 依存サービス

    private let calendarProvider: CalendarProviding
    private let alarmScheduler: AlarmScheduling
    private let voiceGenerator: VoiceSynthesizing
    private let eventStore: AlarmEventStore

    init(
        calendarProvider: CalendarProviding  = AppleCalendarProvider(),
        alarmScheduler: AlarmScheduling      = AlarmKitScheduler(),
        voiceGenerator: VoiceSynthesizing    = VoiceFileGenerator(),
        eventStore: AlarmEventStore          = .shared
    ) {
        self.calendarProvider = calendarProvider
        self.alarmScheduler   = alarmScheduler
        self.voiceGenerator   = voiceGenerator
        self.eventStore       = eventStore
    }

    // MARK: - フル同期（メインエントリーポイント）

    /// EventKitとAlarmKitの差分を洗い出し、ローカルマッピングと照合して修正する
    /// アプリのフォアグラウンド復帰時に必ず呼ぶ
    func performFullSync() async {
        // 1. 現在の状態を収集する
        let ekEvents      = (try? await calendarProvider.fetchAppEvents()) ?? []
        let localMappings = eventStore.loadAll()

        // 2. 差分を計算する
        let diffs = computeDiffs(ekEvents: ekEvents, localMappings: localMappings)

        // 3. 差分を解消する（並列実行でも安全だが、順番に処理して安定性を優先）
        for diff in diffs {
            await reconcile(diff)
        }
    }

    // MARK: - 差分計算

    private func computeDiffs(ekEvents: [AlarmEvent], localMappings: [AlarmEvent]) -> [SyncDiff] {
        var diffs: [SyncDiff] = []

        // EventKitのイベントをIDで引ける辞書に変換
        let ekDict = Dictionary(uniqueKeysWithValues: ekEvents.map { ($0.id, $0) })

        // ローカルマッピングのイベントをIDで引ける辞書に変換
        let localDict = Dictionary(uniqueKeysWithValues: localMappings.map { ($0.id, $0) })

        // A. ローカルマッピングを基準にEventKit側の状態を確認
        for local in localMappings {
            if let ekEvent = ekDict[local.id] {
                // EventKit側にイベントが存在する
                if abs(ekEvent.fireDate.timeIntervalSince(local.fireDate)) > 60 {
                    // 1分以上のズレ → 時間が変更されている
                    diffs.append(.mismatch(current: local, newFireDate: ekEvent.fireDate))
                } else {
                    // 一致
                    diffs.append(.matched(local))
                }
            } else {
                // EventKit側からイベントが消えている → アラームを孤立キャンセル
                diffs.append(.orphanedAlarm(
                    alarmKitID: local.alarmKitIdentifier ?? UUID(),
                    voiceFileName: local.voiceFileName
                ))
            }
        }

        // B. EventKit側にあるがローカルマッピングにない → 再スケジュール
        for ekEvent in ekEvents {
            if localDict[ekEvent.id] == nil {
                diffs.append(.orphanedEvent(ekEvent))
            }
        }

        return diffs
    }

    // MARK: - 差分解消

    private func reconcile(_ diff: SyncDiff) async {
        switch diff {

        case .matched:
            // 一致しているので何もしない
            break

        case .mismatch(let current, let newFireDate):
            // EventKitで時間が変更された → AlarmKit再登録 + 音声ファイル再生成
            var updated = current
            updated.fireDate = newFireDate

            // 古いアラームをキャンセル
            if let oldAlarmKitID = current.alarmKitIdentifier {
                try? await alarmScheduler.cancel(alarmKitID: oldAlarmKitID)
            }
            // 音声ファイルを再生成（既存ファイルを削除してから再生成）
            if current.voiceFileName != nil {
                voiceGenerator.deleteAudio(alarmID: current.id)
                updated.voiceFileName = nil
            }
            let speechText = VoiceFileGenerator.speechText(for: updated)
            if let voiceURL = try? await voiceGenerator.generateAudio(
                text: speechText,
                character: updated.voiceCharacter,
                alarmID: updated.id
            ) {
                updated.voiceFileName = voiceURL.lastPathComponent
            }
            // 新しい時間でアラームを再登録
            if let newAlarmKitID = try? await alarmScheduler.schedule(updated) {
                updated.alarmKitIdentifier = newAlarmKitID
            }
            eventStore.save(updated)

        case .orphanedAlarm(let alarmKitID, let voiceFileName):
            // EventKitから削除済み → アラームキャンセル + 音声ファイル削除 + ローカル削除
            try? await alarmScheduler.cancel(alarmKitID: alarmKitID)
            if voiceFileName != nil,
               let alarmEvent = eventStore.find(alarmKitID: alarmKitID) {
                voiceGenerator.deleteAudio(alarmID: alarmEvent.id)
                eventStore.delete(id: alarmEvent.id)
            }

        case .orphanedEvent(let ekEvent):
            // AlarmKitからアラームが消えている（通常は起こらないが念のため再登録）
            var alarm = ekEvent
            // 音声ファイルを新規生成
            let speechText = VoiceFileGenerator.speechText(for: alarm)
            if let voiceURL = try? await voiceGenerator.generateAudio(
                text: speechText,
                character: alarm.voiceCharacter,
                alarmID: alarm.id
            ) {
                alarm.voiceFileName = voiceURL.lastPathComponent
            }
            if let newAlarmKitID = try? await alarmScheduler.schedule(alarm) {
                alarm.alarmKitIdentifier = newAlarmKitID
                eventStore.save(alarm)
            }
        }
    }
}
