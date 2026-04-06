import UserNotifications

/// アプリがフォアグラウンドのときも通知バナーを表示するためのデリゲート
/// デフォルトでは iOS はアプリが前面にいるとき通知を表示しないため、これが必要
final class ForegroundNotificationDelegate: NSObject, UNUserNotificationCenterDelegate, @unchecked Sendable {

    static let shared = ForegroundNotificationDelegate()

    /// バナーのアクションボタン操作を受け取るためのNotificationCenter通知名
    static let alarmActionNotification = Notification.Name("AlarmNotificationAction")
    /// userInfo のキー: アクション識別子（Constants.Notification.actionXxx）
    static let alarmActionIdentifierKey = "actionIdentifier"
    /// userInfo のキー: 通知に紐づく AlarmKit ID（文字列）
    static let alarmKitIDKey = "alarmKitID"

    private override init() {
        super.init()
    }

    // MARK: - フォアグラウンド表示

    /// フォアグラウンド中に通知が届いたときの表示オプションを返す
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler(Self.presentationOptions(for: notification.request.content.categoryIdentifier))
    }

    // MARK: - アクションボタン処理

    /// バナーの「止める / あとで / 今日は休む」ボタンが押されたときに呼ばれる
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        defer { completionHandler() }

        let actionID = response.actionIdentifier
        // カテゴリ対象外の通知（家族予定お知らせ等）はスキップ
        guard response.notification.request.content.categoryIdentifier
                == Constants.Notification.alarmCategoryID else { return }

        // AlarmKit ID を userInfo から取得（アクション側で対象アラームを特定するため）
        let alarmKitIDString = response.notification.request.content.userInfo[
            ForegroundNotificationDelegate.alarmKitIDKey
        ] as? String

        // NotificationCenter で AppRouter / RingingViewModel に伝達する
        // SwiftUI の Environment に直接アクセスできないためこの迂回路を使う
        NotificationCenter.default.post(
            name: ForegroundNotificationDelegate.alarmActionNotification,
            object: nil,
            userInfo: [
                ForegroundNotificationDelegate.alarmActionIdentifierKey: actionID,
                ForegroundNotificationDelegate.alarmKitIDKey: alarmKitIDString ?? ""
            ]
        )
    }

    /// 通知カテゴリごとの前面表示オプションを返す
    static func presentationOptions(for categoryIdentifier: String) -> UNNotificationPresentationOptions {
        // AlarmKitのアラーム通知はRingingViewで対応するためバナー不要。
        // それ以外（家族お知らせ等）はバナーを表示する。
        if categoryIdentifier == Constants.Notification.alarmCategoryID {
            return [.badge]
        }
        return [.banner, .sound, .list]
    }
}
