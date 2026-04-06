import AVFoundation

/// システム音声APIへ接続する本番実装
final class SystemAlarmAudioController: AlarmAudioControlling {
    var currentOutputPortTypes: [AVAudioSession.Port] {
        AVAudioSession.sharedInstance().currentRoute.outputs.map(\.portType)
    }

    func configurePlaybackSession(
        mode: AVAudioSession.Mode,
        options: AVAudioSession.CategoryOptions,
        forceSpeaker: Bool
    ) throws {
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playback, mode: mode, options: options)
        try session.setActive(true)
        if forceSpeaker {
            try session.overrideOutputAudioPort(.speaker)
        }
    }

    func deactivatePlaybackSession() throws {
        try AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    func makeAudioPlayer(url: URL) throws -> AudioPlayerControlling {
        try SystemAudioPlayer(url: url)
    }

    func makeSpeechSynthesizer() -> SpeechSynthesizerControlling {
        SystemSpeechSynthesizer()
    }
}

private final class SystemAudioPlayer: AudioPlayerControlling {
    private let player: AVAudioPlayer

    init(url: URL) throws {
        self.player = try AVAudioPlayer(contentsOf: url)
    }

    var delegate: AVAudioPlayerDelegate? {
        get { player.delegate }
        set { player.delegate = newValue }
    }

    var numberOfLoops: Int {
        get { player.numberOfLoops }
        set { player.numberOfLoops = newValue }
    }

    func prepareToPlay() {
        player.prepareToPlay()
    }

    func play() -> Bool {
        player.play()
    }

    func stop() {
        player.stop()
    }
}

private final class SystemSpeechSynthesizer: SpeechSynthesizerControlling {
    private let synthesizer = AVSpeechSynthesizer()

    var delegate: AVSpeechSynthesizerDelegate? {
        get { synthesizer.delegate }
        set { synthesizer.delegate = newValue }
    }

    func speak(_ utterance: AVSpeechUtterance) {
        synthesizer.speak(utterance)
    }

    func stopSpeaking(at boundary: AVSpeechBoundary) -> Bool {
        synthesizer.stopSpeaking(at: boundary)
    }
}
