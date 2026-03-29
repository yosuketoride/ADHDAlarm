# Phase 1 実装計画書：土台（デザイントークン・AppState・ルーティング）

## このフェーズの完成基準

- [ ] アプリがビルド・起動する
- [ ] ModeSelectionView が表示される（当事者/家族カードが2枚見える）
- [ ] モード選択 → PersonHomeView（プレースホルダー）/ FamilyHomeView（プレースホルダー）に遷移できる
- [ ] 既存ユーザー（`isOnboardingComplete == true`）は ModeSelectionView をスキップしてホームへ直行する
- [ ] AlarmKit 発火時に RingingView がフルスクリーンで表示される（既存コードそのまま動く）
- [ ] Xcode の strict concurrency（`SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`）ビルドエラーゼロ

---

## 変更ファイル一覧

| # | 操作 | ファイルパス | 理由 |
|---|------|------------|------|
| 1 | 書き換え | `ADHDAlarm/Extensions/Color+Theme.swift` | 仕様書トークン（owlAmber等）に差し替え |
| 2 | 新規作成 | `ADHDAlarm/Extensions/Spacing+Theme.swift` | Spacing/ComponentSize/CornerRadius/BorderWidth/IconSize |
| 3 | 追記のみ | `ADHDAlarm/App/Constants.swift` | 新 UserDefaults キー（owlName/owlXP/owlStage）追加 |
| 4 | 書き換え | `ADHDAlarm/App/AppState.swift` | appMode/owlName/owlXP/owlStage/navigationPath を追加 |
| 5 | 書き換え | `ADHDAlarm/App/AppRouter.swift` | NavigationPath ベースに変更、ringingAlarm は維持 |
| 6 | 書き換え | `ADHDAlarm/ADHDAlarmApp.swift` | RootView を NavigationStack ベースに変更 |
| 7 | 新規作成 | `ADHDAlarm/Views/Onboarding/ModeSelectionView.swift` | 新オンボーディング起点 |
| 8 | 新規作成 | `ADHDAlarm/Views/Dashboard/PersonHomeView.swift` | プレースホルダー（Phase 2 で肉付け） |
| 9 | 新規作成 | `ADHDAlarm/Views/Family/FamilyHomeView.swift` | プレースホルダー（Phase 4 で肉付け） |

## 触らないファイル（Phase 1 では一切変更しない）

```
ADHDAlarm/Models/           ← 全ファイル変更なし
ADHDAlarm/Protocols/        ← 全ファイル変更なし
ADHDAlarm/Services/         ← 全ファイル変更なし
ADHDAlarm/AppIntents/       ← 全ファイル変更なし
ADHDAlarm/Extensions/Date+Formatting.swift
ADHDAlarm/Views/Alarm/RingingView.swift        ← Phase 2 で改修
ADHDAlarm/ViewModels/RingingViewModel.swift    ← Phase 2 で改修
```

## 古いファイルの扱い（削除せず放置・Phase 2 で整理）

以下のファイルは Phase 1 終了後は「参照されない Dead code」になる。ビルドエラーにはならない（クラス定義が残るだけ）。削除は Phase 2 の最初のタスクとして行う。

```
Views/Main/MainTabView.swift        （タブ構造 → 廃止）
Views/Main/AlarmListTab.swift
Views/Main/VoiceInputTab.swift
Views/Main/SettingsTab.swift
Views/Dashboard/DashboardView.swift （PersonHomeView に置き換わる）
Views/Onboarding/OnboardingContainerView.swift
Views/Onboarding/HookView.swift
```

---

## 実装詳細

### 1. `Extensions/Color+Theme.swift`（書き換え）

