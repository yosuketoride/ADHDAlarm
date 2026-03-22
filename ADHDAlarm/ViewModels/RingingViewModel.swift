import Foundation
import AVFoundation
import AudioToolbox
import Observation

/// アラーム鳴動中の状態管理
/// AlarmKit経由で全画面が起動した際、またはアプリ内テストアラーム時に使用する
@Observable
final class RingingViewModel: NSObject {
    var activeAlarm: AlarmEvent?
    /// エスカレーション発動: 5分間応答なし → SOS iMessageを送る
    var shouldSendSOS = false

    private var audioPlayer: AVAudioPlayer?
    private var speechSynthesizer: AVSpeechSynthesizer?
    private var repeatTimer: Timer?
    /// 5分間応答なしで SOS を送るタイマー
    private var escalationTimer: Timer?
    private let scheduler: AlarmScheduling
    private let voiceGenerator: VoiceSynthesizing
    private var notificationType: NotificationType = .alarmAndVoice
    private var audioOutputMode: AudioOutputMode = .automatic
    /// SOS送信先の電話番号（PRO: 設定画面で家族の番号を登録）
    var sosContactPhone: String?

    init(
        scheduler: AlarmScheduling = AlarmKitScheduler(),
        voiceGenerator: VoiceSynthesizing = VoiceFileGenerator(),
        notificationType: NotificationType = .alarmAndVoice,
        audioOutputMode: AudioOutputMode = .automatic
    ) {
        self.scheduler = scheduler
        self.voiceGenerator = voiceGenerator
        self.notificationType = notificationType
        self.audioOutputMode = audioOutputMode
    }

    // MARK: - 設定反映

    func configure(
        notificationType: NotificationType,
        audioOutputMode: AudioOutputMode,
        sosContactPhone: String? = nil
    ) {
        self.notificationType = notificationType
        self.audioOutputMode = audioOutputMode
        self.sosContactPhone = sosContactPhone
    }

    // MARK: - 音声再生

    /// アラーム画面が表示されたとき音声を再生する
    /// alarmAndVoice: ビープ音 → ナレーション（.cafまたはTTS）を繰り返す
    /// alarmOnly: アプリ側は何も再生しない（AlarmKitのシステム音のみ）
    /// PRO: 5分間応答なしの場合、家族へ SOS iMessage を自動送信する
    func startAudioPlayback() {
        // PRO機能: SOSタイマーを開始（5分 = 300秒後に発動）
        if sosContactPhone != nil {
            escalationTimer = Timer.scheduledTimer(withTimeInterval: 300, repeats: false) { [weak self] _ in
                self?.shouldSendSOS = true
            }
        }
        guard let alarm = activeAlarm else { return }

        // alarmOnly の場合はアプリ側で何も再生しない（AlarmKitのシステム通知音のみ）
        guard notificationType == .alarmAndVoice else { return }

        // ビープ音 → ナレーション の順で再生する
        // AVAudioSession は .caf再生時のみ設定し、AVSpeechSynthesizer は自身で管理させる
        // AlarmKitのシステム音と競合しないよう1.5秒待ってからスタート
        Task { [weak self] in
            guard let self else { return }
            try? await Task.sleep(for: .seconds(1.5))
            guard self.activeAlarm != nil else { return }  // 停止済みなら再生しない
            self.playBeepThenNarration(alarm: alarm)
        }
    }

    /// ビープ音を鳴らし、0.8秒後にナレーションを再生する
    private func playBeepThenNarration(alarm: AlarmEvent) {
        // 「ピピピピ」相当のアラート音を4回鳴らす
        // AudioServicesPlayAlertSound: 着信音量で鳴る（メディア音量に依存しない）
        for i in 0..<4 {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(i) * 0.25) {
                AudioServicesPlayAlertSound(1005)
            }
        }
        // ビープ音4発（約1秒）の後にナレーション再生
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { [weak self] in
            guard let self, self.activeAlarm != nil else { return }
            self.playNarration(alarm: alarm)
        }
    }

    /// ナレーションを再生する（.cafまたはTTSフォールバック）
    private func playNarration(alarm: AlarmEvent) {
        if let fileName = alarm.voiceFileName,
           let url = FileManager.default.urls(for: .libraryDirectory, in: .userDomainMask).first?
               .appendingPathComponent("Sounds")
               .appendingPathComponent(fileName),
           FileManager.default.fileExists(atPath: url.path),
           let player = try? AVAudioPlayer(contentsOf: url) {
            // .caf再生時のみ AVAudioSession を設定する（TTSは自身で管理するため不要）
            do {
                try AVAudioSession.sharedInstance().setCategory(.playback, options: [.duckOthers])
                try AVAudioSession.sharedInstance().setActive(true)
            } catch {
                print("【音声セッション】確保失敗: \(error.localizedDescription)")
            }
            self.audioPlayer = player
            self.audioPlayer?.numberOfLoops = 0  // 1回再生 → delegate で繰り返す
            self.audioPlayer?.delegate = self
            self.audioPlayer?.play()
        } else {
            // .cafなし → TTSで読み上げ（AVSpeechSynthesizerが自身でセッション管理）
            self.speakAlarmTitle(alarm.title, preNotificationMinutes: alarm.preNotificationMinutes)
        }
    }

    func stopAudioPlayback() {
        escalationTimer?.invalidate()
        escalationTimer = nil
        repeatTimer?.invalidate()
        repeatTimer = nil
        if audioPlayer != nil {
            audioPlayer?.stop()
            audioPlayer = nil
            try? AVAudioSession.sharedInstance().setActive(false)
        }
        speechSynthesizer?.stopSpeaking(at: .immediate)
        speechSynthesizer = nil
    }

    private func speakAlarmTitle(_ title: String, preNotificationMinutes: Int = 0) {
        let synthesizer = AVSpeechSynthesizer()
        synthesizer.delegate = self
        // preNotificationMinutes に応じたテキストを生成（VoiceFileGeneratorの仕様に合わせる）
        let minutesText = preNotificationMinutes == 0
            ? "になりました"
            : "まであと\(preNotificationMinutes)分です"
        let text = "お時間です。\(title)\(minutesText)。準備はよろしいですか？"
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: "ja-JP")
        utterance.rate  = 0.48
        utterance.pitchMultiplier = 1.1
        synthesizer.speak(utterance)
        speechSynthesizer = synthesizer  // 参照を保持しないと即解放される
    }

    // MARK: - 停止

    /// 停止: アラームを完全に終了する
    func dismiss() {
        guard let alarm = activeAlarm,
              let alarmKitID = alarm.alarmKitIdentifier else {
            stopAudioPlayback()
            activeAlarm = nil
            return
        }

        stopAudioPlayback()

        Task {
            try? await scheduler.cancel(alarmKitID: alarmKitID)
            activeAlarm = nil
        }
    }
}

// MARK: - AVAudioPlayerDelegate

extension RingingViewModel: AVAudioPlayerDelegate {
    /// 音声ファイル再生終了 → 5秒後にビープ→ナレーションを繰り返す
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        guard let alarm = activeAlarm else { return }
        repeatTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: false) { [weak self] _ in
            self?.playBeepThenNarration(alarm: alarm)
        }
    }
}

// MARK: - AVSpeechSynthesizerDelegate

extension RingingViewModel: AVSpeechSynthesizerDelegate {
    /// 読み上げ終了 → 5秒後にビープ→ナレーションを繰り返す
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        guard let alarm = activeAlarm else { return }
        repeatTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: false) { [weak self] _ in
            self?.playBeepThenNarration(alarm: alarm)
        }
    }
}
