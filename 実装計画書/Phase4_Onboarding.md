# Phase 4: オンボーディングフロー 検証・仕上げ

> 担当: Claude推奨（ルーティング整合性チェックが必要）
> 仕様参照元: `仕様書/01_Screen_Flow.md` STEP 1 / STEP 10
> 前提: Phase 3完了済み（v2ブランチ）

---

## 現状（Phase 4 着手前の状態）

ファイルは全て存在し、ルーティング接続も済み。**実装済みだが動作検証が未実施**。

| ファイル | 実装状態 | 確認ポイント |
|---------|---------|------------|
| `ModeSelectionView.swift` | ✅ 実装済み | `.person` → `personWelcome` へ遷移 OK |
| `PersonWelcomeView.swift` | ✅ 実装済み | `permissionsCTA` へ遷移 OK |
| `PermissionsCTAView.swift` | ✅ 実装済み | `requestAll()` 呼び出し後 `owlNaming` へ遷移 **要確認** |
| `OwlNamingView.swift` | ✅ 実装済み | `appState.owlName` への書き込み **要確認** |
| `MagicDemoWarningView.swift` | ✅ 実装済み | AlarmKit権限未承認時の分岐 **要確認** |
| `MagicDemoView.swift` | ✅ 実装済み | `widgetGuide` へ遷移 **要確認** |
| `WidgetGuideView.swift` | ✅ 実装済み | `appState.isOnboardingComplete = true` **最重要確認** |
| `OnboardingViewModel.swift` | ⚠️ プレースホルダー | 現在空のまま。各ViewがAppStateに直書きしているため不要かも |

---

## 完成基準（Done = これが全部✅）

- [x] モード選択 → `自分で使う` → PersonWelcomeView が表示される
- [x] PersonWelcomeView → PermissionsCTAView → 権限リクエスト → OwlNamingView が表示される
- [x] OwlNamingView でふくろうに名前をつけると `appState.owlName` に保存される
- [x] MagicDemoView 完了後 → WidgetGuideView が表示される
- [x] WidgetGuideView の「あとでやる」/「置いた！」どちらをタップしても `isOnboardingComplete = true` になり PersonHomeView に遷移する
- [x] 家族モード選択 → 暫定で直接 FamilyHomeView に遷移する（Phase 5 で本実装）
- [x] hapticOnly=true 時に振動が3回発生する（prepare()修正済み）
- [x] セカンダリボタンのタップ領域が全幅になる（contentShape修正済み）
- [x] ビルドエラーゼロ

## 残タスク（Codex可）

### UI改善（Codex依頼可）
各オンボーディング画面のビジュアル改善（フクロウアニメーション強化、カラー、余白調整など）。
**制約**: ルーティングロジック（`appState.onboardingPath.append(...)`）は一切変更しない。デザイントークン（Spacing.*, ComponentSize.*）を使う。

### WidgetGuideView 画像差し込み（Codex依頼可）
`pageContent()` 内の `"（ここに画像が入ります）"` プレースホルダーを実際の画像アセットに差し替え。
```swift
// 現在:
Text("（ここに画像が入ります）")
// 変更後（アセット名を渡すだけ）:
Image("widget_guide_step\(index + 1)")
    .resizable().scaledToFit()
```
アセット画像（`widget_guide_step1`〜`widget_guide_step4`）をAssets.xcassetsに追加してから依頼する。

---

## 遷移フロー（正規）

```
ModeSelectionView
  └─ .person → PersonWelcomeView
                └─ PermissionsCTAView
                    └─ OwlNamingView
                        └─ MagicDemoWarningView
                            └─ MagicDemoView
                                └─ WidgetGuideView
                                    └─ isOnboardingComplete = true → PersonHomeView（RootViewが自動切替）
  └─ .family → isOnboardingComplete = true → FamilyHomeView（Phase 5で本実装）
```

---

## ルーティング実装（ADHDAlarmApp.swift）

既存の `destinationView(for:)` が全ケースを網羅済み：

```swift
switch destination {
case .personWelcome:    PersonWelcomeView()
case .permissionsCTA:   PermissionsCTAView()
case .owlNaming:        OwlNamingView()
case .magicDemoWarning: MagicDemoWarningView()
case .magicDemo(let hapticOnly): MagicDemoView(hapticOnly: hapticOnly)
case .widgetGuide:      WidgetGuideView()
}
```

---

## 修正が必要な可能性が高い箇所

### OwlNamingView
`appState.owlName` への書き込みと次画面への遷移が実装されているか確認。
期待コード:
```swift
appState.owlName = owlNameInput.isEmpty ? "ふくろう" : owlNameInput
appState.onboardingPath.append(OnboardingDestination.magicDemoWarning)
```

### WidgetGuideView
`finishOnboarding()` が `isOnboardingComplete = true` をセットしているか確認。
期待コード:
```swift
private func finishOnboarding() {
    appState.isOnboardingComplete = true
    // onboardingPath はクリアしなくてOK（RootView条件分岐で自動切替）
}
```

### MagicDemoView
完了後に `widgetGuide` へ遷移しているか確認。

---

## 検証手順

1. シミュレーター起動（iPhone 17）
2. `UserDefaults` をリセット（シミュレーター再起動 or `appState.isOnboardingComplete = false` を一時追加）
3. 上記の遷移フロー全ステップを目視確認
4. 「自分で使う」ルートでホームまで到達することを確認
5. 「家族の見守り」ルートで FamilyHomeView（プレースホルダー）に到達することを確認

---

## 触らないファイル（Phase 4では変更禁止）

```
Services/          （全て）
ViewModels/        （OnboardingViewModel以外）
Models/            （全て）
Views/Dashboard/   （全て）
ADHDAlarmApp.swift （destinationView追加は可）
```
