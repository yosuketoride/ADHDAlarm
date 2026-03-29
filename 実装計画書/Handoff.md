# 引き継ぎ資料（Gemini / 別AIへの引き継ぎ用）

> 最終更新: 2026-03-29
> Phase 1〜3 実装: Claude Sonnet 4.6
> Phase 4〜5 実装予定: Claude Sonnet 4.6
> Phase 6〜7 実装予定: Antigravity（Gemini Pro）

---

## 1. 現在のブランチ・コミット状況

```
ブランチ: main
最新コミット: cdf5d2b - fix: レビュー指摘修正（Phase 2 品質改善）

タグ: v1-release （v1 完成版・保護済み）
```

**main ブランチ上で作業している。破壊的な変更は必ずビルド確認してからコミットすること。**

---

## 2. 確立した設計判断（絶対に逆行させないこと）

### 2-1. ルーティング: NavigationPath ベース（タブレス）

```swift
// ADHDAlarmApp.swift の RootView
if !appState.isOnboardingComplete || appState.appMode == nil {
    ModeSelectionView()
} else if appState.appMode == .person {
    PersonHomeView()
} else {
    FamilyHomeView()
}
```

- **MainTabView は廃止済み**（Views/Main/ フォルダごと削除済み）
- タブ構造に戻してはいけない
- `AppRouter` は `ringingAlarm: AlarmEvent?` のみを持つ

### 2-2. 並行処理: actor SyncEngine

```swift
// Services/SyncEngine.swift
actor SyncEngine {  // ← final class から変更済み
```

- `final class` に戻すと `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor` 環境でデータ競合エラーが出る
- **絶対に `final class` に戻さない**

### 2-3. @Observable @MainActor（ObservableObject 禁止）

```swift
// すべての ViewModel はこのパターンを使う
@Observable @MainActor
final class XxxViewModel { ... }
```

- `ObservableObject` / `@Published` は使わない
- `@StateObject` / `@ObservedObject` は使わない
- View から参照する場合: `@Environment(XxxViewModel.self)` or `@State private var vm = XxxViewModel()`

**例外: `RingingViewModel` は `NSObject` 継承（AVAudioPlayerDelegate 等のため）なので `@MainActor` をクラスに付けず、必要なメソッドにだけ付ける**

### 2-4. async/await のみ（Completion handler 禁止）

```swift
// ✅ これを使う
func loadEvents() async { ... }

// ❌ これは書かない
func loadEvents(completion: @escaping ([AlarmEvent]) -> Void) { ... }
```

### 2-5. デザイントークン（マジックナンバー禁止）

```swift
// Extensions/Spacing+Theme.swift に定義済み
Spacing.xs/sm/md/lg/xl
ComponentSize.eventRow/fab/primary/actionGiant/toggleChip/small/settingRow/inputField/templateCard
CornerRadius.sm/md/lg/input/fab/pill
BorderWidth.thin/thick
IconSize.sm/md/lg/xl

// Extensions/Color+Theme.swift に定義済み
Color.owlAmber / .owlBrown / .statusSuccess / .statusDanger / .statusSkipped / ...
Color.morning / .afternoon / .evening / .night  // 時間帯背景色
```

- 数値リテラル（16pt, 72pt 等）を直接書かない

---

## 3. Phase 3 で確立した設計（Phase 3〜以降で必ず守ること）

### 3-1. CompletionStatus（アラーム完了状態）

```swift
// Models/AlarmEvent.swift
enum CompletionStatus: String, Codable {
    case completed  // ユーザーが「とめる」を押した
    case skipped    // ユーザーが「スキップ」を選んだ
}

struct AlarmEvent {
    var completionStatus: CompletionStatus?  // nil = 未対応 or 後方互換プロキシ
}
```

**判定ルール（PersonHomeViewModel）:**
```swift
// 未完了 = completionStatus が nil かつ fireDate が未来
incompleteTodayEvents = events.filter { $0.completionStatus == nil && $0.fireDate >= Date() }

// 完了済み = completionStatus が設定済み、または fireDate 過去（後方互換）
completedTodayEvents = events.filter { $0.completionStatus != nil || $0.fireDate < Date() }
```

### 3-2. XP システム（暫定実装・Phase 8 で正式化）