```swift
// ⚠️ 旧ファイルを全削除して以下で上書きする
import SwiftUI

extension Color {
    // ── ブランドカラー ──────────────────────────────────
    static let owlAmber     = Color(hex: "#F5A623")  // ライトモード
    static let owlAmberDark = Color(hex: "#F7B544")  // ダークモード（+10%明度）
    static let owlBrown     = Color(hex: "#8B5E3C")  // ライトモード
    static let owlBrownDark = Color(hex: "#A87850")  // ダークモード（+15%明度）

    // ── ステータスカラー ────────────────────────────────
    static let statusSuccess  = Color(hex: "#34C759")
    static let statusWarning  = Color(hex: "#FF9500")
    static let statusDanger   = Color(hex: "#FF3B30")
    static let statusPending  = Color(hex: "#007AFF")
    static let statusSkipped  = Color(hex: "#8E8E93")

    // ── XP・成長カラー ──────────────────────────────────
    static let xpGold = Color(hex: "#FFD700")

    // ── 時間帯オーバーレイ（必ず opacity 指定で使う）──────
    static let morning   = Color(hex: "#87CEEB")  // 朝  05:00-10:59  .opacity(0.12)
    static let afternoon = Color(hex: "#FFF9C4")  // 昼  11:00-16:59  .opacity(0.10)
    static let evening   = Color(hex: "#FFB347")  // 夕  17:00-20:59  .opacity(0.13)
    static let night     = Color(hex: "#4B5EA3")  // 夜  21:00-04:59  .opacity(0.16)

    // ── ヘルパー（16進数文字列からColorを作る）─────────────
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let r = Double((int >> 16) & 0xFF) / 255
        let g = Double((int >>  8) & 0xFF) / 255
        let b = Double((int      ) & 0xFF) / 255
        self.init(red: r, green: g, blue: b)
    }
}
```

**⚠️ 注意:** 旧ファイルの `themeBackground`, `alarmRed` 等は削除する。
使用箇所（RingingView 等）が残っていたら `statusDanger`, `.systemBackground` 等に置換する。

---

### 2. `Extensions/Spacing+Theme.swift`（新規作成）

```swift
import CoreGraphics

// ── スペーシング（4pt grid）──────────────────────────────
enum Spacing {
    static let xs: CGFloat =  4
    static let sm: CGFloat =  8
    static let md: CGFloat = 16
    static let lg: CGFloat = 24
    static let xl: CGFloat = 32
}

// ── コンポーネントサイズ ──────────────────────────────────
enum ComponentSize {
    static let eventRow:      CGFloat = 64   // EventRow 最小高さ
    static let fab:           CGFloat = 72   // マイクFAB（正方形）
    static let templateCard:  CGFloat = 80   // 家族送信テンプレートカード
    static let settingRow:    CGFloat = 52   // 設定行の高さ
    static let inputField:    CGFloat = 52   // テキスト入力フィールド
    static let small:         CGFloat = 44   // Apple HIG 最小タップターゲット
    static let primary:       CGFloat = 56   // プライマリボタン（全画面共通）
    static let actionGiant:   CGFloat = 72   // RingingView 完了ボタン専用
    static let toggleChip:    CGFloat = 36   // トグルチップス（事前通知プリセット等）
}

// ── コーナー半径 ──────────────────────────────────────────
enum CornerRadius {
    static let sm:    CGFloat = 8
    static let md:    CGFloat = 12
    static let lg:    CGFloat = 16
    static let input: CGFloat = 10
    static let fab:   CGFloat = 36
    static let pill:  CGFloat = .infinity
}

// ── ボーダー幅 ────────────────────────────────────────────
enum BorderWidth {
    static let thin:  CGFloat = 1
    static let thick: CGFloat = 2
}

// ── アイコンサイズ ────────────────────────────────────────
enum IconSize {
    static let sm: CGFloat = 20
    static let md: CGFloat = 24
    static let lg: CGFloat = 28   // EventRow 絵文字・テンプレートカード
    static let xl: CGFloat = 56   // 権限プリプロンプト等の大アイコン
}
```

---

### 3. `App/Constants.swift`（追記のみ）

`Keys` enum に以下を追記する（既存キーはそのまま残す）:

```swift
// 追記箇所: Keys enum の末尾
static let owlName   = "owl_name"
static let owlXP     = "owl_xp"
static let owlStage  = "owl_stage"
```

---

### 4. `App/AppState.swift`（書き換え）

