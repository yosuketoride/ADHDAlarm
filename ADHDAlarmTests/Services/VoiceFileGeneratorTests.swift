import XCTest
import AVFoundation
@testable import ADHDAlarm

final class VoiceFileGeneratorTests: XCTestCase {

    // MARK: - speechText（静的メソッド）

    func testSpeechText_ZeroMinutes_SaysNarimashita() {
        let alarm = AlarmEvent(title: "カフェ", fireDate: Date(), preNotificationMinutes: 0)
        let text = VoiceFileGenerator.speechText(for: alarm)

        XCTAssertTrue(text.contains("カフェ"), "タイトルが含まれていない")
        XCTAssertTrue(text.contains("になりました"), "0分の場合は「になりました」が含まれるべき")
        XCTAssertFalse(text.contains("あと"), "0分の場合は「あとX分」を含まない")
    }

    func testSpeechText_15Minutes_SaysAto15Fun() {
        let alarm = AlarmEvent(title: "会議", fireDate: Date(), preNotificationMinutes: 15)
        let text = VoiceFileGenerator.speechText(for: alarm)

        XCTAssertTrue(text.contains("会議"), "タイトルが含まれていない")
        XCTAssertTrue(text.contains("15"), "15分の数字が含まれていない")
        XCTAssertTrue(text.contains("分"), "「分」が含まれていない")
    }

    func testSpeechText_30Minutes_SaysAto30Fun() {
        let alarm = AlarmEvent(title: "出張", fireDate: Date(), preNotificationMinutes: 30)
        let text = VoiceFileGenerator.speechText(for: alarm)

        XCTAssertTrue(text.contains("出張"))
        XCTAssertTrue(text.contains("30"))
    }

    func testSpeechText_IncludesPolitePrefix() {
        let alarm = AlarmEvent(title: "テスト", fireDate: Date())
        let text = VoiceFileGenerator.speechText(for: alarm)

        // 「お時間です」で始まる丁寧な表現
        XCTAssertTrue(text.hasPrefix("お時間です"), "丁寧な前置きで始まるべき")
    }

    func testSpeechText_IncludesEndQuestion() {
        let alarm = AlarmEvent(title: "テスト", fireDate: Date())
        let text = VoiceFileGenerator.speechText(for: alarm)

        // 「準備はよろしいですか？」で終わる
        XCTAssertTrue(text.contains("準備"), "準備確認のフレーズが含まれていない")
    }

    func testSpeechText_WithJapaneseTitleSpecialChars() {
        let alarm = AlarmEvent(title: "大阪・東京出張（新幹線）", fireDate: Date(), preNotificationMinutes: 15)
        let text = VoiceFileGenerator.speechText(for: alarm)

        XCTAssertTrue(text.contains("大阪・東京出張（新幹線）"))
        XCTAssertTrue(text.contains("15"))
    }

    func testSpeechText_WithEmptyLikeTitle() {
        let alarm = AlarmEvent(title: "A", fireDate: Date(), preNotificationMinutes: 5)
        let text = VoiceFileGenerator.speechText(for: alarm)

        XCTAssertFalse(text.isEmpty)
        XCTAssertTrue(text.contains("A"))
    }

    func testSpeechText_DifferentPreNotificationValues() {
        let values = [0, 5, 10, 15, 30]
        for minutes in values {
            let alarm = AlarmEvent(title: "テスト", fireDate: Date(), preNotificationMinutes: minutes)
            let text = VoiceFileGenerator.speechText(for: alarm)
            XCTAssertFalse(text.isEmpty, "preNotificationMinutes=\(minutes) でテキストが空")
        }
    }

    // MARK: - sanitizeForSpeech（静的メソッド）

    func testSanitizeForSpeech_RemovesEmoji() {
        let sanitized = VoiceFileGenerator.sanitizeForSpeech("会議😀📅")

        XCTAssertEqual(sanitized, "会議")
    }

    func testSanitizeForSpeech_ReplacesBracketsWithComma() {
        let sanitized = VoiceFileGenerator.sanitizeForSpeech("病院（内科）")

        XCTAssertFalse(sanitized.contains("（"))
        XCTAssertFalse(sanitized.contains("）"))
        XCTAssertTrue(sanitized.contains("病院、"), "開き括弧が読点に変換されること")
        XCTAssertTrue(sanitized.contains("内科、"), "閉じ括弧が読点に変換されること")
    }

    func testSanitizeForSpeech_CollapsesRepeatedPunctuation() {
        let sanitized = VoiceFileGenerator.sanitizeForSpeech("会議、、。。")

        XCTAssertFalse(sanitized.contains("、、"))
        XCTAssertFalse(sanitized.contains("。。"))
        XCTAssertEqual(sanitized, "会議、 。")
    }

    func testSanitizeForSpeech_ReplacesCommonAbbreviations() {
        let sanitized = VoiceFileGenerator.sanitizeForSpeech("MRIとCTの検査")

        XCTAssertTrue(sanitized.contains("エムアールアイ"))
        XCTAssertTrue(sanitized.contains("シーティー"))
        XCTAssertFalse(sanitized.contains("MRI"))
        XCTAssertFalse(sanitized.contains("CT"))
    }

