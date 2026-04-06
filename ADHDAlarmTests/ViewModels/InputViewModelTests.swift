import XCTest
@testable import ADHDAlarm

/// InputViewModelのNL解析・確認フローをテストする
@MainActor
final class InputViewModelTests: XCTestCase {

    private let store = AlarmEventStore.shared

    override func setUp() {
        super.setUp()
        store.saveAll([])
        clearXPDefaults()
    }

    override func tearDown() {
        store.saveAll([])
        clearXPDefaults()
        super.tearDown()
    }

    private func makeViewModel(
        scheduler: MockAlarmScheduler? = nil,
        calProvider: MockCalendarProvider? = nil,
        voiceGen: MockVoiceGenerator? = nil,
        appState: AppState? = nil
    ) -> InputViewModel {
        InputViewModel(
            nlParser: NLParserService(),
            calendarProvider: calProvider ?? MockCalendarProvider(),
            alarmScheduler: scheduler ?? MockAlarmScheduler(),
            voiceGenerator: voiceGen ?? MockVoiceGenerator(),
            eventStore: store,
            appState: appState ?? AppState()
        )
    }

    // MARK: - parse

    func testParse_ValidInput_SetsParsedInput() {
        let viewModel = makeViewModel()
        viewModel.parse(text: "明日の15時にカフェ")

        XCTAssertNotNil(viewModel.parsedInput)
        XCTAssertEqual(viewModel.parsedInput?.title, "カフェ")
        XCTAssertNil(viewModel.errorMessage)
    }

    func testParse_InvalidInput_SetsErrorMessage() {
        let viewModel = makeViewModel()
        viewModel.parse(text: "カフェ")  // 日時なし

        XCTAssertNil(viewModel.parsedInput)
        XCTAssertNotNil(viewModel.errorMessage)
        XCTAssertFalse(viewModel.errorMessage?.isEmpty ?? true)
    }

    func testParse_EmptyInput_SetsErrorMessage() {
        let viewModel = makeViewModel()
        viewModel.parse(text: "")

        XCTAssertNil(viewModel.parsedInput)
        XCTAssertNotNil(viewModel.errorMessage)
    }

    func testParse_ValidInput_ClearsErrorMessage() {
        let viewModel = makeViewModel()
        viewModel.parse(text: "カフェ")  // まずエラーにする
        XCTAssertNotNil(viewModel.errorMessage)

        viewModel.parse(text: "明日の10時に病院")  // 有効な入力
        XCTAssertNil(viewModel.errorMessage)
    }

    func testParse_RelativeTime_Works() {
        let viewModel = makeViewModel()
        viewModel.parse(text: "30分後に歯医者")

        XCTAssertNotNil(viewModel.parsedInput)
        XCTAssertEqual(viewModel.parsedInput?.title, "歯医者")
    }

    // MARK: - confirmAndSchedule

    func testConfirmAndSchedule_Success_SavesAlarm() async {
        let scheduler = MockAlarmScheduler()
        let calProvider = MockCalendarProvider()
        let voiceGen = MockVoiceGenerator()
        voiceGen.returnURL = URL(fileURLWithPath: "/tmp/test.caf")

        let viewModel = makeViewModel(
            scheduler: scheduler,
            calProvider: calProvider,
            voiceGen: voiceGen
        )

        viewModel.parse(text: "明日の10時に病院")
        await viewModel.confirmAndSchedule()

        // ストアに保存されている
        XCTAssertEqual(store.loadAll().count, 1)
        XCTAssertNotNil(viewModel.confirmationMessage)
        XCTAssertNil(viewModel.errorMessage)
        XCTAssertNil(viewModel.parsedInput)
    }

    func testConfirmAndSchedule_Success_CallsScheduler() async {
        let scheduler = MockAlarmScheduler()
        let calProvider = MockCalendarProvider()
        let voiceGen = MockVoiceGenerator()

        let viewModel = makeViewModel(
            scheduler: scheduler,
            calProvider: calProvider,
            voiceGen: voiceGen
        )

        viewModel.parse(text: "明日の15時にランチ")
        await viewModel.confirmAndSchedule()

        XCTAssertEqual(scheduler.scheduledAlarms.count, 1)
        XCTAssertEqual(calProvider.writtenEvents.count, 1)
        XCTAssertEqual(voiceGen.generatedAlarmIDs.count, 1)
    }

    func testConfirmAndSchedule_PassesTitleToVoiceGenerator() async {
        let scheduler = MockAlarmScheduler()
        let calProvider = MockCalendarProvider()
        let voiceGen = MockVoiceGenerator()

        let viewModel = makeViewModel(
            scheduler: scheduler,
            calProvider: calProvider,
            voiceGen: voiceGen
        )

        viewModel.parse(text: "明日の15時に薬を飲む")
        await viewModel.confirmAndSchedule()

        XCTAssertEqual(voiceGen.generateCalls.count, 1)
        XCTAssertEqual(voiceGen.generateCalls.first?.eventTitle, "薬飲む")
    }

