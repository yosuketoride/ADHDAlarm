import Foundation
import AVFoundation
import AudioToolbox
import Observation

/// アラーム鳴動中の状態管理
@Observable @MainActor
final class RingingViewModel: NSObject {
    var activeAlarm: AlarmEvent?
    /// SOSのステータス
    var sosStatus: SOSStatus = .idle
    /// スパム防止（1セッションで1回のみ）
    private var hasSentSOS = false

    private var audioPlayer: AVAudioPlayer?
    private var speechSynthesizer: AVSpeechSynthesizer?
    private var repeatTimer: Timer?
    /// 応答なしで SOS を送るタイマー
    var escalationTimer: Timer?
    private let scheduler: AlarmScheduling
    private let voiceGenerator: VoiceSynthesizing
    private let calendarProvider: CalendarProviding
    private var notificationType: NotificationType = .alarmAndVoice
    private var audioOutputMode: AudioOutputMode = .automatic
    /// Supabase LINE連携用のペアリングID
    var sosPairingId: String?
    /// SOSエスカレーションまでの時間（分）
    private var sosEscalationMinutes: Int = 5
    
    private let sosService: SOSNotifying
    private var appState: AppState?

    init(
        scheduler: AlarmScheduling? = nil,
        voiceGenerator: VoiceSynthesizing? = nil,
        calendarProvider: CalendarProviding? = nil,
        notificationType: NotificationType = .alarmAndVoice,
        audioOutputMode: AudioOutputMode = .automatic,
        sosService: SOSNotifying? = nil
    ) {
        self.scheduler = scheduler ?? AlarmKitScheduler()
        self.voiceGenerator = voiceGenerator ?? VoiceFileGenerator()
        self.calendarProvider = calendarProvider ?? AppleCalendarProvider()
        self.notificationType = notificationType
        self.audioOutputMode = audioOutputMode
        self.sosService = sosService ?? SupabaseSOSService()
    }

    func bindAppStateIfNeeded(_ appState: AppState) {
        if self.appState == nil {
            self.appState = appState
        }
    }

    // MARK: - 設定反映

    func configure(
        notificationType: NotificationType,
        audioOutputMode: AudioOutputMode,
        sosPairingId: String? = nil,
        sosEscalationMinutes: Int = 5
    ) {
        self.notificationType = notificationType
        self.audioOutputMode = audioOutputMode
        self.sosPairingId = sosPairingId
        self.sosEscalationMinutes = sosEscalationMinutes
    }

    // MARK: - 音声再生

