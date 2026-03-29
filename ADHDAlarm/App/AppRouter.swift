import Foundation
import Observation

/// アプリ全体のナビゲーション状態を管理する
@Observable @MainActor
final class AppRouter {
    /// AlarmKitが発火したアラーム（非nilのときRingingViewをフルスクリーン表示）
    var ringingAlarm: AlarmEvent?

    init() {}
}
