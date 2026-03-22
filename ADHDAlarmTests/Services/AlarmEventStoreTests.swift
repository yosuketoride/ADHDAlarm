import XCTest
@testable import ADHDAlarm

/// AlarmEventStoreのCRUD操作をテストする
/// setUp/tearDownでストアをクリアしてテスト間の干渉を防ぐ
final class AlarmEventStoreTests: XCTestCase {

    private let store = AlarmEventStore.shared

    override func setUp() {
        super.setUp()
        store.saveAll([])  // テスト前にクリア
    }

    override func tearDown() {
        store.saveAll([])  // テスト後にクリア
        super.tearDown()
    }

    // MARK: - loadAll

    func testLoadAll_EmptyInitially() {
        let result = store.loadAll()
        XCTAssertTrue(result.isEmpty)
    }

    func testLoadAll_ReturnsAllSaved() {
        let alarms = [
            AlarmEvent(title: "予定1", fireDate: Date()),
            AlarmEvent(title: "予定2", fireDate: Date()),
            AlarmEvent(title: "予定3", fireDate: Date()),
        ]
        store.saveAll(alarms)

        let loaded = store.loadAll()
        XCTAssertEqual(loaded.count, 3)
    }

    // MARK: - save

    func testSave_AddsNewAlarm() {
        let alarm = AlarmEvent(title: "新しい予定", fireDate: Date())
        store.save(alarm)

        let loaded = store.loadAll()
        XCTAssertEqual(loaded.count, 1)
        XCTAssertEqual(loaded[0].id, alarm.id)
        XCTAssertEqual(loaded[0].title, alarm.title)
    }

    func testSave_UpdatesExistingAlarm() {
        var alarm = AlarmEvent(title: "元のタイトル", fireDate: Date())
        store.save(alarm)

        alarm.title = "変更後のタイトル"
        store.save(alarm)

        let loaded = store.loadAll()
        XCTAssertEqual(loaded.count, 1)  // 件数は増えない
        XCTAssertEqual(loaded[0].title, "変更後のタイトル")
    }

    func testSave_MultipleDifferentAlarms() {
        let alarm1 = AlarmEvent(title: "予定A", fireDate: Date())
        let alarm2 = AlarmEvent(title: "予定B", fireDate: Date())
        store.save(alarm1)
        store.save(alarm2)

        let loaded = store.loadAll()
        XCTAssertEqual(loaded.count, 2)
    }

    func testSave_PreservesAllFields() {
        let alarmKitID = UUID()
        let alarm = AlarmEvent(
            title: "フル情報予定",
            fireDate: Date(),
            preNotificationMinutes: 30,
            eventKitIdentifier: "ek-999",
            alarmKitIdentifier: alarmKitID,
            voiceFileName: "test.caf",
            calendarIdentifier: "cal-x",
            voiceCharacter: .maleButler
        )
        store.save(alarm)

        let loaded = store.find(id: alarm.id)
        XCTAssertNotNil(loaded)
        XCTAssertEqual(loaded?.preNotificationMinutes, 30)
        XCTAssertEqual(loaded?.eventKitIdentifier, "ek-999")
        XCTAssertEqual(loaded?.alarmKitIdentifier, alarmKitID)
        XCTAssertEqual(loaded?.voiceFileName, "test.caf")
        XCTAssertEqual(loaded?.voiceCharacter, .maleButler)
    }

    // MARK: - find by id

    func testFindByID_Found() {
        let alarm = AlarmEvent(title: "探索対象", fireDate: Date())
        store.save(alarm)

        let found = store.find(id: alarm.id)
        XCTAssertNotNil(found)
        XCTAssertEqual(found?.id, alarm.id)
    }

    func testFindByID_NotFound() {
        let found = store.find(id: UUID())
        XCTAssertNil(found)
    }

    // MARK: - find by eventKitIdentifier

