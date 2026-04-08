import Foundation
import AVFoundation
@testable import ADHDAlarm

// MARK: - MockFamilyService

@MainActor
final class MockFamilyService: FamilyScheduling {
    var currentDeviceId: String? = "mock-device-id"
    var shouldThrow = false

    // 記録
    var registeredDevices: [String] = []
    var updatedTokens: [String] = []
    var updatedLastSeen = false
    var generatedCodes: [(linkId: String, code: String)] = []
    var joinedCodes: [String] = []
    var unlinkedIds: [String] = []
    var createdEvents: [RemoteEventPayload] = []
    var cancelledEventIds: [String] = []
    var syncedEventIds: [String] = []
    var rolledBackEventIds: [String] = []
    var updatedRemoteStatuses: [(id: String, status: String)] = []

    // スタブ返り値
    var stubLinkId = "mock-link-id"
    var stubCode = "123456"
    var stubPendingEvents: [RemoteEventRecord] = []
    var stubCancelledEvents: [RemoteEventRecord] = []
    var stubSentEvents: [RemoteEventRecord] = []
    var stubLastSeen: Date? = nil
    var stubFamilyLinks: [FamilyLinkRecord] = []
    var statusStream: AsyncStream<String> = AsyncStream { $0.finish() }

    func ensureDeviceRegistered() async throws -> String {
        if shouldThrow { throw MockError.intentional }
        registeredDevices.append(currentDeviceId ?? "mock-device-id")
        return currentDeviceId ?? "mock-device-id"
    }

    func updateDeviceToken(_ token: String) async throws {
        if shouldThrow { throw MockError.intentional }
        updatedTokens.append(token)
    }

    func updateLastSeen() async throws {
        if shouldThrow { throw MockError.intentional }
        updatedLastSeen = true
    }

    func deleteAccount() async throws {
        if shouldThrow { throw MockError.intentional }
    }

    func generateFamilyCode() async throws -> (linkId: String, code: String) {
        if shouldThrow { throw MockError.intentional }
        let result = (linkId: stubLinkId, code: stubCode)
        generatedCodes.append(result)
        return result
    }

    func listenToFamilyLinkStatus(linkId: String) -> AsyncStream<String> { statusStream }

    func unlinkFamily(linkId: String) async throws {
        if shouldThrow { throw MockError.intentional }
        unlinkedIds.append(linkId)
    }

    func joinFamily(code: String) async throws -> String {
        if shouldThrow { throw FamilyError.invalidCode }
        joinedCodes.append(code)
        return stubLinkId
    }

    func createRemoteEvent(_ event: RemoteEventPayload) async throws {
        if shouldThrow { throw MockError.intentional }
        createdEvents.append(event)
    }

    func cancelRemoteEvent(id: String) async throws {
        if shouldThrow { throw MockError.intentional }
        cancelledEventIds.append(id)
    }

    func fetchSentEvents(linkId: String) async throws -> [RemoteEventRecord] {
        if shouldThrow { throw MockError.intentional }
        return stubSentEvents
    }

    func fetchLastSeen(linkId: String) async throws -> Date? {
        if shouldThrow { throw MockError.intentional }
        return stubLastSeen
    }

    func fetchPendingEvents() async throws -> [RemoteEventRecord] {
        if shouldThrow { throw MockError.intentional }
        return stubPendingEvents
    }

    func fetchCancelledEvents() async throws -> [RemoteEventRecord] {
        if shouldThrow { throw MockError.intentional }
        return stubCancelledEvents
    }

    func markEventSynced(id: String) async throws {
        if shouldThrow { throw MockError.intentional }
        syncedEventIds.append(id)
    }

    func markEventRolledBack(id: String) async throws {
        if shouldThrow { throw MockError.intentional }
        rolledBackEventIds.append(id)
    }

    func updateRemoteEventStatus(id: String, status: String) async throws {
        if shouldThrow { throw MockError.intentional }
        updatedRemoteStatuses.append((id: id, status: status))
    }

    func listenToNewEvents() -> AsyncStream<RemoteEventRecord> {
        AsyncStream { $0.finish() }
    }

    func fetchMyFamilyLinks() async throws -> [FamilyLinkRecord] {
        if shouldThrow { throw MockError.intentional }
        return stubFamilyLinks
    }

    var updatedPremiumStatuses: [Bool] = []

    func updatePremiumStatus(isPro: Bool) async throws {
        if shouldThrow { throw MockError.intentional }
        updatedPremiumStatuses.append(isPro)
    }
}

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
    var foundAppEvent: AlarmEvent?
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

    func findAppEvent(id: UUID) async throws -> AlarmEvent? {
        if shouldThrow { throw MockError.intentional }
        guard let foundAppEvent, foundAppEvent.id == id else { return nil }
        return foundAppEvent
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

    var importCandidates: [ImportCandidate] = []
    var appendedMarkers: [(ekIdentifier: String, alarmID: UUID)] = []

    func fetchImportCandidates(
        from: Date,
        to: Date,
        excludingEKIdentifiers: Set<String>,
        calendarIdentifiers: Set<String>?
    ) async throws -> [ImportCandidate] {
        if shouldThrow { throw MockError.intentional }
        return importCandidates.filter { !excludingEKIdentifiers.contains($0.id) }
    }

    func appendMarker(to ekIdentifier: String, alarmID: UUID) async throws {
        if shouldThrow { throw MockError.intentional }
        appendedMarkers.append((ekIdentifier: ekIdentifier, alarmID: alarmID))
    }
}

// MARK: - MockVoiceGenerator

final class MockVoiceGenerator: VoiceSynthesizing {
    struct GenerateCall {
        let text: String
        let character: VoiceCharacter
        let alarmID: UUID
        let eventTitle: String
    }