**方針:** 既存の全プロパティを維持しつつ、新プロパティを追加する。
UserDefaults キーは既存のものを変更しない（ユーザーデータの継続性を保つ）。

```swift
import Foundation
import Observation

/// アプリ全体のグローバル状態
/// @Observable により依存する View が自動的に再描画される
/// ⚠️ AppState 肥大化防止ルール（仕様書 00_Root_Concept.md 参照）:
///    複数の View が同時に参照 & ナビゲーションに影響する & アプリ全体で1つだけ、の条件を満たすものだけ追加する
@Observable @MainActor
final class AppState {

    // MARK: - モード選択（新規）
    /// 当事者（.person）か家族（.family）か。初回のみModeSelectionViewで選択
    var appMode: AppMode? {
        didSet {
            UserDefaults.standard.set(appMode?.rawValue, forKey: Constants.Keys.appMode)
        }
    }

    // MARK: - ふくろう育成（新規）
    var owlName: String {
        didSet { UserDefaults.standard.set(owlName, forKey: Constants.Keys.owlName) }
    }
    var owlXP: Int {
        didSet { UserDefaults.standard.set(owlXP, forKey: Constants.Keys.owlXP) }
    }
    /// 0=ひよこ 1=こふくろう 2=ふくろう 3=ふくろう長老
    var owlStage: Int {
        didSet { UserDefaults.standard.set(owlStage, forKey: Constants.Keys.owlStage) }
    }

    // MARK: - ナビゲーション（新規）
    /// 当事者モードの NavigationPath
    var personNavigationPath = NavigationPath()
    /// 家族モードの NavigationPath
    var familyNavigationPath = NavigationPath()
    /// シート全閉じフラグ（ディープリンク遷移時に使用）
    var dismissAllSheets = false

    // MARK: - オンボーディング（既存・維持）
    var isOnboardingComplete: Bool {
        didSet { UserDefaults.standard.set(isOnboardingComplete, forKey: Constants.Keys.onboardingComplete) }
    }

    // MARK: - サブスクリプション（既存・維持）
    var subscriptionTier: SubscriptionTier {
        didSet {
            UserDefaults.standard.set(subscriptionTier.rawValue, forKey: Constants.Keys.subscriptionTier)
            UserDefaults(suiteName: Constants.appGroupID)?.set(subscriptionTier.rawValue, forKey: Constants.Keys.subscriptionTier)
        }
    }

    // MARK: - 設定（既存・維持）
    var voiceCharacter: VoiceCharacter {
        didSet {
            UserDefaults.standard.set(voiceCharacter.rawValue, forKey: Constants.Keys.voiceCharacter)
            UserDefaults(suiteName: Constants.appGroupID)?.set(voiceCharacter.rawValue, forKey: Constants.Keys.voiceCharacter)
        }
    }
    var preNotificationMinutesList: Set<Int> {
        didSet {
            let arr = Array(preNotificationMinutesList)
            UserDefaults.standard.set(arr, forKey: Constants.Keys.preNotificationMinutesList)
            UserDefaults(suiteName: Constants.appGroupID)?.set(arr, forKey: Constants.Keys.preNotificationMinutesList)
        }
    }
    var preNotificationMinutes: Int { preNotificationMinutesList.max() ?? 15 }
    var selectedCalendarID: String? {
        didSet {
            UserDefaults.standard.set(selectedCalendarID, forKey: Constants.Keys.selectedCalendarID)
            UserDefaults(suiteName: Constants.appGroupID)?.set(selectedCalendarID, forKey: Constants.Keys.selectedCalendarID)
        }
    }
    var isAccessibilityModeEnabled: Bool {
        didSet { UserDefaults.standard.set(isAccessibilityModeEnabled, forKey: Constants.Keys.accessibilityModeEnabled) }
    }
    var notificationType: NotificationType {
        didSet { UserDefaults.standard.set(notificationType.rawValue, forKey: Constants.Keys.notificationType) }
    }
    var audioOutputMode: AudioOutputMode {
        didSet { UserDefaults.standard.set(audioOutputMode.rawValue, forKey: Constants.Keys.audioOutputMode) }
    }
    var micInputMode: MicInputMode {
        didSet { UserDefaults.standard.set(micInputMode.rawValue, forKey: Constants.Keys.micInputMode) }
    }

    // MARK: - 見守り（既存・維持）
    var sosPairingId: String? {
        didSet { UserDefaults.standard.set(sosPairingId, forKey: Constants.Keys.sosPairingId) }
    }
    var sosEscalationMinutes: Int {
        didSet { UserDefaults.standard.set(sosEscalationMinutes, forKey: Constants.Keys.sosEscalationMinutes) }
    }

    // MARK: - 家族リモートスケジュール（既存・維持）
    var familyLinkId: String? {
        didSet { UserDefaults.standard.set(familyLinkId, forKey: Constants.Keys.familyLinkId) }
    }
    var familyChildLinkIds: [String] {
        didSet { UserDefaults.standard.set(familyChildLinkIds, forKey: Constants.Keys.familyChildLinkIds) }
    }
    var unreadFamilyEventCount: Int {
        didSet { UserDefaults.standard.set(unreadFamilyEventCount, forKey: Constants.Keys.unreadFamilyEventCount) }
    }

    // MARK: - 初期化
    init() {
        let d = UserDefaults.standard
        // 新プロパティ
        self.appMode    = AppMode(rawValue: d.string(forKey: Constants.Keys.appMode) ?? "")
        self.owlName    = d.string(forKey: Constants.Keys.owlName) ?? "ふくろう"
        self.owlXP      = d.integer(forKey: Constants.Keys.owlXP)
        self.owlStage   = d.integer(forKey: Constants.Keys.owlStage)
        // 既存プロパティ（キーは変更しない）
        self.isOnboardingComplete = d.bool(forKey: Constants.Keys.onboardingComplete)
        self.subscriptionTier     = SubscriptionTier(rawValue: d.string(forKey: Constants.Keys.subscriptionTier) ?? "") ?? .free
        self.voiceCharacter       = VoiceCharacter(rawValue: d.string(forKey: Constants.Keys.voiceCharacter) ?? "") ?? .femaleConcierge
        if let arr = d.array(forKey: Constants.Keys.preNotificationMinutesList) as? [Int], !arr.isEmpty {
            self.preNotificationMinutesList = Set(arr)
        } else {
            let legacy = d.integer(forKey: Constants.Keys.preNotificationMinutes)
            self.preNotificationMinutesList = [legacy == 0 ? 15 : legacy]
        }
        self.selectedCalendarID        = d.string(forKey: Constants.Keys.selectedCalendarID)
        self.isAccessibilityModeEnabled = d.bool(forKey: Constants.Keys.accessibilityModeEnabled)
        self.notificationType  = NotificationType(rawValue: d.string(forKey: Constants.Keys.notificationType) ?? "") ?? .alarmAndVoice
        self.audioOutputMode   = AudioOutputMode(rawValue: d.string(forKey: Constants.Keys.audioOutputMode) ?? "") ?? .automatic
        self.micInputMode      = MicInputMode(rawValue: d.string(forKey: Constants.Keys.micInputMode) ?? "") ?? .tapToggle
        self.sosPairingId      = d.string(forKey: Constants.Keys.sosPairingId)
        self.sosEscalationMinutes = d.object(forKey: Constants.Keys.sosEscalationMinutes) == nil ? 5 : d.integer(forKey: Constants.Keys.sosEscalationMinutes)
        self.familyLinkId      = d.string(forKey: Constants.Keys.familyLinkId)
        self.familyChildLinkIds = d.stringArray(forKey: Constants.Keys.familyChildLinkIds) ?? []
        self.unreadFamilyEventCount = d.integer(forKey: Constants.Keys.unreadFamilyEventCount)
    }

    // MARK: - ナビゲーションヘルパー
    /// ディープリンク遷移時: 表示中の全シートを閉じる
    func dismissAllSheetsNow() {
        dismissAllSheets = true
        // 1フレーム後に false に戻す（.onChange で検知するため）
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 16_000_000)
            dismissAllSheets = false
        }
    }
}
```

