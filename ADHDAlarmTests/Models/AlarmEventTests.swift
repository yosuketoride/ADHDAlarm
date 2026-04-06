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
        XCTAssertEqual(alarm.alarmKitIdentifiers, [])
        XCTAssertEqual(alarm.alarmKitMinutesMap, [:])
        XCTAssertNil(alarm.completionStatus)
        XCTAssertEqual(alarm.snoozeCount, 0)
        XCTAssertFalse(alarm.isToDo)
        XCTAssertNil(alarm.undoPendingUntil)
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
        let createdAt = Date()
        let a1 = AlarmEvent(id: id, title: "A", fireDate: date, createdAt: createdAt)
        let a2 = AlarmEvent(id: id, title: "A", fireDate: date, createdAt: createdAt)
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
        let undoDeadline = Date().addingTimeInterval(300)
        let original = AlarmEvent(
            title: "ランチ",
            fireDate: Date(),
            preNotificationMinutes: 10,
            eventKitIdentifier: "ek-456",
            alarmKitIdentifier: UUID(),
            alarmKitIdentifiers: [UUID(), UUID()],
            alarmKitMinutesMap: ["a": 15, "b": 0],
            voiceFileName: "ランチ.caf",
            calendarIdentifier: "cal-2",
            voiceCharacter: .maleButler,
            eventEmoji: "☕",
            completionStatus: .completed,
            snoozeCount: 2,
            isToDo: true,
            undoPendingUntil: undoDeadline
        )

        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(AlarmEvent.self, from: data)

        XCTAssertEqual(decoded.id, original.id)
        XCTAssertEqual(decoded.title, original.title)
        XCTAssertEqual(decoded.preNotificationMinutes, original.preNotificationMinutes)
        XCTAssertEqual(decoded.eventKitIdentifier, original.eventKitIdentifier)
        XCTAssertEqual(decoded.alarmKitIdentifier, original.alarmKitIdentifier)
        XCTAssertEqual(decoded.alarmKitIdentifiers, original.alarmKitIdentifiers)
        XCTAssertEqual(decoded.alarmKitMinutesMap, original.alarmKitMinutesMap)
        XCTAssertEqual(decoded.voiceFileName, original.voiceFileName)
        XCTAssertEqual(decoded.calendarIdentifier, original.calendarIdentifier)
        XCTAssertEqual(decoded.voiceCharacter, original.voiceCharacter)
        XCTAssertEqual(decoded.eventEmoji, original.eventEmoji)
        XCTAssertEqual(decoded.completionStatus, original.completionStatus)
        XCTAssertEqual(decoded.snoozeCount, original.snoozeCount)
        XCTAssertEqual(decoded.isToDo, original.isToDo)
        XCTAssertEqual(decoded.undoPendingUntil, original.undoPendingUntil)
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

    func testBackwardCompatibleDecode_FillsDefaultsForNewFields() throws {
        let legacyJSON = """
        {
          "id": "\(UUID().uuidString)",
          "title": "旧データ",
          "fireDate": \(Date().timeIntervalSince1970),
          "preNotificationMinutes": 15,
          "voiceCharacter": "female_concierge",
          "createdAt": \(Date().timeIntervalSince1970)
        }
        """.data(using: .utf8)!

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .secondsSince1970
        let decoded = try decoder.decode(AlarmEvent.self, from: legacyJSON)

        XCTAssertEqual(decoded.alarmKitIdentifiers, [])
        XCTAssertEqual(decoded.alarmKitMinutesMap, [:])
        XCTAssertNil(decoded.completionStatus)
        XCTAssertEqual(decoded.snoozeCount, 0)
        XCTAssertFalse(decoded.isToDo)
        XCTAssertNil(decoded.undoPendingUntil)
    }

    func testResolvedEmoji_DefaultsToPinWhenEmojiIsMissingOrEmpty() {
        let noEmoji = AlarmEvent(title: "予定", fireDate: Date())
        let emptyEmoji = AlarmEvent(title: "予定", fireDate: Date(), eventEmoji: "")
        let customEmoji = AlarmEvent(title: "予定", fireDate: Date(), eventEmoji: "💊")

        XCTAssertEqual(noEmoji.resolvedEmoji, "📌")
        XCTAssertEqual(emptyEmoji.resolvedEmoji, "📌")
        XCTAssertEqual(customEmoji.resolvedEmoji, "💊")
    }

    func testDisplayTitle_RemovesLeadingEmoji() {
        let alarm = AlarmEvent(title: "💊 くすり", fireDate: Date())
        XCTAssertEqual(alarm.displayTitle, "くすり")
    }

    func testDisplayTitle_DoesNotStripLeadingDigit() {
        let alarm = AlarmEvent(title: "5001円", fireDate: Date())
        XCTAssertEqual(alarm.displayTitle, "5001円")
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
        XCTAssertEqual(VoiceCharacter.allCases.count, 3)
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
