import XCTest
@testable import ADHDAlarm

final class AlarmEventTests: XCTestCase {

    // MARK: - Init Defaults

    func testInitDefaults() {
        let date = Date()
        let alarm = AlarmEvent(title: "カフェ", fireDate: date)

        XCTAssertEqual(alarm.title, "カフェ")
        XCTAssertEqual(alarm.fireDate, date)
        XCTAssertEqual(alarm.preNotificationMinutes, 15)
        XCTAssertEqual(alarm.voiceCharacter, .femaleConcierge)
        XCTAssertNil(alarm.eventKitIdentifier)
        XCTAssertNil(alarm.alarmKitIdentifier)
        XCTAssertNil(alarm.voiceFileName)
        XCTAssertNil(alarm.calendarIdentifier)
    }

    func testInitCustomValues() {
        let id = UUID()
        let date = Date()
        let alarmKitID = UUID()

        let alarm = AlarmEvent(
            id: id,
            title: "会議",
            fireDate: date,
            preNotificationMinutes: 30,
            eventKitIdentifier: "ek-123",
            alarmKitIdentifier: alarmKitID,
            voiceFileName: "abc.caf",
            calendarIdentifier: "cal-1",
            voiceCharacter: .maleButler
        )

        XCTAssertEqual(alarm.id, id)
        XCTAssertEqual(alarm.title, "会議")
        XCTAssertEqual(alarm.preNotificationMinutes, 30)
        XCTAssertEqual(alarm.eventKitIdentifier, "ek-123")
        XCTAssertEqual(alarm.alarmKitIdentifier, alarmKitID)
        XCTAssertEqual(alarm.voiceFileName, "abc.caf")
        XCTAssertEqual(alarm.calendarIdentifier, "cal-1")
        XCTAssertEqual(alarm.voiceCharacter, .maleButler)
    }

    // MARK: - Equatable

    func testEquatableSameID() {
        let id = UUID()
        let date = Date()
        let a1 = AlarmEvent(id: id, title: "A", fireDate: date)
        let a2 = AlarmEvent(id: id, title: "A", fireDate: date)
        XCTAssertEqual(a1, a2)
    }

    func testEquatableDifferentID() {
        let date = Date()
        let a1 = AlarmEvent(id: UUID(), title: "A", fireDate: date)
        let a2 = AlarmEvent(id: UUID(), title: "A", fireDate: date)
        XCTAssertNotEqual(a1, a2)
    }

    // MARK: - Codable

    func testCodableRoundTrip() throws {
        let original = AlarmEvent(
            title: "ランチ",
            fireDate: Date(),
            preNotificationMinutes: 10,
            eventKitIdentifier: "ek-456",
            alarmKitIdentifier: UUID(),
            voiceFileName: "ランチ.caf",
            calendarIdentifier: "cal-2",
            voiceCharacter: .maleButler
        )

        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(AlarmEvent.self, from: data)

        XCTAssertEqual(decoded.id, original.id)
        XCTAssertEqual(decoded.title, original.title)
        XCTAssertEqual(decoded.preNotificationMinutes, original.preNotificationMinutes)
        XCTAssertEqual(decoded.eventKitIdentifier, original.eventKitIdentifier)
        XCTAssertEqual(decoded.alarmKitIdentifier, original.alarmKitIdentifier)
        XCTAssertEqual(decoded.voiceFileName, original.voiceFileName)
        XCTAssertEqual(decoded.calendarIdentifier, original.calendarIdentifier)
        XCTAssertEqual(decoded.voiceCharacter, original.voiceCharacter)
    }

    func testCodableArrayRoundTrip() throws {
        let alarms = [
            AlarmEvent(title: "予定1", fireDate: Date()),
            AlarmEvent(title: "予定2", fireDate: Date().addingTimeInterval(3600)),
            AlarmEvent(title: "予定3", fireDate: Date().addingTimeInterval(7200)),
        ]

        let data = try JSONEncoder().encode(alarms)
        let decoded = try JSONDecoder().decode([AlarmEvent].self, from: data)

        XCTAssertEqual(decoded.count, 3)
        XCTAssertEqual(decoded.map(\.title), ["予定1", "予定2", "予定3"])
    }

    func testCodableWithNilFields() throws {
        let alarm = AlarmEvent(title: "最小予定", fireDate: Date())
        let data = try JSONEncoder().encode(alarm)
        let decoded = try JSONDecoder().decode(AlarmEvent.self, from: data)

        XCTAssertNil(decoded.eventKitIdentifier)
        XCTAssertNil(decoded.alarmKitIdentifier)
        XCTAssertNil(decoded.voiceFileName)
        XCTAssertNil(decoded.calendarIdentifier)
    }

    // MARK: - VoiceCharacter

    func testVoiceCharacterRawValues() {
        XCTAssertEqual(VoiceCharacter.femaleConcierge.rawValue, "female_concierge")
        XCTAssertEqual(VoiceCharacter.maleButler.rawValue, "male_butler")
    }

    func testVoiceCharacterDisplayNames() {
        XCTAssertFalse(VoiceCharacter.femaleConcierge.displayName.isEmpty)
        XCTAssertFalse(VoiceCharacter.maleButler.displayName.isEmpty)
    }

    func testVoiceCharacterCaseIterable() {
        XCTAssertEqual(VoiceCharacter.allCases.count, 2)
    }

    // MARK: - SubscriptionTier

    func testSubscriptionTierGates() {
        XCTAssertFalse(SubscriptionTier.free.canSelectCalendar)
        XCTAssertTrue(SubscriptionTier.pro.canSelectCalendar)

        XCTAssertFalse(SubscriptionTier.free.canSelectVoiceCharacter)
        XCTAssertTrue(SubscriptionTier.pro.canSelectVoiceCharacter)

        XCTAssertEqual(SubscriptionTier.free.maxPreNotifications, 1)
        XCTAssertGreaterThan(SubscriptionTier.pro.maxPreNotifications, 1)
    }
}