---

### 5. `App/AppRouter.swift`（書き換え）

```swift
import Foundation
import Observation

/// アラーム発火の監視とRingingView表示を担当する軽量コーディネーター
/// ナビゲーション管理は AppState.personNavigationPath / familyNavigationPath に委譲
@Observable @MainActor
final class AppRouter {

    /// AlarmKit 発火中のアラーム（非nil のとき RingingView をフルスクリーン表示）
    var ringingAlarm: AlarmEvent?

    init() {}
}
```

**⚠️ 注意:** 旧 `AppRouter` にあった `currentDestination`, `selectedTab`, `completeOnboarding()` は削除する。
これらは AppState の `isOnboardingComplete` + `appMode` で代替する。

---

### 6. `ADHDAlarmApp.swift`（書き換え）

```swift
import SwiftUI
import AlarmKit
import AppIntents
import UserNotifications

@main
struct ADHDAlarmApp: App {
    @State private var appState = AppState()
    @State private var appRouter = AppRouter()
    @State private var storeKit = StoreKitService()
    @Environment(\.scenePhase) private var scenePhase

    private let syncEngine         = SyncEngine()
    private let permissionsService = PermissionsService()

    init() {
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
                .task { await watchAlarmUpdates() }
                .onOpenURL { url in handleOpenURL(url) }
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                permissionsService.refreshStatuses()
                Task {
                    await syncEngine.performFullSync()
                    let newCount = await syncEngine.syncRemoteEvents()
                    if newCount > 0 {
                        await MainActor.run { appState.unreadFamilyEventCount += newCount }
                    }
                }
            }
        }
    }

    // MARK: - 起動時処理
    private func startupTasks() async {
        async let isPro   = storeKit.checkEntitlement()
        async let _: Void = storeKit.loadProducts()
        if await isPro { appState.subscriptionTier = .pro }
        VoiceMemoAlarmShortcuts.updateAppShortcutParameters()
        await permissionsService.requestNotification()
    }

    // MARK: - URL Scheme ハンドラ
    private func handleOpenURL(_ url: URL) {
        guard url.scheme == "adhdalarm" else { return }
        // Phase 1: 最低限の実装。詳細は Phase 2 で対応
        if url.host == "alarm" {
            // アラーム詳細へのディープリンク
        }
    }

    // MARK: - AlarmKit 発火監視
    private func watchAlarmUpdates() async {
        for await alarms in AlarmManager.shared.alarmUpdates {
            guard let alertingAlarm = alarms.first(where: { $0.state == .alerting }) else { continue }

            // すでに同じアラームを表示中なら重複スキップ
            if appRouter.ringingAlarm?.alarmKitIdentifiers.contains(alertingAlarm.id) == true ||
               appRouter.ringingAlarm?.alarmKitIdentifier == alertingAlarm.id { continue }

            let foundEvent = AlarmEventStore.shared.find(alarmKitID: alertingAlarm.id)
            var alarmToDisplay = foundEvent ?? AlarmEvent(
                id: UUID(), title: "アラーム", fireDate: Date(),
                alarmKitIdentifier: alertingAlarm.id
            )
            if let mappedMinutes = foundEvent?.alarmKitMinutesMap[alertingAlarm.id.uuidString] {
                alarmToDisplay.preNotificationMinutes = mappedMinutes
            }
            await MainActor.run { appRouter.ringingAlarm = alarmToDisplay }
        }
    }
}

// MARK: - RootView

struct RootView: View {
    @Environment(AppState.self)  private var appState
    @Environment(AppRouter.self) private var appRouter

    var body: some View {
        Group {
            if !appState.isOnboardingComplete || appState.appMode == nil {
                // 初回: ModeSelectionView を起点にオンボーディング
                ModeSelectionView()
            } else if appState.appMode == .person {
                // 当事者ホーム（Phase 2 で肉付け）
                PersonHomeView()
            } else {
                // 家族ホーム（Phase 4 で肉付け）
                FamilyHomeView()
            }
        }
        .dynamicTypeSize(...DynamicTypeSize.accessibility1)
        // AlarmKit 発火時にフルスクリーンで RingingView を表示
        .fullScreenCover(item: Binding(
            get: { appRouter.ringingAlarm },
            set: { appRouter.ringingAlarm = $0 }
        )) { alarm in
            RingingView(alarm: alarm) {
                appRouter.ringingAlarm = nil
            }
        }
    }
}
```

