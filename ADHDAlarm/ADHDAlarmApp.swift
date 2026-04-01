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
                if appState.appMode == .person {
                    Task {
                        try? await FamilyRemoteService.shared.updateLastSeen()
                    }
                }
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
        // アラームバナーに「止める / あとで / 今日は休む」ボタンを登録する
        registerAlarmNotificationCategory()
    }

    /// UNNotificationCategoryを登録してバナーにアクションボタンを追加する
    /// ※ AlarmKitが発行する通知にcategoryIdentifierが設定されていれば、このカテゴリのボタンが表示される
    private func registerAlarmNotificationCategory() {
        let dismiss = UNNotificationAction(
            identifier: Constants.Notification.actionDismiss,
            title: "止める",
            options: [.foreground]  // アプリを前面に出してRingingViewで視覚的に停止確認できるようにする
        )
        let snooze = UNNotificationAction(
            identifier: Constants.Notification.actionSnooze,
            title: "あとで（30分後）",
            options: []  // バックグラウンドで再スケジュール処理する
        )
        let skip = UNNotificationAction(
            identifier: Constants.Notification.actionSkip,
            title: "今日は休む",
            options: [.destructive]  // 赤色で「取り消せない操作」であることをユーザーに示す
        )
        let category = UNNotificationCategory(
            identifier: Constants.Notification.alarmCategoryID,
            actions: [dismiss, snooze, skip],
            intentIdentifiers: [],
            options: []
        )
        UNUserNotificationCenter.current().setNotificationCategories([category])
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
        // バナーの「止める / あとで / 今日は休む」ボタン処理
        .onReceive(NotificationCenter.default.publisher(
            for: ForegroundNotificationDelegate.alarmActionNotification
        )) { notification in
            handleAlarmAction(from: notification, router: router)
        }
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

    // MARK: - バナーアクション処理

    /// 通知バナーのボタンが押されたときの処理
    /// - 止める: アラームをdismiss（RingingViewが開いていればそちらで処理、なければ直接停止）
    /// - あとで: 30分後にスヌーズ登録してdismiss
    /// - 今日は休む: スキップとしてdismiss
    private func handleAlarmAction(from notification: Foundation.Notification, router: AppRouter) {
        guard let userInfo = notification.userInfo,
              let actionID = userInfo[ForegroundNotificationDelegate.alarmActionIdentifierKey] as? String
        else { return }

        // RingingView が既に開いている場合は AppRouter 経由で処理する
        // （RingingView 自身が dismiss/snooze/skip を持っているため）
        if router.ringingAlarm != nil {
            switch actionID {
            case Constants.Notification.actionDismiss:
                // .foreground オプションでアプリが前面に来るため、ユーザーが手動で止める
                break
            case Constants.Notification.actionSnooze:
                router.pendingAlarmAction = .snooze
            case Constants.Notification.actionSkip:
                router.pendingAlarmAction = .skip
            default:
                break
            }
            return
        }

        // RingingView が閉じている状態（バックグラウンドや別画面）での処理
        // AlarmEventStore から対象アラームを特定してアクションを実行する
        let alarmKitIDString = userInfo[ForegroundNotificationDelegate.alarmKitIDKey] as? String ?? ""
        guard let alarmKitUUID = UUID(uuidString: alarmKitIDString),
              let alarm = AlarmEventStore.shared.find(alarmKitID: alarmKitUUID)
        else {
            // 対象アラームが見つからない場合は止めるのみ（安全側に倒す）
            return
        }

        switch actionID {
        case Constants.Notification.actionDismiss:
            // アプリが前面に来るので RingingView を表示して視覚的に停止できるようにする
            router.ringingAlarm = alarm
        case Constants.Notification.actionSnooze:
            // バックグラウンドでスヌーズ登録：30分後に再アラーム
            Task { @MainActor in
                var snoozed = alarm
                snoozed.snoozeCount = alarm.snoozeCount + 1
                AlarmEventStore.shared.save(snoozed)
                let snoozeDate = Date().addingTimeInterval(30 * 60)
                let snoozeAlarm = AlarmEvent(
                    id: alarm.id,
                    title: alarm.title,
                    fireDate: snoozeDate,
                    preNotificationMinutes: 0,
                    voiceFileName: alarm.voiceFileName,
                    voiceCharacter: alarm.voiceCharacter,
                    remoteEventId: alarm.remoteEventId
                )
                if let alarmKitID = alarm.alarmKitIdentifier {
                    try? await AlarmKitScheduler().cancel(alarmKitID: alarmKitID)
                }
                if let newID = try? await AlarmKitScheduler().schedule(snoozeAlarm) {
                    var final = snoozeAlarm
                    final.alarmKitIdentifier = newID
                    AlarmEventStore.shared.save(final)
                }
            }
        case Constants.Notification.actionSkip:
            // バックグラウンドでスキップ記録
            Task { @MainActor in
                var skipped = alarm
                skipped.completionStatus = .skipped
                AlarmEventStore.shared.save(skipped)
                if let alarmKitID = alarm.alarmKitIdentifier {
                    try? await AlarmKitScheduler().cancel(alarmKitID: alarmKitID)
                }
                if let ekID = alarm.eventKitIdentifier {
                    try? await AppleCalendarProvider().deleteEvent(eventKitIdentifier: ekID)
                }
            }
        default:
            break
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
