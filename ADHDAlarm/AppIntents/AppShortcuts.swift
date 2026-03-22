import AppIntents

/// App Shortcuts の登録
/// 「Hey Siri、こえメモにお願い」等でこのアプリが起動する
/// ※ INAlternativeAppNames は iOS 26 beta では動作しないため、アプリ名のみ対応
struct VoiceMemoAlarmShortcuts: AppShortcutsProvider {

    static var appShortcuts: [AppShortcut] {

        // 予定を声で追加する（PRO機能）
        // Siriが「いつ？」「なんの予定？」と順番に聞いてくれる2ステップ対話形式
        // ※ Stringパラメータはフレーズ内補間不可のため、起動フレーズのみ登録する
        AppShortcut(
            intent: AddEventIntent(),
            phrases: [
                "\(.applicationName)にお願い",
                "\(.applicationName)で予定を追加",
                "\(.applicationName)で予定を登録して",
                "\(.applicationName)に予定を入れて",
            ],
            shortTitle: "予定を追加する",
            systemImageName: "calendar.badge.plus"
        )

        // カレンダーとアラームを同期する
        AppShortcut(
            intent: SyncIntent(),
            phrases: [
                "\(.applicationName)を読み込む",
                "\(.applicationName)の予定を更新して",
            ],
            shortTitle: "予定を最新にする",
            systemImageName: "arrow.triangle.2.circlepath"
        )
    }
}