    private let lock = NSLock()
    private var storedGeneratedAlarmIDs: [UUID] = []
    private var storedGenerateCalls: [GenerateCall] = []
    private var storedDeletedAlarmIDs: [UUID] = []
    var shouldThrow = false
    var returnURL: URL = URL(fileURLWithPath: "/tmp/mock.caf")

    var generatedAlarmIDs: [UUID] {
        lock.lock()
        defer { lock.unlock() }
        return storedGeneratedAlarmIDs
    }

    var generateCalls: [GenerateCall] {
        lock.lock()
        defer { lock.unlock() }
        return storedGenerateCalls
    }

    var deletedAlarmIDs: [UUID] {
        lock.lock()
        defer { lock.unlock() }
        return storedDeletedAlarmIDs
    }

    func generateAudio(text: String, character: VoiceCharacter, alarmID: UUID, eventTitle: String) async throws -> URL {
        if shouldThrow { throw MockError.intentional }
        lock.lock()
        storedGeneratedAlarmIDs.append(alarmID)
        storedGenerateCalls.append(.init(text: text, character: character, alarmID: alarmID, eventTitle: eventTitle))
        lock.unlock()
        return returnURL
    }

    func deleteAudio(alarmID: UUID) {
        lock.lock()
        storedDeletedAlarmIDs.append(alarmID)
        lock.unlock()
    }
}

// MARK: - Mock Alarm Audio

final class MockAlarmAudioController: AlarmAudioControlling {
    struct ConfigureCall {
        let mode: AVAudioSession.Mode
        let options: AVAudioSession.CategoryOptions
        let forceSpeaker: Bool
    }

    var currentOutputPortTypes: [AVAudioSession.Port] = []
    var configureCalls: [ConfigureCall] = []
    var deactivateCallCount = 0
    var shouldThrowOnConfigure = false
    var nextPlayer: MockAudioPlayer?
    let speechSynthesizer = MockSpeechSynthesizer()
    var createdPlayerURLs: [URL] = []

    func configurePlaybackSession(
        mode: AVAudioSession.Mode,
        options: AVAudioSession.CategoryOptions,
        forceSpeaker: Bool
    ) throws {
        if shouldThrowOnConfigure { throw MockError.intentional }
        configureCalls.append(.init(mode: mode, options: options, forceSpeaker: forceSpeaker))
    }

    func deactivatePlaybackSession() throws {
        deactivateCallCount += 1
    }

    func makeAudioPlayer(url: URL) throws -> AudioPlayerControlling {
        createdPlayerURLs.append(url)
        return nextPlayer ?? MockAudioPlayer()
    }

    func makeSpeechSynthesizer() -> SpeechSynthesizerControlling {
        speechSynthesizer
    }
}

final class MockAudioPlayer: AudioPlayerControlling {
    var delegate: AVAudioPlayerDelegate?
    var numberOfLoops: Int = 0
    var prepareToPlayCallCount = 0
    var playCallCount = 0
    var stopCallCount = 0
    var playShouldSucceed = true

    func prepareToPlay() {
        prepareToPlayCallCount += 1
    }

    func play() -> Bool {
        playCallCount += 1
        return playShouldSucceed
    }

    func stop() {
        stopCallCount += 1
    }
}

final class MockSpeechSynthesizer: SpeechSynthesizerControlling {
    var delegate: AVSpeechSynthesizerDelegate?
    var spokenUtterances: [AVSpeechUtterance] = []
    var stopCallCount = 0

    func speak(_ utterance: AVSpeechUtterance) {
        spokenUtterances.append(utterance)
    }

    func stopSpeaking(at boundary: AVSpeechBoundary) -> Bool {
        stopCallCount += 1
        return true
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
        voiceFileName: String? = nil,
        snoozeCount: Int = 0
    ) -> AlarmEvent {
        AlarmEvent(
            title: title,
            fireDate: Date().addingTimeInterval(offsetFromNow),
            preNotificationMinutes: preNotificationMinutes,
            alarmKitIdentifier: alarmKitIdentifier,
            voiceFileName: voiceFileName,
            snoozeCount: snoozeCount
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

// MARK: - MockSOSService

final class MockSOSService: SOSNotifying {
    var generatedPairingId: String = "mock-id-1234"
    var generatedCode: String = "1234"
    var shouldThrowGenerate = false
    
    var streamValues: [String] = []
    
    var unpairedId: String? = nil
    var shouldThrowUnpair = false
    
    var sentSOSPairingId: String? = nil
    var sentSOSAlarmTitle: String? = nil
    var sentSOSMinutes: Int? = nil
    var shouldThrowSendSOS = false
    
    func generatePairingCode() async throws -> (pairingId: String, code: String) {
        if shouldThrowGenerate { throw MockError.intentional }
        return (pairingId: generatedPairingId, code: generatedCode)
    }
    
    func listenToPairingStatus(id: String) -> AsyncStream<String> {
        return AsyncStream { continuation in
            Task {
                for value in streamValues {
                    continuation.yield(value)
                    try? await Task.sleep(nanoseconds: 10_000_000) // 10ms
                }
                continuation.finish()
            }
        }
    }
    
    func unpair(id: String) async throws {
        if shouldThrowUnpair { throw MockError.intentional }
        unpairedId = id
    }
    
    func sendSOS(pairingId: String, alarmTitle: String, minutes: Int) async throws {
        if shouldThrowSendSOS { throw MockError.intentional }
        sentSOSPairingId = pairingId
        sentSOSAlarmTitle = alarmTitle
        sentSOSMinutes = minutes
    }
}
