import Foundation
import AVFoundation

/// AVSpeechSynthesizerを使って読み上げテキストを.cafファイルに変換する
/// 生成したファイルはLibrary/Sounds/WasurebuAlarms/{alarmID}.cafに保存する
final class VoiceFileGenerator: VoiceSynthesizing {

    private enum SpeechTuning {
        static let naturalRate: Float = 0.46
        static let naturalFemalePitch: Float = 0.98
        static let naturalMalePitch: Float = 0.86
        static let naturalPreDelay: TimeInterval = 0.12
        static let naturalPostDelay: TimeInterval = 0.08

        static let clearRate: Float = 0.40
        static let clearPitch: Float = 0.80
        static let clearPreDelay: TimeInterval = 0.18
        static let clearPostDelay: TimeInterval = 0.12
    }

    private nonisolated static let pronunciationMap: [String: String] = [
        "MRI": "エムアールアイ",
        "CT": "シーティー",
    ]

    nonisolated init() {}

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
        // ビープ音を先頭に合成する（失敗時は読み上げ単体のファイルをそのまま残す）
        prependBeep(to: outputURL)
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
    nonisolated static func speechText(for alarm: AlarmEvent) -> String {
        if alarm.preNotificationMinutes == 0 {
            return "お時間です。\(alarm.title)の時間になりました。準備はよろしいですか？"
        }
        return "お時間です。あと\(alarm.preNotificationMinutes)分で\(alarm.title)の時間です。準備はよろしいですか？"
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
        let utterance = VoiceFileGenerator.makeUtterance(
            text: text,
            character: character,
            isClearVoiceEnabled: false
        )

        // AVSpeechSynthesizer.write()でPCMバッファを受け取り、.cafファイルに書き出す
        // レビュー指摘 #2: AVFoundation内部スレッドから並行コールバックが来る可能性があるため
        // NSLockでfinishedフラグをスレッドセーフに保護し、continuation多重Resume（即クラッシュ）を防ぐ
        return try await withCheckedThrowingContinuation { continuation in
            var outputFile: AVAudioFile?
            var finished = false
            let lock = NSLock()

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
                        lock.lock()
                        let alreadyDone = finished; finished = true
                        lock.unlock()
                        if !alreadyDone { continuation.resume(throwing: VoiceError.invalidAudioFormat) }
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
                        lock.lock()
                        let alreadyDone = finished; finished = true
                        lock.unlock()
                        if !alreadyDone { continuation.resume(throwing: error) }
                        return
                    }
                }

                if pcmBuffer.frameLength == 0 {
                    // frameLength == 0 は書き込み完了のシグナル
                    lock.lock()
                    let alreadyDone = finished; finished = true
                    lock.unlock()
                    if !alreadyDone { continuation.resume() }
                    return
                }

