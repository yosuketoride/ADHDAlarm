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
}
