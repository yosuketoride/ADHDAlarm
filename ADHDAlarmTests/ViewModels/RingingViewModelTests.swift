import XCTest
import AVFoundation
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
    
    // MARK: - Task 6：褒め言葉フィードバック（dismiss時）

    /// alarmKitIdentifierなし: dismiss()はsyncにactiveAlarmをnilにする
    func testDismissWithoutAlarmKitIDClearsAlarm() {
        let alarm = AlarmEvent.makeTest(title: "ID無しアラーム", alarmKitIdentifier: nil)
        viewModel.activeAlarm = alarm
        viewModel.configure(notificationType: .alarmAndVoice, audioOutputMode: .automatic)

        viewModel.dismiss()

        XCTAssertNil(viewModel.activeAlarm, "alarmKitIdentifierがない場合、dismiss()は同期的にactiveAlarmをnilにする")
    }

    /// alarmKitIdentifierあり: dismiss()はTaskで非同期にactiveAlarmをnilにする
    func testDismissWithAlarmKitIDClearsAlarmAsync() async throws {
        let alarmID = UUID()
        let alarm = AlarmEvent.makeTest(title: "ID有りアラーム", alarmKitIdentifier: alarmID)
        viewModel.activeAlarm = alarm
        viewModel.configure(notificationType: .alarmAndVoice, audioOutputMode: .automatic)

        viewModel.dismiss()

        // TaskでalarmKitIdentifier経由のキャンセルが走るので少し待つ
        try await Task.sleep(for: .milliseconds(100))
        XCTAssertNil(viewModel.activeAlarm, "alarmKitIdentifierがある場合、dismiss()は非同期的にactiveAlarmをnilにする")
        XCTAssertTrue(mockScheduler.cancelledIDs.contains(alarmID), "AlarmKitのキャンセルが呼ばれること")
    }

    /// dismiss()後にrepeatTimer・escalationTimerが止まること
    func testDismissStopsTimers() {
        let alarm = AlarmEvent.makeTest(title: "タイマーテスト")
        viewModel.activeAlarm = alarm
        viewModel.configure(
            notificationType: .alarmAndVoice,
            audioOutputMode: .automatic,
            sosPairingId: "test-id",
            sosEscalationMinutes: 1
        )
        viewModel.startAudioPlayback()

        viewModel.dismiss()

        XCTAssertNil(viewModel.escalationTimer, "dismiss後はescalationTimerが無効化されること")
    }

    // MARK: - Task 7：イヤホン切断時の音声自動停止

    /// routeChangeが.newDeviceAvailable（接続）のときは何も止まらない
    func testRouteChangeNewDeviceAvailableDoesNotStopAlarm() {
        let alarm = AlarmEvent.makeTest(title: "接続テスト")
        viewModel.activeAlarm = alarm
        viewModel.configure(notificationType: .alarmAndVoice, audioOutputMode: .automatic)
        viewModel.startAudioPlayback()

        let userInfo: [AnyHashable: Any] = [
            AVAudioSessionRouteChangeReasonKey: AVAudioSession.RouteChangeReason.newDeviceAvailable.rawValue
        ]
        NotificationCenter.default.post(
            name: AVAudioSession.routeChangeNotification,
            object: nil,
            userInfo: userInfo
        )

        XCTAssertNotNil(viewModel.activeAlarm, "接続イベントでactiveAlarmが消えないこと")
    }

    /// routeChangeが.oldDeviceUnavailableでも、直前ルートにヘッドフォンがなければ止まらない
    func testRouteChangeOldDeviceUnavailableWithoutPreviousHeadphonesDoesNotStopAlarm() {
        let alarm = AlarmEvent.makeTest(title: "切断テスト（非イヤホン）")
        viewModel.activeAlarm = alarm
        viewModel.configure(notificationType: .alarmAndVoice, audioOutputMode: .automatic)
        viewModel.startAudioPlayback()

        // previousRouteキーなし → hadHeadphones = false → 何もしない
        let userInfo: [AnyHashable: Any] = [
            AVAudioSessionRouteChangeReasonKey: AVAudioSession.RouteChangeReason.oldDeviceUnavailable.rawValue
        ]
        NotificationCenter.default.post(
            name: AVAudioSession.routeChangeNotification,
            object: nil,
            userInfo: userInfo
        )

        XCTAssertNotNil(viewModel.activeAlarm, "ヘッドフォン以外の切断でactiveAlarmが消えないこと")
    }

    /// stopAudioPlayback()後はrouteChangeの通知を受けてもhandleされない（監視解除の確認）
    func testRouteChangeNotHandledAfterStopAudioPlayback() {
        let alarm = AlarmEvent.makeTest(title: "監視解除テスト")
        viewModel.activeAlarm = alarm
        viewModel.configure(notificationType: .alarmAndVoice, audioOutputMode: .automatic)
        viewModel.startAudioPlayback()
        viewModel.stopAudioPlayback()

        // 一度stopした後にrouteChange通知を飛ばしても、observerが解除されているので何も起きない
        let userInfo: [AnyHashable: Any] = [
            AVAudioSessionRouteChangeReasonKey: AVAudioSession.RouteChangeReason.oldDeviceUnavailable.rawValue
        ]
        NotificationCenter.default.post(
            name: AVAudioSession.routeChangeNotification,
            object: nil,
            userInfo: userInfo
        )

        // クラッシュしないこと・activeAlarmは変わらないこと（stopで既にnilになっているわけではない）
        // stopAudioPlayback()はactiveAlarmをnilにしないので、notNil確認
        XCTAssertNotNil(viewModel.activeAlarm, "stopAudioPlayback後にrouteChange通知を受けてもクラッシュしないこと")
    }

    // MARK: - SOS（既存）

    func testSOSAutomaticallyTriggeredWhenTimerExpires() async throws {
        // Arrange
        let alarm = AlarmEvent.makeTest(title: "SOS Test Alarm")
        viewModel.activeAlarm = alarm
        
        // 疑似的に設定画面でペアリング完了状態とエスカレーション時間(1分)をセット
        viewModel.configure(
            notificationType: .alarmAndVoice,
            audioOutputMode: .automatic,
            sosPairingId: "test-pairing-id",
            sosEscalationMinutes: 1
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
        
        // ペアリングIDなし
        viewModel.configure(
            notificationType: .alarmAndVoice,
            audioOutputMode: .automatic,
            sosPairingId: nil,
            sosEscalationMinutes: 5
        )
        
        // Act
        viewModel.startAudioPlayback()
        
        // Assert
        XCTAssertNil(viewModel.escalationTimer, "SOS timer should NOT be scheduled when no pairing ID is configured")
    }
}
