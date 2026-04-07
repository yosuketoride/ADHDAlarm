import Foundation
import AVFoundation
import AudioToolbox
import Observation
import WidgetKit

/// アラーム鳴動中の状態管理
@Observable @MainActor
final class RingingViewModel: NSObject {
    static let maximumSnoozeCount = 3
    static let snoozeInterval: TimeInterval = 30 * 60

    var activeAlarm: AlarmEvent?
    /// SOSのステータス
    var sosStatus: SOSStatus = .idle
    /// スパム防止（1セッションで1回のみ）
    private var hasSentSOS = false

    private var audioPlayer: AudioPlayerControlling?
    private var speechSynthesizer: SpeechSynthesizerControlling?
    private var repeatTimer: Timer?
    private var isPlaybackStarted = false  // 二重呼び出し防止

    /// RingingView を閉じた理由（awaitingResponse 書き込みの要否判定に使う）
    private enum CloseReason { case pending, acted }
    /// ユーザーが明示的に操作した場合は .acted にセットし、awaitingResponse 書き込みを抑制する
    private var closeReason: CloseReason = .pending
    /// 応答なしで SOS を送るタイマー
    var escalationTimer: Timer?
    private let scheduler: AlarmScheduling
    private let voiceGenerator: VoiceSynthesizing
    private let calendarProvider: CalendarProviding
    private var audioOutputMode: AudioOutputMode = .automatic
    /// Supabase LINE連携用のペアリングID
    var sosPairingId: String?
    /// SOSエスカレーションまでの時間（分）
    private var sosEscalationMinutes: Int = 5
    
    private let sosService: SOSNotifying
    private let audioController: AlarmAudioControlling
    private let playbackStartDelay: Duration
    private let undoFinalizeDelay: Duration
    private var appState: AppState?
    /// P-9-13: Undo猶予タスク（30秒後にEK/AlarmKit削除確定）
    private var undoTask: Task<Void, Never>?

    init(
        scheduler: AlarmScheduling? = nil,
        voiceGenerator: VoiceSynthesizing? = nil,
        calendarProvider: CalendarProviding? = nil,
        audioOutputMode: AudioOutputMode = .automatic,
        sosService: SOSNotifying? = nil,
        audioController: AlarmAudioControlling? = nil,
        playbackStartDelay: Duration = .seconds(4),
        undoFinalizeDelay: Duration = .seconds(30)
    ) {
        self.scheduler = scheduler ?? AlarmKitScheduler()
        self.voiceGenerator = voiceGenerator ?? VoiceFileGenerator()
        self.calendarProvider = calendarProvider ?? AppleCalendarProvider()
        self.audioOutputMode = audioOutputMode
        self.sosService = sosService ?? SupabaseSOSService()
        self.audioController = audioController ?? SystemAlarmAudioController()
        self.playbackStartDelay = playbackStartDelay
        self.undoFinalizeDelay = undoFinalizeDelay
    }

    func bindAppStateIfNeeded(_ appState: AppState) {
        if self.appState == nil {
            self.appState = appState
        }
    }

    // MARK: - スヌーズUI

    var currentSnoozeCount: Int {
        activeAlarm?.snoozeCount ?? 0
    }

    var canSnooze: Bool {
        Self.canSnooze(currentSnoozeCount)
    }

    static func canSnooze(_ count: Int) -> Bool {
        count < maximumSnoozeCount
    }

    var snoozeButtonTitle: String {
        currentSnoozeCount == 2
            ? "30分後にまた教えて（最後の1回）"
            : "30分後にまた教えて"
    }

    var snoozeHelperMessage: String? {
        currentSnoozeCount == 2 ? "次はパスか完了を選んでね" : nil
    }

    var snoozeLimitMessage: String {
        "🦉 何度もお知らせしたよ。今日は無理せず「今回はパス」にしてね"
    }

    var shouldShowSnoozeLimitArrow: Bool {
        !canSnooze
    }

    // MARK: - 設定反映

    func configure(
        audioOutputMode: AudioOutputMode,
        sosPairingId: String? = nil,
        sosEscalationMinutes: Int = 5
    ) {
        self.audioOutputMode = audioOutputMode
        self.sosPairingId = sosPairingId
        self.sosEscalationMinutes = sosEscalationMinutes
    }

