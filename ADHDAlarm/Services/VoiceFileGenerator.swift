import Foundation
import AVFoundation

/// AVSpeechSynthesizerを使って読み上げテキストを.cafファイルに変換する
/// 生成したファイルはLibrary/Sounds/WasurebuAlarms/{alarmID}.cafに保存する
final class VoiceFileGenerator: VoiceSynthesizing {

    // MARK: - VoiceSynthesizing

    /// テキストを音声ファイル(.caf)として生成し、保存先URLを返す
    /// character == .customRecording の場合は保存済みの録音ファイルをコピーして使う
    nonisolated func generateAudio(text: String, character: VoiceCharacter, alarmID: UUID, eventTitle: String = "") async throws -> URL {
        let outputURL = try soundFileURL(for: alarmID)

        // すでに生成済みの場合は再利用
        if FileManager.default.fileExists(atPath: outputURL.path) {
            return outputURL
        }

        // 家族の生声: カテゴリ別録音 → other録音 → TTSの順でフォールバック
        if character == .customRecording {
            let dir = try soundsDirectory()

            // ① タイトルからカテゴリを判定して対応録音を探す
            let category = VoiceCategory.match(for: eventTitle)
            let categoryURL = dir.appendingPathComponent(category.fileName)
            if FileManager.default.fileExists(atPath: categoryURL.path) {
                try FileManager.default.copyItem(at: categoryURL, to: outputURL)
                return outputURL
            }

            // ② カテゴリ録音がなければ「その他」録音を使う
            let otherURL = dir.appendingPathComponent(VoiceCategory.other.fileName)
            if FileManager.default.fileExists(atPath: otherURL.path) {
                try FileManager.default.copyItem(at: otherURL, to: outputURL)
                return outputURL
            }

            // ③ 旧形式（単一録音）との後方互換
            let legacyURL = dir.appendingPathComponent("custom_voice.caf")
            if FileManager.default.fileExists(atPath: legacyURL.path) {
                try FileManager.default.copyItem(at: legacyURL, to: outputURL)
                return outputURL
            }
            // すべてなければTTSにフォールバック
        }

        try await renderSpeech(text: text, character: character, to: outputURL)
        return outputURL
    }

    /// 家族の生声の固定保存先URL
    nonisolated func customVoiceURL() throws -> URL {
        try soundsDirectory().appendingPathComponent("custom_voice.caf")
    }

    /// 音声ファイルを削除する（アラーム削除時のクリーンアップ）
    nonisolated func deleteAudio(alarmID: UUID) {
        guard let url = try? soundFileURL(for: alarmID) else { return }
        try? FileManager.default.removeItem(at: url)
    }

    // MARK: - テキスト生成ヘルパー

    /// アラームの読み上げテキストを生成する
    /// 例: 「お時間です。あと15分でカフェのご予定ですよ。」
    static func speechText(for alarm: AlarmEvent) -> String {
        let minutesText = alarm.preNotificationMinutes == 0
            ? "になりました"
            : "まであと\(alarm.preNotificationMinutes)分です"
        return "お時間です。\(alarm.title)\(minutesText)。準備はよろしいですか？"
    }

    // MARK: - Private

    /// 保存先URLを返す。ディレクトリが存在しない場合は作成する
    private nonisolated func soundFileURL(for alarmID: UUID) throws -> URL {
        let soundsDir = try soundsDirectory()
        return soundsDir.appendingPathComponent("\(alarmID.uuidString).caf")
    }

