import XCTest
@testable import ADHDAlarm

final class ParseConfirmationViewTests: XCTestCase {

    func testInitialSelectedFireDate_DoesNotOverwriteExplicitDate() {
        let calendar = Calendar.current
        let now = calendar.date(from: DateComponents(year: 2026, month: 4, day: 5, hour: 13, minute: 56))!
        let explicitDate = calendar.date(from: DateComponents(year: 2026, month: 4, day: 18, hour: 9, minute: 0))!
        let parsed = ParsedInput(
            title: "5001円支払い",
            fireDate: explicitDate,
            recurrenceRule: nil,
            hasExplicitDate: true
        )

        let selected = ParseConfirmationView.initialSelectedFireDate(
            parsed: parsed,
            currentSelection: nil,
            now: now
        )

        XCTAssertNil(selected, "絶対日付入力なのに確認画面が勝手に明日に補正している")
    }

    func testInitialSelectedFireDate_AutoSelectsTomorrowOnlyForTimeOnlyInput() {
        let calendar = Calendar.current
        let now = calendar.date(from: DateComponents(year: 2026, month: 4, day: 5, hour: 13, minute: 56))!
        let parsedTimeOnly = calendar.date(from: DateComponents(year: 2026, month: 4, day: 5, hour: 9, minute: 0))!
        let parsed = ParsedInput(
            title: "支払い",
            fireDate: parsedTimeOnly,
            recurrenceRule: nil,
            hasExplicitDate: false
        )

        let selected = ParseConfirmationView.initialSelectedFireDate(
            parsed: parsed,
            currentSelection: nil,
            now: now
        )

        XCTAssertNotNil(selected)
        guard let selected else { return }
        XCTAssertTrue(calendar.isDateInTomorrow(selected))
        XCTAssertEqual(calendar.component(.hour, from: selected), 9)
        XCTAssertEqual(calendar.component(.minute, from: selected), 0)
    }
}
