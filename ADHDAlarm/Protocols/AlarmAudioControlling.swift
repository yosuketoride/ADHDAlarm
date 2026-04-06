import AVFoundation

/// アラーム再生に必要な音声APIの薄い窓口
protocol AlarmAudioControlling {
    /// 現在の出力ポート種別
    var currentOutputPortTypes: [AVAudioSession.Port] { get }

    /// 再生用のAudioSessionを構成する
    func configurePlaybackSession(
        mode: AVAudioSession.Mode,
        options: AVAudioSession.CategoryOptions,
        forceSpeaker: Bool
    ) throws

    /// 再生用AudioSessionを解放する
    func deactivatePlaybackSession() throws

    /// 音声ファイルプレーヤーを生成する
    func makeAudioPlayer(url: URL) throws -> AudioPlayerControlling

    /// TTS再生器を生成する
    func makeSpeechSynthesizer() -> SpeechSynthesizerControlling
}

/// テストで差し替えやすい音声ファイルプレーヤー
protocol AudioPlayerControlling: AnyObject {
    var delegate: AVAudioPlayerDelegate? { get set }
    var numberOfLoops: Int { get set }

    func prepareToPlay()
    func play() -> Bool
    func stop()
}

/// テストで差し替えやすいTTS再生器
protocol SpeechSynthesizerControlling: AnyObject {
    var delegate: AVSpeechSynthesizerDelegate? { get set }

    func speak(_ utterance: AVSpeechUtterance)
    @discardableResult
    func stopSpeaking(at boundary: AVSpeechBoundary) -> Bool
}
