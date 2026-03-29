import Foundation
import EventKit
import UserNotifications

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
    private let familyService: FamilyScheduling?

    init(
        calendarProvider: CalendarProviding  = AppleCalendarProvider(),
        alarmScheduler: AlarmScheduling      = AlarmKitScheduler(),
        voiceGenerator: VoiceSynthesizing    = VoiceFileGenerator(),
        eventStore: AlarmEventStore          = .shared,
        familyService: FamilyScheduling?     = FamilyRemoteService.shared
    ) {
        self.calendarProvider = calendarProvider
        self.alarmScheduler   = alarmScheduler
        self.voiceGenerator   = voiceGenerator
        self.eventStore       = eventStore
        self.familyService    = familyService
    }

    // MARK: - フル同期（メインエントリーポイント）

    /// EventKitとAlarmKitの差分を洗い出し、ローカルマッピングと照合して修正する
    /// アプリのフォアグラウンド復帰時に必ず呼ぶ
    func performFullSync() async {
        // カレンダー権限がない場合はスキップ
        // 権限なしでfetchAppEventsが空を返すと、全ローカルイベントが誤削除される
        let authStatus = EKEventStore.authorizationStatus(for: .event)
        guard authStatus == .fullAccess || authStatus == .authorized else { return }

        // 1. 現在の状態を収集する
        let ekEvents      = (try? await calendarProvider.fetchAppEvents()) ?? []
        let localMappings = eventStore.loadAll()

        // EventKitが空なのにローカルにイベントがある場合はスキップ
        // （EventKitキャッシュ未更新 or 一時的な読み取り失敗の可能性があり、誤削除を防ぐ）
        if ekEvents.isEmpty && !localMappings.isEmpty { return }

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

    // MARK: - 家族リモートスケジュール同期

    /// 家族から届いた予定を取り込み、キャンセルされた予定を削除する
    /// アプリのフォアグラウンド復帰時に performFullSync() と合わせて呼ぶ
    /// - Returns: 新たに取り込んだ予定の件数（バッジ・バナー表示用）
    @discardableResult
    func syncRemoteEvents() async -> Int {
        guard let service = familyService else {
            print("[SyncEngine] familyService が nil のためスキップ")
            return 0
        }
        var syncedCount = 0

        // pending（未同期）の新規予定を取り込む
        do {
            let pendingEvents = try await service.fetchPendingEvents()
            print("[SyncEngine] pending件数: \(pendingEvents.count)")
            for record in pendingEvents {
                let integrated = await integrateRemoteEvent(record, service: service)
                if integrated { syncedCount += 1 }
            }
        } catch {
            print("[SyncEngine] fetchPendingEvents エラー: \(error)")
        }

        // cancelled（子がキャンセルした）予定をロールバックする
        do {
            let cancelledEvents = try await service.fetchCancelledEvents()
            print("[SyncEngine] cancelled件数: \(cancelledEvents.count)")
            for record in cancelledEvents {
                await rollbackRemoteEvent(record, service: service)
            }
        } catch {
            print("[SyncEngine] fetchCancelledEvents エラー: \(error)")
        }

        print("[SyncEngine] syncRemoteEvents 完了: \(syncedCount)件取り込み")
        return syncedCount
    }

    /// リモート予定をローカルに取り込む（AlarmKit登録 + EventKit書き込み + ローカル保存）
    /// - Returns: 取り込み成功かどうか（重複スキップ時はfalse）
    private func integrateRemoteEvent(_ record: RemoteEventRecord, service: FamilyScheduling) async -> Bool {
        // 既に同期済みのイベントはスキップ（重複防止）
        guard eventStore.find(remoteEventId: record.id) == nil else {
            print("[SyncEngine] \(record.title) は既に同期済みのためスキップ")
            return false
        }

        print("[SyncEngine] 取り込み開始: \(record.title) / \(record.fireDate)")

        // RemoteEventRecordをAlarmEventに変換
        var alarm = AlarmEvent(
            title: record.title,
            fireDate: record.fireDate,
            preNotificationMinutes: record.preNotificationMinutes,
            voiceCharacter: VoiceCharacter(rawValue: record.voiceCharacter) ?? .femaleConcierge,
            remoteEventId: record.id
        )

        // 音声ファイルを生成
        let speechText = VoiceFileGenerator.speechText(for: alarm)
        if let voiceURL = try? await voiceGenerator.generateAudio(
            text: speechText,
            character: alarm.voiceCharacter,
            alarmID: alarm.id
        ) {
            alarm.voiceFileName = voiceURL.lastPathComponent
            print("[SyncEngine] 音声ファイル生成: \(voiceURL.lastPathComponent)")
        } else {
            print("[SyncEngine] 音声ファイル生成スキップ（失敗 or 権限なし）")
        }

        // AlarmKit登録
        if let alarmKitID = try? await alarmScheduler.schedule(alarm) {
            alarm.alarmKitIdentifier = alarmKitID
            print("[SyncEngine] AlarmKit登録: \(alarmKitID)")
        } else {
            print("[SyncEngine] AlarmKit登録スキップ（失敗 or 権限なし）")
        }

        // EventKit書き込み
        if let ekIdentifier = try? await calendarProvider.writeEvent(alarm, to: nil) {
            alarm.eventKitIdentifier = ekIdentifier
            print("[SyncEngine] EventKit書き込み完了")
        } else {
            print("[SyncEngine] EventKit書き込みスキップ（失敗 or 権限なし）")
        }

        // ローカルストアに保存
        eventStore.save(alarm)
        print("[SyncEngine] ローカル保存完了")

        // Supabaseのステータスを同期済みに更新
        do {
            try await service.markEventSynced(id: record.id)
            print("[SyncEngine] Supabase status → synced")
        } catch {
            print("[SyncEngine] markEventSynced エラー: \(error)")
        }

        // 「家族から予定が届きました」ローカル通知
        await notifyFamilyEventArrived(title: alarm.title)

        return true
    }

    /// キャンセルされたリモート予定をロールバックする（AlarmKit削除 + EventKit削除 + ローカル削除）
    private func rollbackRemoteEvent(_ record: RemoteEventRecord, service: FamilyScheduling) async {
        // ローカルのAlarmEventを検索
        guard let alarm = eventStore.find(remoteEventId: record.id) else {
            // ローカルにない場合でも rolled_back にマークしておく（再ロールバック防止）
            try? await service.markEventRolledBack(id: record.id)
            return
        }

        // AlarmKitアラームを削除（複数アラーム対応）
        if !alarm.alarmKitIdentifiers.isEmpty {
            try? await alarmScheduler.cancelAll(alarmKitIDs: alarm.alarmKitIdentifiers)
        } else if let alarmKitID = alarm.alarmKitIdentifier {
            try? await alarmScheduler.cancel(alarmKitID: alarmKitID)
        }

        // EventKitイベントを削除
        if let ekIdentifier = alarm.eventKitIdentifier {
            try? await calendarProvider.deleteEvent(eventKitIdentifier: ekIdentifier)
        }

        // 音声ファイルを削除
        voiceGenerator.deleteAudio(alarmID: alarm.id)

        // ローカルストアから削除
        eventStore.delete(id: alarm.id)

        // Supabaseのステータスをrolled_backに更新
        try? await service.markEventRolledBack(id: record.id)
    }

    /// ローカル通知で「家族から予定が届きました」をユーザーに知らせる
    private func notifyFamilyEventArrived(title: String) async {
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()
        print("[SyncEngine] 通知権限状態: \(settings.authorizationStatus.rawValue)")
        guard settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional else {
            print("[SyncEngine] 通知権限なし → 通知スキップ")
            return
        }

        let content = UNMutableNotificationContent()
        content.title = "家族から予定が届きました"
        content.body = "「\(title)」が自動でアラームにセットされました。"
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: "family-event-\(UUID().uuidString)",
            content: content,
            trigger: nil  // 即時配信
        )
        do {
            try await center.add(request)
            print("[SyncEngine] 通知スケジュール完了: \(title)")
        } catch {
            print("[SyncEngine] 通知スケジュールエラー: \(error)")
        }
    }
}