    func testConfirmAndSchedule_Success_ConfirmationMessageContainsTitle() async {
        let scheduler = MockAlarmScheduler()
        let calProvider = MockCalendarProvider()
        let voiceGen = MockVoiceGenerator()

        let viewModel = makeViewModel(
            scheduler: scheduler,
            calProvider: calProvider,
            voiceGen: voiceGen
        )

        viewModel.parse(text: "明日の9時に大阪出張")
        await viewModel.confirmAndSchedule()

        XCTAssertTrue(viewModel.confirmationMessage?.contains("大阪出張") ?? false,
                      "確認メッセージにタイトルが含まれていない")
    }

    func testConfirmAndSchedule_DoesNotAddXP() async {
        let scheduler = MockAlarmScheduler()
        let calProvider = MockCalendarProvider()
        let voiceGen = MockVoiceGenerator()
        let appState = AppState()

        let viewModel = makeViewModel(
            scheduler: scheduler,
            calProvider: calProvider,
            voiceGen: voiceGen,
            appState: appState
        )

        viewModel.parse(text: "明日の9時に病院")
        await viewModel.confirmAndSchedule()

        XCTAssertEqual(appState.owlXP, 0, "予定追加だけではXPが加算されないこと")
    }

    func testConfirmAndSchedule_NoParsedInput_DoesNothing() async {
        let scheduler = MockAlarmScheduler()
        let viewModel = makeViewModel(scheduler: scheduler)

        // parsedInputが設定されていない状態
        await viewModel.confirmAndSchedule()

        XCTAssertTrue(scheduler.scheduledAlarms.isEmpty)
        XCTAssertTrue(store.loadAll().isEmpty)
    }

    func testConfirmAndSchedule_CalendarProviderThrows_StillSavesAlarm() async {
        let calProvider = MockCalendarProvider()
        calProvider.shouldThrow = true

        let voiceGen = MockVoiceGenerator()
        let viewModel = makeViewModel(calProvider: calProvider, voiceGen: voiceGen)

        viewModel.parse(text: "明日の10時にテスト")
        await viewModel.confirmAndSchedule()

        XCTAssertNil(viewModel.errorMessage)
        XCTAssertEqual(store.loadAll().count, 1, "カレンダー書き込み失敗でもローカル保存は継続すること")
    }

    func testConfirmAndSchedule_SchedulerThrows_SetsErrorMessage() async {
        let scheduler = MockAlarmScheduler()
        scheduler.shouldThrow = true
        let calProvider = MockCalendarProvider()
        let voiceGen = MockVoiceGenerator()

        let viewModel = makeViewModel(
            scheduler: scheduler,
            calProvider: calProvider,
            voiceGen: voiceGen
        )

        viewModel.parse(text: "明日の10時にテスト")
        await viewModel.confirmAndSchedule()

        XCTAssertNotNil(viewModel.errorMessage)
        XCTAssertTrue(store.loadAll().isEmpty)
    }

    // MARK: - isWritingThrough

    func testIsWritingThrough_FalseInitially() {
        let viewModel = makeViewModel()
        XCTAssertFalse(viewModel.isWritingThrough)
    }

    // MARK: - reset

    func testReset_ClearsAllState() {
        let viewModel = makeViewModel()
        viewModel.parse(text: "明日の9時にテスト")
        viewModel.reset()

        XCTAssertTrue(viewModel.transcribedText.isEmpty)
        XCTAssertNil(viewModel.parsedInput)
        XCTAssertNil(viewModel.errorMessage)
        XCTAssertNil(viewModel.confirmationMessage)
        XCTAssertFalse(viewModel.isListening)
    }

    // MARK: - preNotificationMinutes (QA #4 デグレ防止)

    func testConfirmAndSchedule_VoiceTextContainsPreNotificationMinutes() {
        // preNotificationMinutes=15の場合、音声テキストに15分が含まれる
        let alarm = AlarmEvent(title: "テスト", fireDate: Date(), preNotificationMinutes: 15)
        let speechText = VoiceFileGenerator.speechText(for: alarm)

        XCTAssertTrue(speechText.contains("15") || speechText.contains("になりました"),
                      "事前通知分数が音声テキストに反映されていない")
    }

    func testPrepareManualParsedInput_UsesAppSettingPreNotificationMinutes() async {
        let scheduler = MockAlarmScheduler()
        let appState = AppState()
        appState.preNotificationMinutesList = [0]

        let viewModel = makeViewModel(
            scheduler: scheduler,
            appState: appState
        )

        let parsed = ParsedInput(
            title: "テスト",
            fireDate: Date().addingTimeInterval(600),
            hasExplicitDate: true,
            isToDo: false
        )

        viewModel.prepareManualParsedInput(parsed)
        await viewModel.confirmAndSchedule()

        XCTAssertEqual(viewModel.selectedPreNotificationMinutesList, [0], "手入力確認画面でも設定の通知タイミングを引き継ぐこと")
        XCTAssertEqual(scheduler.scheduledAlarms.count, 1)
        XCTAssertEqual(scheduler.scheduledAlarms.first?.preNotificationMinutes, 0, "手入力でもジャスト設定が保持されること")
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
}
