import XCTest
@testable import ADHDAlarm

/// SyncEngineのdiff計算ロジックと同期処理をテストする
/// AlarmKit/EventKitはモックで差し替え
final class SyncEngineTests: XCTestCase {

    private let store = AlarmEventStore.shared

    override func setUp() {
        super.setUp()
        store.saveAll([])
    }

    override func tearDown() {
        store.saveAll([])
        super.tearDown()
    }

    private func makeSyncEngine(
        calendarProvider: MockCalendarProvider = MockCalendarProvider(),
        alarmScheduler: MockAlarmScheduler = MockAlarmScheduler(),
        voiceGenerator: MockVoiceGenerator = MockVoiceGenerator()
    ) -> SyncEngine {
        SyncEngine(
            calendarProvider: calendarProvider,
            alarmScheduler: alarmScheduler,
            voiceGenerator: voiceGenerator,
            eventStore: store
        )
    }

    // MARK: - matched（一致）

    func testSync_Matched_NoChanges() async {
        let akID = UUID()
        var alarm = AlarmEvent.makeTest(title: "一致する予定")
        alarm.alarmKitIdentifier = akID
        store.save(alarm)

        let calProvider = MockCalendarProvider()
        calProvider.appEvents = [alarm]  // EventKit側と一致

        let scheduler = MockAlarmScheduler()
        let engine = makeSyncEngine(calendarProvider: calProvider, alarmScheduler: scheduler)

        await engine.performFullSync()

        // 一致している場合はキャンセルも再スケジュールもしない
        XCTAssertTrue(scheduler.cancelledIDs.isEmpty)
        XCTAssertTrue(scheduler.scheduledAlarms.isEmpty)
    }

    // MARK: - orphanedAlarm（EventKitから削除済み）

    func testSync_OrphanedAlarm_CancelsAlarmKit() async {
        // ローカルにはあるがEventKit側にはない
        let akID = UUID()
        var alarm = AlarmEvent.makeTest(title: "削除済み予定")
        alarm.alarmKitIdentifier = akID
        store.save(alarm)

        let calProvider = MockCalendarProvider()
        calProvider.appEvents = []  // EventKitには何もない

        let scheduler = MockAlarmScheduler()
        let engine = makeSyncEngine(calendarProvider: calProvider, alarmScheduler: scheduler)

        await engine.performFullSync()

        XCTAssertTrue(scheduler.cancelledIDs.contains(akID),
                      "孤立したアラームはキャンセルされるべき")
    }

    func testSync_OrphanedAlarm_MultipleAlarms_AllCancelled() async {
        let ids = [UUID(), UUID(), UUID()]
        for (i, akID) in ids.enumerated() {
            var alarm = AlarmEvent.makeTest(title: "予定\(i)")
            alarm.alarmKitIdentifier = akID
            store.save(alarm)
        }

        let calProvider = MockCalendarProvider()
        calProvider.appEvents = []

        let scheduler = MockAlarmScheduler()
        let engine = makeSyncEngine(calendarProvider: calProvider, alarmScheduler: scheduler)

        await engine.performFullSync()

        for id in ids {
            XCTAssertTrue(scheduler.cancelledIDs.contains(id))
        }
    }

    // MARK: - orphanedEvent（AlarmKitから消えた）

    func testSync_OrphanedEvent_ReschedulesAlarm() async {
        let alarm = AlarmEvent.makeTest(title: "再登録が必要な予定")
        // EventKit側にあるが、ローカルマッピングにはない
        let calProvider = MockCalendarProvider()
        calProvider.appEvents = [alarm]

        let scheduler = MockAlarmScheduler()
        let voiceGen = MockVoiceGenerator()
        voiceGen.returnURL = URL(fileURLWithPath: "/tmp/\(alarm.id.uuidString).caf")
        let engine = makeSyncEngine(
            calendarProvider: calProvider,
            alarmScheduler: scheduler,
            voiceGenerator: voiceGen
        )

        await engine.performFullSync()

        XCTAssertEqual(scheduler.scheduledAlarms.count, 1,
                       "孤立イベントは再スケジュールされるべき")
    }

    // MARK: - mismatch（日時変更）

    func testSync_Mismatch_ReschedulesWithNewDate() async {
        let akID = UUID()
        var localAlarm = AlarmEvent.makeTest(title: "変更される予定", offsetFromNow: 3600)
        localAlarm.alarmKitIdentifier = akID
        store.save(localAlarm)

        // EventKit側では1時間後ろにズレた
        var ekAlarm = localAlarm
        ekAlarm.fireDate = localAlarm.fireDate.addingTimeInterval(3600)  // +1時間

        let calProvider = MockCalendarProvider()
        calProvider.appEvents = [ekAlarm]

        let scheduler = MockAlarmScheduler()
        let voiceGen = MockVoiceGenerator()
        voiceGen.returnURL = URL(fileURLWithPath: "/tmp/\(localAlarm.id.uuidString).caf")
        let engine = makeSyncEngine(
            calendarProvider: calProvider,
            alarmScheduler: scheduler,
            voiceGenerator: voiceGen
        )

        await engine.performFullSync()

        // 古いアラームをキャンセルして新しい日時で再登録
        XCTAssertTrue(scheduler.cancelledIDs.contains(akID),
                      "変更前のアラームキャンセルが必要")
        XCTAssertEqual(scheduler.scheduledAlarms.count, 1,
                       "新しい日時で再スケジュールが必要")
    }

    func testSync_MinorTimeDiff_Under60s_NoReschedule() async {
        let akID = UUID()
        var localAlarm = AlarmEvent.makeTest(title: "微小な差異", offsetFromNow: 3600)
        localAlarm.alarmKitIdentifier = akID
        store.save(localAlarm)

        // EventKit側では30秒だけ違う（許容範囲内）
        var ekAlarm = localAlarm
        ekAlarm.fireDate = localAlarm.fireDate.addingTimeInterval(30)  // 30秒差

        let calProvider = MockCalendarProvider()
        calProvider.appEvents = [ekAlarm]

        let scheduler = MockAlarmScheduler()
        let engine = makeSyncEngine(calendarProvider: calProvider, alarmScheduler: scheduler)

        await engine.performFullSync()

        // 60秒未満の差異は無視
        XCTAssertTrue(scheduler.cancelledIDs.isEmpty)
        XCTAssertTrue(scheduler.scheduledAlarms.isEmpty)
    }

    // MARK: - エラーハンドリング

    func testSync_CalendarProviderThrows_DoesNotCrash() async {
        let calProvider = MockCalendarProvider()
        calProvider.shouldThrow = true

        let engine = makeSyncEngine(calendarProvider: calProvider)

        // エラーが発生してもクラッシュしない
        await engine.performFullSync()
    }

    func testSync_SchedulerThrows_ContinuesWithOtherDiffs() async {
        let alarms = [
            AlarmEvent.makeTest(title: "予定A"),
            AlarmEvent.makeTest(title: "予定B"),
        ]

        let calProvider = MockCalendarProvider()
        calProvider.appEvents = alarms  // どちらもorphanedEvent

        let scheduler = MockAlarmScheduler()
        scheduler.shouldThrow = true  // スケジューリング失敗

        let engine = makeSyncEngine(calendarProvider: calProvider, alarmScheduler: scheduler)

        // エラーが発生してもクラッシュしない
        await engine.performFullSync()
    }
}
