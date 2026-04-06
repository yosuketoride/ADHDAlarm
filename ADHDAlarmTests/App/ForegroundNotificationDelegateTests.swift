import XCTest
import UserNotifications
@testable import ADHDAlarm

final class ForegroundNotificationDelegateTests: XCTestCase {

    func testPresentationOptions_ForAlarmCategory_ShowsNoBanner() {
        let options = ForegroundNotificationDelegate.presentationOptions(
            for: Constants.Notification.alarmCategoryID
        )

        XCTAssertTrue(options.contains(.badge))
        XCTAssertFalse(options.contains(.banner))
        XCTAssertFalse(options.contains(.sound))
        XCTAssertFalse(options.contains(.list))
    }

    func testPresentationOptions_ForNonAlarmNotification_ShowsBannerSoundAndList() {
        let options = ForegroundNotificationDelegate.presentationOptions(for: "family-notice")

        XCTAssertTrue(options.contains(.banner))
        XCTAssertTrue(options.contains(.sound))
        XCTAssertTrue(options.contains(.list))
        XCTAssertFalse(options.contains(.badge))
    }
}