---

### 7. `Views/Onboarding/ModeSelectionView.swift`（新規作成）

**仕様書根拠:** 01_Screen_Flow.md §10-2

```swift
import SwiftUI

struct ModeSelectionView: View {
    @Environment(AppState.self) private var appState
    @State private var selectedMode: AppMode? = nil

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            // ふくろうイメージ（160pt）
            Image(systemName: "bird.fill")  // ⚠️ Phase 2 でアセット画像に差し替え
                .resizable()
                .scaledToFit()
                .frame(height: 160)
                .foregroundStyle(Color.owlAmber)

            Spacer().frame(height: Spacing.lg)  // 24pt

            Text("どなたがお使いですか？")
                .font(.title2).bold()
                .multilineTextAlignment(.center)

            Spacer().frame(height: Spacing.md)  // 16pt

            // モードカード（2枚横並び）
            HStack(spacing: Spacing.md) {
                ModeCard(
                    icon: "person.fill",
                    title: "自分で使う",
                    subtitle: "ADHD・高齢者本人",
                    isSelected: selectedMode == .person
                ) { selectedMode = .person }

                ModeCard(
                    icon: "figure.2.and.child.holdinghands",
                    title: "家族の見守り",
                    subtitle: "離れて暮らす家族",
                    isSelected: selectedMode == .family
                ) { selectedMode = .family }
            }
            .padding(.horizontal, Spacing.md)  // 16pt

            Spacer()

            // 確定ボタン
            Button {
                guard let mode = selectedMode else { return }
                appState.appMode = mode
                if appState.isOnboardingComplete {
                    // 既存ユーザー: オンボーディングスキップ
                    // RootView の条件分岐が自動で切り替わる
                } else {
                    // 初回: 次のオンボーディング画面へ（Phase 3 で実装）
                    // 今は isOnboardingComplete を立てて直接ホームへ
                    appState.isOnboardingComplete = true
                }
            } label: {
                Text(appState.isOnboardingComplete ? "この設定で使う" : "🦉 はじめる")
                    .font(.body).bold()
                    .frame(maxWidth: .infinity)
                    .frame(height: ComponentSize.primary)  // 56pt
            }
            .buttonStyle(.borderedProminent)
            .tint(Color.owlAmber)
            // 選択前はボタンを無効化
            .disabled(selectedMode == nil)
            .padding(.horizontal, Spacing.md)   // 16pt
            .padding(.bottom, Spacing.xl)        // 32pt
        }
        // 初期値: 既存ユーザーなら現在のモードをデフォルト選択
        .onAppear {
            if let current = appState.appMode {
                selectedMode = current
            }
        }
    }
}

// MARK: - モード選択カード

private struct ModeCard: View {
    let icon: String
    let title: String
    let subtitle: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: Spacing.sm) {  // 8pt
                Image(systemName: icon)
                    .font(.system(size: IconSize.xl))  // 56pt
                    .foregroundStyle(isSelected ? .black : Color.owlAmber)

                Text(title)
                    .font(.headline)
                    .foregroundStyle(.primary)

                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 100)
            .background(
                RoundedRectangle(cornerRadius: CornerRadius.lg)  // 16pt
                    .fill(isSelected ? Color.owlAmber : Color(.secondarySystemBackground))
            )
            .overlay(
                RoundedRectangle(cornerRadius: CornerRadius.lg)
                    .strokeBorder(
                        isSelected ? Color.owlAmber : Color(.separator),
                        lineWidth: isSelected ? BorderWidth.thick : BorderWidth.thin
                    )
            )
        }
        .contentShape(Rectangle())
    }
}

#Preview {
    ModeSelectionView()
        .environment(AppState())
}
```

