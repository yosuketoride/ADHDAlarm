import AppIntents
import Foundation
import WidgetKit

/// Siri 経由で予定を追加するインテント（PRO機能）
///
/// 【2ステップ対話フロー】
/// 1. Siri: 「いつのアラームをセットしますか？」→ ユーザー: 「明日の15時」
/// 2. Siri: 「明日の15時ですね。なんの予定ですか？」→ ユーザー: 「病院」
/// 3. Siri: 「わかりました！明日の15時に『病院』をメモして、アラームをセットしました。」
struct AddEventIntent: AppIntent {

    static var title: LocalizedStringResource = "予定を追加する"
    static var description = IntentDescription(
        "「ふくろうにお願い」と話しかけるだけで予定を登録します。（PRO機能）",
        categoryName: "ふくろう"
    )

    /// バックグラウンドで動作（アプリを前面に出さない）
    static var openAppWhenRun: Bool = false

    /// Step 1: いつか（「明日の15時」のように話す）
    @Parameter(
        title: "日時",
        description: "「明日の15時」「今週金曜の朝9時」のように話してください",
        requestValueDialog: IntentDialog("いつのアラームをセットしますか？")
    )
    var dateText: String

    /// Step 2: なんの予定か（タイトルをそのまま話す）
    @Parameter(
        title: "予定の内容",
        description: "「病院」「カフェで待ち合わせ」のように話してください",
        requestValueDialog: IntentDialog("なんの予定ですか？")
    )
    var eventTitle: String

    static var parameterSummary: some ParameterSummary {
        Summary("\(\.$dateText)に\(\.$eventTitle)をセット")
    }

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        // PRO確認: App Group経由で読む（SiriはApp本体と別プロセスのためstandard不可）
        let defaults = UserDefaults(suiteName: Constants.appGroupID) ?? UserDefaults.standard
        let tierRaw  = defaults.string(forKey: Constants.Keys.subscriptionTier) ?? ""
        let tier     = SubscriptionTier(rawValue: tierRaw) ?? .free
        guard tier == .pro else {
            return .result(dialog: "この機能はPROプランでご利用いただけます。アプリを開いてアップグレードしてください。")
        }

        let parser = NLParserService()

        // ① まず dateText をフル解析（「明日の15時に病院」のように一気に言った場合）
        let fullParsed = parser.parse(text: dateText)

        let fireDate: Date
        let resolvedTitle: String

        if let fp = fullParsed, !fp.title.isEmpty {
            // 一気に言った場合: 日時＋タイトル両方取れた → Step 2 をスキップ
            fireDate      = fp.fireDate
            resolvedTitle = fp.title
        } else {
            // ② 日時だけ抽出を試みる（「10分後」「明日の15時」など）
            guard let date = parser.parseDate(text: dateText) else {
                return .result(dialog: "ごめんなさい、日時が読み取れませんでした。「10分後」「明日の15時」のように話しかけてみてください。")
            }
            fireDate      = date
            resolvedTitle = eventTitle  // Step 2 で Siri が「なんの予定ですか？」と聞いた回答
        }

        // 確認用の日時テキスト
        let confirmedDateText = fireDate.naturalJapaneseString

        // ユーザー設定を UserDefaults から取得（AppState を使わずに直接読む）
        let voiceCharacterRaw      = defaults.string(forKey: Constants.Keys.voiceCharacter) ?? ""
        let voiceCharacter         = VoiceCharacter(rawValue: voiceCharacterRaw) ?? .femaleConcierge
        let savedMinutes           = defaults.integer(forKey: Constants.Keys.preNotificationMinutes)
        let preNotificationMinutes = savedMinutes == 0 ? 15 : savedMinutes
        let selectedCalendarID     = defaults.string(forKey: Constants.Keys.selectedCalendarID)

        // AlarmEvent を組み立てる（resolvedTitle / fireDate は上で確定済み）
        var alarm = AlarmEvent(
            title: resolvedTitle,
            fireDate: fireDate,
            preNotificationMinutes: preNotificationMinutes,
            calendarIdentifier: selectedCalendarID,
            voiceCharacter: voiceCharacter
        )

        // Write-Through
        let voiceGenerator   = VoiceFileGenerator()
        let calendarProvider = AppleCalendarProvider()
        let alarmScheduler   = AlarmKitScheduler()

        do {
            // Step 1: 音声ファイル（.caf）を生成
            let speechText = VoiceFileGenerator.speechText(for: alarm)
            if let voiceURL = try? await voiceGenerator.generateAudio(
                text: speechText,
                character: alarm.voiceCharacter,
                alarmID: alarm.id,
                eventTitle: resolvedTitle
            ) {
                alarm.voiceFileName = voiceURL.lastPathComponent
            }

            // Step 2: EventKit に書き込む
            let eventKitID = try await calendarProvider.writeEvent(alarm, to: alarm.calendarIdentifier)
            alarm.eventKitIdentifier = eventKitID

            // Step 3: AlarmKit に登録
            let akID = try await alarmScheduler.schedule(alarm)
            alarm.alarmKitIdentifier  = akID
            alarm.alarmKitIdentifiers = [akID]

            // Step 4: ローカルに保存
            AlarmEventStore.shared.save(alarm)

            // WidgetKit のタイムラインを即座に更新
            WidgetCenter.shared.reloadAllTimelines()

            // フクロウらしい完了メッセージ
            let confirmText = "わかりました！\(confirmedDateText)に『\(resolvedTitle)』の予定をメモして、アラームをセットしました。"
            return .result(dialog: IntentDialog(stringLiteral: confirmText))

        } catch {
            // ロールバック
            if let ekID = alarm.eventKitIdentifier {
                try? await calendarProvider.deleteEvent(eventKitIdentifier: ekID)
            }
            voiceGenerator.deleteAudio(alarmID: alarm.id)
            return .result(dialog: "うまくセットできませんでした。もう一度やってみてくださいね。")
        }
    }
}
