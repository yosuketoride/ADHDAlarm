import UserNotifications

/// アプリがフォアグラウンドのときも通知バナーを表示するためのデリゲート
/// デフォルトでは iOS はアプリが前面にいるとき通知を表示しないため、これが必要
final class ForegroundNotificationDelegate: NSObject, UNUserNotificationCenterDelegate, @unchecked Sendable {

    static let shared = ForegroundNotificationDelegate()

    private override init() {
        super.init()
    }

    /// フォアグラウンド中に通知が届いたときの表示オプションを返す
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        // バナー・サウンド・バッジをすべて表示する
        completionHandler([.banner, .sound, .badge])
    }
}
