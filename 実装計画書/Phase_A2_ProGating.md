# Phase A2：PRO機能ゲート実装

## 担当: Claude
## 難易度: 中（UX判断・PaywallView連携・複数ファイル）

---

## 概要
PRO限定機能に触れた瞬間に `PaywallView` を表示するゲートを3箇所に追加する。
**コア機能（アラームが鳴る）は絶対に課金壁にしない。**

---

## PRO機能ゲート一覧

| 機能 | 無料の制限 | 実装場所 |
|------|----------|--------|
| カレンダー選択 | デフォルトカレンダー固定 | `ParseConfirmationView.swift` または `PersonManualInputView.swift` のカレンダーピッカー部分 |
| 事前通知の複数設定 | 1回のみ（15分前固定） | `SettingsView.swift` の詳細設定内、preNotificationMinutesList 設定箇所 |
| 全音声キャラ | デフォルト（femaleConcierge）のみ | `VoiceCharacterPicker.swift`（既にロック表示あり・要確認） |

---

## ゲートのUIパターン

```swift
// 標準パターン（全箇所で統一）
@Environment(AppState.self) private var appState
@State private var showPaywall = false

// PRO機能ボタン
Button {
    if appState.subscriptionTier == .pro {
        // PRO機能を実行
        showCalendarPicker = true
    } else {
        showPaywall = true
    }
} label: {
    HStack {
        Text("カレンダーを選ぶ")
        if appState.subscriptionTier != .pro {
            Image(systemName: "lock.fill")
                .foregroundStyle(.secondary)
                .font(.caption)
        }
    }
}
.sheet(isPresented: $showPaywall) {
    PaywallView()
        .presentationDetents([.large])
}
```

---

## 変更ファイル一覧

### 1. VoiceCharacterPicker.swift
**現状確認が必要**: SettingsView から `VoiceCharacterPicker(isPro: viewModel.isPro, onUpgradeTapped: ...)` で呼ばれている。
`isPro` フラグと `onUpgradeTapped` コールバックが既にある可能性が高い。

実装内容:
- `isPro == false` の場合、PRO限定キャラのセルにロックアイコンを表示
- PRO限定キャラをタップ → `onUpgradeTapped()` を呼ぶ
- 無料キャラ（femaleConcierge のみ）は常に選択可能

### 2. PreNotificationMinutes（設定画面内）
**現状確認が必要**: `SettingsView.swift` の `advancedCard` 内に事前通知設定があるか確認する。

実装内容:
- 無料ユーザー: 1回選択のみ。複数選択UIを無効化してロックアイコン表示
- PRO ユーザー: 複数回選択 UI（チェックボックス形式）を表示
- ゲートパターン: 複数回設定エリアをタップ → PaywallView を sheet 表示

### 3. カレンダー選択
**現状確認が必要**: `ParseConfirmationView.swift` または `PersonManualInputView.swift` にカレンダー選択UIがあるか確認する。

実装内容:
- 無料ユーザー: カレンダー選択ボタンにロックアイコン表示
- タップ → PaywallView を sheet 表示
- PRO ユーザー: 通常のカレンダーピッカーを表示

---

## 実装前の確認事項

Claude が実装を開始する前に以下のファイルを読むこと:

1. `ADHDAlarm/Views/Settings/VoiceCharacterPicker.swift` — isPro 引数の有無を確認
2. `ADHDAlarm/Views/Settings/SettingsView.swift` の `advancedCard` — 事前通知設定UIを確認
3. `ADHDAlarm/Views/Input/ParseConfirmationView.swift` — カレンダー選択UIを確認
4. `ADHDAlarm/Views/Input/PersonManualInputView.swift` — カレンダー選択UIを確認

---

## 完成確認

- [ ] SettingsView で無料ユーザーが2個目以上の事前通知を設定しようとするとPaywallViewが開く
- [ ] 無料ユーザーがカレンダー選択ボタンをタップするとPaywallViewが開く
- [ ] 無料ユーザーが音声キャラのPRO限定キャラをタップするとPaywallViewが開く
- [ ] PRO ユーザーはすべての機能を制限なく使える
- [ ] PaywallView を閉じてもアプリが正常動作する
- [ ] コア機能（アラームが鳴る）に制限はかかっていない
- [ ] ビルドエラーゼロ
