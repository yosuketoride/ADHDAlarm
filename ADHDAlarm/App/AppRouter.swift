import Foundation
import Observation

/// アプリ全体のナビゲーション状態を管理する
@Observable @MainActor
final class AppRouter {
    /// AlarmKitが発火したアラーム（非nilのときRingingViewをフルスクリーン表示）
    var ringingAlarm: AlarmEvent?
    /// バナーのボタンから届いたアクション（RingingViewが開いているときに処理する）
    var pendingAlarmAction: AlarmBannerAction?
    /// マイクシートが開いているか（アラーム発火時の待機判定に使用）
    var isMicSheetOpen = false

    init() {}
}

/// 通知バナーのアクションボタンの種類
enum AlarmBannerAction {
    case snooze
    case skip
}
