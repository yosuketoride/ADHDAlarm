# Phase A1：クリアボイスモード実装

## 担当: Codex
## 難易度: 低（変更箇所4ファイル・独立した機能）

---

## 概要
アラーム鳴動時のTTS（読み上げ音声）を「聞き取りやすいこえ」モードに切り替える機能。
設定 ON 時: ゆっくり・低い声（rate=0.40、pitchMultiplier=0.80）
設定 OFF 時: 現在の値（rate=0.48、pitchMultiplier=1.1）

---

## 変更ファイル一覧

| # | ファイル | 変更内容 |
|---|---------|---------|
| 1 | `ADHDAlarm/App/Constants.swift` | Keys に `isClearVoiceEnabled` キー追加 |
| 2 | `ADHDAlarm/App/AppState.swift` | `isClearVoiceEnabled: Bool` プロパティ追加 |
| 3 | `ADHDAlarm/ViewModels/RingingViewModel.swift` | `speakAlarmTitle()` の rate/pitchMultiplier を条件分岐 |
| 4 | `ADHDAlarm/Views/Settings/SettingsView.swift` | 詳細設定カード内にトグル追加 |

---

## Codex 向けプロンプト

---

以下の変更を正確に実行してください。コーディングルール：`@Observable` を使う / コメントは日本語 / デザイントークン使用。

### 変更1: Constants.swift

`ADHDAlarm/App/Constants.swift` の `enum Keys` ブロック内（`owlStage` の行の直後）に以下を追加する。

```swift
static let isClearVoiceEnabled = "is_clear_voice_enabled"
```

### 変更2: AppState.swift

`ADHDAlarm/App/AppState.swift` に以下の変更を加える。

**プロパティ追加**（`// MARK: - 設定` セクション内、`voiceCharacter` の `didSet` ブロックの直後）：
```swift
/// クリアボイスモード: ONにするとゆっくり・低い声で読み上げる（聞き取りやすさ優先）
var isClearVoiceEnabled: Bool {
    didSet { UserDefaults.standard.set(isClearVoiceEnabled, forKey: Constants.Keys.isClearVoiceEnabled) }
}
```

**init() に追加**（`self.voiceCharacter = ...` の行の直後）：
```swift
self.isClearVoiceEnabled = defaults.bool(forKey: Constants.Keys.isClearVoiceEnabled)
```

### 変更3: RingingViewModel.swift

`ADHDAlarm/ViewModels/RingingViewModel.swift` の `speakAlarmTitle(_:preNotificationMinutes:)` 関数内で、現在
```swift
utterance.rate  = 0.48
utterance.pitchMultiplier = 1.1
```
となっている2行を、以下のように書き換える（`appState` は既に `weak var` または参照で持っている想定）：

```swift
// クリアボイスモード: ONならゆっくり・低音で読み上げる
if appState?.isClearVoiceEnabled == true {
    utterance.rate  = 0.40
    utterance.pitchMultiplier = 0.80
} else {
    utterance.rate  = 0.48
    utterance.pitchMultiplier = 1.1
}
```

### 変更4: SettingsView.swift

`ADHDAlarm/Views/Settings/SettingsView.swift` の `advancedCard`（詳細設定カード）内の最後のコンテンツの直後に、以下のトグル行を追加する。

```swift
// クリアボイスモード
Toggle(isOn: Binding(
    get: { appState.isClearVoiceEnabled },
    set: { appState.isClearVoiceEnabled = $0 }
)) {
    Label {
        VStack(alignment: .leading, spacing: 2) {
            Text("聞き取りやすいこえ")
                .font(.body)
            Text("アラームの声をゆっくり・低めに読み上げます")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    } icon: {
        Image(systemName: "ear.badge.checkmark")
            .foregroundStyle(.blue)
    }
}
.frame(minHeight: ComponentSize.settingRow)
```

---

## 完成確認

- [ ] ビルドエラーゼロ
- [ ] 設定画面の詳細設定カードに「聞き取りやすいこえ」トグルが表示される
- [ ] トグルをONにしてアラームを鳴らすと、ゆっくり・低い声で読み上げられる（実機テスト必須）
- [ ] アプリを再起動してもトグルのON/OFF状態が保持される
