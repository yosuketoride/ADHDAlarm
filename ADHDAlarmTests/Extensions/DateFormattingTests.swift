import XCTest
@testable import ADHDAlarm

final class DateFormattingTests: XCTestCase {

    private let calendar = Calendar.current

    // MARK: - japaneseTimeString

    func testJapaneseTimeString_Format_HH_mm() {
        var components = calendar.dateComponents([.year, .month, .day], from: Date())
        components.hour = 15
        components.minute = 30
        let date = calendar.date(from: components)!

        XCTAssertEqual(date.japaneseTimeString, "15:30")
    }

    func testJapaneseTimeString_MidnightFormat() {
        var components = calendar.dateComponents([.year, .month, .day], from: Date())
        components.hour = 0
        components.minute = 0
        let date = calendar.date(from: components)!

        XCTAssertEqual(date.japaneseTimeString, "00:00")
    }

    func testJapaneseTimeString_SingleDigitHour_PadsZero() {
        var components = calendar.dateComponents([.year, .month, .day], from: Date())
        components.hour = 9
        components.minute = 5
        let date = calendar.date(from: components)!

        XCTAssertEqual(date.japaneseTimeString, "09:05")
    }

    func testJapaneseTimeString_Noon() {
        var components = calendar.dateComponents([.year, .month, .day], from: Date())
        components.hour = 12
        components.minute = 0
        let date = calendar.date(from: components)!

        XCTAssertEqual(date.japaneseTimeString, "12:00")
    }

    // MARK: - japaneseDateString

    func testJapaneseDateString_ContainsMonthDay() {
        var components = DateComponents()
        components.year = 2026
        components.month = 3
        components.day = 20
        components.hour = 10
        let date = calendar.date(from: components)!

        let str = date.japaneseDateString
        XCTAssertTrue(str.contains("3月"), "月が含まれていない: \(str)")
        XCTAssertTrue(str.contains("20日"), "日が含まれていない: \(str)")
    }

    func testJapaneseDateString_ContainsWeekday() {
        var components = DateComponents()
        components.year = 2026
        components.month = 3
        components.day = 20  // 2026年3月20日 = 金曜日
        let date = calendar.date(from: components)!

        let str = date.japaneseDateString
        // 曜日文字が含まれているか確認
        let weekdays = ["月", "火", "水", "木", "金", "土", "日"]
        let containsWeekday = weekdays.contains { str.contains($0) }
        XCTAssertTrue(containsWeekday, "曜日が含まれていない: \(str)")
    }

    // MARK: - naturalJapaneseString

    func testNaturalJapaneseString_Today() {
        var components = calendar.dateComponents([.year, .month, .day], from: Date())
        components.hour = 14
        components.minute = 0
        let todayDate = calendar.date(from: components)!

        XCTAssertTrue(todayDate.naturalJapaneseString.hasPrefix("今日の"))
    }

    func testNaturalJapaneseString_Tomorrow() {
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: Date())!
        var components = calendar.dateComponents([.year, .month, .day], from: tomorrow)
        components.hour = 10
        let tomorrowDate = calendar.date(from: components)!

        XCTAssertTrue(tomorrowDate.naturalJapaneseString.hasPrefix("明日の"))
    }

    func testNaturalJapaneseString_DayAfterTomorrow_UsesDayFormat() {
        let dayAfter = calendar.date(byAdding: .day, value: 2, to: Date())!
        var components = calendar.dateComponents([.year, .month, .day], from: dayAfter)
        components.hour = 9
        let date = calendar.date(from: components)!

        // 明後日以降は「今日/明日」ではなく日付形式
        let str = date.naturalJapaneseString
        XCTAssertFalse(str.hasPrefix("今日の"), "明後日が「今日」で表示されている")
        XCTAssertFalse(str.hasPrefix("明日の"), "明後日が「明日」で表示されている")
    }

    func testNaturalJapaneseString_ContainsTime() {
        var components = calendar.dateComponents([.year, .month, .day], from: Date())
        components.hour = 15
        components.minute = 30
        let date = calendar.date(from: components)!

        XCTAssertTrue(date.naturalJapaneseString.contains("15:30"))
    }
}
