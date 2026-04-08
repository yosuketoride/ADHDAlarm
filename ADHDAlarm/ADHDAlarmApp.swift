import SwiftUI
import AlarmKit
import ActivityKit
import AppIntents
import UserNotifications
import BackgroundTasks
import EventKit
import FirebaseCore
import FirebaseCrashlytics

enum ForegroundSyncDebouncer {
    static let minimumInterval: TimeInterval = 60

    /// フォアグラウンド復帰時の再同期を実行してよいか判定する
    static func shouldRun(now: Date, lastSyncTimestamp: Date) -> Bool {
        now.timeIntervalSince(lastSyncTimestamp) >= minimumInterval
    }
}

// MARK: - AppDelegate（レビュー指摘 #2）
// UNUserNotificationCenter.delegate は App.init() ではなく AppDelegate で設定する。
// SwiftUI の App 構造体の init は Scene 再構築で複数回呼ばれる可能性があるため。
private final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        FirebaseApp.configure()
        UNUserNotificationCenter.current().delegate = ForegroundNotificationDelegate.shared
        // P-9-6: データモデルのマイグレーション（新フィールド追加時に既存データを補完）
        DataMigrationService.migrateIfNeeded()
        // バックグラウンドで家族からの予定を定期取り込みするタスクを登録
        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: "com.yosuke.WasurenboAlarm.syncRemoteEvents",
            using: nil
        ) { task in
            guard let refreshTask = task as? BGAppRefreshTask else { return }
            Task {
                let tierRaw = UserDefaults.standard.string(forKey: Constants.Keys.subscriptionTier) ?? ""
                let tier = SubscriptionTier(rawValue: tierRaw) ?? .free
                let modeRaw = UserDefaults.standard.string(forKey: Constants.Keys.appMode) ?? ""
                let count = (tier == .pro && modeRaw == AppMode.person.rawValue)
                    ? await SyncEngine().syncRemoteEvents() : 0
                if count > 0 {
                    // フォアグラウンドに通知（AppStateへのアクセスはMainActor経由）
                    await MainActor.run {
                        NotificationCenter.default.post(
                            name: .didReceiveRemoteFamilyEvents,
                            object: nil,
                            userInfo: ["count": count]
                        )
                    }
                }
                refreshTask.setTaskCompleted(success: true)
            }
            // タイムアウト時は中断としてマーク
            refreshTask.expirationHandler = { refreshTask.setTaskCompleted(success: false) }
            // 次回のBGRefreshをスケジュール
            AppDelegate.scheduleBGSync()
        }
        return true
    }

    /// BGAppRefreshをスケジュールする（最短15分間隔。実際の実行頻度はiOSが決定）
    static func scheduleBGSync() {
        let request = BGAppRefreshTaskRequest(identifier: "com.yosuke.WasurenboAlarm.syncRemoteEvents")
        request.earliestBeginDate = Date(timeIntervalSinceNow: 15 * 60)
        try? BGTaskScheduler.shared.submit(request)
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
    private let networkMonitor     = NetworkMonitorService()
    @State private var storeKit    = StoreKitService()

    // P-5-4: scenePhase .active の多重発火を防ぐデバウンス用タイムスタンプ
    // コントロールセンター開閉などで .active が連打されても最低60秒は再同期しない
    @State private var lastSyncCheckTimestamp: Date = .distantPast

    init() {}

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(appState)
                .environment(appRouter)
                .environment(permissionsService)
                .environment(networkMonitor)
                .environment(storeKit)
                .task { await startupTasks() }
                // AlarmKit発火監視: alerting状態になったらRingingViewを表示
                .task { await watchAlarmUpdates() }
                // EventKit変更通知監視: カレンダーアプリでの時刻変更を素早く取り込む
                .task { await watchEventKitChanges() }
                // 本人モードで前面表示中はRealtimeで家族予定の到着を監視する
                .task(id: shouldListenToRemoteEvents) {
                    await watchRemoteFamilyEvents()
                }
                // ウィジェットやURL Schemeからの起動ハンドラ
                .onOpenURL { url in handleOpenURL(url) }
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .background {
                // バックグラウンド移行時に次回BGSyncをスケジュール
                AppDelegate.scheduleBGSync()
            }
            if newPhase == .active {
                permissionsService.refreshStatuses()
                checkBatteryLevel()
                Task {
                    await syncSubscriptionTier()
                    if appState.appMode == .person {
                        if let linkId = appState.familyLinkId {
                            let links = try? await FamilyRemoteService.shared.fetchMyFamilyLinks()
                            let isStillPaired = links?.contains { $0.id == linkId && $0.status == "paired" } ?? false
                            if !isStillPaired {
                                await MainActor.run {
                                    appState.familyLinkId = nil
                                }
                            }
                        }
                        try? await FamilyRemoteService.shared.updateLastSeen()
                    }
                }
                // P-5-4: 前回同期から60秒未満ならスキップ（多重発火防止）
                let now = Date()
                guard ForegroundSyncDebouncer.shouldRun(now: now, lastSyncTimestamp: lastSyncCheckTimestamp) else { return }
                lastSyncCheckTimestamp = now
                Task {
                    await OfflineActionQueue.shared.flush()
                    await syncEngine.performFullSync()
                    let newCount = (appState.subscriptionTier == .pro && appState.appMode == .person)
                        ? await syncEngine.syncRemoteEvents()
                        : 0
                    if newCount > 0 {
                        appState.unreadFamilyEventCount += newCount
                    }
                }
            }
        }
    }

    // MARK: - 起動時処理

    private var shouldListenToRemoteEvents: Bool {
        appState.appMode == .person && scenePhase == .active && appState.subscriptionTier == .pro
    }

    private func startupTasks() async {
        async let _: Void = storeKit.loadProducts()
        await syncSubscriptionTier()
        // App Shortcutsをシステムに登録する（これを呼ばないと毎回許可ダイアログが出る）
        VoiceMemoAlarmShortcuts.updateAppShortcutParameters()
        // 通知権限をリクエスト（家族機能のお知らせ・事前通知に使用）
        // 既に許可済みの場合はダイアログが出ない
        await permissionsService.requestNotification()
        // アラームバナーに「止める / あとで / 今日は休む」ボタンを登録する
        registerAlarmNotificationCategory()
        // 家族モードの端末に過去の不具合で誤登録されたアラームを削除する
        if appState.appMode == .family {
            await purgeMisregisteredAlarmsIfNeeded()
        }
    }

    /// 家族モード端末に誤って登録された remoteEventId 付きのローカル予定を削除する
    /// syncRemoteEvents() の appMode ガード漏れで取り込まれた予定の救済処理
    private func purgeMisregisteredAlarmsIfNeeded() async {
        let scheduler = AlarmKitScheduler()
        let calendarProvider = AppleCalendarProvider()
        let misregistered = await MainActor.run {
            AlarmEventStore.shared.all.filter { $0.remoteEventId != nil }
        }
        guard !misregistered.isEmpty else { return }
        print("🧹 [purgeMisregistered] 家族端末の誤登録アラームを削除: \(misregistered.count)件")
        for alarm in misregistered {
            let alarmKitIDs = !alarm.alarmKitIdentifiers.isEmpty
                ? alarm.alarmKitIdentifiers
                : [alarm.alarmKitIdentifier].compactMap { $0 }
            if !alarmKitIDs.isEmpty {
                try? await scheduler.cancelAll(alarmKitIDs: alarmKitIDs)
            }
            if let ekID = alarm.eventKitIdentifier {
                try? await calendarProvider.deleteEvent(eventKitIdentifier: ekID)
            }
            await MainActor.run { AlarmEventStore.shared.delete(alarm.id) }
        }
        print("🧹 [purgeMisregistered] 削除完了")
    }

    @MainActor
    private func syncSubscriptionTier() async {
        if await storeKit.checkEntitlement() {
            appState.subscriptionTier = .pro
            return
        }

        do {
            let links = try await FamilyRemoteService.shared.fetchMyFamilyLinks()
            appState.subscriptionTier = links.contains(where: { $0.isPremium }) ? .pro : .free
        } catch {
            // 家族のPRO伝播は通信に依存するため、取得失敗時は現在値を維持して誤ロックを避ける
        }
    }

    // MARK: - EventKit変更監視

    /// EventKit変更通知を監視し、前面中は追加でフル同期する
    private func watchEventKitChanges() async {
        for await _ in NotificationCenter.default.notifications(named: .EKEventStoreChanged) {
            guard !Task.isCancelled else { return }
            guard scenePhase == .active else { continue }

            // Calendar.app 側の編集直後は EventKit の値が揺れることがあるため、少しだけ待ってから読む
            try? await Task.sleep(for: .milliseconds(700))
            guard !Task.isCancelled else { return }

            print("📆 [ADHDAlarmApp/watchEventKitChanges] EKEventStoreChanged を検知")
            await syncEngine.performFullSync()
        }
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
            options: [.customDismissAction]
        )
        UNUserNotificationCenter.current().setNotificationCategories([category])
    }

    /// 本人モードで前面表示中はRealtimeのINSERTを購読し、家族予定を素早く取り込む
    private func watchRemoteFamilyEvents() async {
        guard shouldListenToRemoteEvents else { return }
        do {
            _ = try await FamilyRemoteService.shared.ensureDeviceRegistered()
        } catch {
            return
        }

        let stream = FamilyRemoteService.shared.listenToNewEvents()
        for await _ in stream {
            guard !Task.isCancelled else { return }
            guard appState.subscriptionTier == .pro else { continue }
            let newCount = await syncEngine.syncRemoteEvents()
            guard newCount > 0 else { continue }
            await MainActor.run {
                appState.unreadFamilyEventCount += newCount
            }
        }
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
        // ToastWindowManager 経由で表示（RingingView上にも表示可能）
        ToastWindowManager.shared.show(ToastMessage(
            text: "充電残量が少なくなっています。充電してからアラームを使ってね",
            style: .error
        ))
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
            let alertingIDs = Set(alarms.filter { $0.state == .alerting }.map(\.id))
            PresentedAlarmStore.shared.retainOnly(alertingIDs)

            // alerting（発火中）のアラームを探す
            guard let alertingAlarm = alarms.first(where: { $0.state == .alerting }) else {
                continue
            }

            if HandledAlarmStore.shared.isHandled(alertingAlarm.id) {
                continue
            }
            if PresentedAlarmStore.shared.isPresented(alertingAlarm.id) {
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

            // マイク録音など他のオーディオセッションを先に停止させる。
            // マイクシートが開いている場合はシートのcloseアニメーション完了を待つ必要がある。
            let micSheetOpen = appRouter.isMicSheetOpen
            NotificationCenter.default.post(name: .alarmWillStartPlaying, object: nil)
            // SwiftUIのレンダリングサイクルが確実に処理されるよう最低100ms待つ。
            // マイクシートが開いている場合はcloseアニメーション完了のため500ms待つ。
            try? await Task.sleep(for: .milliseconds(micSheetOpen ? 500 : 100))
            PresentedAlarmStore.shared.markPresented(alertingAlarm.id)
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
        // iPhoneの「テキストサイズ」設定に自動追従。
        // RingingView などの実機テストで accessibility3 が必要なため、上限を引き上げる。
        .dynamicTypeSize(...DynamicTypeSize.accessibility3)
        // P-9-3: グローバルトースト → ToastWindowManager 経由（checkBatteryLevel参照）
        // バナーの「止める / あとで / 今日は休む」ボタン処理
        .onReceive(NotificationCenter.default.publisher(
            for: ForegroundNotificationDelegate.alarmActionNotification
        )) { notification in
            handleAlarmAction(from: notification, router: router)
        }
        // BGSync完了通知: バックグラウンドで新しい家族予定が届いたらバッジを更新
        .onReceive(NotificationCenter.default.publisher(for: .didReceiveRemoteFamilyEvents)) { notification in
            if let count = notification.userInfo?["count"] as? Int, count > 0 {
                appState.unreadFamilyEventCount += count
            }
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

        let isDismissAction = actionID == Constants.Notification.actionDismiss
            || actionID == UNNotificationDismissActionIdentifier

        // RingingView が既に開いている場合は AppRouter 経由で処理する
        // （RingingView 自身が dismiss/snooze/skip を持っているため）
        if router.ringingAlarm != nil {
            switch actionID {
            case _ where isDismissAction:
                if let ringingAlarm = router.ringingAlarm {
                    Task { @MainActor in
                        await completeAlarmFromNotification(ringingAlarm, router: router)
                    }
                }
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
        case _ where isDismissAction:
            Task { @MainActor in
                await completeAlarmFromNotification(alarm, router: router)
            }
        case Constants.Notification.actionSnooze:
            // バックグラウンドでスヌーズ登録：30分後に再アラーム
            Task { @MainActor in
                guard RingingViewModel.canSnooze(alarm.snoozeCount) else { return }
                var snoozed = alarm
                snoozed.snoozeCount = alarm.snoozeCount + 1
                AlarmEventStore.shared.save(snoozed)
                let snoozeDate = Date().addingTimeInterval(RingingViewModel.snoozeInterval)
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
            Task { @MainActor in
                PresentedAlarmStore.shared.markPresented(alarmKitUUID)
                router.ringingAlarm = alarm
            }
        }
    }

    @MainActor
    private func completeAlarmFromNotification(_ alarm: AlarmEvent, router: AppRouter) async {
        print("✅ [ADHDAlarmApp/completeAlarmFromNotification] 開始 alarmID=\(alarm.id) remoteEventId=\(alarm.remoteEventId ?? "nil")")
        let scheduler = AlarmKitScheduler()
        let calendarProvider = AppleCalendarProvider()
        let alarmKitIDs = !alarm.alarmKitIdentifiers.isEmpty
            ? alarm.alarmKitIdentifiers
            : [alarm.alarmKitIdentifier].compactMap { $0 }

        for id in alarmKitIDs {
            HandledAlarmStore.shared.markHandled(id)
        }

        var completed = alarm
        completed.completionStatus = .completed
        AlarmEventStore.shared.save(completed)
        print("✅ [ADHDAlarmApp/completeAlarmFromNotification] ローカル完了保存")
        // 家族モードでは XP を付与しない（誤登録アラームの副作用を防ぐ）
        if appState.appMode == .person {
            appState.addXP(10)
        }

        if let remoteEventId = alarm.remoteEventId {
            print("🔄 [ADHDAlarmApp/completeAlarmFromNotification] remote へ completed 送信開始 eventID=\(remoteEventId)")
            Task {
                await OfflineActionQueue.shared.sendOrEnqueueStatusUpdate(
                    eventID: remoteEventId,
                    status: "completed"
                )
            }
        } else {
            print("⚠️ [ADHDAlarmApp/completeAlarmFromNotification] remoteEventId が nil のため送信スキップ")
        }

        if !alarmKitIDs.isEmpty {
            try? await scheduler.cancelAll(alarmKitIDs: alarmKitIDs)
        }

        if let ekID = alarm.eventKitIdentifier {
            try? await calendarProvider.deleteEvent(eventKitIdentifier: ekID)
        }

        if router.ringingAlarm?.id == alarm.id {
            router.ringingAlarm = nil
        }
    }

    @ViewBuilder
    private func destinationView(for destination: OnboardingDestination) -> some View {
        switch destination {
        case .personWelcome:    PersonWelcomeView()
        case .permissionsCTA:   PermissionsCTAView()
        case .owlNaming:        OwlNamingView()
        case .magicDemoWarning: MagicDemoWarningView()
        case .magicDemo:        MagicDemoView()
        case .widgetGuide:      WidgetGuideView()
        }
    }
}
