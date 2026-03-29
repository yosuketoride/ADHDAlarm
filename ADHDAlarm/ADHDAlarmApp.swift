import SwiftUI
import AlarmKit
import ActivityKit
import AppIntents
import UserNotifications

@main
struct ADHDAlarmApp: App {
    @State private var appState  = AppState()
    @State private var appRouter = AppRouter()
    @Environment(\.scenePhase) private var scenePhase

    private let syncEngine         = SyncEngine()
    private let permissionsService = PermissionsService()
    @State private var storeKit    = StoreKitService()

    init() {
        // フォアグラウンド中も通知を表示するためにデリゲートを設定
        UNUserNotificationCenter.current().delegate = ForegroundNotificationDelegate.shared
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
        // 通知権限をリクエスト（家族機能のお知らせ・事前通知に使用）
        // 既に許可済みの場合はダイアログが出ない
        await permissionsService.requestNotification()
    }

    // MARK: - URL Scheme ハンドラ

    /// adhdalarm://voice-input → 当事者ホームに移動（Phase 2で詳細実装）
    private func handleOpenURL(_ url: URL) {
        guard url.scheme == "adhdalarm" else { return }
        // TODO: Phase 2でdeeplink対応を実装する
    }

    // MARK: - AlarmKit発火監視

    /// alarmUpdatesを常時監視し、alerting状態になったアラームをRingingViewに渡す
    private func watchAlarmUpdates() async {
        for await alarms in AlarmManager.shared.alarmUpdates {
            // alerting（発火中）のアラームを探す
            guard let alertingAlarm = alarms.first(where: { $0.state == .alerting }) else {
                continue
            }

            // アプリ内ストアからAlarmEventを検索
            let foundEvent = AlarmEventStore.shared.find(alarmKitID: alertingAlarm.id)

            // すでに同じアラームを表示中なら重複表示しない
            if appRouter.ringingAlarm?.alarmKitIdentifiers.contains(alertingAlarm.id) == true ||
               appRouter.ringingAlarm?.alarmKitIdentifier == alertingAlarm.id { continue }

            // alarmKitMinutesMap から発火したアラームの事前通知分数を取得
            var alarmToDisplay = foundEvent ?? AlarmEvent(
                id: UUID(),
                title: "アラーム",
                fireDate: Date(),
                alarmKitIdentifier: alertingAlarm.id
            )
            if let mappedMinutes = foundEvent?.alarmKitMinutesMap[alertingAlarm.id.uuidString] {
                alarmToDisplay.preNotificationMinutes = mappedMinutes
            }

            appRouter.ringingAlarm = alarmToDisplay
        }
    }
}

// MARK: - ルートビュー

struct RootView: View {
    @Environment(AppRouter.self) private var router
    @Environment(AppState.self) private var appState

    var body: some View {
        @Bindable var appState = appState

        Group {
            if !appState.isOnboardingComplete || appState.appMode == nil {
                NavigationStack(path: $appState.onboardingPath) {
                    ModeSelectionView()
                        .navigationDestination(for: OnboardingDestination.self) { destination in
                            destinationView(for: destination)
                        }
                }
                .transition(.opacity)
            } else if appState.appMode == .person {
                PersonHomeView()
                    .transition(.opacity)
            } else {
                FamilyHomeView()
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

    @ViewBuilder
    private func destinationView(for destination: OnboardingDestination) -> some View {
        switch destination {
        case .personWelcome:    PersonWelcomeView()
        case .permissionsCTA:   PermissionsCTAView()
        case .owlNaming:        OwlNamingView()
        case .magicDemoWarning: MagicDemoWarningView()
        case .magicDemo(let hapticOnly): MagicDemoView(hapticOnly: hapticOnly)
        case .widgetGuide:      WidgetGuideView()
        }
    }
}