RingingViewModel と PersonHomeViewModel の両方が UserDefaults に直書きしている。

```swift
// 使用するキー
Constants.Keys.owlXP  // = "owl_xp"
"owl_xp_today"        // Constants に未定義（Phase 8 で追加予定）

// XP 付与タイミング
dismiss() → +10 XP（完了）
skip()    → +3 XP（スキップ）
```

Phase 8 で `AppState.owlXP` と同期させること。`AppState.init()` は起動時に `UserDefaults.standard.integer(forKey: "owl_xp")` を読むので、UserDefaults 直書きでも次回起動時には反映される。

### 3-3. RingingView のスキップフロー

```
onAppear → 5秒後 → showSkipSection = true → スキップボタン表示
スキップタップ → viewModel.skip() → isSkipped = true → showDismissMessage = true
dismissView → isSkipped に応じてメッセージを切り替え
```

---

## 4. Dead code・削除済みファイル

### 削除済み（Phase 1〜2 で Xcode から削除）
```
ADHDAlarm/Views/Main/          ← フォルダごと削除済み
ADHDAlarm/Views/Dashboard/DashboardView.swift        ← 削除済み
ADHDAlarm/Views/Onboarding/OnboardingContainerView.swift ← 削除済み
ADHDAlarm/Views/Onboarding/HookView.swift            ← 削除済み
```

### 削除待ち（まだ残っている・参照しないこと）
```
ADHDAlarm/ViewModels/DashboardViewModel.swift  ← Phase 8 で削除
ADHDAlarm/Views/Dashboard/NextAlarmCard.swift  ← Phase 3 で整理予定（未着手）
ADHDAlarm/Views/Dashboard/WidgetStatusBanner.swift ← Phase 6 で整理
```

---

## 5. Phase 別タスク状況

### Phase 3: 完了 ✅

- [x] `AlarmEvent.completionStatus` フィールド追加（`.completed` / `.skipped`）
- [x] `RingingViewModel.dismiss()` → `.completed` 永続化 + XP +10
- [x] `RingingViewModel.skip()` 追加 → `.skipped` 永続化 + XP +3
- [x] `RingingView` スキップボタン（5秒後表示）追加
- [x] `RingingView` 停止ボタン高さ → `ComponentSize.actionGiant`（72pt）
- [x] `PersonHomeViewModel` の完了判定を `completionStatus` ベースに更新

**未着手（Phase 3 当初のスコープだが後回し）:**
- [ ] EventKit への Write-Through（`AppleCalendarProvider.writeEvent()`）
- [ ] AlarmKit スケジューリング完全実装
- [ ] PermissionsService 完全実装

### Phase 4: 未着手（Claude が実装予定）

仕様書参照: `仕様書/01_Screen_Flow.md` STEP 10

- [ ] PersonWelcomeView 実装
- [ ] PermissionsCTAView 実装（既存ファイルあり・v2 仕様に合わせて書き換え）
- [ ] OwlNamingView 実装（`appState.owlName` に書き込む）
- [ ] MagicDemoView 実装（既存ファイルあり・v2 仕様に合わせて書き換え）
- [ ] WidgetGuideView 実装（既存ファイルあり）
- [ ] ModeSelectionView → オンボーディングフロー接続

### Phase 5: 未着手（Claude が実装予定）

仕様書参照: `仕様書/01_Screen_Flow.md` STEP 3〜5, `仕様書/04_Feature_Modules.md`

- [ ] FamilyHomeView 本実装（3タブ: 家族ダッシュボード / 予定送信 / 設定）
- [ ] FamilySendTab（テンプレートカード送信）
- [ ] FamilyPairingView（6桁コード）
- [ ] FamilyInboxBanner 改修

### Phase 6: 未着手（Antigravity が実装予定）← 今すぐ着手可能

仕様書参照: `仕様書/04_Feature_Modules.md` ウィジェットセクション

- [ ] 次の予定を表示するウィジェット（中サイズ）
- [ ] App Group 経由でデータ共有

**Phase 5 完了を待たずに着手できる。AlarmEvent モデルは Phase 3 で安定済み。**

### Phase 7: 未着手（Antigravity が実装予定）← 今すぐ着手可能