    func testFindByEventKitID_Found() {
        var alarm = AlarmEvent(title: "EK検索", fireDate: Date())
        alarm.eventKitIdentifier = "ek-test-123"
        store.save(alarm)

        let found = store.find(eventKitIdentifier: "ek-test-123")
        XCTAssertNotNil(found)
        XCTAssertEqual(found?.eventKitIdentifier, "ek-test-123")
    }

    func testFindByEventKitID_NotFound() {
        let found = store.find(eventKitIdentifier: "nonexistent")
        XCTAssertNil(found)
    }

    // MARK: - find by alarmKitID

    func testFindByAlarmKitID_Found() {
        let akID = UUID()
        var alarm = AlarmEvent(title: "AlarmKit検索", fireDate: Date())
        alarm.alarmKitIdentifier = akID
        store.save(alarm)

        let found = store.find(alarmKitID: akID)
        XCTAssertNotNil(found)
        XCTAssertEqual(found?.alarmKitIdentifier, akID)
    }

    func testFindByAlarmKitID_NotFound() {
        let found = store.find(alarmKitID: UUID())
        XCTAssertNil(found)
    }

    // MARK: - delete

    func testDelete_RemovesAlarm() {
        let alarm = AlarmEvent(title: "削除対象", fireDate: Date())
        store.save(alarm)
        XCTAssertEqual(store.loadAll().count, 1)

        store.delete(id: alarm.id)
        XCTAssertEqual(store.loadAll().count, 0)
    }

    func testDelete_OnlyRemovesTarget() {
        let alarm1 = AlarmEvent(title: "残す予定", fireDate: Date())
        let alarm2 = AlarmEvent(title: "削除する予定", fireDate: Date())
        store.save(alarm1)
        store.save(alarm2)

        store.delete(id: alarm2.id)

        let loaded = store.loadAll()
        XCTAssertEqual(loaded.count, 1)
        XCTAssertEqual(loaded[0].id, alarm1.id)
    }

    func testDelete_NonexistentID_DoesNothing() {
        let alarm = AlarmEvent(title: "残す予定", fireDate: Date())
        store.save(alarm)

        store.delete(id: UUID())  // 存在しないID

        XCTAssertEqual(store.loadAll().count, 1)
    }

    // MARK: - saveAll

    func testSaveAll_ReplacesAll() {
        store.save(AlarmEvent(title: "古い予定", fireDate: Date()))
        store.save(AlarmEvent(title: "古い予定2", fireDate: Date()))

        let newAlarms = [AlarmEvent(title: "新しい予定のみ", fireDate: Date())]
        store.saveAll(newAlarms)

        let loaded = store.loadAll()
        XCTAssertEqual(loaded.count, 1)
        XCTAssertEqual(loaded[0].title, "新しい予定のみ")
    }

    func testSaveAll_EmptyArray_ClearsStore() {
        store.save(AlarmEvent(title: "消される予定", fireDate: Date()))
        store.saveAll([])
        XCTAssertTrue(store.loadAll().isEmpty)
    }

    // MARK: - データ永続化

    func testPersistence_SurvivesNewInstance() {
        let alarm = AlarmEvent(title: "永続化テスト", fireDate: Date())
        store.save(alarm)

        // 新しいAlarmEventStoreインスタンスで読み込む
        let newStore = AlarmEventStore()
        let loaded = newStore.loadAll()

        XCTAssertEqual(loaded.count, 1)
        XCTAssertEqual(loaded[0].id, alarm.id)
    }

    // MARK: - Constants.eventMarker

    func testEventMarker_Format() {
        let id = UUID()
        let marker = Constants.eventMarker(for: id)
        XCTAssertTrue(marker.hasPrefix(Constants.eventMarkerPrefix))
        XCTAssertTrue(marker.hasSuffix(Constants.eventMarkerSuffix))
        XCTAssertTrue(marker.contains(id.uuidString))
    }
}
