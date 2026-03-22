import Foundation
import Observation
import WidgetKit

/// マイク入力 → NL解析 → 確認 → Write-Through の状態管理
@Observable
final class InputViewModel {

    // MARK: - 状態

    /// リアルタイム文字起こしテキスト
    var transcribedText = ""
    /// NL解析結果（確認カードに表示）
    var parsedInput: ParsedInput?
    /// マイク録音中かどうか
    var isListening = false
    /// 書き込み処理中かどうか（ボタンのローディング表示に使用）
    var isWritingThrough = false
    /// 成功後の確認メッセージ（「バッチリです！」）
    var confirmationMessage: String?
    /// エラーメッセージ
    var errorMessage: String?
    /// NL解析中かどうか（「考えています…」表示用）
    var isParsing = false
    /// このイベント単位の事前通知分数セット（確認画面でユーザーが選択。PRO時は複数選択可）
    var selectedPreNotificationMinutesList: Set<Int> = [15]

    // MARK: - 依存サービス

    private let nlParser: NLParsing
    private let calendarProvider: CalendarProviding
    private let alarmScheduler: AlarmScheduling
    private let voiceGenerator: VoiceSynthesizing
    private let eventStore: AlarmEventStore
    private let appState: AppState
    private let speechService = SpeechRecognitionService()
    private var listeningTask: Task<Void, Never>?

    init(
        nlParser: NLParsing             = NLParserService(),
        calendarProvider: CalendarProviding = AppleCalendarProvider(),
        alarmScheduler: AlarmScheduling = AlarmKitScheduler(),
        voiceGenerator: VoiceSynthesizing   = VoiceFileGenerator(),
        eventStore: AlarmEventStore     = .shared,
        appState: AppState
    ) {
        self.nlParser         = nlParser
        self.calendarProvider = calendarProvider
        self.alarmScheduler   = alarmScheduler
        self.voiceGenerator   = voiceGenerator
        self.eventStore       = eventStore
        self.appState         = appState
    }

    // MARK: - マイク入力

    /// マイク録音を開始する（押している間だけ録音するプレスホールド方式）
    func startListening() {
        isListening = true
        errorMessage = nil
        parsedInput = nil
        transcribedText = ""

        listeningTask = Task {
            var receivedAny = false
            for await text in speechService.startListening() {
                transcribedText = text
                receivedAny = true
            }
            // ストリーム終了 = 録音停止 → テキストがあれば自動でNL解析
            if !transcribedText.isEmpty {
                isParsing = true
                parse(text: transcribedText)
                isParsing = false
            } else if !receivedAny {
                // 音声が一切届かなかった場合（権限エラーや音声認識失敗）
                errorMessage = "うまく聞き取れませんでした。\nもう一度ゆっくり話してみてくださいね。"
            }
            isListening = false
        }
    }

    /// マイク録音を停止する
    func stopListening() {
        speechService.stopListening()
        listeningTask?.cancel()
        listeningTask = nil
    }

    // MARK: - NL解析

    /// テキストをNL解析してparsedInputをセットする
    func parse(text: String) {
        parsedInput = nlParser.parse(text: text)
        if parsedInput == nil {
            errorMessage = "日時が読み取れませんでした。「明日の15時にカフェ」のように話してみてください。"
        } else {
            errorMessage = nil
            // グローバル設定＋ジャスト（0分）をデフォルト選択としてセット
            selectedPreNotificationMinutesList = [0, appState.preNotificationMinutes]
        }
    }

    // MARK: - Write-Through（アラーム登録の核心）

    /// 確認後に実行するWrite-Through処理
    /// 1. 音声ファイル生成 → 2. EventKit書き込み → 3. AlarmKit登録 → 4. ローカル保存
    func confirmAndSchedule() async {
        guard let parsed = parsedInput else { return }

        isWritingThrough = true
        errorMessage = nil

        // アラームEventの基本情報を組み立てる
        // 複数選択がある場合は最も早い通知（最大分数）を主として使用
        let primaryMinutes = selectedPreNotificationMinutesList.max() ?? 15
        var alarm = AlarmEvent(
            title: parsed.title,
            fireDate: parsed.fireDate,
            preNotificationMinutes: primaryMinutes,
            calendarIdentifier: appState.subscriptionTier.canSelectCalendar
                ? appState.selectedCalendarID
                : nil,
            voiceCharacter: appState.voiceCharacter
        )

        do {
            // Step 1: 音声ファイル（.caf）を生成してLibrary/Soundsに保存
            let speechText = VoiceFileGenerator.speechText(for: alarm)
            let voiceURL   = try await voiceGenerator.generateAudio(
                text: speechText,
                character: alarm.voiceCharacter,
                alarmID: alarm.id
            )
            alarm.voiceFileName = voiceURL.lastPathComponent

            // Step 2: EventKitに予定を書き込む
            let eventKitID = try await calendarProvider.writeEvent(
                alarm,
                to: alarm.calendarIdentifier
            )
            alarm.eventKitIdentifier = eventKitID

            // Step 3: 選択された各分数ごとにAlarmKitアラームを登録
            // ジャスト（0分）は常に含まれる（parse()でデフォルト選択済み）
            var scheduledIDs: [UUID] = []
            var minutesMap: [String: Int] = [:]
            for minutes in selectedPreNotificationMinutesList.sorted(by: >) {
                var tempAlarm = alarm
                tempAlarm.preNotificationMinutes = minutes
                let akID = try await alarmScheduler.schedule(tempAlarm)
                scheduledIDs.append(akID)
                // AlarmKit ID → 分数のマッピングを記録（発火時に正しいテキストを読み上げるため）
                minutesMap[akID.uuidString] = minutes
            }
            alarm.alarmKitIdentifiers = scheduledIDs
            alarm.alarmKitIdentifier = scheduledIDs.first
            alarm.alarmKitMinutesMap = minutesMap

            // Step 4: マッピングをローカルに永続化
            eventStore.save(alarm)

            // WidgetKitのタイムラインを即座に更新
            WidgetCenter.shared.reloadAllTimelines()

            // 成功フィードバック（コンシェルジュ口調）
            confirmationMessage = "\(parsed.fireDate.naturalJapaneseString)、\(parsed.title)ですね。アラームをセットしました！バッチリです。"
            parsedInput = nil
            transcribedText = ""

        } catch {
            // ロールバック: 一部だけ書き込まれた場合のクリーンアップ
            if let ekID = alarm.eventKitIdentifier {
                try? await calendarProvider.deleteEvent(eventKitIdentifier: ekID)
            }
            let idsToCancel = alarm.alarmKitIdentifiers.isEmpty
                ? [alarm.alarmKitIdentifier].compactMap { $0 }
                : alarm.alarmKitIdentifiers
            if !idsToCancel.isEmpty {
                try? await AlarmKitScheduler().cancelAll(alarmKitIDs: idsToCancel)
            }
            voiceGenerator.deleteAudio(alarmID: alarm.id)

            errorMessage = "うまくセットできませんでした。\nもう一度やってみてくださいね。"
        }

        isWritingThrough = false
    }

    // MARK: - リセット

    func reset() {
        stopListening()
        transcribedText   = ""
        parsedInput       = nil
        errorMessage      = nil
        confirmationMessage = nil
        isListening       = false
        selectedPreNotificationMinutesList = [appState.preNotificationMinutes]
    }
}
