import Foundation

extension Notification.Name {
    /// バックグラウンド同期で家族からの新しい予定を受信したとき
    static let didReceiveRemoteFamilyEvents = Notification.Name("didReceiveRemoteFamilyEvents")
}
