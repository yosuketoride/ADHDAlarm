import XCTest
@testable import ADHDAlarm

@MainActor
final class RingingViewModelTests: XCTestCase {
    
    var viewModel: RingingViewModel!
    var mockScheduler: MockAlarmScheduler!
    var mockCalendarProvider: MockCalendarProvider!
    var mockVoiceGenerator: MockVoiceGenerator!
    var mockSOSService: MockSOSService!
    var appState: AppState!
    
    override func setUp() async throws {
        mockScheduler = MockAlarmScheduler()
        mockCalendarProvider = MockCalendarProvider()
        mockVoiceGenerator = MockVoiceGenerator()
        mockSOSService = MockSOSService()
        appState = AppState()
        
        viewModel = RingingViewModel(
            scheduler: mockScheduler,
            voiceGenerator: mockVoiceGenerator,
            sosService: mockSOSService
        )
    }
    
    override func tearDown() async throws {
        viewModel.stopAudioPlayback()
        viewModel = nil
        mockScheduler = nil
        mockCalendarProvider = nil
        mockVoiceGenerator = nil
        mockSOSService = nil
        appState = nil
    }
    
    func testSOSAutomaticallyTriggeredWhenTimerExpires() async throws {
        // Arrange
        let alarm = AlarmEvent.makeTest(title: "SOS Test Alarm")
        viewModel.activeAlarm = alarm
        
        // 疑似的に設定画面でペアリング完了状態とエスカレーション時間(1分)をセット
        viewModel.configure(
            notificationType: .alarmAndVoice,
            audioOutputMode: .automatic,
            sosContactPhone: nil,
            sosPairingId: "test-pairing-id",
            sosEscalationMinutes: 1 // 1 minutes
        )
        
        // Act: startAudioPlayback fires the SOS timer
        viewModel.startAudioPlayback()
        
        // Assert
        XCTAssertNotNil(viewModel.escalationTimer, "SOS timer should be scheduled when pairingId is present")
        
        let timeRemaining = viewModel.escalationTimer?.fireDate.timeIntervalSinceNow ?? 0
        XCTAssertTrue(timeRemaining > 59.0 && timeRemaining <= 60.5, "Timer should be scheduled for ~60s, got \(timeRemaining)")
    }
    
    func testNoSOSTimerIfNoPairingOrPhone() async throws {
        // Arrange
        let alarm = AlarmEvent.makeTest(title: "Normal Alarm")
        viewModel.activeAlarm = alarm
        
        // No pairing ID or Phone
        viewModel.configure(
            notificationType: .alarmAndVoice,
            audioOutputMode: .automatic,
            sosContactPhone: nil,
            sosPairingId: nil,
            sosEscalationMinutes: 5
        )
        
        // Act
        viewModel.startAudioPlayback()
        
        // Assert
        XCTAssertNil(viewModel.escalationTimer, "SOS timer should NOT be scheduled when no pairing ID or phone is configured")
    }
}
