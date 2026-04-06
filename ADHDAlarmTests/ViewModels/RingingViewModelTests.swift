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
    var mockAudioController: MockAlarmAudioController!
    var appState: AppState!
    let store = AlarmEventStore.shared
    var temporarySoundURLs: [URL] = []
    
    override func setUp() async throws {
        clearXPDefaults()
        clearHandledAlarmDefaults()
        store.saveAll([])
        mockScheduler = MockAlarmScheduler()
        mockCalendarProvider = MockCalendarProvider()
        mockVoiceGenerator = MockVoiceGenerator()
        mockSOSService = MockSOSService()
        mockAudioController = MockAlarmAudioController()
        appState = AppState()
        
        viewModel = RingingViewModel(
            scheduler: mockScheduler,
            voiceGenerator: mockVoiceGenerator,
            calendarProvider: mockCalendarProvider,
            sosService: mockSOSService,
            audioController: mockAudioController,
            playbackStartDelay: .zero,
            undoFinalizeDelay: .milliseconds(50)
        )
        PresentedAlarmStore.shared.clearAll()
    }
    
    override func tearDown() async throws {
        viewModel.stopAudioPlayback()
        viewModel = nil
        mockScheduler = nil
        mockCalendarProvider = nil
        mockVoiceGenerator = nil
        mockSOSService = nil
        mockAudioController = nil
        appState = nil
        store.saveAll([])
        for url in temporarySoundURLs {
            try? FileManager.default.removeItem(at: url)
        }
        temporarySoundURLs.removeAll()
        clearXPDefaults()
        clearHandledAlarmDefaults()
        PresentedAlarmStore.shared.clearAll()
    }
    
    // MARK: - Task 6：褒め言葉フィードバック（dismiss時）

    /// alarmKitIdentifierなし: dismiss()はsyncにactiveAlarmをnilにする
    func testDismissWithoutAlarmKitIDClearsAlarm() {
        let alarm = AlarmEvent.makeTest(title: "ID無しアラーム", alarmKitIdentifier: nil)
        viewModel.activeAlarm = alarm
        viewModel.configure(audioOutputMode: .automatic)

        viewModel.dismiss()

        XCTAssertNil(viewModel.activeAlarm, "alarmKitIdentifierがない場合、dismiss()は同期的にactiveAlarmをnilにする")
    }

    /// alarmKitIdentifierあり: dismiss()後すぐはUndo猶予のためAlarmKitを消さず、画面だけ閉じる
    func testDismissWithAlarmKitIDClearsAlarmWithoutImmediateCancel() async throws {
        let alarmID = UUID()
        let alarm = AlarmEvent.makeTest(title: "ID有りアラーム", alarmKitIdentifier: alarmID)
        viewModel.activeAlarm = alarm
        viewModel.configure(audioOutputMode: .automatic)

        viewModel.dismiss()

        // Undo猶予タスクは30秒待つため、直後の状態だけ確認する
        try await Task.sleep(for: .milliseconds(100))
        XCTAssertNil(viewModel.activeAlarm, "dismiss()直後に鳴動中アラームが閉じること")
        XCTAssertFalse(
            mockScheduler.cancelledIDs.contains(alarmID),
            "Undo猶予中はAlarmKitのキャンセルをまだ実行しないこと"
        )
    }

    func testDismiss_FinalizesDeletionAfterUndoGracePeriod() async throws {
        let alarmID = UUID()
        var alarm = AlarmEvent.makeTest(title: "Undo確定テスト", alarmKitIdentifier: alarmID)
        alarm.eventKitIdentifier = "ek-undo-finalize"
        viewModel.activeAlarm = alarm

        viewModel.dismiss()

        XCTAssertTrue(
            mockCalendarProvider.deletedIDs.isEmpty,
            "Undo猶予の直後はEventKit削除がまだ走らないこと"
        )
        XCTAssertTrue(
            mockScheduler.cancelledIDs.isEmpty,
            "Undo猶予の直後はAlarmKitキャンセルがまだ走らないこと"
        )

        try await Task.sleep(for: .milliseconds(120))

        XCTAssertEqual(
            mockCalendarProvider.deletedIDs,
            ["ek-undo-finalize"],
            "Undo猶予後にEventKit削除が確定すること"
        )
        XCTAssertEqual(
            mockScheduler.cancelledIDs,
            [alarmID],
            "Undo猶予後にAlarmKitキャンセルが確定すること"
        )
    }

    /// dismiss()後にrepeatTimer・escalationTimerが止まること
    func testDismissStopsTimers() {
        let alarm = AlarmEvent.makeTest(title: "タイマーテスト")
        viewModel.activeAlarm = alarm
        viewModel.configure(
            audioOutputMode: .automatic,
            sosPairingId: "test-id",
            sosEscalationMinutes: 1
        )
        viewModel.startAudioPlayback()

        viewModel.dismiss()

        XCTAssertNil(viewModel.escalationTimer, "dismiss後はescalationTimerが無効化されること")
    }

    func testDismiss_AddsTenXPToBoundAppState() {
        let alarm = AlarmEvent.makeTest(title: "XP完了テスト")
        viewModel.activeAlarm = alarm
        viewModel.bindAppStateIfNeeded(appState)

        viewModel.dismiss()

        XCTAssertEqual(appState.owlXP, 10, "完了時は10XP加算されること")
    }

    func testSkip_AddsThreeXPToBoundAppState() {
        let alarm = AlarmEvent.makeTest(title: "XPスキップテスト")
        viewModel.activeAlarm = alarm
        viewModel.bindAppStateIfNeeded(appState)

        viewModel.skip()

        XCTAssertEqual(appState.owlXP, 3, "スキップ時は3XP加算されること")
    }

    func testUndoCompletion_SetsUndoPendingUntilAndRestoresIncompleteState() throws {
        var alarm = AlarmEvent.makeTest(title: "Undo復元テスト")
        alarm.completionStatus = .completed

        viewModel.undoCompletion(alarm: alarm)

        let saved = try XCTUnwrap(store.find(id: alarm.id))
        XCTAssertNil(saved.completionStatus, "Undo後は完了状態が解除されること")
        let undoPendingUntil = try XCTUnwrap(saved.undoPendingUntil)
        XCTAssertGreaterThan(
            undoPendingUntil.timeIntervalSinceNow,
            4 * 60,
            "Undo保護期間が約5分先に設定されること"
        )
        XCTAssertEqual(viewModel.activeAlarm?.id, alarm.id, "Undo後は再び鳴動中アラームとして扱えること")
    }

    // MARK: - スヌーズ（P-2-2 / P-9-15）

    func testSnooze_ReschedulesThirtyMinutesLaterWithoutCompletion() async throws {
        let previousAlarmKitID = UUID()
        let alarm = AlarmEvent.makeTest(
            title: "スヌーズ予定",
            alarmKitIdentifier: previousAlarmKitID
        )
        viewModel.activeAlarm = alarm

        let before = Date()
        viewModel.snooze()
        try await Task.sleep(for: .milliseconds(100))

        XCTAssertTrue(
            mockScheduler.cancelledIDs.contains(previousAlarmKitID),
            "既存のAlarmKit登録がキャンセルされること"
        )
        XCTAssertEqual(mockScheduler.scheduledAlarms.count, 1, "30分後の再登録が行われること")

        let rescheduled = try XCTUnwrap(mockScheduler.scheduledAlarms.first)
        let interval = rescheduled.fireDate.timeIntervalSince(before)
        XCTAssertTrue(interval >= 29 * 60 && interval <= 31 * 60, "再登録時刻がおおむね30分後であること")
        XCTAssertEqual(rescheduled.preNotificationMinutes, 0, "スヌーズ再登録は直近発火として扱うこと")
        XCTAssertNil(rescheduled.completionStatus, "スヌーズではcompletionStatusがnilのままであること")
        XCTAssertEqual(rescheduled.snoozeCount, 1, "スヌーズ回数が1回増えること")

        let saved = try XCTUnwrap(store.find(id: alarm.id))
        XCTAssertEqual(saved.snoozeCount, 1, "保存済みイベントにもスヌーズ回数が反映されること")
        XCTAssertNil(saved.completionStatus, "保存済みイベントでも完了状態は変わらないこと")
        XCTAssertEqual(saved.alarmKitIdentifier, mockScheduler.fixedReturnID, "再登録後のAlarmKit IDが保存されること")
        XCTAssertNil(viewModel.activeAlarm, "スヌーズ完了後は鳴動中アラームが閉じること")
    }

    func testSnoozeButtonTitle_ShowsLastChanceOnThirdSnooze() {
        let alarm = AlarmEvent.makeTest(title: "3回目直前", snoozeCount: 2)
        viewModel.activeAlarm = alarm

        XCTAssertTrue(viewModel.canSnooze, "3回目まではスヌーズ可能であること")
        XCTAssertEqual(viewModel.snoozeButtonTitle, "30分後にまた教えて（最後の1回）")
        XCTAssertEqual(viewModel.snoozeHelperMessage, "次はパスか完了を選んでね")
    }

    func testSnoozeLimitUI_ShowsMessageAndArrowAfterThirdSnooze() {
        let alarm = AlarmEvent.makeTest(title: "上限到達", snoozeCount: 3)
        viewModel.activeAlarm = alarm

        XCTAssertFalse(viewModel.canSnooze, "4回目はスヌーズ不可であること")
        XCTAssertEqual(
            viewModel.snoozeLimitMessage,
            "🦉 何度もお知らせしたよ。今日は無理せず「今回はパス」にしてね"
        )
        XCTAssertTrue(viewModel.shouldShowSnoozeLimitArrow, "上限到達時はパスボタンへの矢印を表示すること")
    }

    func testSnooze_DoesNotRescheduleWhenLimitReached() async throws {
        let previousAlarmKitID = UUID()
        let alarm = AlarmEvent.makeTest(
            title: "上限超過防止",
            alarmKitIdentifier: previousAlarmKitID,
            snoozeCount: 3
        )
        viewModel.activeAlarm = alarm

        viewModel.snooze()
        try await Task.sleep(for: .milliseconds(100))

        XCTAssertTrue(mockScheduler.scheduledAlarms.isEmpty, "4回目は再登録しないこと")
        XCTAssertTrue(mockScheduler.cancelledIDs.isEmpty, "4回目は既存アラームも触らないこと")
        XCTAssertEqual(store.find(id: alarm.id)?.snoozeCount, nil, "保存内容も増えないこと")
        XCTAssertNotNil(viewModel.activeAlarm, "上限到達時はそのまま選択待ちにすること")
    }

    // MARK: - 音声経路

    func testStartAudioPlayback_ConfiguresVoicePromptSessionBeforeSpeechFallback() async throws {
        let alarm = AlarmEvent.makeTest(title: "音声フォールバック")
        viewModel.activeAlarm = alarm
        viewModel.configure(audioOutputMode: .automatic)

        viewModel.startAudioPlayback()
        try await Task.sleep(for: .milliseconds(50))

        XCTAssertGreaterThanOrEqual(mockAudioController.configureCalls.count, 2, "再生前とTTS前のAudioSession設定が行われること")
        XCTAssertEqual(mockAudioController.configureCalls.first?.mode, .voicePrompt)
        XCTAssertEqual(mockAudioController.speechSynthesizer.spokenUtterances.count, 1, "音声ファイルがない場合はTTSへフォールバックすること")
    }

    func testStartAudioPlayback_ForcesSpeakerInSpeakerMode() async throws {
        let alarm = AlarmEvent.makeTest(title: "スピーカーモード")
        viewModel.activeAlarm = alarm
        viewModel.configure(audioOutputMode: .speaker)

        viewModel.startAudioPlayback()
        try await Task.sleep(for: .milliseconds(50))

        XCTAssertEqual(mockAudioController.configureCalls.first?.forceSpeaker, true, "スピーカー強制モードではスピーカー出力を使うこと")
    }

    func testStartAudioPlayback_ForcesSpeakerWhenBluetoothOutputIsActive() async throws {
        mockAudioController.currentOutputPortTypes = [.bluetoothA2DP]
        let alarm = AlarmEvent.makeTest(title: "Bluetooth出力")
        viewModel.activeAlarm = alarm
        viewModel.configure(audioOutputMode: .automatic)

        viewModel.startAudioPlayback()
        try await Task.sleep(for: .milliseconds(50))

        XCTAssertEqual(mockAudioController.configureCalls.first?.forceSpeaker, true, "Bluetooth接続中はスピーカーへ切り替えること")
    }

    func testStartAudioPlayback_FallsBackToSpeechWhenAudioPlayerFails() async throws {
        let fileURL = try makeTemporarySoundFile()
        let player = MockAudioPlayer()
        player.playShouldSucceed = false
        mockAudioController.nextPlayer = player
        let alarm = AlarmEvent.makeTest(title: "再生失敗", voiceFileName: fileURL.lastPathComponent)
        viewModel.activeAlarm = alarm
        viewModel.configure(audioOutputMode: .automatic)

        viewModel.startAudioPlayback()
        try await Task.sleep(for: .milliseconds(50))

        XCTAssertEqual(mockAudioController.createdPlayerURLs.first?.lastPathComponent, fileURL.lastPathComponent)
        XCTAssertEqual(player.playCallCount, 1, "音声ファイル再生が試行されること")
        XCTAssertEqual(mockAudioController.speechSynthesizer.spokenUtterances.count, 1, "再生失敗時はTTSへフォールバックすること")
    }

    func testStartAudioPlayback_PlaysAudioFileWhenPlayerSucceeds() async throws {
        let fileURL = try makeTemporarySoundFile()
        let player = MockAudioPlayer()
        player.playShouldSucceed = true
        mockAudioController.nextPlayer = player
        let alarm = AlarmEvent.makeTest(title: "音声ファイル成功", voiceFileName: fileURL.lastPathComponent)
        viewModel.activeAlarm = alarm
        viewModel.configure(audioOutputMode: .automatic)

        viewModel.startAudioPlayback()
        try await Task.sleep(for: .milliseconds(50))

        XCTAssertEqual(player.playCallCount, 1, "音声ファイル再生が実行されること")
        XCTAssertEqual(mockAudioController.speechSynthesizer.spokenUtterances.count, 0, "音声ファイル再生成功時はTTSに落ちないこと")
    }

    // MARK: - Task 7：イヤホン切断時の音声自動停止

    /// routeChangeが.newDeviceAvailable（接続）のときは何も止まらない
    func testRouteChangeNewDeviceAvailableDoesNotStopAlarm() {
        let alarm = AlarmEvent.makeTest(title: "接続テスト")
        viewModel.activeAlarm = alarm
        viewModel.configure(audioOutputMode: .automatic)
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
        viewModel.configure(audioOutputMode: .automatic)
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
        viewModel.configure(audioOutputMode: .automatic)
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
            audioOutputMode: .automatic,
            sosPairingId: nil,
            sosEscalationMinutes: 5
        )
        
        // Act
        viewModel.startAudioPlayback()
        
        // Assert
        XCTAssertNil(viewModel.escalationTimer, "SOS timer should NOT be scheduled when no pairing ID is configured")
    }

    private func clearXPDefaults() {
        let keys = [
            Constants.Keys.owlXP,
            Constants.Keys.owlXPToday,
            Constants.Keys.owlXPLastDate,
        ]

        for key in keys {
            UserDefaults.standard.removeObject(forKey: key)
            UserDefaults(suiteName: Constants.appGroupID)?.removeObject(forKey: key)
        }
    }

    private func clearHandledAlarmDefaults() {
        UserDefaults.standard.removeObject(forKey: Constants.Keys.handledAlarmKitIDs)
        UserDefaults(suiteName: Constants.appGroupID)?.removeObject(forKey: Constants.Keys.handledAlarmKitIDs)
    }

    private func makeTemporarySoundFile() throws -> URL {
        let soundsDirectory = FileManager.default
            .urls(for: .libraryDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Sounds", isDirectory: true)
        try FileManager.default.createDirectory(
            at: soundsDirectory,
            withIntermediateDirectories: true,
            attributes: nil
        )
        let fileURL = soundsDirectory.appendingPathComponent("\(UUID().uuidString).caf")
        try Data([0x01, 0x02, 0x03]).write(to: fileURL)
        temporarySoundURLs.append(fileURL)
        return fileURL
    }
}
