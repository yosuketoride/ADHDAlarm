import Foundation
import Speech
import AVFoundation

/// SFSpeechRecognizerを使ったリアルタイム日本語音声認識
final class SpeechRecognitionService {

    private let recognizer = SFSpeechRecognizer(locale: Locale(identifier: "ja_JP"))
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let audioEngine = AVAudioEngine()
    private var alarmObserver: NSObjectProtocol?

    // MARK: - 録音開始

    /// マイクからのリアルタイム文字起こしを AsyncStream で返す
    func startListening() -> AsyncStream<String> {
        // アラーム発火通知を受けたら録音を即時停止する。
        // fullScreenCover + sheet の競合でonDisappearが呼ばれない場合の保険。
        alarmObserver = NotificationCenter.default.addObserver(
            forName: .alarmWillStartPlaying,
            object: nil,
            queue: nil  // nilにすることで投稿スレッド（MainActor）上で同期実行される
        ) { [weak self] _ in
            self?.stopListening()
        }
        return AsyncStream { continuation in
            do {
                try setupAudioSession()
                let request = makeRecognitionRequest()
                self.recognitionRequest = request

                recognitionTask = recognizer?.recognitionTask(with: request) { result, error in
                    if let result {
                        continuation.yield(result.bestTranscription.formattedString)
                    }
                    if error != nil || result?.isFinal == true {
                        continuation.finish()
                    }
                }

                // マイク入力をSpeechRecognizerに流す
                let inputNode = audioEngine.inputNode
                // レビュー指摘 #1: 既存Tapが残っている状態でinstallTapを呼ぶと即クラッシュする。
                // 先にremoveTapで安全にクリアしてからinstallTapを呼ぶ。
                inputNode.removeTap(onBus: 0)
                let format = inputNode.outputFormat(forBus: 0)
                inputNode.installTap(onBus: 0, bufferSize: 1024, format: format) { buffer, _ in
                    request.append(buffer)
                }
                audioEngine.prepare()
                try audioEngine.start()

                continuation.onTermination = { [weak self] _ in
                    // @Sendableクロージャから@MainActorメソッドを安全に呼ぶ
                    Task { @MainActor [weak self] in self?.stopListening() }
                }
            } catch {
                continuation.finish()
            }
        }
    }

    /// 録音を終了する
    func stopListening() {
        if let observer = alarmObserver {
            NotificationCenter.default.removeObserver(observer)
            alarmObserver = nil
        }
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        recognitionRequest?.endAudio()
        recognitionRequest = nil
        recognitionTask?.cancel()
        recognitionTask = nil
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    // MARK: - Private

    private func setupAudioSession() throws {
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.record, mode: .measurement, options: .duckOthers)
        try session.setActive(true, options: .notifyOthersOnDeactivation)
    }

    /// 音声認識リクエストを現在の方針で組み立てる
    func makeRecognitionRequest() -> SFSpeechAudioBufferRecognitionRequest {
        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        request.requiresOnDeviceRecognition = true
        return request
    }
}
