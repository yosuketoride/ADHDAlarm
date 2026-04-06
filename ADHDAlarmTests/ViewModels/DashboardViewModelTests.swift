import XCTest
@testable import ADHDAlarm

/// PersonHomeViewModelの予定表示ロジックをテストする
/// 旧DashboardViewModelTestsを現行実装に合わせて更新
@MainActor
final class DashboardViewModelTests: XCTestCase {

    private let store = AlarmEventStore.shared

    override func setUp() {
        super.setUp()
        store.saveAll([])
        clearDashboardDefaults()
    }

    override func tearDown() {
        store.saveAll([])
        clearDashboardDefaults()
        super.tearDown()
    }

    // MARK: - 今日フィルタ（QA #9 デグレ防止）

    func testLoadEvents_TodayEventsIncluded() async {
        let todayAlarm = AlarmEvent.makeToday(hour: 14, title: "今日の予定")
        store.save(todayAlarm)

        let viewModel = PersonHomeViewModel(eventStore: store)
        await viewModel.loadEvents()

        XCTAssertEqual(viewModel.events.count, 1)
        XCTAssertEqual(viewModel.events[0].title, "今日の予定")
    }

    func testLoadEvents_YesterdayEventsExcluded() async {
        // 昨日の予定は表示しない
        let yesterdayAlarm = AlarmEvent.makeYesterday(hour: 9, title: "昨日の予定")
        store.save(yesterdayAlarm)

        let viewModel = PersonHomeViewModel(eventStore: store)
        await viewModel.loadEvents()

        XCTAssertTrue(viewModel.events.isEmpty, "昨日の予定が表示されている（バグ）")
    }

    func testLoadEvents_TomorrowEventsExcluded() async {
        // 明日の予定は表示しない（QA #9 の修正）
        let tomorrowAlarm = AlarmEvent.makeTomorrow(hour: 10, title: "明日の予定")
        store.save(tomorrowAlarm)

        let viewModel = PersonHomeViewModel(eventStore: store)
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

        let viewModel = PersonHomeViewModel(eventStore: store)
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

        let viewModel = PersonHomeViewModel(eventStore: store)
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

        let viewModel = PersonHomeViewModel(eventStore: store)
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

        let viewModel = PersonHomeViewModel(eventStore: store)
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

        let viewModel = PersonHomeViewModel(eventStore: store)
        await viewModel.loadEvents()

        XCTAssertEqual(viewModel.nextAlarm?.title, "近い予定")
    }

    func testNextAlarm_NilWhenNoFutureAlarms() async {
        let past = AlarmEvent(title: "過去の予定", fireDate: Date().addingTimeInterval(-3600))
        store.save(past)

        let viewModel = PersonHomeViewModel(eventStore: store)
        await viewModel.loadEvents()

        XCTAssertNil(viewModel.nextAlarm)
    }

    // MARK: - greeting

    func testGreeting_NotEmpty() {
        let viewModel = PersonHomeViewModel(eventStore: store)
        XCTAssertFalse(viewModel.greeting.isEmpty)
    }

    // MARK: - emptyStateInfo

    func testEmptyStateInfo_NoEventsShowsRelaxedMessage() async {
        let viewModel = PersonHomeViewModel(eventStore: store)
        await viewModel.loadEvents()

        XCTAssertTrue(viewModel.emptyStateInfo.message.contains("今日はのんびり"))
        XCTAssertTrue(viewModel.emptyStateInfo.ctaLabel.contains("予定を追加"))
    }

    func testEmptyStateInfo_AllCompletedShowsCompletionMessage() async {
        var alarm = AlarmEvent.makeTest(title: "完了した予定", offsetFromNow: 3600)
        alarm.completionStatus = .completed
        store.save(alarm)

        let viewModel = PersonHomeViewModel(eventStore: store)
        await viewModel.loadEvents()

        XCTAssertTrue(viewModel.emptyStateInfo.message.contains("全部終わった"))
        XCTAssertTrue(viewModel.emptyStateInfo.ctaLabel.contains("明日の予定"))
    }

