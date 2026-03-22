import AppIntents
import Foundation

/// ショートカット・オートメーションで呼び出せる「カレンダーとアラームを同期する」インテント
///
/// 使い方:
/// iOS「ショートカット」アプリのオートメーションから「毎日午前1時」などのトリガーで呼ぶと、
/// バックグラウンドで EventKit ⇔ AlarmKit の差分同期が走る。
/// アプリを前面に出さずに動作する。
struct SyncIntent: AppIntent {

    static var title: LocalizedStringResource = "カレンダーとアラームを同期する"
    static var description = IntentDescription(
        "予定とアラームを最新の状態に更新します。「ショートカット」アプリのオートメーションに登録すると、自動でお掃除してくれます。",
        categoryName: "こえメモ"
    )

    /// バックグラウンドで動作する（アプリを前面に出さない）
    static var openAppWhenRun: Bool = false

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let engine = SyncEngine()
        await engine.performFullSync()
        return .result(dialog: "予定とアラームを最新の状態に更新しました。")
    }
}