                do {
                    try outputFile?.write(from: pcmBuffer)
                } catch {
                    lock.lock()
                    let alreadyDone = finished; finished = true
                    lock.unlock()
                    if !alreadyDone { continuation.resume(throwing: error) }
                }
            }
        }
    }

    // MARK: - ビープ合成

    /// TTS .caf の先頭に短いビープ＋無音を挿入して上書きする
    /// 失敗した場合は元の読み上げ単体ファイルをそのまま残す（沈黙にしない）
    nonisolated func prependBeep(to url: URL) {
        // TTS ファイルを読み込む
        guard let ttsFile = try? AVAudioFile(forReading: url) else { return }
        let format = ttsFile.processingFormat
        let ttsFrameCount = AVAudioFrameCount(ttsFile.length)
        guard
            let ttsBuffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: ttsFrameCount),
            (try? ttsFile.read(into: ttsBuffer)) != nil
        else { return }

        // ビープ音（880Hz / 0.12秒 × 3回）と間隔・前置無音のバッファを生成
        // 音量0.45: TTS と競合しない程度に抑えつつ、ロック画面でも聞こえる強さ
        guard
            let beepBuffer     = makeBeepBuffer(format: format, frequency: 880.0, durationSeconds: 0.12),
            let gapBuffer      = makeSilenceBuffer(format: format, durationSeconds: 0.08),  // ビープ間の短い隙間
            let leadinBuffer   = makeSilenceBuffer(format: format, durationSeconds: 0.15)   // TTS 前の余白
        else { return }

        // 一時ファイルに [ビープ×3 + 余白 + TTS] を書き出す
        let tmpURL = url.deletingLastPathComponent()
            .appendingPathComponent("tmp_\(UUID().uuidString).caf")

        guard let outFile = try? AVAudioFile(
            forWriting: tmpURL,
            settings: format.settings,
            commonFormat: .pcmFormatFloat32,
            interleaved: false
        ) else { return }

        do {
            // ビビビ（3連ビープ）
            try outFile.write(from: beepBuffer)
            try outFile.write(from: gapBuffer)
            try outFile.write(from: beepBuffer)
            try outFile.write(from: gapBuffer)
            try outFile.write(from: beepBuffer)
            // TTS 前の余白
            try outFile.write(from: leadinBuffer)
            // 読み上げ本文
            try outFile.write(from: ttsBuffer)
        } catch {
            // 書き出し失敗 → 一時ファイルを削除して元の TTS ファイルを残す
            try? FileManager.default.removeItem(at: tmpURL)
            return
        }

        // 合成済みファイルで元ファイルをアトミックに置き換える
        // replaceItemAt を使うことで、置換失敗時も元ファイルが残ることを保証する
        do {
            _ = try FileManager.default.replaceItemAt(url, withItemAt: tmpURL)
        } catch {
            // 置換失敗 → 一時ファイルだけ消して元の TTS ファイルを残す
            try? FileManager.default.removeItem(at: tmpURL)
        }
    }

    /// サイン波のビープ音 PCM バッファを生成する
    /// フェードイン・フェードアウト（10ms）でクリックノイズを防ぐ
    private nonisolated func makeBeepBuffer(
        format: AVAudioFormat,
        frequency: Double,
        durationSeconds: Double
    ) -> AVAudioPCMBuffer? {
        let sampleRate  = format.sampleRate
        let frameCount  = AVAudioFrameCount(sampleRate * durationSeconds)
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount) else { return nil }
        buffer.frameLength = frameCount

        let fadeFrames = Int(sampleRate * 0.01)  // 10ms フェード
        for ch in 0..<Int(format.channelCount) {
            guard let channelData = buffer.floatChannelData?[ch] else { continue }
            for i in 0..<Int(frameCount) {
                let t: Double = Double(i) / sampleRate
                let fade: Float
                if i < fadeFrames {
                    fade = Float(i) / Float(fadeFrames)
                } else if i > Int(frameCount) - fadeFrames {
                    fade = Float(Int(frameCount) - i) / Float(max(fadeFrames, 1))
                } else {
                    fade = 1.0
                }
                channelData[i] = Float(sin(2.0 * Double.pi * frequency * t)) * 0.45 * fade
            }
        }
        return buffer
    }

    /// 無音 PCM バッファを生成する（バッファはゼロ初期化済み）
    private nonisolated func makeSilenceBuffer(
        format: AVAudioFormat,
        durationSeconds: Double
    ) -> AVAudioPCMBuffer? {
        let frameCount = AVAudioFrameCount(format.sampleRate * durationSeconds)
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount) else { return nil }
        buffer.frameLength = frameCount
        return buffer
    }

    /// キャラクターに対応するAVSpeechSynthesisVoiceを選択する（VoiceCharacterPickerの試聴でも使用）
    nonisolated static func voice(for character: VoiceCharacter) -> AVSpeechSynthesisVoice? {
        let jaVoices = AVSpeechSynthesisVoice.speechVoices().filter {
            $0.language.hasPrefix("ja")
        }

        switch character {
        case .femaleConcierge:
            return bestJapaneseVoice(
                from: jaVoices,
                preferredIdentifiers: ["Kyoko", "O-ren"]
            ) ?? AVSpeechSynthesisVoice(language: "ja-JP")

        case .maleButler:
            return bestJapaneseVoice(
                from: jaVoices,
                preferredIdentifiers: ["Otoya"]
            ) ?? AVSpeechSynthesisVoice(language: "ja-JP")

        case .customRecording:
            return bestJapaneseVoice(
                from: jaVoices,
                preferredIdentifiers: ["Kyoko", "O-ren"]
            ) ?? AVSpeechSynthesisVoice(language: "ja-JP")
        }
    }

    nonisolated static func makeUtterance(
        text: String,
        character: VoiceCharacter,
        isClearVoiceEnabled: Bool
    ) -> AVSpeechUtterance {
        let utterance = AVSpeechUtterance(string: sanitizeForSpeech(text))
        utterance.voice = voice(for: character)
        utterance.rate = isClearVoiceEnabled ? SpeechTuning.clearRate : SpeechTuning.naturalRate
        utterance.pitchMultiplier = pitchMultiplier(
            for: character,
            isClearVoiceEnabled: isClearVoiceEnabled
        )
        utterance.preUtteranceDelay = isClearVoiceEnabled
            ? SpeechTuning.clearPreDelay
            : SpeechTuning.naturalPreDelay
        utterance.postUtteranceDelay = isClearVoiceEnabled
            ? SpeechTuning.clearPostDelay
            : SpeechTuning.naturalPostDelay
        return utterance
    }

    nonisolated static func sanitizeForSpeech(_ text: String) -> String {
        let withoutEmoji = text.filter { !$0.isEmojiLike }
        let expandedAbbreviations = applyPronunciationMap(to: withoutEmoji)
        let normalizedBrackets = expandedAbbreviations
            .replacingOccurrences(of: "（", with: "、")
            .replacingOccurrences(of: "）", with: "、")
            .replacingOccurrences(of: "(", with: "、")
            .replacingOccurrences(of: ")", with: "、")
        let normalizedPunctuation = normalizedBrackets
            .replacingOccurrences(of: "！", with: "。")
            .replacingOccurrences(of: "!", with: "。")
            .replacingOccurrences(of: "？", with: "。")
            .replacingOccurrences(of: "?", with: "。")
            .replacingOccurrences(of: "、", with: "、 ")
            .replacingOccurrences(of: "。", with: "。 ")
            .replacingOccurrences(of: "\n", with: "。 ")
        let collapsedPunctuation = collapseRepeatedPunctuation(in: normalizedPunctuation)
        let collapsedWhitespace = collapsedPunctuation
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return replaceClockText(in: collapsedWhitespace)
    }

    private nonisolated static func bestJapaneseVoice(
        from voices: [AVSpeechSynthesisVoice],
        preferredIdentifiers: [String]
    ) -> AVSpeechSynthesisVoice? {
        let qualityOrder: [AVSpeechSynthesisVoiceQuality] = [.premium, .enhanced, .default]

        for quality in qualityOrder {
            if let preferred = voices.first(where: { voice in
                voice.quality == quality &&
                preferredIdentifiers.contains(where: { voice.identifier.contains($0) })
            }) {
                return preferred
            }
        }

        for quality in qualityOrder {
            if let fallback = voices.first(where: { $0.quality == quality }) {
                return fallback
            }
        }

        return nil
    }

    private nonisolated static func pitchMultiplier(
        for character: VoiceCharacter,
        isClearVoiceEnabled: Bool
    ) -> Float {
        switch character {
        case .maleButler:
            return isClearVoiceEnabled ? SpeechTuning.clearPitch : SpeechTuning.naturalMalePitch
        case .femaleConcierge, .customRecording:
            return isClearVoiceEnabled ? SpeechTuning.clearPitch : SpeechTuning.naturalFemalePitch
        }
    }

    private nonisolated static func applyPronunciationMap(to text: String) -> String {
        pronunciationMap.reduce(text) { partialResult, entry in
            partialResult.replacingOccurrences(
                of: entry.key,
                with: entry.value,
                options: [.caseInsensitive]
            )
        }
    }

    private nonisolated static func collapseRepeatedPunctuation(in text: String) -> String {
        var result = ""
        var lastPunctuation: Character?

        for character in text {
            if character == "、" || character == "。" {
                if lastPunctuation == character {
                    continue
                }
                lastPunctuation = character
                result.append(character)
                continue
            }

            if !character.isWhitespace {
                lastPunctuation = nil
            }
            result.append(character)
        }

        return result
    }

    private nonisolated static func replaceClockText(in text: String) -> String {
        guard let regex = try? NSRegularExpression(pattern: #"(\d{1,2}):(\d{2})"#) else { return text }

        var result = text
        let matches = regex.matches(in: result, range: NSRange(result.startIndex..., in: result)).reversed()
        for match in matches {
            guard let hourRange = Range(match.range(at: 1), in: result),
                  let minuteRange = Range(match.range(at: 2), in: result),
                  let fullRange = Range(match.range, in: result) else { continue }

            let hour = String(result[hourRange])
            let minute = String(result[minuteRange])
            let replacement = minute == "00" ? "\(hour)時ちょうど" : "\(hour)時\(minute)分"
            result.replaceSubrange(fullRange, with: replacement)
        }

        return result
    }
}

private extension Character {
    var isEmojiLike: Bool {
        unicodeScalars.contains { scalar in
            scalar.properties.isEmojiPresentation || scalar.properties.isEmoji
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