    func testEmptyStateInfo_SkippedShowsRestMessage() async {
        var alarm = AlarmEvent.makeTest(title: "お休みした予定", offsetFromNow: 3600)
        alarm.completionStatus = .skipped
        store.save(alarm)

        let viewModel = PersonHomeViewModel(eventStore: store)
        await viewModel.loadEvents()

        XCTAssertTrue(viewModel.emptyStateInfo.message.contains("無理せず休もう"))
        XCTAssertTrue(viewModel.emptyStateInfo.ctaLabel.contains("体調が戻ったら"))
    }

    func testTomorrowEvents_LimitsUpcomingListToTwoItems() async {
        let tomorrow = AlarmEvent.makeTomorrow(hour: 9, title: "明日1")
        let dayAfterTomorrow = AlarmEvent.makeTomorrow(hour: 10, title: "明日2")
        let third = AlarmEvent(
            title: "明日3",
            fireDate: Calendar.current.date(byAdding: .day, value: 2, to: Date()) ?? Date()
        )
        store.saveAll([third, dayAfterTomorrow, tomorrow])

        let viewModel = PersonHomeViewModel(eventStore: store)
        await viewModel.loadEvents()

        XCTAssertEqual(viewModel.tomorrowEvents.count, 2)
        XCTAssertEqual(viewModel.tomorrowEvents.map(\.title), ["明日1", "明日2"])
    }

    // MARK: - 大量タスク折りたたみ

    func testVisibleEvents_CollapsedShowsOnlyThreeIncompleteEvents() async {
        let alarms = [
            AlarmEvent.makeTest(title: "予定1", offsetFromNow: 900),
            AlarmEvent.makeTest(title: "予定2", offsetFromNow: 1800),
            AlarmEvent.makeTest(title: "予定3", offsetFromNow: 2700),
            AlarmEvent.makeTest(title: "予定4", offsetFromNow: 3600),
            AlarmEvent.makeTest(title: "予定5", offsetFromNow: 4500),
        ]
        store.saveAll(alarms)

        let viewModel = PersonHomeViewModel(eventStore: store)
        await viewModel.loadEvents()

        XCTAssertEqual(viewModel.visibleEvents.count, 3)
        XCTAssertEqual(viewModel.visibleEvents.map(\.title), ["予定2", "予定3", "予定4"])
        XCTAssertEqual(viewModel.hiddenEventCount, 1)
        XCTAssertTrue(viewModel.shouldShowExpandButton)
        XCTAssertFalse(viewModel.shouldShowCollapseButton)
    }

    func testVisibleEvents_ExpandedShowsAllIncompleteEventsAndCollapseButton() async {
        let alarms = [
            AlarmEvent.makeTest(title: "予定1", offsetFromNow: 900),
            AlarmEvent.makeTest(title: "予定2", offsetFromNow: 1800),
            AlarmEvent.makeTest(title: "予定3", offsetFromNow: 2700),
            AlarmEvent.makeTest(title: "予定4", offsetFromNow: 3600),
            AlarmEvent.makeTest(title: "予定5", offsetFromNow: 4500),
        ]
        store.saveAll(alarms)

        let viewModel = PersonHomeViewModel(eventStore: store)
        await viewModel.loadEvents()
        viewModel.isEventListExpanded = true

        XCTAssertEqual(viewModel.visibleEvents.count, 4)
        XCTAssertEqual(viewModel.visibleEvents.map(\.title), ["予定2", "予定3", "予定4", "予定5"])
        XCTAssertEqual(viewModel.hiddenEventCount, 1)
        XCTAssertFalse(viewModel.shouldShowExpandButton)
        XCTAssertTrue(viewModel.shouldShowCollapseButton)
    }

