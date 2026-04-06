import Foundation

extension Notification.Name {
    /// バックグラウンド同期で家族からの新しい予定を受信したとき
    static let didReceiveRemoteFamilyEvents = Notification.Name("didReceiveRemoteFamilyEvents")
    /// アラームが発火してRingingViewが表示される直前。録音中の全サービスはこれを受けて即座に停止すること。
    static let alarmWillStartPlaying = Notification.Name("alarmWillStartPlaying")
}
