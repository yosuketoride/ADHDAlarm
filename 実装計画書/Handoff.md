# 引き継ぎ資料（Gemini / 別AIへの引き継ぎ用）

> 作成日: 2026-03-29
> 担当: Claude Sonnet 4.6（Phase 1〜2 実装）
> 引き継ぎ先: Gemini Pro（Phase 3〜7 実装予定）

---

## 1. 現在のブランチ・コミット状況

```
ブランチ: v2
最新コミット: 9912955 - feat: Phase 2 PersonHomeView 本実装
前コミット:  bbd9940 - feat: Phase 1 Foundation - デザイントークン・AppState・ルーティング土台

タグ: v1-release （main ブランチ = v1 完成版・保護済み）
```

**v2 ブランチでのみ作業すること。main ブランチには触れない。**

---

## 2. Phase 1〜2 で確立した設計判断（絶対に逆行させないこと）

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

- **MainTabView は廃止済み**（削除は下記 Dead code セクション参照）
- タブ構造に戻してはいけない
- `AppRouter` は `ringingAlarm: AlarmEvent?` のみを持つ（selectedTab / currentDestination は削除済み）

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
ComponentSize.eventRow/fab/primary/actionGiant/...
CornerRadius.sm/md/lg/fab/pill/...
BorderWidth.thin/thick
IconSize.sm/md/lg/xl

