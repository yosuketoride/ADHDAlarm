import XCTest
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
}
