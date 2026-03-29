import SwiftUI

/// メインTabView（3タブ構成）
/// Tab 1: 音声入力  Tab 2: 予定リスト  Tab 3: 設定
struct MainTabView: View {
    @Environment(AppState.self)  private var appState
    @Environment(AppRouter.self) private var router
    @State private var dashboardViewModel = DashboardViewModel()
    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            VoiceInputTab(dashboardViewModel: dashboardViewModel)
                .tabItem {
                    Label("追加", systemImage: "mic.fill")
                }
                .tag(0)

            AlarmListTab(viewModel: dashboardViewModel)
                .tabItem {
                    Label("予定", systemImage: "list.bullet.clipboard")
                }
                .tag(1)

            SettingsTab()
                .tabItem {
                    Label("設定", systemImage: "gearshape")
                }
                .tag(2)
        }
        .environment(dashboardViewModel)
        .task {
            await dashboardViewModel.loadEvents()
            await dashboardViewModel.checkWidgetStatus()
        }
    }
}
