import Foundation
import Speech
import AVFoundation

/// SFSpeechRecognizerを使ったリアルタイム日本語音声認識
final class SpeechRecognitionService {

    private let recognizer = SFSpeechRecognizer(locale: Locale(identifier: "ja_JP"))
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let audioEngine = AVAudioEngine()

    // MARK: - 録音開始

    /// マイクからのリアルタイム文字起こしを AsyncStream で返す
    func startListening() -> AsyncStream<String> {
        AsyncStream { continuation in
            do {
                try setupAudioSession()
                let request = SFSpeechAudioBufferRecognitionRequest()
                request.shouldReportPartialResults = true
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
}