    func testVisibleEvents_CompletedEventsDoNotCountTowardCollapseThreshold() async {
        let alarms = [
            AlarmEvent.makeTest(title: "予定1", offsetFromNow: 900),
            AlarmEvent.makeTest(title: "予定2", offsetFromNow: 1800),
            AlarmEvent.makeTest(title: "予定3", offsetFromNow: 2700),
        ]
        var completed = AlarmEvent.makeTest(title: "完了済み", offsetFromNow: 3600)
        completed.completionStatus = .completed
        store.saveAll(alarms + [completed])

        let viewModel = PersonHomeViewModel(eventStore: store)
        await viewModel.loadEvents()

        XCTAssertEqual(viewModel.visibleEvents.count, 2)
        XCTAssertEqual(viewModel.hiddenEventCount, 0)
        XCTAssertFalse(viewModel.shouldShowExpandButton)
        XCTAssertFalse(viewModel.shouldShowCollapseButton)
        XCTAssertEqual(viewModel.completedTodayEvents.map(\.title), ["完了済み"])
    }

    // MARK: - ふくろう進化

    func testOwlEvolutionStage_ChangesAtXPThresholds() {
        XCTAssertEqual(PersonHomeViewModel.evolutionStage(for: 0), 0)
        XCTAssertEqual(PersonHomeViewModel.evolutionStage(for: 99), 0)
        XCTAssertEqual(PersonHomeViewModel.evolutionStage(for: 100), 1)
        XCTAssertEqual(PersonHomeViewModel.evolutionStage(for: 499), 1)
        XCTAssertEqual(PersonHomeViewModel.evolutionStage(for: 500), 2)
        XCTAssertEqual(PersonHomeViewModel.evolutionStage(for: 999), 2)
        XCTAssertEqual(PersonHomeViewModel.evolutionStage(for: 1000), 3)
    }

    // MARK: - デイリーミニタスク

    func testCompleteDailyMiniTask_AwardsXPOnlyOncePerDayAndResetsNextDay() {
        let appState = AppState()
        let viewModel = PersonHomeViewModel(eventStore: store)
        viewModel.bindAppStateIfNeeded(appState)

        viewModel.completeDailyMiniTask()
        XCTAssertEqual(appState.owlXP, 5)
        XCTAssertTrue(viewModel.isMiniTaskCompletedToday)

        viewModel.completeDailyMiniTask()
        XCTAssertEqual(appState.owlXP, 5, "同じ日は再加算されないこと")

        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: Date()) ?? .distantPast
        UserDefaults.standard.set(yesterday, forKey: "miniTaskCompletedDate")

        viewModel.completeDailyMiniTask()
        XCTAssertEqual(appState.owlXP, 10, "翌日は再び+5XPされること")
    }

    // MARK: - deleteEvent

    func testDeleteEvent_HidesImmediatelyAndRemovesFromStoreAfterUndoWindow() async throws {
        let alarm = AlarmEvent.makeToday(hour: 15, title: "削除対象")
        store.save(alarm)

        let viewModel = PersonHomeViewModel(
            calendarProvider: MockCalendarProvider(),
            eventStore: store
        )
        await viewModel.loadEvents()
        XCTAssertEqual(viewModel.events.count, 1)

        await viewModel.deleteEvent(alarm)

        XCTAssertEqual(viewModel.events.count, 0)
        XCTAssertEqual(viewModel.pendingDelete?.id, alarm.id, "Undo猶予中の予定として保持されること")
        XCTAssertNotNil(store.find(id: alarm.id), "Undo猶予中はストアから即削除しないこと")

        try await Task.sleep(for: .seconds(3.2))

        XCTAssertNil(viewModel.pendingDelete, "Undo猶予後はpendingDeleteが解放されること")
        XCTAssertNil(store.find(id: alarm.id), "Undo猶予後はストアから削除されること")
    }

    private func clearDashboardDefaults() {
        let keys = [
            "miniTaskCompletedDate",
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
