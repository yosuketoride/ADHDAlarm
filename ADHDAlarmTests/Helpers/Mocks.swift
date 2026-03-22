import Foundation
@testable import ADHDAlarm

// MARK: - MockAlarmScheduler

final class MockAlarmScheduler: AlarmScheduling {
    var scheduledAlarms: [AlarmEvent] = []
    var cancelledIDs: [UUID] = []
    var shouldThrow = false
    var fixedReturnID = UUID()

    func schedule(_ alarm: AlarmEvent) async throws -> UUID {
        if shouldThrow { throw MockError.intentional }
        scheduledAlarms.append(alarm)
        return fixedReturnID
    }

    func cancel(alarmKitID: UUID) async throws {
        if shouldThrow { throw MockError.intentional }
        cancelledIDs.append(alarmKitID)
    }

    func cancelAll(alarmKitIDs: [UUID]) async throws {
        if shouldThrow { throw MockError.intentional }
        cancelledIDs.append(contentsOf: alarmKitIDs)
    }

    func scheduledIDs() async -> [UUID] {
        scheduledAlarms.compactMap { $0.alarmKitIdentifier }
    }
}

// MARK: - MockCalendarProvider

final class MockCalendarProvider: CalendarProviding {
    var appEvents: [AlarmEvent] = []
    var writtenEvents: [(alarm: AlarmEvent, calendarID: String?)] = []
    var deletedIDs: [String] = []
    var shouldThrow = false

    func fetchAppEvents() async throws -> [AlarmEvent] {
        if shouldThrow { throw MockError.intentional }
        return appEvents
    }

    func fetchAppEvents(from: Date, to: Date) async throws -> [AlarmEvent] {
        if shouldThrow { throw MockError.intentional }
        return appEvents.filter { $0.fireDate >= from && $0.fireDate <= to }
    }

    func writeEvent(_ alarm: AlarmEvent, to calendarID: String?) async throws -> String {
        if shouldThrow { throw MockError.intentional }
        writtenEvents.append((alarm: alarm, calendarID: calendarID))
        return "ek-\(alarm.id.uuidString)"
    }

    func deleteEvent(eventKitIdentifier: String) async throws {
        if shouldThrow { throw MockError.intentional }
        deletedIDs.append(eventKitIdentifier)
    }

    func availableCalendars() async throws -> [CalendarInfo] {
        if shouldThrow { throw MockError.intentional }
        return [
            CalendarInfo(id: "cal-1", title: "仕事", colorHex: "#FF0000"),
            CalendarInfo(id: "cal-2", title: "プライベート", colorHex: "#0000FF"),
        ]
    }
}

// MARK: - MockVoiceGenerator

final class MockVoiceGenerator: VoiceSynthesizing {
    var generatedAlarmIDs: [UUID] = []
    var deletedAlarmIDs: [UUID] = []
    var shouldThrow = false
    var returnURL: URL = URL(fileURLWithPath: "/tmp/mock.caf")

    func generateAudio(text: String, character: VoiceCharacter, alarmID: UUID) async throws -> URL {
        if shouldThrow { throw MockError.intentional }
        generatedAlarmIDs.append(alarmID)
        return returnURL
    }

    func deleteAudio(alarmID: UUID) {
        deletedAlarmIDs.append(alarmID)
    }
}

// MARK: - MockError

enum MockError: Error {
    case intentional
}

// MARK: - AlarmEvent Factory Helpers

extension AlarmEvent {
    /// テスト用: 今日のN時間後にfireDateを設定したAlarmEvent
    static func makeTest(
        title: String = "テスト予定",
        offsetFromNow: TimeInterval = 3600,
        preNotificationMinutes: Int = 15,
        alarmKitIdentifier: UUID? = nil,
        voiceFileName: String? = nil
    ) -> AlarmEvent {
        AlarmEvent(
            title: title,
            fireDate: Date().addingTimeInterval(offsetFromNow),
            preNotificationMinutes: preNotificationMinutes,
            alarmKitIdentifier: alarmKitIdentifier,
            voiceFileName: voiceFileName
        )
    }

    /// テスト用: 指定した日のN時に予定を設定
    static func makeToday(hour: Int, minute: Int = 0, title: String = "今日の予定") -> AlarmEvent {
        let calendar = Calendar.current
        var components = calendar.dateComponents([.year, .month, .day], from: Date())
        components.hour = hour
        components.minute = minute
        components.second = 0
        let date = calendar.date(from: components) ?? Date()
        return AlarmEvent(title: title, fireDate: date)
    }

    /// テスト用: 昨日の指定時刻の予定
    static func makeYesterday(hour: Int = 9, title: String = "昨日の予定") -> AlarmEvent {
        let calendar = Calendar.current
        let yesterday = calendar.date(byAdding: .day, value: -1, to: Date())!
        var components = calendar.dateComponents([.year, .month, .day], from: yesterday)
        components.hour = hour
        components.second = 0
        let date = calendar.date(from: components) ?? Date()
        return AlarmEvent(title: title, fireDate: date)
    }

    /// テスト用: 明日の指定時刻の予定
    static func makeTomorrow(hour: Int = 9, title: String = "明日の予定") -> AlarmEvent {
        let calendar = Calendar.current
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: Date())!
        var components = calendar.dateComponents([.year, .month, .day], from: tomorrow)
        components.hour = hour
        components.second = 0
        let date = calendar.date(from: components) ?? Date()
        return AlarmEvent(title: title, fireDate: date)
    }
}
