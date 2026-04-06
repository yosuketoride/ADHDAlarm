import XCTest
@testable import ADHDAlarm

final class DataMigrationServiceTests: XCTestCase {

    private let store = AlarmEventStore.shared

    override func setUp() {
        super.setUp()
        store.saveAll([])
        UserDefaults.standard.removeObject(forKey: "dataModelVersion")
    }

    override func tearDown() {
        store.saveAll([])
        UserDefaults.standard.removeObject(forKey: "dataModelVersion")
        super.tearDown()
    }

    func testMigrateIfNeeded_SavesCurrentVersion() {
        UserDefaults.standard.set(1, forKey: "dataModelVersion")

        DataMigrationService.migrateIfNeeded()

        XCTAssertEqual(
            UserDefaults.standard.integer(forKey: "dataModelVersion"),
            DataMigrationService.currentVersion
        )
    }

    func testMigrateIfNeeded_RewritesExistingEventsWithoutLosingData() {
        let alarm = AlarmEvent(
            title: "既存予定",
            fireDate: Date().addingTimeInterval(3600),
            preNotificationMinutes: 30,
            eventKitIdentifier: "ek-existing",
            voiceCharacter: .maleButler,
            eventEmoji: "💊",
            isToDo: true
        )
        store.save(alarm)
        UserDefaults.standard.set(1, forKey: "dataModelVersion")

        DataMigrationService.migrateIfNeeded()

        store.invalidateCache()
        let migrated = store.find(id: alarm.id)
        XCTAssertNotNil(migrated)
        XCTAssertEqual(migrated?.title, "既存予定")
        XCTAssertEqual(migrated?.preNotificationMinutes, 30)
        XCTAssertEqual(migrated?.eventKitIdentifier, "ek-existing")
        XCTAssertEqual(migrated?.voiceCharacter, .maleButler)
        XCTAssertEqual(migrated?.eventEmoji, "💊")
        XCTAssertEqual(migrated?.isToDo, true)
    }

    func testMigrateIfNeeded_FillsMissingEmojiWithPin() {
        let alarm = AlarmEvent(
            title: "絵文字なし予定",
            fireDate: Date().addingTimeInterval(7200),
            eventEmoji: nil
        )
        store.save(alarm)
        UserDefaults.standard.set(1, forKey: "dataModelVersion")

        DataMigrationService.migrateIfNeeded()

        store.invalidateCache()
        let migrated = try! XCTUnwrap(store.find(id: alarm.id))
        XCTAssertEqual(migrated.eventEmoji, "📌")
    }
}