仕様書参照: `仕様書/05_Data_Architecture.md`, CLAUDE.md ビジネスモデルセクション

- [ ] PRO課金壁（カレンダー選択・複数事前通知・テーマ）
- [ ] PaywallView 改修（`storeKit` サービスは実装済み）

### Phase 8: 未着手（仕上げ）

- [ ] SettingsView v2 完全版
- [ ] NLParser 絵文字推定（`AlarmEvent.eventEmoji` に自動書き込み）
- [ ] XP の AppState 同期（UserDefaults 直書きを `AppState.owlXP` に統一）
- [ ] Dead code ファイル削除（セクション 4 のリスト）
- [ ] App Store 提出準備

---

## 6. Phase 6（WidgetKit）向け引き継ぎ情報

### 必要な知識

**App Group:**
```swift
// Constants.swift
static let appGroupID = "group.com.yosuke.WasurenboAlarm"

// AlarmEventStore.swift は既に App Group 対応済み
// FileManager.containerURL(forSecurityApplicationGroupIdentifier:) でコンテナを取得
// App Group エンタイトルメントを Widget ターゲットに追加すれば自動で共有される
```

**データの読み方（ウィジェット側）:**
```swift
// AlarmEventStore().loadAll() をそのまま呼ぶ
// alarm_events.json が App Group コンテナに保存されている
let events = AlarmEventStore().loadAll()
let nextEvent = events
    .filter { $0.completionStatus == nil && $0.fireDate > Date() }
    .sorted { $0.fireDate < $1.fireDate }
    .first
```

**ウィジェット更新のトリガー:**
```swift
// PersonHomeViewModel.commitDelete() で既に呼ばれている
WidgetCenter.shared.reloadAllTimelines()
// 予定追加・削除のタイミングでも呼ぶこと
```

**Xcode での手順（コードだけでは完結しない）:**
1. File → New Target → Widget Extension を追加
2. App Group エンタイトルメントを Widget ターゲットと本体ターゲットの両方に追加
3. App Group ID: `group.com.yosuke.WasurenboAlarm`

---

## 7. Phase 7（StoreKit 2）向け引き継ぎ情報

### 既存の実装状況

```swift
// Models/SubscriptionTier.swift
enum SubscriptionTier: String, Codable {
    case free
    case pro
}

// App/AppState.swift
var subscriptionTier: SubscriptionTier  // UserDefaults 永続化済み

// PRO 機能の判定例
if appState.subscriptionTier == .pro {
    // PRO 限定機能
}
```

### PRO 機能の対象（CLAUDE.md より）

| 機能 | 無料 | PRO |
|------|------|-----|
| マナーモード貫通アラーム | ✅ | ✅ |
| カレンダー選択 | ❌ | ✅ |
| 事前通知複数回 | ❌ | ✅ |
| 全テーマ | ❌ | ✅ |
| 全音声キャラ | ❌ | ✅ |

**コア機能（アラームが鳴る）は絶対に課金壁にしない。**

### PaywallView の状態
- `Views/Paywall/PaywallView.swift` が既存（v1 実装）
- v2 デザイントークンに合わせて全面書き換えが必要
- StoreKit サービスクラスは実装済み（詳細は `Services/` フォルダ確認）

---

## 8. CLAUDE.md に書ききれていない暗黙のルール

### AlarmKit 制約
- AlarmKit は **実機のみ動作**（シミュレーター不可）
- ビルドは通るが、シミュレーターでは実際のアラームは鳴らない
- テストは実機で行うこと（`YskのiPhone` または `取出洋介のiPhone`）

### EventKit の注意点
- EventKit の権限確認は **起動時に必ず実行**（`scenePhase == .active`）
- `AppleCalendarProvider` は `@MainActor` で動作する
- アプリ作成イベントの識別: `EKEvent.notes` に `<!-- wasure-bou:{UUID} -->` を埋め込む
  - `Constants.eventMarker(for:)` で生成する

### 既存サービスの状態
- `SyncEngine.swift` の `performFullSync()` と `syncRemoteEvents()` は実装済み
- `AlarmKitScheduler.swift` は大部分が実装済み
- `AppleCalendarProvider.swift` は Read 系は実装済み・Write 系が未完成