---

### 8. `Views/Dashboard/PersonHomeView.swift`（新規・プレースホルダー）

```swift
import SwiftUI

/// 当事者ホーム画面（Phase 2 で本実装）
struct PersonHomeView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        ZStack {
            Color(.systemBackground).ignoresSafeArea()

            VStack(spacing: Spacing.lg) {
                Image(systemName: "bird.fill")
                    .font(.system(size: 80))
                    .foregroundStyle(Color.owlAmber)

                Text("\(appState.owlName)のホーム")
                    .font(.title2).bold()

                Text("Phase 2 で実装予定")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

#Preview {
    PersonHomeView()
        .environment(AppState())
}
```

---

### 9. `Views/Family/FamilyHomeView.swift`（新規・プレースホルダー）

```swift
import SwiftUI

/// 家族ホーム画面（Phase 4 で本実装）
struct FamilyHomeView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        ZStack {
            Color(.systemBackground).ignoresSafeArea()

            VStack(spacing: Spacing.lg) {
                Image(systemName: "figure.2.and.child.holdinghands")
                    .font(.system(size: 60))
                    .foregroundStyle(Color.owlAmber)

                Text("家族ホーム")
                    .font(.title2).bold()

                Text("Phase 4 で実装予定")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

#Preview {
    FamilyHomeView()
        .environment(AppState())
}
```

