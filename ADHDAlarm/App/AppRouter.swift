import Foundation
import Observation

/// アプリ全体のナビゲーション状態を管理する
@Observable
final class AppRouter {
    enum Destination {
        case onboarding
        case dashboard
    }

    var currentDestination: Destination

    /// AlarmKitが発火したアラーム（非nilのときRingingViewをフルスクリーン表示）
    var ringingAlarm: AlarmEvent?

    /// MainTabViewで選択中のタブ（0=入力, 1=予定リスト, 2=設定）
    var selectedTab = 0

    init(appState: AppState) {
        self.currentDestination = appState.isOnboardingComplete ? .dashboard : .onboarding
    }

    func completeOnboarding() {
        currentDestination = .dashboard
    }
}
