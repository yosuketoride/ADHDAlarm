import Foundation
import AVFoundation
import AudioToolbox
import Observation

/// アラーム鳴動中の状態管理
@Observable
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
    private var notificationType: NotificationType = .alarmAndVoice
    private var audioOutputMode: AudioOutputMode = .automatic
    /// Supabase LINE連携用のペアリングID
    var sosPairingId: String?
    /// SOSエスカレーションまでの時間（分）
    private var sosEscalationMinutes: Int = 5
    
    private let sosService: SOSNotifying

    init(
        scheduler: AlarmScheduling = AlarmKitScheduler(),
        voiceGenerator: VoiceSynthesizing = VoiceFileGenerator(),
        notificationType: NotificationType = .alarmAndVoice,
        audioOutputMode: AudioOutputMode = .automatic,
        sosService: SOSNotifying = SupabaseSOSService()
    ) {
        self.scheduler = scheduler
        self.voiceGenerator = voiceGenerator
        self.notificationType = notificationType
        self.audioOutputMode = audioOutputMode
        self.sosService = sosService
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
        let synthesizer = AVSpeechSynthesizer()
        synthesizer.delegate = self
        let minutesText = preNotificationMinutes == 0
            ? "になりました"
            : "まであと\(preNotificationMinutes)分です"
        let text = "お時間です。\(title)\(minutesText)。準備はよろしいですか？"
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: "ja-JP")
        utterance.rate  = 0.48
        utterance.pitchMultiplier = 1.1
        synthesizer.speak(utterance)
        speechSynthesizer = synthesizer
    }

    // MARK: - 停止

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
