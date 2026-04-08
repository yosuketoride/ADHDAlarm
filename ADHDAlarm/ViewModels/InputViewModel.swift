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
    /// 確認画面でユーザーが選択した繰り返しルール（nilなら単発）
    var selectedRecurrence: RecurrenceRule?
    /// PRO版かつ複数カレンダーがある場合に表示する選択肢
    var availableCalendars: [CalendarInfo] = []
    /// P-1-7: 重複検知の結果（nil = 重複なし）
    var duplicateWarning: DuplicateWarning?
    /// 予定単位で選択したカレンダーID（nilならグローバル設定を使用）
    var selectedCalendarID: String?
    /// 確認画面でユーザーが今日/明日を切り替えた日時（nilならparsedInput.fireDateを使用）
    var selectedFireDate: Date?

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
            errorMessage = "うまく聞き取れませんでした。\n「明日の15時にカフェ」のように、\n日時と予定を一緒に話してみてね。"
        } else {
            errorMessage = nil
            applyConfirmationDefaults(for: parsedInput)
            // P-1-7: 重複検知インターセプト
            checkForDuplicates()
        }
    }

    /// 手入力で組み立てた予定を確認画面に渡す
    func prepareManualParsedInput(_ parsed: ParsedInput) {
        parsedInput = parsed
        errorMessage = nil
        duplicateWarning = nil
        applyConfirmationDefaults(for: parsedInput)
    }

    // MARK: - 重複検知（P-1-7）

    /// 同一タイトルまたは同一日時（±30分）の既存予定があれば警告をセット
    private func checkForDuplicates() {
        guard let parsed = parsedInput else { return }
        duplicateWarning = nil

        let existingEvents = eventStore.loadAll()
        let sevenDaysLater = Date().addingTimeInterval(7 * 24 * 3600)
        let upcoming = existingEvents.filter {
            $0.fireDate > Date() && $0.fireDate < sevenDaysLater && $0.completionStatus == nil
        }

        for event in upcoming {
            // 同一日時（±30分）の判定
            let timeDiff = abs(event.fireDate.timeIntervalSince(parsed.fireDate))
            if timeDiff < 30 * 60 {
                duplicateWarning = DuplicateWarning(existingTitle: event.title, existingDate: event.fireDate)
                return
            }
            // タイトルの部分一致判定
            let existingLower = event.title.lowercased()
            let newLower = parsed.title.lowercased()
            if existingLower.contains(newLower) || newLower.contains(existingLower) {
                duplicateWarning = DuplicateWarning(existingTitle: event.title, existingDate: event.fireDate)
                return
            }
        }
    }

    /// 重複警告を無視して登録を続行する
    func dismissDuplicateWarning() {
        duplicateWarning = nil
    }

    // MARK: - Write-Through（アラーム登録の核心）

    /// 確認後に実行するWrite-Through処理
    /// 1. 音声ファイル生成 → 2. AlarmKit登録（成功時のみ3へ）→ 3. EventKit書き込み → 4. ローカル保存
    /// ★ AlarmKit成功後にEventKitを書くことで、失敗時の重複書込を防ぐ
    func confirmAndSchedule() async {
        guard let parsed = parsedInput else { return }
        // すでに処理中なら多重タップを無視する
        guard !isWritingThrough else { return }

        isWritingThrough = true
        errorMessage = nil

        // アラームEventの基本情報を組み立てる
        // 複数選択がある場合は最も早い通知（最大分数）を主として使用
        let primaryMinutes = selectedPreNotificationMinutesList.max() ?? 15
        let recurrence = selectedRecurrence
        let calendarID = appState.subscriptionTier.canSelectCalendar
            ? (selectedCalendarID ?? appState.selectedCalendarID)
            : nil

        // 繰り返し予定の場合は共通グループIDを付与（将来の一括削除に使用）
        let groupID: UUID? = recurrence != nil ? UUID() : nil

        // ユーザーが今日/明日トグルで選択した日時を優先、なければNLParser解析結果を使用
        let resolvedFireDate = parsed.isToDo
            ? Calendar.current.startOfDay(for: selectedFireDate ?? parsed.fireDate)
            : (selectedFireDate ?? parsed.fireDate)

        // 登録する発火日時のリスト（単発なら1件、繰り返しならN件）
        let fireDates: [Date]
        if let rule = recurrence {
            fireDates = rule.nextOccurrences(from: resolvedFireDate, count: rule.scheduledCount)
        } else {
            fireDates = [resolvedFireDate]
        }

        var alarmKitSucceeded = false

        for (index, fireDate) in fireDates.enumerated() {
            var alarm = AlarmEvent(
                title: parsed.title,
                fireDate: fireDate,
                preNotificationMinutes: primaryMinutes,
                calendarIdentifier: calendarID,
                voiceCharacter: appState.voiceCharacter,
                recurrenceRule: recurrence,
                recurrenceGroupID: groupID,
                eventEmoji: nlParser.inferEmoji(from: parsed.title),
                isToDo: parsed.isToDo
            )

            // Step 1: 音声ファイル（.caf）を生成してLibrary/Soundsに保存（失敗してもスキップして続行）
            let speechText = VoiceFileGenerator.speechText(for: alarm)
            if let voiceURL = try? await voiceGenerator.generateAudio(
                text: speechText,
                character: alarm.voiceCharacter,
                alarmID: alarm.id,
                eventTitle: alarm.title
            ) {
                alarm.voiceFileName = voiceURL.lastPathComponent
            }

            // Step 2: AlarmKitアラームを登録（最重要ステップ。失敗時はEventKitに書かず重複を防ぐ）
            // P-1-11: ToDoタスクはアラーム発火不要のためAlarmKit登録をスキップ
            if !alarm.isToDo {
                do {
                    var scheduledIDs: [UUID] = []
                    var minutesMap: [String: Int] = [:]
                    for minutes in selectedPreNotificationMinutesList.sorted(by: >) {
                        var tempAlarm = alarm
                        tempAlarm.preNotificationMinutes = minutes
                        let akID = try await alarmScheduler.schedule(tempAlarm)
                        scheduledIDs.append(akID)
                        minutesMap[akID.uuidString] = minutes
                    }
                    alarm.alarmKitIdentifiers = scheduledIDs
                    alarm.alarmKitIdentifier = scheduledIDs.first
                    alarm.alarmKitMinutesMap = minutesMap
                } catch {
                    // AlarmKit登録失敗 → EventKit書込をスキップしてループを継続
                    continue
                }
            }
            // ToDoはAlarmKit不要のため、ここでalarmKitSucceededをtrueにしてアーリーリターンを防ぐ
            if alarm.isToDo { alarmKitSucceeded = true }

            // Step 3: EventKitに予定を書き込む（AlarmKit成功後のみ。カレンダー権限なし時はスキップ）
            if index == 0 {
                if let eventKitID = try? await calendarProvider.writeEvent(
                    alarm,
                    to: alarm.calendarIdentifier
                ) {
                    alarm.eventKitIdentifier = eventKitID
                    alarm.lastLocalCalendarWriteAt = Date()
                }
            }

            // Step 4: ローカルに永続化
            eventStore.save(alarm)
            alarmKitSucceeded = true
        }

        if !alarmKitSucceeded {
            errorMessage = "アラームのセットに失敗しました。\niPhoneの「設定」アプリからアラームの\n許可をオンにして、もう一度お試しください。"
            isWritingThrough = false
            return
        }

        // WidgetKitのタイムラインを即座に更新
        WidgetCenter.shared.reloadAllTimelines()

        // 成功フィードバック（コンシェルジュ口調）
        let recurrenceSuffix = recurrence.map { "（\($0.shortDisplayName)）" } ?? ""
        let calendarName = await resolvedCalendarName(id: calendarID)
        let calendarSuffix = calendarName.map { "「\($0)」にも登録しました。" } ?? ""
        if parsed.isToDo {
            confirmationMessage = "「\(parsed.title)」をやることリストに追加したよ！\(calendarSuffix)バッチリです。"
        } else {
            confirmationMessage = "\(resolvedFireDate.naturalJapaneseString)、\(parsed.title)\(recurrenceSuffix)ですね。アラームをセットしました！\(calendarSuffix)バッチリです。"
        }
        parsedInput = nil
        transcribedText = ""

        isWritingThrough = false
    }

    // MARK: - カレンダー情報

    /// PRO版かつ複数カレンダー所持の場合に利用可能カレンダーをロードする
    func loadCalendarsIfNeeded() async {
        guard appState.subscriptionTier.canSelectCalendar else { return }
        guard let calendars = try? await calendarProvider.availableCalendars(),
              calendars.count >= 2 else { return }
        availableCalendars = calendars
        // デフォルト選択: グローバル設定 → 最初のカレンダーの順でフォールバック
        if selectedCalendarID == nil {
            selectedCalendarID = appState.selectedCalendarID ?? calendars.first?.id
        }
    }

    /// カレンダーIDからカレンダー名を解決する（成功メッセージ用）
    private func resolvedCalendarName(id: String?) async -> String? {
        guard let id else { return nil }
        let calendars = (try? await calendarProvider.availableCalendars()) ?? []
        return calendars.first(where: { $0.id == id })?.title
    }

    /// 確認画面で使う初期値を現在の設定から反映する
    private func applyConfirmationDefaults(for parsed: ParsedInput?) {
        selectedFireDate = nil
        selectedPreNotificationMinutesList = appState.preNotificationMinutesList
        selectedRecurrence = parsed?.recurrenceRule
    }

    // MARK: - リセット

    func reset() {
        stopListening()
        transcribedText   = ""
        parsedInput       = nil
        errorMessage      = nil
        confirmationMessage = nil
        isListening       = false
        selectedFireDate  = nil
        selectedPreNotificationMinutesList = appState.preNotificationMinutesList
        selectedRecurrence = nil
        selectedCalendarID = nil
        duplicateWarning  = nil
    }
}

// MARK: - 重複警告モデル（P-1-7）

struct DuplicateWarning {
    let existingTitle: String
    let existingDate: Date
}
