import Foundation
import Observation

/// アプリ全体のナビゲーション状態を管理する
@Observable @MainActor
final class AppRouter {
    /// AlarmKitが発火したアラーム（非nilのときRingingViewをフルスクリーン表示）
    var ringingAlarm: AlarmEvent?
    /// バナーのボタンから届いたアクション（RingingViewが開いているときに処理する）
    var pendingAlarmAction: AlarmBannerAction?

    init() {}
}

/// 通知バナーのアクションボタンの種類
enum AlarmBannerAction {
    case snooze
    case skip
}
