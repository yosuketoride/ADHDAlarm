import XCTest
@testable import ADHDAlarm

/// SyncEngineのdiff計算ロジックと同期処理をテストする
/// AlarmKit/EventKitはモックで差し替え
final class SyncEngineTests: XCTestCase {

    private let store = AlarmEventStore.shared

    override func setUp() {
        super.setUp()
        store.saveAll([])
        UserDefaults.standard.removeObject(forKey: "lastDailyResetDate")
    }

    override func tearDown() {
        store.saveAll([])
        UserDefaults.standard.removeObject(forKey: "lastDailyResetDate")
        super.tearDown()
    }

    private func makeSyncEngine(
        calendarProvider: MockCalendarProvider = MockCalendarProvider(),
        alarmScheduler: MockAlarmScheduler = MockAlarmScheduler(),
        voiceGenerator: MockVoiceGenerator = MockVoiceGenerator(),
        familyService: MockFamilyService? = nil
    ) -> SyncEngine {
        SyncEngine(
            calendarProvider: calendarProvider,
            alarmScheduler: alarmScheduler,
            voiceGenerator: voiceGenerator,
            eventStore: store,
            familyService: familyService
        )
    }

    /// テスト用RemoteEventRecordを作成するヘルパー
    private func makeRemoteRecord(
        id: String = UUID().uuidString,
        title: String = "テストリモート予定",
        status: String = "pending",
        offsetFromNow: TimeInterval = 3600
    ) -> RemoteEventRecord {
        RemoteEventRecord(
            id: id,
            familyLinkId: "link-1",
            creatorDeviceId: "child-device",
            targetDeviceId: "parent-device",
            title: title,
            fireDate: Date().addingTimeInterval(offsetFromNow),
            preNotificationMinutes: 15,
            voiceCharacter: "femaleConcierge",
            note: nil,
            status: status,
            createdAt: Date(),
            syncedAt: nil
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

    func testSync_Mismatch_WithNewerEventKitModifiedDate_AppliesImmediately() async {
        let akID = UUID()
        var localAlarm = AlarmEvent.makeTest(title: "外部編集で変更された予定", offsetFromNow: 3600)
        localAlarm.alarmKitIdentifier = akID
        localAlarm.eventKitLastModifiedAt = Date().addingTimeInterval(-120)
        store.save(localAlarm)

        var ekAlarm = localAlarm
        ekAlarm.fireDate = localAlarm.fireDate.addingTimeInterval(1800)
        ekAlarm.eventKitLastModifiedAt = Date()

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

        let saved = store.find(id: localAlarm.id)
        XCTAssertEqual(saved?.fireDate, ekAlarm.fireDate, "外部編集らしい変更は初回で採用されること")
        XCTAssertNil(saved?.pendingEventKitFireDate, "採用後は保留中の差分を残さないこと")
        XCTAssertTrue(scheduler.cancelledIDs.contains(akID))
        XCTAssertEqual(scheduler.scheduledAlarms.count, 1)
    }

    func testSync_Mismatch_WithoutModifiedDate_KeepsPendingUntilNextSync() async {
        let akID = UUID()
        var localAlarm = AlarmEvent.makeTest(title: "揺れるEventKit差分", offsetFromNow: 3600)
        localAlarm.alarmKitIdentifier = akID
        store.save(localAlarm)

        var ekAlarm = localAlarm
        ekAlarm.fireDate = localAlarm.fireDate.addingTimeInterval(1800)
        ekAlarm.eventKitLastModifiedAt = nil

        let calProvider = MockCalendarProvider()
        calProvider.appEvents = [ekAlarm]

        let scheduler = MockAlarmScheduler()
        let engine = makeSyncEngine(calendarProvider: calProvider, alarmScheduler: scheduler)

        await engine.performFullSync()

        let saved = store.find(id: localAlarm.id)
        XCTAssertEqual(saved?.fireDate, localAlarm.fireDate, "判断材料が弱い差分は初回では採用しないこと")
        XCTAssertEqual(saved?.pendingEventKitFireDate, ekAlarm.fireDate, "次回確認用に保留値を持つこと")
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

    // MARK: - syncRemoteEvents: pending→登録

    func testSyncRemoteEvents_PendingEvent_RegistersAlarmAndMarksSync() async {
        // Arrange
        let record = makeRemoteRecord(title: "お薬の時間")
        let mockFamily = MockFamilyService()
        mockFamily.stubPendingEvents = [record]

        let scheduler = MockAlarmScheduler()
        let calProvider = MockCalendarProvider()
        let voiceGen = MockVoiceGenerator()

        let engine = makeSyncEngine(
            calendarProvider: calProvider,
            alarmScheduler: scheduler,
            voiceGenerator: voiceGen,
            familyService: mockFamily
        )

        // Act
        await engine.syncRemoteEvents()

        // Assert: アラームが登録されている
        XCTAssertEqual(scheduler.scheduledAlarms.count, 1)
        XCTAssertEqual(scheduler.scheduledAlarms.first?.title, "お薬の時間")

        // カレンダーに書き込まれている
        XCTAssertEqual(calProvider.writtenEvents.count, 1)

        // 音声ファイルが生成されている
        XCTAssertEqual(voiceGen.generatedAlarmIDs.count, 1)

        // Supabaseにsynced済みとしてマークされている
        XCTAssertEqual(mockFamily.syncedEventIds, [record.id])

        // ローカルストアにremoteEventIdつきで保存されている
        let saved = store.find(remoteEventId: record.id)
        XCTAssertNotNil(saved)
        XCTAssertEqual(saved?.title, "お薬の時間")
    }

    func testSyncRemoteEvents_ExpiredPendingEvent_SavesAsMissedWithoutScheduling() async {
        let record = makeRemoteRecord(
            title: "期限切れ予定",
            offsetFromNow: -(16 * 60)
        )
        let mockFamily = MockFamilyService()
        mockFamily.stubPendingEvents = [record]

        let scheduler = MockAlarmScheduler()
        let engine = makeSyncEngine(alarmScheduler: scheduler, familyService: mockFamily)

        await engine.syncRemoteEvents()

        XCTAssertTrue(scheduler.scheduledAlarms.isEmpty, "15分超過の予定はAlarmKit登録しないこと")
        let saved = store.find(remoteEventId: record.id)
        XCTAssertEqual(saved?.completionStatus, .missed, "15分超過の予定はmissedで保存されること")
        XCTAssertEqual(mockFamily.syncedEventIds, [record.id], "取り込み済みとして同期されること")
    }

    func testSyncRemoteEvents_AlreadySyncedEvent_NotDuplicated() async {
        // Arrange: 既にローカルに同じremoteEventIdで保存済み
        let record = makeRemoteRecord(title: "既存予定")
        var existingAlarm = AlarmEvent(
            title: "既存予定",
            fireDate: record.fireDate,
            remoteEventId: record.id
        )
        store.save(existingAlarm)

        let mockFamily = MockFamilyService()
        mockFamily.stubPendingEvents = [record]

        let scheduler = MockAlarmScheduler()
        let engine = makeSyncEngine(alarmScheduler: scheduler, familyService: mockFamily)

        // Act
        await engine.syncRemoteEvents()

        // Assert: 重複スケジュールされない
        XCTAssertTrue(scheduler.scheduledAlarms.isEmpty)
        XCTAssertTrue(mockFamily.syncedEventIds.isEmpty)
    }

    // MARK: - syncRemoteEvents: cancelled→ロールバック

    func testSyncRemoteEvents_CancelledEvent_RemovesAlarmAndMarksRolledBack() async {
        // Arrange: ローカルに登録済みのアラームをキャンセルされた状態にする
        let record = makeRemoteRecord(title: "ゴミ出し", status: "cancelled")
        let akID = UUID()
        var localAlarm = AlarmEvent(
            title: "ゴミ出し",
            fireDate: record.fireDate,
            alarmKitIdentifier: akID,
            remoteEventId: record.id
        )
        localAlarm.eventKitIdentifier = "ek-test-id"
        store.save(localAlarm)

        let mockFamily = MockFamilyService()
        mockFamily.stubCancelledEvents = [record]

        let scheduler = MockAlarmScheduler()
        let calProvider = MockCalendarProvider()
        let voiceGen = MockVoiceGenerator()

        let engine = makeSyncEngine(
            calendarProvider: calProvider,
            alarmScheduler: scheduler,
            voiceGenerator: voiceGen,
            familyService: mockFamily
        )

        // Act
        await engine.syncRemoteEvents()

        // Assert: アラームがキャンセルされている
        XCTAssertTrue(scheduler.cancelledIDs.contains(akID))

        // EventKitから削除されている
        XCTAssertEqual(calProvider.deletedIDs, ["ek-test-id"])

        // 音声ファイルが削除されている
        XCTAssertEqual(voiceGen.deletedAlarmIDs, [localAlarm.id])

        // ローカルストアから削除されている
        XCTAssertNil(store.find(remoteEventId: record.id))

        // Supabaseにrolled_backとしてマークされている
        XCTAssertEqual(mockFamily.rolledBackEventIds, [record.id])
    }

    func testSyncRemoteEvents_CancelledEventWithNoLocal_MarksRolledBackAnyway() async {
        // Arrange: ローカルに存在しないキャンセル済みイベント
        let record = makeRemoteRecord(status: "cancelled")
        let mockFamily = MockFamilyService()
        mockFamily.stubCancelledEvents = [record]

        let engine = makeSyncEngine(familyService: mockFamily)

        // Act
        await engine.syncRemoteEvents()

        // Assert: ローカルに何もなくてもrolled_backにマークされる（再ロールバック防止）
        XCTAssertEqual(mockFamily.rolledBackEventIds, [record.id])
    }

    func testSync_OrphanedAlarm_ReconnectsByMarkerWithoutDeleting() async {
        let akID = UUID()
        var localAlarm = AlarmEvent.makeTest(title: "再接続される予定", offsetFromNow: 3600)
        localAlarm.alarmKitIdentifier = akID
        localAlarm.eventKitIdentifier = "stale-ek-id"
        store.save(localAlarm)

        var rescued = localAlarm
        rescued.eventKitIdentifier = "new-ek-id"
        rescued.eventKitLastModifiedAt = Date()
        rescued.fireDate = localAlarm.fireDate.addingTimeInterval(900)

        let calProvider = MockCalendarProvider()
        calProvider.appEvents = []
        calProvider.foundAppEvent = rescued

        let scheduler = MockAlarmScheduler()
        let engine = makeSyncEngine(calendarProvider: calProvider, alarmScheduler: scheduler)

        await engine.performFullSync()

        let saved = store.find(id: localAlarm.id)
        XCTAssertEqual(saved?.eventKitIdentifier, "new-ek-id", "marker再探索でEventKit IDを結び直すこと")
        XCTAssertEqual(saved?.fireDate, rescued.fireDate, "再接続時にfireDateも更新すること")
        XCTAssertTrue(scheduler.cancelledIDs.isEmpty, "再接続できた予定は削除扱いにしないこと")
    }

    func testSyncRemoteEvents_FamilyServiceNil_DoesNotCrash() async {
        // Arrange: familyService=nil
        let engine = makeSyncEngine(familyService: nil)

        // Act & Assert: クラッシュしない
        await engine.syncRemoteEvents()
    }

    func testPerformFullSync_DailyResetDeletesCompletedToDo() async {
        var completedToDo = AlarmEvent(
            title: "完了済みToDo",
            fireDate: Date().addingTimeInterval(-3600),
            isToDo: true
        )
        completedToDo.completionStatus = .completed
        store.save(completedToDo)

        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: Date()) ?? .distantPast
        UserDefaults.standard.set(yesterday, forKey: "lastDailyResetDate")

        let engine = makeSyncEngine()
        await engine.performFullSync()

        XCTAssertNil(store.find(id: completedToDo.id), "日付変更時に完了済みToDoは削除されること")
    }

    func testPerformFullSync_DailyResetKeepsIncompleteToDoForNextDay() async {
        let pendingToDo = AlarmEvent(
            title: "持ち越しToDo",
            fireDate: Date().addingTimeInterval(-3600),
            isToDo: true
        )
        store.save(pendingToDo)

        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: Date()) ?? .distantPast
        UserDefaults.standard.set(yesterday, forKey: "lastDailyResetDate")

        let engine = makeSyncEngine()
        await engine.performFullSync()

        let carriedOver = store.find(id: pendingToDo.id)
        XCTAssertNotNil(carriedOver, "未完了ToDoは翌日に持ち越されること")
        XCTAssertNil(carriedOver?.completionStatus)
        XCTAssertTrue(carriedOver?.isToDo == true)
    }
}