    // MARK: - 音声再生

    /// アラーム画面が表示されたとき音声を再生する
    func startAudioPlayback() {
        guard !isPlaybackStarted else {
            print("【音声再生】startAudioPlayback() の二重呼び出しを防止した")
            return
        }
        isPlaybackStarted = true
        closeReason = .pending  // 本当に新しい鳴動セッションを開始するときだけ pending に戻す
        // イヤホン切断監視を開始
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleRouteChange(_:)),
            name: AVAudioSession.routeChangeNotification,
            object: nil
        )
        // PRO機能: SOSタイマーを開始 (ペアリング済みのLINE、または電話番号がある場合)
        print("DEBUG: startAudioPlayback - sosPairingId: \(sosPairingId ?? "nil")")
        if sosPairingId != nil {
            // sosEscalationMinutes == 0 はデバッグビルド専用の「10秒テストモード」
            #if DEBUG
            let interval = sosEscalationMinutes == 0 ? 10.0 : Double(sosEscalationMinutes * 60)
            #else
            let interval = Double(sosEscalationMinutes * 60)
            #endif
            print("DEBUG: SOS timer scheduled for \(interval) seconds from now")
            escalationTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: false) { [weak self] _ in
                print("DEBUG: SOS Escalation Timer FIRED!")
                Task {
                    await self?.sendSOSAutomatically()
                }
            }
        }
        guard let alarm = activeAlarm else {
            print("【音声再生】activeAlarmがnil → 早期リターン")
            return
        }

        // AlarmKitのシステム音を鳴らし終わるまで待ってからAudioSessionを確保する。
        // 起動直後に setActive(true) するとAlarmKitの音が即座に止まってしまうため。
        Task { [weak self] in
            guard let self else { return }
            // AlarmKitのシステム音は通常3〜5秒で終わる
            try? await Task.sleep(for: playbackStartDelay)
            guard self.activeAlarm != nil else { return }
            self.acquireAudioSessionAndStartLoop(alarm: alarm)
        }
    }

    /// AudioSessionを確保してナレーションループを開始する
    private func acquireAudioSessionAndStartLoop(alarm: AlarmEvent) {
        do {
            try audioController.configurePlaybackSession(
                mode: .voicePrompt,
                options: [],
                forceSpeaker: shouldForceSpeakerOutput
            )
        } catch {
            print("【音声セッション】確保失敗: \(error.localizedDescription)")
        }
        startAlarmLoop(alarm: alarm)
    }

    /// ユーザーが操作するまでナレーションをループ再生する
    /// 次回再生は AVAudioPlayer / AVSpeechSynthesizer の完了後に予約する
    private func startAlarmLoop(alarm: AlarmEvent) {
        repeatTimer?.invalidate()
        repeatTimer = nil
        playNarration(alarm: alarm)
    }


    /// ナレーションを再生する（.cafファイルまたはTTSフォールバック）
    private func playNarration(alarm: AlarmEvent) {
        let fileName = alarm.voiceFileName
        print("【音声再生】playNarration開始 voiceFileName=\(fileName ?? "nil")")

        let fileSize: Int
        if let fn = fileName,
           let url = FileManager.default.urls(for: .libraryDirectory, in: .userDomainMask).first?
               .appendingPathComponent("Sounds").appendingPathComponent(fn) {
            let exists = FileManager.default.fileExists(atPath: url.path)
            fileSize = ((try? FileManager.default.attributesOfItem(atPath: url.path))?[FileAttributeKey.size] as? Int) ?? 0
            print("【音声再生】.cafファイル exists=\(exists) size=\(fileSize)bytes path=\(url.path)")
        } else {
            fileSize = 0
        }

        if let fn = fileName,
           let url = FileManager.default.urls(for: .libraryDirectory, in: .userDomainMask).first?
               .appendingPathComponent("Sounds")
               .appendingPathComponent(fn),
           FileManager.default.fileExists(atPath: url.path),
           fileSize > 0,
           let player = try? audioController.makeAudioPlayer(url: url) {
            do {
                try audioController.configurePlaybackSession(
                    mode: .voicePrompt,
                    options: [.duckOthers],
                    forceSpeaker: shouldForceSpeakerOutput
                )
                print("【音声再生】AudioSession設定成功 → .caf再生開始")
            } catch {
                print("【音声セッション】.caf再生前の設定失敗: \(error.localizedDescription) → TTSへ")
                speakAlarmTitle(alarm)
                return
            }
            audioPlayer = player
            audioPlayer?.numberOfLoops = 0
            audioPlayer?.delegate = self
            audioPlayer?.prepareToPlay()
            let success = audioPlayer?.play() ?? false
            print("【音声再生】AVAudioPlayer.play() → \(success ? "成功" : "失敗")")
            if !success {
                audioPlayer = nil
                speakAlarmTitle(alarm)
            }
        } else {
            print("【音声再生】.cafなし or サイズ0 → TTS使用")
            speakAlarmTitle(alarm)
        }
    }

    func stopAudioPlayback() {
        isPlaybackStarted = false
        NotificationCenter.default.removeObserver(self, name: AVAudioSession.routeChangeNotification, object: nil)
        escalationTimer?.invalidate()
        escalationTimer = nil
        repeatTimer?.invalidate()
        repeatTimer = nil
        if audioPlayer != nil {
            audioPlayer?.stop()
            audioPlayer = nil
            try? audioController.deactivatePlaybackSession()
        }
        speechSynthesizer?.stopSpeaking(at: .immediate)
        speechSynthesizer = nil
    }

    private func speakAlarmTitle(_ alarm: AlarmEvent, retryCount: Int = 0) {
        // ⚠️ P-4-1: マナーモード中でもTTSが聞こえるようにAudioSessionカテゴリを強制上書き
        // .playback + .voicePrompt を設定しないと、マナーモード中に「アラームは鳴るがふくろうが喋らない」致命的バグが発生する
        do {
            try audioController.configurePlaybackSession(
                mode: .voicePrompt,
                options: [.duckOthers],
                forceSpeaker: shouldForceSpeakerOutput
            )
        } catch {
            print("【TTS音声セッション】確保失敗(\(retryCount)回目): \(error.localizedDescription)")
            // セッション確保失敗時は2秒後にリトライ（最大2回）
            if retryCount < 2 {
                Task { [weak self] in
                    guard let self, self.activeAlarm != nil else { return }
                    try? await Task.sleep(for: .seconds(2))
                    self.speakAlarmTitle(alarm, retryCount: retryCount + 1)
                }
            }
            return
        }

        let synthesizer = audioController.makeSpeechSynthesizer()
        synthesizer.delegate = self
        let minutesText = alarm.preNotificationMinutes == 0
            ? "になりました"
            : "まであと\(alarm.preNotificationMinutes)分です"
        let rawText = "お時間です。\(alarm.title)\(minutesText)。準備はよろしいですか？"
        let utterance = VoiceFileGenerator.makeUtterance(
            text: rawText,
            character: alarm.voiceCharacter,
            isClearVoiceEnabled: appState?.isClearVoiceEnabled == true
        )
        synthesizer.speak(utterance)
        speechSynthesizer = synthesizer
    }

    /// 発話終了後の次回ナレーションを予約する
    private func scheduleNextNarration(after interval: TimeInterval, alarm: AlarmEvent) {
        repeatTimer?.invalidate()
        repeatTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: false) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self, self.activeAlarm != nil else { return }
                self.playNarration(alarm: alarm)
            }
        }
    }

    // MARK: - 音声出力ルート判定

    /// 現在BluetoothデバイスがアクティブなAudio出力かどうかを返す
    private func isBluetoothOutputActive() -> Bool {
        audioController.currentOutputPortTypes.contains {
            [.bluetoothA2DP, .bluetoothLE, .bluetoothHFP].contains($0)
        }
    }

    /// スピーカー強制が必要かを返す
    private var shouldForceSpeakerOutput: Bool {
        audioOutputMode == .speaker || isBluetoothOutputActive()
    }

    // MARK: - イヤホン切断検知

    /// イヤホン・Bluetoothが切断されたとき、音声のみ停止してスピーカー漏れを防ぐ
    @objc private func handleRouteChange(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let reasonValue = userInfo[AVAudioSessionRouteChangeReasonKey] as? UInt,
              let reason = AVAudioSession.RouteChangeReason(rawValue: reasonValue),
              reason == .oldDeviceUnavailable else { return }

        // 切断前のルートにヘッドフォン/Bluetoothが含まれていたか確認
        let previousRoute = userInfo[AVAudioSessionRouteChangePreviousRouteKey] as? AVAudioSessionRouteDescription
        let hadHeadphones = previousRoute?.outputs.contains(where: {
            [.headphones, .bluetoothA2DP, .bluetoothLE, .bluetoothHFP].contains($0.portType)
        }) ?? false

        guard hadHeadphones else { return }

        // 音声のみ停止（activeAlarmは残してアラーム画面を表示し続ける）
        DispatchQueue.main.async { [weak self] in
            self?.stopAudioPlayback()
        }
    }

    // MARK: - 停止

    func dismiss() {
        closeReason = .acted  // ユーザーが明示的に停止 → awaitingResponse 書き込みを抑制
        guard let alarm = activeAlarm else {
            stopAudioPlayback()
            activeAlarm = nil
            playPraisePhrase()
            return
        }
        // watchAlarmUpdatesの再検知を防ぐためにHandledAlarmStoreへ登録する
        let alarmKitIDs = !alarm.alarmKitIdentifiers.isEmpty
            ? alarm.alarmKitIdentifiers
            : [alarm.alarmKitIdentifier].compactMap { $0 }
        alarmKitIDs.forEach { HandledAlarmStore.shared.markHandled($0) }
        // completionStatus を .completed に更新して永続化
        recordCompletion(for: alarm, status: .completed)
        print("✅ [RingingViewModel/dismiss] ローカル完了保存 alarmID=\(alarm.id) remoteEventId=\(alarm.remoteEventId ?? "nil")")
        print("🔄 [RingingViewModel/dismiss] remote へ completed 送信を開始 remoteEventId=\(alarm.remoteEventId ?? "nil")")
        syncReactionToRemote(alarm: alarm, status: "completed")
        appState?.addXP(10)
        stopAudioPlayback()
        activeAlarm = nil
        playPraisePhrase()

        // P-9-13: EK/AlarmKit削除は30秒後（Undo猶予期間）
        undoTask?.cancel()
        undoTask = Task { [weak self] in
            guard !Task.isCancelled, let self else { return }
            try? await Task.sleep(for: self.undoFinalizeDelay)
            guard !Task.isCancelled else { return }
            // EK から削除（SyncEngine による復活を防ぐ）
            if let ekID = alarm.eventKitIdentifier {
                try? await self.calendarProvider.deleteEvent(eventKitIdentifier: ekID)
            }
            if let alarmKitID = alarm.alarmKitIdentifier {
                try? await self.scheduler.cancel(alarmKitID: alarmKitID)
            }
            WidgetCenter.shared.reloadAllTimelines()
        }
    }

    /// スヌーズ（30分後に再アラーム）: completionStatus は変えず snoozeCount をインクリメント（P-2-2）
    func snooze() {
        guard let alarm = activeAlarm else {
            stopAudioPlayback()
            activeAlarm = nil
            return
        }
        guard Self.canSnooze(alarm.snoozeCount) else { return }
        closeReason = .acted  // スヌーズ確定 → awaitingResponse 書き込みを抑制
        var updated = alarm
        updated.snoozeCount = alarm.snoozeCount + 1
        AlarmEventStore.shared.save(updated)
        syncReactionToRemote(alarm: alarm, status: "snoozed")
        stopAudioPlayback()
        let snoozeDate = Date().addingTimeInterval(Self.snoozeInterval)
        // 新しいアラームイベントとして30分後に再登録する
        var snoozedAlarm = alarm
        snoozedAlarm = AlarmEvent(
            id: alarm.id,
            title: alarm.title,
            fireDate: snoozeDate,
            preNotificationMinutes: 0,
            eventKitIdentifier: alarm.eventKitIdentifier,
            alarmKitIdentifier: nil,
            alarmKitIdentifiers: [],
            alarmKitMinutesMap: [:],
            voiceFileName: alarm.voiceFileName,
            calendarIdentifier: alarm.calendarIdentifier,
            voiceCharacter: alarm.voiceCharacter,
            createdAt: alarm.createdAt,
            recurrenceRule: alarm.recurrenceRule,
            recurrenceGroupID: alarm.recurrenceGroupID,
            remoteEventId: alarm.remoteEventId,
            eventEmoji: alarm.eventEmoji,
            completionStatus: nil,
            snoozeCount: updated.snoozeCount
        )
        Task {
            if let alarmKitID = alarm.alarmKitIdentifier {
                try? await scheduler.cancel(alarmKitID: alarmKitID)
            }
            // AlarmKitに30分後で再登録
            let alarmKitID = try? await scheduler.schedule(snoozedAlarm)
            let alarmKitIDs: [UUID] = alarmKitID.map { [$0] } ?? []
            var final = snoozedAlarm
            final.alarmKitIdentifiers = alarmKitIDs
            final.alarmKitIdentifier = alarmKitIDs.first
            AlarmEventStore.shared.save(final)
            activeAlarm = nil
        }
    }

    /// スキップ（今日は休む）: completionStatus を .skipped にして XP +3
    func skip() {
        closeReason = .acted  // ユーザーが明示的にスキップ → awaitingResponse 書き込みを抑制
        guard let alarm = activeAlarm else {
            stopAudioPlayback()
            activeAlarm = nil
            return
        }
        // watchAlarmUpdatesの再検知を防ぐためにHandledAlarmStoreへ登録する
        let alarmKitIDs = !alarm.alarmKitIdentifiers.isEmpty
            ? alarm.alarmKitIdentifiers
            : [alarm.alarmKitIdentifier].compactMap { $0 }
        alarmKitIDs.forEach { HandledAlarmStore.shared.markHandled($0) }
        recordCompletion(for: alarm, status: .skipped)
        syncReactionToRemote(alarm: alarm, status: "skipped")
        appState?.addXP(3)
        stopAudioPlayback()
        Task {
            // EK から削除（SyncEngine による復活を防ぐ）
            if let ekID = alarm.eventKitIdentifier {
                try? await calendarProvider.deleteEvent(eventKitIdentifier: ekID)
            }
            if let alarmKitID = alarm.alarmKitIdentifier {
                try? await scheduler.cancel(alarmKitID: alarmKitID)
            }
            activeAlarm = nil
        }
    }

    // MARK: - Undo完了（P-2-1/P-9-13）

    /// 完了をUndoする: completionStatus を nil に戻す（P-2-1/P-9-1）
    func undoCompletion(alarm: AlarmEvent) {
        // P-9-13: 削除タスクをキャンセル（30秒猶予内ならEK/AlarmKitは消えない）
        undoTask?.cancel()
        undoTask = nil
        var reverted = alarm
        reverted.completionStatus = nil
        // P-9-1: 薬の二重服用トラップ防止 — Undo直後の5分間は家族側からの complete 上書きをブロック
        reverted.undoPendingUntil = Date().addingTimeInterval(5 * 60)
        AlarmEventStore.shared.save(reverted)
        // 再度EKに書き戻す（将来Phase3で実装。現時点はローカル復元のみ）
        activeAlarm = reverted
    }

    // MARK: - プライベートヘルパー

    private func recordCompletion(for alarm: AlarmEvent, status: CompletionStatus) {
        var updated = alarm
        updated.completionStatus = status
        AlarmEventStore.shared.save(updated)
    }

    /// 操作なしで RingingView が閉じた場合に awaitingResponse を記録する。
    /// dismiss / skip / snooze のいずれかが呼ばれていた場合は何もしない。
    func recordAwaitingIfUntouched(alarm: AlarmEvent) {
        guard closeReason == .pending else { return }
        recordCompletion(for: alarm, status: .awaitingResponse)
    }

    /// 家族から届いた予定に対する反応を Supabase に反映する
    private func syncReactionToRemote(alarm: AlarmEvent, status: String) {
        guard let remoteId = alarm.remoteEventId else {
            print("⚠️ [RingingViewModel/syncReactionToRemote] remoteEventId が nil のため送信スキップ alarmID=\(alarm.id)")
            return
        }
        print("🔄 [RingingViewModel/syncReactionToRemote] 送信 status=\(status) eventID=\(remoteId)")
        Task {
            await OfflineActionQueue.shared.sendOrEnqueueStatusUpdate(eventID: remoteId, status: status)
        }
    }

    // MARK: - 褒め言葉（アラーム停止時のポジティブフィードバック）

    /// 毎回異なる褒め言葉をランダムに再生して、止める行動を強化する
    private static let praisePhrases: [String] = [
        "えらいですね！今日もよくできました。",
        "すごい！ちゃんと止められましたね。",
        "完璧です！その調子ですよ。",
        "よくできました！自分を褒めてあげましょう。",
        "さすがですね！ばっちりです。",
        "おみごと！今日もよくがんばりましたね。",
        "すばらしい！きちんと確認できていますよ。",
        "花丸です！今日も頑張りましたね。",
        "パーフェクト！やっぱりあなたはすごい。",
        "いいね！その勢いで今日も一日がんばろう。",
        "よし！完璧に対応できましたね。",
        "さすがです！時間通りに確認できました。",
        "素晴らしい行動力です！",
        "今日もよくできました。自分に拍手！",
        "ナイスです！アラームをちゃんと止めましたよ。",
        "しっかり確認できましたね。頼もしい！",
        "よくできました！これが積み重なって大きな成果になります。",
        "ありがとう！ちゃんと気づいてくれましたね。",
        "さすがの一言です！今日も一歩前進しましたよ。",
        "よくできました！今日の自分をたくさん褒めてあげて。",
    ]

    private func playPraisePhrase() {
        let phrase = Self.praisePhrases.randomElement() ?? "よくできました！"
        do {
            try audioController.configurePlaybackSession(
                mode: .default,
                options: [],
                forceSpeaker: false
            )
        } catch {
            print("【褒め言葉】セッション確保失敗: \(error.localizedDescription)")
        }
        let synthesizer = audioController.makeSpeechSynthesizer()
        let utterance = AVSpeechUtterance(string: phrase)
        utterance.voice = AVSpeechSynthesisVoice(language: "ja-JP")
        utterance.rate = 0.50
        utterance.pitchMultiplier = 1.15
        synthesizer.speak(utterance)
        speechSynthesizer = synthesizer
    }
    
    // MARK: - SOS送信（LINE）
    
    @MainActor
    private func sendSOSAutomatically() async {
        print("DEBUG: sendSOSAutomatically invoked")
        guard !hasSentSOS else { 
            print("DEBUG: SOS already sent or pending. Skipping.")
            return 
        }
        guard let alarm = activeAlarm else { 
            print("DEBUG: No active alarm. Skipping SOS.")
            return 
        }
        
        hasSentSOS = true
        
        // LINE連携（Supabase）でSOS送信
        guard let pairingId = sosPairingId else {
            print("DEBUG: No SOS destination (LINE pairing) configured.")
            return
        }
        print("DEBUG: Triggering LINE SOS via Supabase. pairingId: \(pairingId)")
        sosStatus = .sending
        do {
            try await sosService.sendSOS(pairingId: pairingId, alarmTitle: alarm.title, minutes: sosEscalationMinutes)
            print("DEBUG: LINE SOS sent successfully!")
            sosStatus = .sent
        } catch {
            print("DEBUG: LINE SOS FAILED: \(error)")
            sosStatus = .failed(error.localizedDescription)
        }
    }
}

// MARK: - AVAudioPlayerDelegate

extension RingingViewModel: AVAudioPlayerDelegate {
    /// 音声ファイル再生終了 → 5秒後にビープ→ナレーションを繰り返す
    nonisolated func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        Task { @MainActor [weak self] in
            guard let self, let alarm = self.activeAlarm else { return }
            self.scheduleNextNarration(after: 5.0, alarm: alarm)
        }
    }
}

// MARK: - AVSpeechSynthesizerDelegate

extension RingingViewModel: AVSpeechSynthesizerDelegate {
    /// 読み上げ終了 → 5秒後にビープ→ナレーションを繰り返す
    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        Task { @MainActor [weak self] in
            guard let self, let alarm = self.activeAlarm else { return }
            self.scheduleNextNarration(after: 5.0, alarm: alarm)
        }
    }
}
