import SwiftUI
import AlarmKit
import ActivityKit
import AppIntents
import UserNotifications

// MARK: - AppDelegate（レビュー指摘 #2）
// UNUserNotificationCenter.delegate は App.init() ではなく AppDelegate で設定する。
// SwiftUI の App 構造体の init は Scene 再構築で複数回呼ばれる可能性があるため。
private final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        UNUserNotificationCenter.current().delegate = ForegroundNotificationDelegate.shared
        // P-9-6: データモデルのマイグレーション（新フィールド追加時に既存データを補完）
        DataMigrationService.migrateIfNeeded()
        return true
    }
}

@main
struct ADHDAlarmApp: App {
    // AppDelegate を SwiftUI ライフサイクルに接続
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    @State private var appState  = AppState()
    @State private var appRouter = AppRouter()
    @Environment(\.scenePhase) private var scenePhase

    private let syncEngine         = SyncEngine()
    private let permissionsService = PermissionsService()
    @State private var storeKit    = StoreKitService()

    // P-5-4: scenePhase .active の多重発火を防ぐデバウンス用タイムスタンプ
    // コントロールセンター開閉などで .active が連打されても最低60秒は再同期しない
    @State private var lastSyncTimestamp: Date = .distantPast

    init() {}

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
                checkBatteryLevel()
                // P-5-4: 前回同期から60秒未満ならスキップ（多重発火防止）
                let now = Date()
                guard now.timeIntervalSince(lastSyncTimestamp) >= 60 else { return }
                lastSyncTimestamp = now
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

    // MARK: - バッテリー残量チェック（P-9-3）

    /// バッテリー10%未満かつアラーム登録中の場合にトーストを表示
    private func checkBatteryLevel() {
        UIDevice.current.isBatteryMonitoringEnabled = true
        let level = UIDevice.current.batteryLevel
        guard level > 0, level < 0.10 else { return }
        let hasUpcoming = AlarmEventStore.shared.loadAll().contains {
            $0.fireDate > Date() && $0.completionStatus == nil && !$0.isToDo
        }
        guard hasUpcoming else { return }
        appState.globalToast = "🪫 充電残量が少なくなっています。充電してからアラームを使ってね"
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
        // P-9-3: グローバルトースト（バッテリー警告など）
        .overlay(alignment: .top) {
            if let toast = appState.globalToast {
                Text(toast)
                    .font(.callout.weight(.medium))
                    .foregroundStyle(.primary)
                    .padding(16)
                    .background(.regularMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .padding(.horizontal, 24)
                    .padding(.top, 16)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .onAppear {
                        Task {
                            try? await Task.sleep(for: .seconds(5))
                            withAnimation { appState.globalToast = nil }
                        }
                    }
            }
        }
        .animation(.spring(duration: 0.3), value: appState.globalToast != nil)
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
