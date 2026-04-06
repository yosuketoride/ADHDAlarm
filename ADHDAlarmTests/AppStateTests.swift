import XCTest
@testable import ADHDAlarm

@MainActor
final class AppStateTests: XCTestCase {

    private var appState: AppState!

    override func setUp() async throws {
        clearXPDefaults()
        appState = AppState()
    }

    override func tearDown() async throws {
        appState = nil
        clearXPDefaults()
    }

    func testAddXP_CompleteAndSkipAddExpectedXP() {
        XCTAssertEqual(appState.owlXP, 0, "起動直後はXPが0であること")
        XCTAssertEqual(
            UserDefaults.standard.integer(forKey: Constants.Keys.owlXPToday),
            0,
            "起動直後は本日のXP加算量も0であること"
        )

        appState.addXP(10)
        appState.addXP(3)

        XCTAssertEqual(appState.owlXP, 13, "完了+10とスキップ+3で合計13XPになること")
        XCTAssertEqual(
            UserDefaults.standard.integer(forKey: Constants.Keys.owlXPToday),
            13,
            "今日の加算量も13XPとして記録されること"
        )
    }

    func testAddXP_DoesNotExceedDailyCap() {
        appState.addXP(10)
        appState.addXP(45)
        appState.addXP(3)

        XCTAssertEqual(appState.owlXP, 50, "1日の上限50XPを超えないこと")
        XCTAssertEqual(
            UserDefaults.standard.integer(forKey: Constants.Keys.owlXPToday),
            50,
            "今日の加算量も50XPで止まること"
        )
    }

    func testAddXP_ResetsDailyCapAfterDateChange() {
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: Date()) ?? .distantPast
        UserDefaults.standard.set(50, forKey: Constants.Keys.owlXPToday)
        UserDefaults.standard.set(yesterday, forKey: Constants.Keys.owlXPLastDate)

        appState.addXP(10)

        XCTAssertEqual(appState.owlXP, 10, "日付またぎ後は今日の加算として10XP入ること")
        XCTAssertEqual(
            UserDefaults.standard.integer(forKey: Constants.Keys.owlXPToday),
            10,
            "前日の上限到達状態はリセットされること"
        )
        let storedDate = UserDefaults.standard.object(forKey: Constants.Keys.owlXPLastDate) as? Date
        XCTAssertNotNil(storedDate, "最終加算日が更新されること")
        if let storedDate {
            XCTAssertTrue(Calendar.current.isDateInToday(storedDate), "最終加算日は今日に更新されること")
        }
    }

    func testClearVoiceAndAccessibilityMode_AreIndependent() {
        XCTAssertFalse(appState.isClearVoiceEnabled)
        XCTAssertFalse(appState.isAccessibilityModeEnabled)

        appState.isClearVoiceEnabled = true

        XCTAssertTrue(appState.isClearVoiceEnabled)
        XCTAssertFalse(appState.isAccessibilityModeEnabled, "クリアボイスONで文字拡大設定が変化しないこと")

        appState.isAccessibilityModeEnabled = true

        XCTAssertTrue(appState.isClearVoiceEnabled, "文字拡大ON後もクリアボイス設定が維持されること")
        XCTAssertTrue(appState.isAccessibilityModeEnabled)
    }

    private func clearXPDefaults() {
        let keys = [
            Constants.Keys.owlXP,
            Constants.Keys.owlXPToday,
            Constants.Keys.owlXPLastDate,
        ]

        for key in keys {
            UserDefaults.standard.removeObject(forKey: key)
            UserDefaults(suiteName: Constants.appGroupID)?.removeObject(forKey: key)
        }
    }
}
