import SwiftUI
import AlarmKit
import ActivityKit
import AppIntents

@main
struct ADHDAlarmApp: App {
    @State private var appState  = AppState()
    @State private var appRouter: AppRouter
    @Environment(\.scenePhase) private var scenePhase

    private let syncEngine         = SyncEngine()
    private let permissionsService = PermissionsService()
    @State private var storeKit    = StoreKitService()

    init() {
        let state = AppState()
        _appState  = State(initialValue: state)
        _appRouter = State(initialValue: AppRouter(appState: state))
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(appState)
                .environment(appRouter)
                .environment(permissionsService)
                .environment(storeKit)
                .task { await startupTasks() }
                // AlarmKit発火監視: alerting状態になったらRingingViewを表示
                .task { await watchAlarmUpdates() }
                // ウィジェットやURL Schemeからの起動ハンドラ
                .onOpenURL { url in handleOpenURL(url) }
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                permissionsService.refreshStatuses()
                Task {
                    await syncEngine.performFullSync()
                    let newCount = await syncEngine.syncRemoteEvents()
                    if newCount > 0 {
                        appState.unreadFamilyEventCount += newCount
                    }
                }
            }
        }
    }

    // MARK: - 起動時処理

    private func startupTasks() async {
        async let isPro = storeKit.checkEntitlement()
        async let _: Void = storeKit.loadProducts()
        if await isPro { appState.subscriptionTier = .pro }
        // App Shortcutsをシステムに登録する（これを呼ばないと毎回許可ダイアログが出る）
        VoiceMemoAlarmShortcuts.updateAppShortcutParameters()
    }

    // MARK: - URL Scheme ハンドラ

    /// adhdalarm://voice-input → 音声入力タブに切り替える
    private func handleOpenURL(_ url: URL) {
        guard url.scheme == "adhdalarm" else { return }
        if url.host == "voice-input" {
            appRouter.currentDestination = .dashboard
            appRouter.selectedTab = 0
        }
    }

    // MARK: - AlarmKit発火監視

    /// alarmUpdatesを常時監視し、alerting状態になったアラームをRingingViewに渡す
    private func watchAlarmUpdates() async {
        for await alarms in AlarmManager.shared.alarmUpdates {
            // alerting（発火中）のアラームを探す
            guard let alertingAlarm = alarms.first(where: { $0.state == .alerting }) else {
                // 発火中アラームがなくなった（ユーザーが止めた）→ RingingViewを閉じる
                // AlarmKit側で止められた場合のみ閉じる（アプリ内操作は RingingView が自分で閉じる）
                continue
            }

            // アプリ内ストアからAlarmEventを検索（単一IDと配列の両方を検索）
            let foundEvent = AlarmEventStore.shared.find(alarmKitID: alertingAlarm.id)

            // すでに同じアラームを表示中なら重複表示しない
            if appRouter.ringingAlarm?.alarmKitIdentifiers.contains(alertingAlarm.id) == true ||
               appRouter.ringingAlarm?.alarmKitIdentifier == alertingAlarm.id { continue }

            // alarmKitMinutesMap から発火したアラームの事前通知分数を取得
            // （ジャストアラームと事前通知アラームで読み上げテキストが異なるため）
            var alarmToDisplay = foundEvent ?? AlarmEvent(
                id: UUID(),
                title: "アラーム",
                fireDate: Date(),
                alarmKitIdentifier: alertingAlarm.id
            )
            if let mappedMinutes = foundEvent?.alarmKitMinutesMap[alertingAlarm.id.uuidString] {
                alarmToDisplay.preNotificationMinutes = mappedMinutes
            }

            // RingingViewを表示
            appRouter.ringingAlarm = alarmToDisplay
        }
    }
}

// MARK: - ルートビュー

struct RootView: View {
    @Environment(AppRouter.self) private var router
    @Environment(AppState.self) private var appState

    var body: some View {
        Group {
            switch router.currentDestination {
            case .onboarding:
                OnboardingContainerView()
                    .transition(.opacity)
            case .dashboard:
                MainTabView()
                    .transition(.opacity)
            }
        }
        // iPhoneの「テキストサイズ」設定に自動追従。上限はaccessibility1でレイアウト崩壊を防ぐ
        .dynamicTypeSize(...DynamicTypeSize.accessibility1)
        // AlarmKit発火時にフルスクリーンでRingingViewを表示
        .fullScreenCover(item: Binding(
            get: { router.ringingAlarm },
            set: { router.ringingAlarm = $0 }
        )) { alarm in
            RingingView(alarm: alarm) {
                router.ringingAlarm = nil
            }
        }
    }
}