    /// Library/Sounds/ディレクトリのURLを返す
    /// AlarmKitの.named(fileName)が Library/Sounds/ 直下を参照するため、サブディレクトリは使わない
    private nonisolated func soundsDirectory() throws -> URL {
        let library = try FileManager.default.url(
            for: .libraryDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let dir = library.appendingPathComponent("Sounds")

        if !FileManager.default.fileExists(atPath: dir.path) {
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        return dir
    }

    /// AVSpeechSynthesizerでテキストを音声レンダリングし、.cafとして保存する
    /// nonisolated: AVSpeechSynthesizer.write()のコールバックはバックグラウンドキューから呼ばれるため、
    /// MainActor隔離のままだとデッドロックする（SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor環境）
    private nonisolated func renderSpeech(text: String, character: VoiceCharacter, to outputURL: URL) async throws {
        let synthesizer = AVSpeechSynthesizer()
        let utterance = AVSpeechUtterance(string: text)

        // 音声キャラに合わせてボイスを選択
        utterance.voice = selectVoice(for: character)
        utterance.rate  = AVSpeechUtteranceDefaultSpeechRate * 0.85  // ゆっくり・自然に
        utterance.preUtteranceDelay = 0.3                            // 冒頭に間を置いて自然に
        utterance.pitchMultiplier = character == .maleButler ? 0.85 : 1.05  // 女性: 少し柔らかく

        // AVSpeechSynthesizer.write()でPCMバッファを受け取り、.cafファイルに書き出す
        return try await withCheckedThrowingContinuation { continuation in
            var outputFile: AVAudioFile?
            var finished = false

            synthesizer.write(utterance) { buffer in
                guard let pcmBuffer = buffer as? AVAudioPCMBuffer else { return }

                // 最初のバッファでファイルを作成
                if outputFile == nil {
                    guard let format = AVAudioFormat(
                        commonFormat: .pcmFormatFloat32,
                        sampleRate: pcmBuffer.format.sampleRate,
                        channels: pcmBuffer.format.channelCount,
                        interleaved: false
                    ) else {
                        continuation.resume(throwing: VoiceError.invalidAudioFormat)
                        return
                    }
                    do {
                        // CAFフォーマットで書き出す
                        outputFile = try AVAudioFile(
                            forWriting: outputURL,
                            settings: format.settings,
                            commonFormat: .pcmFormatFloat32,
                            interleaved: false
                        )
                    } catch {
                        continuation.resume(throwing: error)
                        return
                    }
                }

                if pcmBuffer.frameLength == 0 {
                    // frameLength == 0 は書き込み完了のシグナル
                    if !finished {
                        finished = true
                        continuation.resume()
                    }
                    return
                }

                do {
                    try outputFile?.write(from: pcmBuffer)
                } catch {
                    if !finished {
                        finished = true
                        continuation.resume(throwing: error)
                    }
                }
            }
        }
    }

    /// キャラクターに対応するAVSpeechSynthesisVoiceを選択する
    private nonisolated func selectVoice(for character: VoiceCharacter) -> AVSpeechSynthesisVoice? {
        // 利用可能な日本語音声から最適なものを選ぶ
        // iOS 26では音声の種類が増えている可能性があるため、フォールバックあり
        let jaVoices = AVSpeechSynthesisVoice.speechVoices().filter {
            $0.language.hasPrefix("ja")
        }

        switch character {
        case .femaleConcierge:
            // プレミアム音声を優先（ダウンロード済みの場合）
            let premiumFemale = jaVoices.first {
                $0.quality == .premium && ($0.identifier.contains("Kyoko") || $0.identifier.contains("O-ren"))
            }
            if let voice = premiumFemale { return voice }
            let female = jaVoices.first { $0.identifier.contains("Kyoko") || $0.identifier.contains("O-ren") }
            return female ?? AVSpeechSynthesisVoice(language: "ja-JP")

        case .maleButler:
            // プレミアム音声を優先（ダウンロード済みの場合）
            let premiumMale = jaVoices.first { $0.quality == .premium && $0.identifier.contains("Otoya") }
            if let voice = premiumMale { return voice }
            let male = jaVoices.first { $0.identifier.contains("Otoya") }
            return male ?? AVSpeechSynthesisVoice(language: "ja-JP")

        case .customRecording:
            // 録音ファイルがない場合のフォールバック: さくら音声
            let premiumFemale = jaVoices.first {
                $0.quality == .premium && ($0.identifier.contains("Kyoko") || $0.identifier.contains("O-ren"))
            }
            if let voice = premiumFemale { return voice }
            return AVSpeechSynthesisVoice(language: "ja-JP")
        }
    }
}

// MARK: - エラー定義

enum VoiceError: LocalizedError {
    case invalidAudioFormat
    case renderingFailed

    var errorDescription: String? {
        switch self {
        case .invalidAudioFormat: return "音声ファイルのフォーマット設定に失敗しました。"
        case .renderingFailed:    return "音声ファイルの生成に失敗しました。"
        }
    }
}
