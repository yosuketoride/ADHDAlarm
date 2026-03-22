import XCTest
@testable import ADHDAlarm

/// DashboardViewModelのフィルタリングロジックをテストする
/// 特に今日のみ表示・過去日・翌日以降の除外を重点テスト
final class DashboardViewModelTests: XCTestCase {

    private let store = AlarmEventStore.shared

    override func setUp() {
        super.setUp()
        store.saveAll([])
    }

    override func tearDown() {
        store.saveAll([])
        super.tearDown()
    }

    // MARK: - 今日フィルタ（QA #9 デグレ防止）

    func testLoadEvents_TodayEventsIncluded() async {
        let todayAlarm = AlarmEvent.makeToday(hour: 14, title: "今日の予定")
        store.save(todayAlarm)

        let viewModel = DashboardViewModel()
        await viewModel.loadEvents()

        XCTAssertEqual(viewModel.events.count, 1)
        XCTAssertEqual(viewModel.events[0].title, "今日の予定")
    }

    func testLoadEvents_YesterdayEventsExcluded() async {
        // 昨日の予定は表示しない
        let yesterdayAlarm = AlarmEvent.makeYesterday(hour: 9, title: "昨日の予定")
        store.save(yesterdayAlarm)

        let viewModel = DashboardViewModel()
        await viewModel.loadEvents()

        XCTAssertTrue(viewModel.events.isEmpty, "昨日の予定が表示されている（バグ）")
    }

    func testLoadEvents_TomorrowEventsExcluded() async {
        // 明日の予定は表示しない（QA #9 の修正）
        let tomorrowAlarm = AlarmEvent.makeTomorrow(hour: 10, title: "明日の予定")
        store.save(tomorrowAlarm)

        let viewModel = DashboardViewModel()
        await viewModel.loadEvents()

        XCTAssertTrue(viewModel.events.isEmpty, "明日の予定が今日に表示されている（バグ）")
    }

    func testLoadEvents_MixedDates_OnlyTodayShown() async {
        let yesterday = AlarmEvent.makeYesterday(title: "昨日")
        let today = AlarmEvent.makeToday(hour: 15, title: "今日")
        let tomorrow = AlarmEvent.makeTomorrow(title: "明日")

        store.save(yesterday)
        store.save(today)
        store.save(tomorrow)

        let viewModel = DashboardViewModel()
        await viewModel.loadEvents()

        XCTAssertEqual(viewModel.events.count, 1)
        XCTAssertEqual(viewModel.events[0].title, "今日")
    }

    func testLoadEvents_StartOfDay_Included() async {
        // 当日00:00:00 は含む
        let calendar = Calendar.current
        let startOfToday = calendar.startOfDay(for: Date())
        let alarm = AlarmEvent(title: "深夜0時", fireDate: startOfToday)
        store.save(alarm)

        let viewModel = DashboardViewModel()
        await viewModel.loadEvents()

        XCTAssertEqual(viewModel.events.count, 1)
    }

    func testLoadEvents_StartOfTomorrow_Excluded() async {
        // 翌日00:00:00 は含まない
        let calendar = Calendar.current
        let startOfTomorrow = calendar.date(
            byAdding: .day, value: 1,
            to: calendar.startOfDay(for: Date())
        )!
        let alarm = AlarmEvent(title: "翌日0時", fireDate: startOfTomorrow)
        store.save(alarm)

        let viewModel = DashboardViewModel()
        await viewModel.loadEvents()

        XCTAssertTrue(viewModel.events.isEmpty, "翌日0時が今日のリストに入っている（バグ）")
    }

    // MARK: - 並び順

    func testLoadEvents_SortedByFireDate() async {
        let alarm1 = AlarmEvent.makeToday(hour: 18, title: "18時")
        let alarm2 = AlarmEvent.makeToday(hour: 9, title: "9時")
        let alarm3 = AlarmEvent.makeToday(hour: 14, title: "14時")

        store.save(alarm1)
        store.save(alarm2)
        store.save(alarm3)

        let viewModel = DashboardViewModel()
        await viewModel.loadEvents()

        XCTAssertEqual(viewModel.events.count, 3)
        XCTAssertEqual(viewModel.events[0].title, "9時")
        XCTAssertEqual(viewModel.events[1].title, "14時")
        XCTAssertEqual(viewModel.events[2].title, "18時")
    }

    // MARK: - nextAlarm

    func testNextAlarm_ReturnsSoonest_FutureOnly() async {
        let past = AlarmEvent(title: "過去の予定", fireDate: Date().addingTimeInterval(-3600))
        let near = AlarmEvent(title: "近い予定", fireDate: Date().addingTimeInterval(1800))
        let far  = AlarmEvent(title: "遠い予定", fireDate: Date().addingTimeInterval(7200))

        store.saveAll([past, near, far])

        let viewModel = DashboardViewModel()
        await viewModel.loadEvents()

        XCTAssertEqual(viewModel.nextAlarm?.title, "近い予定")
    }

    func testNextAlarm_NilWhenNoFutureAlarms() async {
        let past = AlarmEvent(title: "過去の予定", fireDate: Date().addingTimeInterval(-3600))
        store.save(past)

        let viewModel = DashboardViewModel()
        await viewModel.loadEvents()

        XCTAssertNil(viewModel.nextAlarm)
    }

    // MARK: - greeting

    func testGreeting_NotEmpty() {
        let viewModel = DashboardViewModel()
        XCTAssertFalse(viewModel.greeting.isEmpty)
    }

    // MARK: - eventSummary

    func testEventSummary_NoUpcomingEvents() async {
        let viewModel = DashboardViewModel()
        await viewModel.loadEvents()

        XCTAssertTrue(viewModel.eventSummary.contains("ありません"))
    }

    func testEventSummary_WithUpcomingEvents() async {
        let alarm = AlarmEvent.makeTest(title: "未来の予定", offsetFromNow: 3600)
        store.save(alarm)

        let viewModel = DashboardViewModel()
        await viewModel.loadEvents()

        XCTAssertFalse(viewModel.eventSummary.contains("ありません"))
    }

    // MARK: - deleteEvent

    func testDeleteEvent_RemovesFromStore() async {
        let alarm = AlarmEvent.makeToday(hour: 15, title: "削除対象")
        store.save(alarm)

        let viewModel = DashboardViewModel(
            calendarProvider: MockCalendarProvider(),
            eventStore: store
        )
        await viewModel.loadEvents()
        XCTAssertEqual(viewModel.events.count, 1)

        await viewModel.deleteEvent(alarm)

        XCTAssertEqual(viewModel.events.count, 0)
        XCTAssertNil(store.find(id: alarm.id))
    }
}
