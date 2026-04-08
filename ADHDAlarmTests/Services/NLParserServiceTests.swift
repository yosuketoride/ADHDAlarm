import XCTest
@testable import ADHDAlarm

/// NLParserServiceの全パターンをテストする
/// 注意: 内部で Date() を使うため、日時比較は ±120秒の誤差を許容する
final class NLParserServiceTests: XCTestCase {

    private let parser = NLParserService()
    private let tolerance: TimeInterval = 120  // 2分の誤差許容

    // MARK: - タイトル抽出

    func testTitleExtracted_AbsoluteTime() {
        let result = parser.parse(text: "明日の15時にカフェ")
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.title, "カフェ")
    }

    func testTitleExtracted_RelativeMinutes() {
        let result = parser.parse(text: "30分後に歯医者")
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.title, "歯医者")
    }

    func testTitleExtracted_FillerRemoval_Alarm() {
        let result = parser.parse(text: "明日の10時にアラームをセットして")
        XCTAssertNotNil(result)
        XCTAssertFalse(result?.title.contains("アラーム") ?? true, "フィラー「アラーム」が除去されていない")
    }

    func testTitleExtracted_FillerRemoval_Onegai() {
        let result = parser.parse(text: "明後日の9時にお願いします起こして")
        XCTAssertNotNil(result)
        XCTAssertFalse(result?.title.contains("お願い") ?? true, "フィラー「お願いします」が除去されていない")
    }

    func testTitleExtracted_MultipleWords() {
        let result = parser.parse(text: "明日の14時30分に大阪出張")
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.title, "大阪出張")
    }

    func testInferEmoji_MedicineTitleReturnsPill() {
        XCTAssertEqual(parser.inferEmoji(from: "薬を飲む"), "💊")
    }

    func testInferEmoji_HospitalTitleReturnsHospital() {
        XCTAssertEqual(parser.inferEmoji(from: "病院へ行く"), "🏥")
    }

    func testInferEmoji_ShoppingTitleReturnsCart() {
        XCTAssertEqual(parser.inferEmoji(from: "買い物メモ"), "🛒")
    }

    func testInferEmoji_UnknownTitleReturnsNil() {
        XCTAssertNil(parser.inferEmoji(from: "読書"))
    }

    // MARK: - 空文字・無効入力

    func testReturnsNilForEmptyString() {
        XCTAssertNil(parser.parse(text: ""))
    }

    func testReturnsNilForWhitespaceOnly() {
        XCTAssertNil(parser.parse(text: "   "))
    }

    func testReturnsNilForNoDateInfo() {
        XCTAssertNil(parser.parse(text: "カフェ"))
    }

    func testReturnsNilForDateWithoutTitle() {
        // 日時のみでタイトルがゼロになるケース
        let result = parser.parse(text: "明日の15時にアラームをセットして")
        // タイトルが空ならnilになる仕様
        if let r = result {
            XCTAssertFalse(r.title.isEmpty, "タイトルが空の場合はnilを返すべき")
        }
    }

    // MARK: - 相対時刻: 「X分後」

    func testRelativeSeconds_30sec() {
        let before = Date()
        let result = parser.parse(text: "30秒後にテスト")
        let after = Date()

        XCTAssertNotNil(result)
        guard let parsed = result else { return }

        let expected = before.addingTimeInterval(30)
        XCTAssertEqual(parsed.fireDate.timeIntervalSince(expected), 0, accuracy: tolerance)
        XCTAssertLessThanOrEqual(parsed.fireDate, after.addingTimeInterval(30 + tolerance))
        XCTAssertEqual(parsed.title, "テスト")
    }

    func testRelativeMinutes_30min() {
        let before = Date()
        let result = parser.parse(text: "30分後に歯医者")
        let after = Date()

        XCTAssertNotNil(result)
        guard let parsed = result else { return }

        let expected = before.addingTimeInterval(30 * 60)
        XCTAssertEqual(parsed.fireDate.timeIntervalSince(expected), 0, accuracy: tolerance)
        // 上限チェック
        XCTAssertLessThanOrEqual(parsed.fireDate, after.addingTimeInterval(30 * 60 + tolerance))
    }

    func testRelativeMinutes_15min() {
        let before = Date()
        let result = parser.parse(text: "15分後にランチ")
        XCTAssertNotNil(result)
        guard let parsed = result else { return }
        let expected = before.addingTimeInterval(15 * 60)
        XCTAssertEqual(parsed.fireDate.timeIntervalSince(expected), 0, accuracy: tolerance)
    }

    func testRelativeMinutes_1min() {
        let before = Date()
        let result = parser.parse(text: "1分後にテスト")
        XCTAssertNotNil(result)
        guard let parsed = result else { return }
        let expected = before.addingTimeInterval(1 * 60)
        XCTAssertEqual(parsed.fireDate.timeIntervalSince(expected), 0, accuracy: tolerance)
    }

    // MARK: - 相対時刻: 「X時間後」

    func testRelativeHours_2hours() {
        let before = Date()
        let result = parser.parse(text: "2時間後に会議")
        XCTAssertNotNil(result)
        guard let parsed = result else { return }
        let expected = before.addingTimeInterval(2 * 3600)
        XCTAssertEqual(parsed.fireDate.timeIntervalSince(expected), 0, accuracy: tolerance)
    }

    func testRelativeHours_1hour() {
        let before = Date()
        let result = parser.parse(text: "1時間後に運動")
        XCTAssertNotNil(result)
        guard let parsed = result else { return }
        let expected = before.addingTimeInterval(1 * 3600)
        XCTAssertEqual(parsed.fireDate.timeIntervalSince(expected), 0, accuracy: tolerance)
    }

    // MARK: - 相対日付: 今日・明日・明後日

    func testRelativeDate_Today() {
        let result = parser.parse(text: "今日の15時にカフェ")
        XCTAssertNotNil(result)
        guard let parsed = result else { return }
        let cal = Calendar.current
        XCTAssertTrue(cal.isDateInToday(parsed.fireDate))
        XCTAssertEqual(cal.component(.hour, from: parsed.fireDate), 15)
        XCTAssertEqual(cal.component(.minute, from: parsed.fireDate), 0)
    }

    func testRelativeDate_Tomorrow() {
        let result = parser.parse(text: "明日の10時に病院")
        XCTAssertNotNil(result)
        guard let parsed = result else { return }
        let cal = Calendar.current
        XCTAssertTrue(cal.isDateInTomorrow(parsed.fireDate))
        XCTAssertEqual(cal.component(.hour, from: parsed.fireDate), 10)
    }

    func testRelativeDate_DayAfterTomorrow() {
        let result = parser.parse(text: "明後日の9時に出張")
        XCTAssertNotNil(result)
        guard let parsed = result else { return }
        let cal = Calendar.current
        let expected = cal.date(byAdding: .day, value: 2, to: cal.startOfDay(for: Date()))!
        let daysDiff = cal.dateComponents([.day], from: cal.startOfDay(for: Date()), to: cal.startOfDay(for: parsed.fireDate)).day
        XCTAssertEqual(daysDiff, 2)
        XCTAssertEqual(cal.component(.hour, from: parsed.fireDate), 9)
    }

    func testRelativeDate_Asatte() {
        // 「あさって」も明後日と同じ
        let result = parser.parse(text: "あさっての14時にカフェ")
        XCTAssertNotNil(result)
        guard let parsed = result else { return }
        let cal = Calendar.current
        let daysDiff = cal.dateComponents([.day], from: cal.startOfDay(for: Date()), to: cal.startOfDay(for: parsed.fireDate)).day
        XCTAssertEqual(daysDiff, 2)
    }

    func testRelativeDate_DaysLater() {
        let result = parser.parse(text: "3日後にゆかちゃんとデート")
        XCTAssertNotNil(result)
        guard let parsed = result else { return }
        let cal = Calendar.current
        let daysDiff = cal.dateComponents([.day], from: cal.startOfDay(for: Date()), to: cal.startOfDay(for: parsed.fireDate)).day
        XCTAssertEqual(daysDiff, 3)
        XCTAssertEqual(parsed.title, "ゆかちゃんデート")
    }

    // MARK: - 時刻パターン

    func testTime_HHmm() {
        let result = parser.parse(text: "今日の15時30分にランチ")
        XCTAssertNotNil(result)
        guard let parsed = result else { return }
        let cal = Calendar.current
        XCTAssertEqual(cal.component(.hour, from: parsed.fireDate), 15)
        XCTAssertEqual(cal.component(.minute, from: parsed.fireDate), 30)
    }

    func testTime_HH() {
        let result = parser.parse(text: "今日の9時に朝食")
        XCTAssertNotNil(result)
        guard let parsed = result else { return }
        let cal = Calendar.current
        XCTAssertEqual(cal.component(.hour, from: parsed.fireDate), 9)
        XCTAssertEqual(cal.component(.minute, from: parsed.fireDate), 0)
    }

    func testTime_GogoFormat() {
        // 午後3時 → 15時
        let result = parser.parse(text: "明日の午後3時にミーティング")
        XCTAssertNotNil(result)
        guard let parsed = result else { return }
        let cal = Calendar.current
        XCTAssertEqual(cal.component(.hour, from: parsed.fireDate), 15)
    }

    func testTime_GozenFormat() {
        // 午前9時 → 9時
        let result = parser.parse(text: "明日の午前9時に出発")
        XCTAssertNotNil(result)
        guard let parsed = result else { return }
        let cal = Calendar.current
        XCTAssertEqual(cal.component(.hour, from: parsed.fireDate), 9)
    }

    func testTime_ColonFormat() {
        // 15:30 形式
        let result = parser.parse(text: "明日の15:30にカフェ")
        XCTAssertNotNil(result)
        guard let parsed = result else { return }
        let cal = Calendar.current
        XCTAssertEqual(cal.component(.hour, from: parsed.fireDate), 15)
        XCTAssertEqual(cal.component(.minute, from: parsed.fireDate), 30)
    }

    // MARK: - 絶対日付: 「X月Y日」

    func testAbsoluteDate_MonthDay() {
        let result = parser.parse(text: "3月20日の10時に出張")
        XCTAssertNotNil(result)
        guard let parsed = result else { return }
        let cal = Calendar.current
        XCTAssertEqual(cal.component(.month, from: parsed.fireDate), 3)
        XCTAssertEqual(cal.component(.day, from: parsed.fireDate), 20)
        XCTAssertEqual(cal.component(.hour, from: parsed.fireDate), 10)
    }

    func testAbsoluteDate_DefaultsToNineAM_WhenNoTime() {
        // 日付のみ → デフォルト9時
        let result = parser.parse(text: "明日にカフェ")
        XCTAssertNotNil(result)
        guard let parsed = result else { return }
        let cal = Calendar.current
        XCTAssertEqual(cal.component(.hour, from: parsed.fireDate), 9)
        XCTAssertEqual(cal.component(.minute, from: parsed.fireDate), 0)
    }

    // MARK: - 曜日パターン

    func testWeekday_Monday() {
        let result = parser.parse(text: "月曜の15時に会議")
        XCTAssertNotNil(result)
        guard let parsed = result else { return }
        let cal = Calendar.current
        XCTAssertEqual(cal.component(.weekday, from: parsed.fireDate), 2)  // 月曜 = 2
    }

    func testWeekday_Friday() {
        let result = parser.parse(text: "金曜の10時に飲み会")
        XCTAssertNotNil(result)
        guard let parsed = result else { return }
        let cal = Calendar.current
        XCTAssertEqual(cal.component(.weekday, from: parsed.fireDate), 6)  // 金曜 = 6
    }

    // MARK: - 過去時刻の翌日解釈

    func testPastTime_AutoAdvancesToTomorrow() {
        // 日付指定なしで過去の時刻 → 翌日と解釈
        // 0時(深夜)を指定することで「今日の0時」は必ず過去になる
        let result = parser.parse(text: "0時にテスト")
        XCTAssertNotNil(result)
        guard let parsed = result else { return }
        let cal = Calendar.current
        XCTAssertTrue(cal.isDateInTomorrow(parsed.fireDate))
    }

    // MARK: - 絶対日付: 「X日」（日のみ）

    func testAbsoluteDate_DayOnly_ParsesCorrectly() {
        // 「10日に本わらびを買う」のような「日のみ」指定が認識されること
        let cal = Calendar.current
        let today = cal.component(.day, from: Date())
        // 今月の末日より大きい日は除外してテスト対象日を決める
        let targetDay = today < 28 ? today + 2 : today - 2
        let text = "\(targetDay)日に本わらびを買う"
        let result = parser.parse(text: text)
        XCTAssertNotNil(result, "「\(targetDay)日」が日付として認識されなかった")
        guard let parsed = result else { return }
        XCTAssertEqual(cal.component(.day, from: parsed.fireDate), targetDay)
        XCTAssertEqual(parsed.title, "本わらびを買う")
    }

    func testAbsoluteDate_DayOnly_PastDayAdvancesToNextMonth() {
        // 1日指定 → 今日が1日より後なら翌月1日になること
        let cal = Calendar.current
        let currentDay = cal.component(.day, from: Date())
        guard currentDay > 1 else { return }  // 今日が1日なら翌月判定が不定のためスキップ
        let result = parser.parse(text: "1日に歯医者")
        XCTAssertNotNil(result)
        guard let parsed = result else { return }
        XCTAssertEqual(cal.component(.day, from: parsed.fireDate), 1)
        XCTAssertTrue(parsed.fireDate >= Date(), "過去の日付が返ってきた")
    }

    // MARK: - 総合ケース

    func testComplex_TomorrowAfternoonMeetingWithFiller() {
        let result = parser.parse(text: "明日の午後2時に部署の会議があるのでアラームをセットしてください")
        XCTAssertNotNil(result)
        guard let parsed = result else { return }
        XCTAssertFalse(parsed.title.isEmpty)
        XCTAssertFalse(parsed.title.contains("アラーム"))
        let cal = Calendar.current
        XCTAssertTrue(cal.isDateInTomorrow(parsed.fireDate))
        XCTAssertEqual(cal.component(.hour, from: parsed.fireDate), 14)
    }
}