    /// アラーム画面が表示されたとき音声を再生する
    func startAudioPlayback() {
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
        guard let alarm = activeAlarm else { return }
        guard notificationType == .alarmAndVoice else { return }

        // AVAudioSessionを1回だけ確保（マナーモード貫通 + サイドボタン音量で再生）
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, options: [])
            try AVAudioSession.sharedInstance().setActive(true)
            // AlarmKitは常にデバイスのスピーカーから鳴る。
            // Bluetooth接続中にアプリ音声をイヤホンに流すと二重出力になるため、
            // Bluetooth接続中 or スピーカー強制モードの場合はスピーカーに統一する
            if audioOutputMode == .speaker || isBluetoothOutputActive() {
                try AVAudioSession.sharedInstance().overrideOutputAudioPort(.speaker)
            }
        } catch {
            print("【音声セッション】確保失敗: \(error.localizedDescription)")
        }

        // AlarmKitのシステム音と競合しないよう1.5秒待ってからスタート
        Task { [weak self] in
            guard let self else { return }
            try? await Task.sleep(for: .seconds(1.5))
            guard self.activeAlarm != nil else { return }
            self.playBeepThenNarration(alarm: alarm)
        }
    }

    /// ビープ音を鳴らし、1.2秒後にナレーションを再生する
    private func playBeepThenNarration(alarm: AlarmEvent) {
        // 「ピピピピ」相当のアラート音を4回
        for i in 0..<4 {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(i) * 0.25) {
                AudioServicesPlayAlertSound(1005)
            }
        }
        // ビープ後にナレーション再生
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { [weak self] in
            guard let self, self.activeAlarm != nil else { return }
            self.playNarration(alarm: alarm)
        }
    }

    /// ナレーションを再生する（.cafファイルまたはTTSフォールバック）
    private func playNarration(alarm: AlarmEvent) {
        if let fileName = alarm.voiceFileName,
           let url = FileManager.default.urls(for: .libraryDirectory, in: .userDomainMask).first?
               .appendingPathComponent("Sounds")
               .appendingPathComponent(fileName),
           FileManager.default.fileExists(atPath: url.path),
           let player = try? AVAudioPlayer(contentsOf: url) {
            audioPlayer = player
            audioPlayer?.numberOfLoops = 0
            audioPlayer?.delegate = self
            audioPlayer?.play()
        } else {
            // .cafなし → TTSで読み上げ
            speakAlarmTitle(alarm.title, preNotificationMinutes: alarm.preNotificationMinutes)
        }
    }

    func stopAudioPlayback() {
        NotificationCenter.default.removeObserver(self, name: AVAudioSession.routeChangeNotification, object: nil)
        escalationTimer?.invalidate()
        escalationTimer = nil
        repeatTimer?.invalidate()
        repeatTimer = nil
        if audioPlayer != nil {
            audioPlayer?.stop()
            audioPlayer = nil
            try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        }
        speechSynthesizer?.stopSpeaking(at: .immediate)
        speechSynthesizer = nil
    }

    private func speakAlarmTitle(_ title: String, preNotificationMinutes: Int = 0) {
        // ⚠️ P-4-1: マナーモード中でもTTSが聞こえるようにAudioSessionカテゴリを強制上書き
        // .playback + .voicePrompt を設定しないと、マナーモード中に「アラームは鳴るがふくろうが喋らない」致命的バグが発生する
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .voicePrompt, options: [.duckOthers])
            try session.setActive(true)
        } catch {
            print("【TTS音声セッション】確保失敗: \(error.localizedDescription)")
        }

        let synthesizer = AVSpeechSynthesizer()
        synthesizer.delegate = self
        let minutesText = preNotificationMinutes == 0
            ? "になりました"
            : "まであと\(preNotificationMinutes)分です"
        let rawText = "お時間です。\(title)\(minutesText)。準備はよろしいですか？"
        // P-4-2: 時刻表記（例: 15:30）を「15時30分」に変換してTTSで読めるようにする
        let sanitizedText = sanitizeForTTS(rawText)
        let utterance = AVSpeechUtterance(string: sanitizedText)
        utterance.voice = AVSpeechSynthesisVoice(language: "ja-JP")
        utterance.rate  = 0.48
        utterance.pitchMultiplier = 1.1
        synthesizer.speak(utterance)
        speechSynthesizer = synthesizer
    }

    /// TTS用テキストサニタイズ（P-4-2）
    /// 「15:30」→「15時30分」、「○:00」→「○時ちょうど」に変換
    private func sanitizeForTTS(_ text: String) -> String {
        guard let regex = try? NSRegularExpression(pattern: #"(\d{1,2}):(\d{2})"#) else { return text }
        var result = text
        // 後ろから置換して位置ズレを防ぐ
        let nsResult = result as NSString
        let matches = regex.matches(in: result, range: NSRange(result.startIndex..., in: result)).reversed()
        for match in matches {
            guard let r1 = Range(match.range(at: 1), in: result),
                  let r2 = Range(match.range(at: 2), in: result),
                  let fullRange = Range(match.range, in: result) else { continue }
            let hour   = String(result[r1])
            let minute = String(result[r2])
            let replacement = minute == "00" ? "\(hour)時ちょうど" : "\(hour)時\(minute)分"
            result.replaceSubrange(fullRange, with: replacement)
        }
        _ = nsResult  // 未使用変数警告を防ぐ
        return result
    }

    // MARK: - 音声出力ルート判定

    /// 現在BluetoothデバイスがアクティブなAudio出力かどうかを返す
    private func isBluetoothOutputActive() -> Bool {
        let outputs = AVAudioSession.sharedInstance().currentRoute.outputs
        return outputs.contains(where: {
            [.bluetoothA2DP, .bluetoothLE, .bluetoothHFP].contains($0.portType)
        })
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
        guard let alarm = activeAlarm else {
            stopAudioPlayback()
            activeAlarm = nil
            playPraisePhrase()
            return
        }
        // completionStatus を .completed に更新して永続化
        recordCompletion(for: alarm, status: .completed)
        syncReactionToRemote(alarm: alarm, status: "completed")
        addXP(10)
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
        playPraisePhrase()
    }

    /// スヌーズ（30分後に再アラーム）: completionStatus は変えず snoozeCount をインクリメント（P-2-2）
    func snooze() {
        guard let alarm = activeAlarm else {
            stopAudioPlayback()
            activeAlarm = nil
            return
        }
        var updated = alarm
        updated.snoozeCount = alarm.snoozeCount + 1
        AlarmEventStore.shared.save(updated)
        syncReactionToRemote(alarm: alarm, status: "snoozed")
        stopAudioPlayback()
        let snoozeDate = Date().addingTimeInterval(30 * 60)
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
        guard let alarm = activeAlarm else {
            stopAudioPlayback()
            activeAlarm = nil
            return
        }
        recordCompletion(for: alarm, status: .skipped)
        syncReactionToRemote(alarm: alarm, status: "skipped")
        addXP(3)
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
        var reverted = alarm
        reverted.completionStatus = nil
        // P-9-1: 薬の二重服用トラップ防止 — Undo直後の5分間は家族側からの complete 上書きをブロック
        reverted.undoPendingUntil = Date().addingTimeInterval(5 * 60)
        AlarmEventStore.shared.save(reverted)
        // 再度EKに書き戻す（将来Phase3で実装。現時点はローカル復元のみ）
        activeAlarm = nil
    }

    // MARK: - プライベートヘルパー

    private func recordCompletion(for alarm: AlarmEvent, status: CompletionStatus) {
        var updated = alarm
        updated.completionStatus = status
        AlarmEventStore.shared.save(updated)
    }

    /// 家族から届いた予定に対する反応を Supabase に反映する
    private func syncReactionToRemote(alarm: AlarmEvent, status: String) {
        guard let remoteId = alarm.remoteEventId else { return }
        Task {
            try? await FamilyRemoteService.shared.updateRemoteEventStatus(id: remoteId, status: status)
        }
    }

    private func addXP(_ amount: Int) {
        guard let appState else { return }
        let cap = 50
        let defaults = UserDefaults.standard
        // 日付が変わっていたら今日のXPをリセット
        let lastDate = defaults.object(forKey: Constants.Keys.owlXPLastDate) as? Date ?? .distantPast
        var dailyAdded = defaults.integer(forKey: Constants.Keys.owlXPToday)
        if !Calendar.current.isDateInToday(lastDate) {
            dailyAdded = 0
            defaults.set(0, forKey: Constants.Keys.owlXPToday)
        }
        let actual = min(amount, cap - dailyAdded)
        guard actual > 0 else { return }
        appState.owlXP += actual
        defaults.set(dailyAdded + actual, forKey: Constants.Keys.owlXPToday)
        defaults.set(Date(), forKey: Constants.Keys.owlXPLastDate)
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
            try AVAudioSession.sharedInstance().setCategory(.playback, options: [])
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            print("【褒め言葉】セッション確保失敗: \(error.localizedDescription)")
        }
        let synthesizer = AVSpeechSynthesizer()
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
            self.repeatTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: false) { [weak self] _ in
                Task { @MainActor [weak self] in
                    guard let self else { return }
                    self.playBeepThenNarration(alarm: alarm)
                }
            }
        }
    }
}

// MARK: - AVSpeechSynthesizerDelegate

extension RingingViewModel: AVSpeechSynthesizerDelegate {
    /// 読み上げ終了 → 5秒後にビープ→ナレーションを繰り返す
    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        Task { @MainActor [weak self] in
            guard let self, let alarm = self.activeAlarm else { return }
            self.repeatTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: false) { [weak self] _ in
                Task { @MainActor [weak self] in
                    guard let self else { return }
                    self.playBeepThenNarration(alarm: alarm)
                }
            }
        }
    }
}