// Extensions/Color+Theme.swift に定義済み
Color.owlAmber / .owlBrown / .statusSuccess / .statusDanger / ...
```

- 数値リテラル（16pt, 72pt 等）を直接書かない
- 新しいサイズが必要な場合は既存トークンを使うか、トークンファイルに追加してから使う

---

## 3. Dead code 削除待ちファイル（触ってはいけない・削除するだけ）

以下のファイルは Phase 1〜2 で Dead code になった。コンパイルは通るが、もう使われていない。
**ロジックを参照・流用する前に、削除対象であることを確認すること。**

```
ADHDAlarm/Views/Main/MainTabView.swift         ← 削除待ち
ADHDAlarm/Views/Main/AlarmListTab.swift        ← 削除待ち
ADHDAlarm/Views/Main/VoiceInputTab.swift       ← 削除待ち
ADHDAlarm/Views/Main/SettingsTab.swift         ← 削除待ち
ADHDAlarm/Views/Dashboard/DashboardView.swift  ← 削除待ち
ADHDAlarm/Views/Onboarding/OnboardingContainerView.swift ← 削除待ち
ADHDAlarm/Views/Onboarding/HookView.swift      ← 削除待ち
```

削除する前に `xcodebuild` でビルドが通ることを確認すること。

**DashboardViewModel.swift は削除しない。** PersonHomeViewModel が安定してから Phase 3 以降で対処。

---

## 4. Phase 3〜7 タスク一覧

### Phase 3: AlarmKit + EventKit Write-Through（最重要）

仕様書参照: `仕様書/03_Alarm_Engine.md`

- [ ] `AlarmEvent.completionStatus` フィールド追加（`.completed` / `.skipped` / nil）
  - 現在 Phase 2 は `fireDate < Date()` で代替している
- [ ] EventKit への Write-Through 完全実装（`AppleCalendarProvider.writeEvent()`）
- [ ] AlarmKit スケジューリング完全実装（`AlarmKitScheduler.schedule()`）
- [ ] RingingView 改修（仕様書 STEP 2 RingingView 正規階層に合わせる）
  - `CompleteButton` の高さ: `ComponentSize.actionGiant`（72pt）を使う
  - `SnoozeSkipSection`: 5秒後表示
  - XP付与 (`+10` 完了 / `+3` スキップ)
- [ ] PermissionsService 完全実装

### Phase 4: オンボーディング（PersonWelcome → PermissionsCTA → OwlNaming）

仕様書参照: `仕様書/01_Screen_Flow.md` STEP 10

- [ ] PersonWelcomeView 実装
- [ ] PermissionsCTAView 実装（既存ファイルあり・v2 仕様に合わせて書き換え）
- [ ] OwlNamingView 実装（`appState.owlName` に書き込む）
- [ ] MagicDemoView 実装（既存ファイルあり・v2 仕様に合わせて書き換え）
- [ ] WidgetGuideView 実装（既存ファイルあり）
- [ ] ModeSelectionView → オンボーディングフロー接続

### Phase 5: FamilyHomeView 本実装（家族モード）

仕様書参照: `仕様書/01_Screen_Flow.md` STEP 3〜5, `仕様書/04_Feature_Modules.md`

- [ ] FamilyHomeView 本実装（3タブ: 家族ダッシュボード / 予定送信 / 設定）
- [ ] FamilySendTab（テンプレートカード送信）
- [ ] FamilyPairingView（6桁コード）
- [ ] FamilyInboxBanner 改修

### Phase 6: WidgetKit

仕様書参照: `仕様書/04_Feature_Modules.md` ウィジェットセクション

- [ ] 次の予定を表示するウィジェット（中サイズ）
- [ ] App Group 経由でデータ共有

### Phase 7: StoreKit 2 PRO機能

仕様書参照: `仕様書/05_Data_Architecture.md`, CLAUDE.md ビジネスモデルセクション

- [ ] PRO課金壁（カレンダー選択・複数事前通知・テーマ）
- [ ] PaywallView 改修（`storeKit` サービスは実装済み）

### Phase 8: 設定・仕上げ

- [ ] SettingsView v2 完全版
- [ ] NLParser 絵文字推定（`AlarmEvent.eventEmoji` に自動書き込み）
- [ ] XP の AppState 同期（現在 PersonHomeViewModel は UserDefaults に直書きの暫定実装）
- [ ] Dead code ファイル削除（セクション 3 のリスト）
- [ ] App Store 提出準備

---

## 5. CLAUDE.md に書ききれていない暗黙のルール

### AlarmKit 制約
- AlarmKit は **実機のみ動作**（シミュレーター不可）
- ビルドは通るが、シミュレーターでは実際のアラームは鳴らない
- テストは実機で行うこと

### EventKit の注意点
- EventKit の権限確認は **起動時に必ず実行**（`scenePhase == .active`）
- `AppleCalendarProvider` は `@MainActor` で動作する
- アプリ作成イベントの識別: `EKEvent.notes` に `<!-- wasure-bou:{UUID} -->` を埋め込む
  - `Constants.eventMarker(for:)` で生成する

### 既存サービスの状態
- `SyncEngine.swift` の `performFullSync()` と `syncRemoteEvents()` は実装済み
- `AlarmKitScheduler.swift` は大部分が実装済み（Phase 3 で微調整）
- `AppleCalendarProvider.swift` は Read 系は実装済み・Write 系が未完成

### XP システム（暫定実装）
- Phase 2 では `PersonHomeViewModel.addXP()` が UserDefaults に直書きしている
- Phase 8 で `AppState.owlXP` と同期させること（`owl_xp` / `owl_xp_today` キー）

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

## 6. ファイル構成の現在の状態

```
ADHDAlarm/
├── App/
│   ├── AppState.swift         ✅ v2 完成（@MainActor, appMode, owlXXX, NavigationPath）
│   ├── AppRouter.swift        ✅ v2 完成（ringingAlarm のみ）
│   ├── Constants.swift        ✅ v2 完成（owlName/owlXP/owlStage キー追加済み）
│   └── ForegroundNotificationDelegate.swift  ✅ 変更なし
├── Models/
│   └── AlarmEvent.swift       ✅ v2 完成（eventEmoji 追加済み）
│   └── （その他）             ✅ 変更なし
├── Protocols/                 ✅ 変更なし
├── Services/
│   ├── SyncEngine.swift       ✅ actor 化済み
│   └── （その他）             ✅ 変更なし（Phase 3 で調整）
├── ViewModels/
│   ├── PersonHomeViewModel.swift  ✅ v2 新規作成
│   ├── DashboardViewModel.swift   ⚠️  削除待ち（Phase 3〜）
│   └── （その他）                 ✅ 変更なし（Phase 別に対応）
├── Views/
│   ├── Dashboard/
│   │   ├── PersonHomeView.swift       ✅ v2 完成
│   │   ├── EventRow.swift             ✅ v2 完成（絵文字対応）
│   │   ├── TimeOfDayBackground.swift  ✅ v2 新規作成
│   │   ├── DashboardView.swift        ❌ Dead code（削除待ち）
│   │   ├── NextAlarmCard.swift        ⚠️ Dead code（Phase 3 で整理）
│   │   ├── WidgetStatusBanner.swift   ⚠️ Dead code（Phase 6 で整理）
│   │   └── FamilyInboxBanner.swift    ⚠️ Phase 5 で改修
│   ├── Family/
│   │   ├── FamilyHomeView.swift   ✅ プレースホルダー（Phase 5 で本実装）
│   │   └── FamilyInputView.swift  ⚠️ Phase 5 で改修
│   ├── Onboarding/
│   │   ├── ModeSelectionView.swift    ✅ v2 完成
│   │   ├── MagicDemoView.swift        ⚠️ Phase 4 で改修
│   │   ├── PermissionsCTAView.swift   ⚠️ Phase 4 で改修
│   │   ├── WidgetGuideView.swift      ⚠️ Phase 4 で改修
│   │   ├── OnboardingContainerView.swift  ❌ Dead code（削除待ち）
│   │   └── HookView.swift             ❌ Dead code（削除待ち）
│   ├── Alarm/
│   │   └── RingingView.swift          ⚠️ Phase 3 で改修
│   ├── Main/                          ❌ フォルダごと削除待ち
│   └── Shared/
│       ├── View+Shake.swift           ✅ v2 新規作成
│       ├── LargeButtonStyle.swift     ✅ 変更なし
│       └── （その他）                 ✅ 変更なし
├── Extensions/
│   ├── Color+Theme.swift    ✅ v2 完成（owlAmber/owlBrown/status系）
│   └── Spacing+Theme.swift  ✅ v2 新規作成（全デザイントークン）
└── ADHDAlarmApp.swift       ✅ v2 完成（RootView 条件分岐）
```

---

## 7. ビルド・確認手順

```bash
# ビルド確認
xcodebuild -scheme ADHDAlarm -destination 'platform=iOS Simulator,name=iPhone 17' -quiet

# エラーのみ確認
xcodebuild ... 2>&1 | grep ": error:"
```

シミュレーター `iPhone 17`（OS 26.3.1）が利用可能。
AlarmKit は実機のみ動作するため、アラーム関連の最終確認は実機（`YskのiPhone` または `取出洋介のiPhone`）で行うこと。