---

## ビルドが通らない場合のチェックリスト

Phase 1 で起きやすいビルドエラーと対処法:

| エラー | 原因 | 対処 |
|--------|------|------|
| `'themeBackground' is not a member of 'Color'` | 旧 Color+Theme を使っているファイルが残っている | 旧参照を `.systemBackground` 等に置換 |
| `'currentDestination' is not a member of 'AppRouter'` | 旧 AppRouter のプロパティを参照しているファイル | Dead code なので `// TODO` コメントアウトか削除 |
| `'selectedTab' is not a member of 'AppRouter'` | 同上 | 同上 |
| `Sending 'syncEngine' risks causing data races` | SyncEngine が actor 未定義 | `Services/SyncEngine.swift` を `actor SyncEngine` に変更（Phase 1 スコープ内） |
| `Type 'AppState' does not conform to 'Sendable'` | @Observable + @MainActor の組み合わせ | クラス宣言に `@MainActor` が付いているか確認 |

---

## SyncEngine の actor 化（strict concurrency 対応）

ビルドエラーになった場合のみ対応する。`Services/SyncEngine.swift` の先頭行を変更:

```swift
// 変更前
final class SyncEngine {

// 変更後
actor SyncEngine {
```

`actor` に変えると外部から `await` が必要になる。`ADHDAlarmApp.swift` での呼び出しはすでに `await` を使っているので問題なし。他の呼び出し箇所（`DashboardView` 等）は Phase 2 で対応（今は Dead code）。

---

## Phase 1 完了後の確認手順

1. **シミュレーター起動 → ModeSelectionView が表示されること**
2. **「自分で使う」選択 → 「🦉 はじめる」タップ → PersonHomeView（プレースホルダー）が表示されること**
3. **「家族の見守り」選択 → FamilyHomeView（プレースホルダー）が表示されること**
4. **アプリを再起動 → ModeSelectionView をスキップして直接ホームが表示されること**（isOnboardingComplete 保持）
5. **Xcode Build > Product > Build（⌘B）でビルド警告ゼロであること**

---

## 次のフェーズへの前提条件

Phase 2（PersonHomeView 本実装）を開始するには以下が満たされていること:

- [ ] AppState に `owlName`, `owlXP`, `owlStage` が存在している
- [ ] `Color.owlAmber`, `Spacing.md`, `ComponentSize.primary` 等のトークンが使える
- [ ] `NavigationPath` が `appState.personNavigationPath` に存在している
- [ ] `PersonHomeView` が表示される状態になっている（プレースホルダーでも可）
