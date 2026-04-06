import XCTest
@testable import ADHDAlarm

final class ADHDAlarmAppTests: XCTestCase {

    func testForegroundSyncDebouncer_SkipsWhenLessThanSixtySeconds() {
        let now = Date()
        let lastSync = now.addingTimeInterval(-59)

        XCTAssertFalse(
            ForegroundSyncDebouncer.shouldRun(now: now, lastSyncTimestamp: lastSync),
            "60秒未満の.active連打では再同期しないこと"
        )
    }

    func testForegroundSyncDebouncer_RunsWhenSixtySecondsOrMoreElapsed() {
        let now = Date()
        let lastSync = now.addingTimeInterval(-60)

        XCTAssertTrue(
            ForegroundSyncDebouncer.shouldRun(now: now, lastSyncTimestamp: lastSync),
            "60秒以上空いていれば再同期すること"
        )
    }

    @MainActor
    func testPresentedAlarmStore_RetainsOnlyCurrentAlertingIDs() {
        let first = UUID()
        let second = UUID()

        PresentedAlarmStore.shared.clearAll()
        PresentedAlarmStore.shared.markPresented(first)
        PresentedAlarmStore.shared.markPresented(second)

        PresentedAlarmStore.shared.retainOnly([first])

        XCTAssertTrue(PresentedAlarmStore.shared.isPresented(first))
        XCTAssertFalse(PresentedAlarmStore.shared.isPresented(second))
        PresentedAlarmStore.shared.clearAll()
    }
}