### PersonHomeView の ZStack 構造（崩壊させないこと）
```
ZStack(alignment: .bottomTrailing) {
    TimeOfDayBackground()  // レイヤー1
    ScrollView { ... }     // レイヤー2
    micFAB                 // レイヤー3（最前面）
}
```
Toast は `.overlay(alignment: .top)` で追加する。
ZStack に 4 層目を直接追加すると FAB が隠れるバグが起きる。

### ふくろうアセット（未実装）
- 現在は `"OwlIcon"` アセットのみ使用
- Phase 8 で `owl_stage0`〜`owl_stage3` の 4 段階アセットを追加する予定
- `PersonHomeViewModel.owlState` で表示を切り替える準備済み

---

## 9. ファイル構成（Phase 3 完了時点）

```
ADHDAlarm/
├── App/
│   ├── AppState.swift         ✅ 完成（@MainActor, appMode, owlXXX, NavigationPath）
│   ├── AppRouter.swift        ✅ 完成（ringingAlarm のみ）
│   ├── Constants.swift        ✅ 完成（owlName/owlXP/owlStage キー追加済み）
│   └── ForegroundNotificationDelegate.swift  ✅ 変更なし
├── Models/
│   ├── AlarmEvent.swift       ✅ 完成（eventEmoji・completionStatus 追加済み）
│   └── （その他）             ✅ 変更なし
├── Protocols/                 ✅ 変更なし
├── Services/
│   ├── SyncEngine.swift       ✅ actor 化済み
│   ├── AlarmEventStore.swift  ✅ 変更なし（App Group 対応済み）
│   └── （その他）             ✅ 変更なし
├── ViewModels/
│   ├── PersonHomeViewModel.swift  ✅ 完成（completionStatus 対応済み）
│   ├── RingingViewModel.swift     ✅ 完成（dismiss/skip 実装済み）
│   ├── DashboardViewModel.swift   ⚠️ 削除待ち（Phase 8）
│   └── （その他）                 ✅ 変更なし
├── Views/
│   ├── Dashboard/
│   │   ├── PersonHomeView.swift       ✅ 完成
│   │   ├── EventRow.swift             ✅ 完成（絵文字・completionStatus 対応）
│   │   ├── TimeOfDayBackground.swift  ✅ 完成
│   │   ├── NextAlarmCard.swift        ⚠️ Dead code（削除待ち）
│   │   ├── WidgetStatusBanner.swift   ⚠️ Dead code（Phase 6 で整理）
│   │   └── FamilyInboxBanner.swift    ⚠️ Phase 5 で改修
│   ├── Family/
│   │   ├── FamilyHomeView.swift   ⚠️ プレースホルダー（Phase 5 で本実装）
│   │   └── FamilyInputView.swift  ⚠️ Phase 5 で改修
│   ├── Onboarding/
│   │   ├── ModeSelectionView.swift    ✅ 完成
│   │   ├── MagicDemoView.swift        ⚠️ Phase 4 で改修
│   │   ├── PermissionsCTAView.swift   ⚠️ Phase 4 で改修
│   │   └── WidgetGuideView.swift      ⚠️ Phase 4 で改修
│   ├── Alarm/
│   │   └── RingingView.swift          ✅ Phase 3 完成（スキップ対応済み）
│   └── Shared/
│       ├── View+Shake.swift           ✅ 完成
│       └── （その他）                 ✅ 変更なし
├── Extensions/
│   ├── Color+Theme.swift    ✅ 完成（owlAmber/owlBrown/status系/時間帯色）
│   └── Spacing+Theme.swift  ✅ 完成（全デザイントークン）
└── ADHDAlarmApp.swift       ✅ 完成（RootView 条件分岐）
```

---

## 10. ビルド・確認手順

```bash
# ビルド確認
xcodebuild -scheme ADHDAlarm -destination 'platform=iOS Simulator,name=iPhone 17' -quiet

# エラーのみ確認
xcodebuild -scheme ADHDAlarm -destination 'platform=iOS Simulator,name=iPhone 17' -quiet 2>&1 | grep ": error:"
```

シミュレーター `iPhone 17`（OS 26.3.1）が利用可能。
AlarmKit は実機のみ動作するため、アラーム関連の最終確認は実機で行うこと。
