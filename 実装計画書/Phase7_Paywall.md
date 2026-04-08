# Phase 7: StoreKit 2 / Paywall 統合

> 担当: UIはCodex可、機能ゲート統合はClaude推奨
> 仕様参照元: `仕様書/07_AppStore.md`, `CLAUDE.md` ビジネスモデルセクション
> 前提: Phase 5完了済み

---

## 現状

| ファイル | 状態 |
|---------|------|
| `Services/StoreKitService.swift` | ✅ 実装済み（商品取得・購入・復元・監視） |
| `Views/Paywall/PaywallView.swift` | ✅ 実装済み（約605行、A/Bバリアント対応） |
| `ViewModels/PaywallViewModel.swift` | 確認必要 |
| `AppState.subscriptionTier` | ✅ UserDefaults永続化済み |

**主な問題**: PaywallViewが適切なタイミングで呼ばれているか未確認。
PRO機能のゲートが実際に効いているか未確認。

---

## 完成基準（Done = これが全部✅）

- [ ] PRO限定機能にアクセスしようとするとPaywallViewが表示される
- [ ] 購入成功 → `appState.subscriptionTier = .pro` に更新される
- [ ] 復元 → 正しく反映される
- [ ] アプリ再起動後もPRO状態が維持される（`checkEntitlement()` で確認）
- [ ] 無料版でコア機能（アラームが鳴る）は制限されない
- [ ] ビルドエラーゼロ

---

## PRO機能ゲートの実装方針

### ゲートをかける箇所（仕様書より）

| 機能 | 無料 | PRO | 実装場所 |
|------|------|-----|--------|
| マナーモード貫通アラーム | ✅ 無制限 | ✅ | ゲート不要 |
| カレンダー選択 | ❌ デフォルト固定 | ✅ | `ParseConfirmationView` |
| 事前通知複数回 | ❌ 1回のみ | ✅ | `PreNotificationPicker` |
| 全音声キャラ | ❌ デフォルトのみ | ✅ | `VoiceCharacterPicker` |
| 家族リモートアラーム | ❌ | ✅ | `FamilySendTab` |
| カスタム音声録音 | ❌ | ✅ | `CustomVoiceRecorderView` |

### ゲートのパターン

```swift
// 方針: PRO機能に触れた瞬間にPaywallViewをsheetで表示
// @Environment(StoreKitService.self) を使う

@Environment(StoreKitService.self) private var storeKit
@Environment(AppState.self) private var appState

// PRO機能ボタンに付ける
Button("カレンダーを選ぶ") {
    if appState.subscriptionTier == .pro {
        showCalendarPicker = true
    } else {
        showPaywall = true
    }
}
.sheet(isPresented: $showPaywall) {
    PaywallView()
}
```

---

## PaywallView の呼び出し方（既存）

```swift
// PaywallViewは単体で表示可能。StoreKitServiceは @Environment から取得。
// 親から渡すものは不要（内部でEnvironmentを参照している）

.sheet(isPresented: $showPaywall) {
    PaywallView()
        .presentationDetents([.large])
}
```

---

## StoreKit 商品ID（Constants.swift に定義済み）

```swift
Constants.ProductID.proMonthly   // 月額
Constants.ProductID.proYearly    // 年額
Constants.ProductID.proLifetime  // 買い切り
```

---

## AppState との統合

```swift
// StoreKitService.purchase() 成功後:
appState.subscriptionTier = .pro

// アプリ起動時（ADHDAlarmApp.startupTasks()）:
let isPro = await storeKit.checkEntitlement()
if isPro { appState.subscriptionTier = .pro }
// ← これはすでに実装済み
```

---

## Codexへのプロンプトテンプレート（PRO機能ゲート実装）

```
ADHDAlarmのSwiftUIプロジェクトで、PRO機能ゲートを実装してください。

【対象ファイル】
- Views/Settings/VoiceCharacterPicker.swift
- Views/Input/ParseConfirmationView.swift（カレンダー選択部分）

【ルール】
- appState.subscriptionTier == .pro の場合は通常通り表示
- .free の場合は .sheet(isPresented:) で PaywallView() を表示する
- @Environment(AppState.self) private var appState で取得
- PaywallViewは引数なしで使える（内部でEnvironmentを参照）
- @Observable @MainActor を使う（ObservableObjectは使わない）
```

---

## 触らないファイル（Phase 7では変更禁止）

```
Services/StoreKitService.swift（変更不要）
Services/SyncEngine.swift
Services/AlarmKitScheduler.swift
ViewModels/PersonHomeViewModel.swift
Views/Alarm/（全て）
```