    func testMakeUtterance_UsesSanitizedSpeechString() {
        let utterance = VoiceFileGenerator.makeUtterance(
            text: "MRI😀（検査）",
            character: .femaleConcierge,
            isClearVoiceEnabled: false
        )

        XCTAssertEqual(utterance.speechString, "エムアールアイ、 検査、")
    }

    func testMakeUtterance_ClearVoiceAppliesConfiguredRateAndPitch() {
        let utterance = VoiceFileGenerator.makeUtterance(
            text: "テスト",
            character: .femaleConcierge,
            isClearVoiceEnabled: true
        )

        XCTAssertEqual(utterance.rate, 0.40, accuracy: 0.001)
        XCTAssertEqual(utterance.pitchMultiplier, 0.80, accuracy: 0.001)
    }

    // MARK: - ビープ確認用（手動再生）

    /// ビープ構成を手元で試聴するための確認テスト。
    /// 実行後にコンソールに出るパスを afplay で再生できる。
    /// 例: afplay /tmp/beep_preview_xxxx.caf
    /// ※ このテストはファイルを削除しません。確認後に手動削除してください。
    func testBeepPreview_SaveToTmpAndPrintPath() throws {
        // 「無音 0.5秒」を TTS の代わりに使う（ビープ構成とタイミングの確認用）
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("beep_preview_\(UUID().uuidString).caf")
        let silent = try makeSilentCaf(durationSeconds: 0.5)
        defer { try? FileManager.default.removeItem(at: silent) }
        try FileManager.default.copyItem(at: silent, to: url)

        let generator = VoiceFileGenerator()
        generator.prependBeep(to: url)

        print("🔊 [BeepPreview] afplay \(url.path)")
        XCTAssertTrue(FileManager.default.fileExists(atPath: url.path))
    }

    // MARK: - prependBeep

    /// 成功系: 有効な .caf を渡すと、ビープ合成後のファイルが元より大きくなること
    func testPrependBeep_WithValidCaf_OutputIsLarger() throws {
        let url = try makeSilentCaf(durationSeconds: 0.5)
        defer { try? FileManager.default.removeItem(at: url) }

        let originalSize = try FileManager.default.attributesOfItem(atPath: url.path)[.size] as? Int ?? 0

        let generator = VoiceFileGenerator()
        generator.prependBeep(to: url)

        let newSize = try FileManager.default.attributesOfItem(atPath: url.path)[.size] as? Int ?? 0
        XCTAssertGreaterThan(newSize, originalSize, "ビープ合成後はファイルサイズが増えるはず")
    }

    /// 失敗系: 存在しないパスを渡してもクラッシュせず、一時ファイルが残らないこと
    func testPrependBeep_WithNonExistentFile_DoesNotCrash() {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("nonexistent_\(UUID().uuidString).caf")
        let generator = VoiceFileGenerator()
        generator.prependBeep(to: url)  // クラッシュしないこと

        // 一時ファイルが残っていないこと（tmp_ プレフィックス）
        let tmp = url.deletingLastPathComponent()
        let leftovers = (try? FileManager.default.contentsOfDirectory(atPath: tmp.path)) ?? []
        let tmpFiles = leftovers.filter { $0.hasPrefix("tmp_") && $0.hasSuffix(".caf") }
        XCTAssertTrue(tmpFiles.isEmpty, "一時ファイルが残っている: \(tmpFiles)")
    }

    /// フォールバック保証: 合成中にエラーが起きても元ファイルが残ること
    /// 壊れたファイル（AVAudioFile が読めない）を渡すと prependBeep は即リターンし、元ファイルは削除されない
    func testPrependBeep_WithCorruptFile_OriginalPreserved() throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("corrupt_\(UUID().uuidString).caf")
        // 読み込めない内容（ランダムバイト）を書き込む
        try Data([0x00, 0x01, 0x02, 0x03]).write(to: url)
        defer { try? FileManager.default.removeItem(at: url) }

        let generator = VoiceFileGenerator()
        generator.prependBeep(to: url)

        // 元ファイルが残っていること
        XCTAssertTrue(FileManager.default.fileExists(atPath: url.path), "元ファイルが消えている")
        let size = try FileManager.default.attributesOfItem(atPath: url.path)[.size] as? Int ?? 0
        XCTAssertEqual(size, 4, "元ファイルの内容が変わっている")
    }

    // MARK: - テスト用ヘルパー

    /// 指定秒数の無音 .caf を tmp ディレクトリに生成して URL を返す
    private func makeSilentCaf(durationSeconds: Double) throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("silent_\(UUID().uuidString).caf")
        let sampleRate: Double = 22050
        let frameCount = AVAudioFrameCount(sampleRate * durationSeconds)
        let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1)!
        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount)!
        buffer.frameLength = frameCount
        let file = try AVAudioFile(forWriting: url, settings: format.settings, commonFormat: .pcmFormatFloat32, interleaved: false)
        try file.write(from: buffer)
        return url
    }
}
