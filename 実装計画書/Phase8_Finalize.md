# Phase 8: 仕上げ・App Store提出準備

> 担当: タスク次第（以下の表を参照）
> 前提: Phase 7完了済み

---

## 完成基準（Done = これが全部✅）

- [ ] Dead codeファイルが削除されビルドが通る
- [ ] NLParserが絵文字を推定し `AlarmEvent.eventEmoji` に自動書き込みされる
- [ ] XPが `AppState.owlXP` に統一される（UserDefaults直書きを廃止）
- [ ] ふくろうアセットがXP段階（0〜3）で切り替わる
- [ ] 全機能の実機テストが完了
- [ ] App Store Connect にビルドをアップロードできる

---

## タスク一覧

### 8-1. Dead code 削除（Claude必須 - ビルド影響あり）

削除対象（Handoff.md Section 4より）:

| ファイル | 削除理由 |
|---------|---------|
| `ViewModels/DashboardViewModel.swift` | PersonHomeViewModelに移行済み |
| `Views/Dashboard/NextAlarmCard.swift` | PersonHomeViewの内部に統合済み |
| `Views/Dashboard/WidgetStatusBanner.swift` | Phase 6 Widget実装により不要 |

削除手順: Xcodeプロジェクトから削除 → ビルド確認 → 参照エラーを修正

---

### 8-2. NLParser絵文字推定（Codex可）

**対象ファイル**: `Services/NLParserService.swift`

```swift
// NLParserServiceに追加するメソッド
func inferEmoji(from title: String) -> String? {
    // キーワードマッピング（拡張可能）
    let mappings: [(keywords: [String], emoji: String)] = [
        (["薬", "服薬", "飲む", "錠"], "💊"),
        (["病院", "診察", "クリニック", "医者"], "🏥"),
        (["ご飯", "食事", "昼", "朝", "夜", "夕"], "🍴"),
        (["運動", "散歩", "ウォーキング", "体操"], "🚶"),
        (["電話", "連絡", "コール"], "📞"),
        (["美容院", "カット", "髪"], "💇"),
        (["買い物", "スーパー", "コンビニ"], "🛒"),
        (["ゴミ", "ごみ", "資源"], "🗑️"),
        (["掃除", "片付け"], "🧹"),
        (["寝る", "就寝", "お昼寝"], "😴"),
    ]
    let lowercased = title.lowercased()
    for (keywords, emoji) in mappings {
        if keywords.contains(where: { lowercased.contains($0) }) {
            return emoji
        }
    }
    return nil  // マッチしなければnilを返す（EventRowで "📌" にフォールバック）
}
```

**呼び出し場所**: `InputViewModel.confirmAndSchedule()` の中で `parsedInput.title` に対して実行し、`AlarmEvent.eventEmoji` に書き込む。

---

### 8-3. XP の AppState 統合（Codex可）

**問題**: `PersonHomeViewModel` と `RingingViewModel` が独立して `UserDefaults` に直書きしている。

**解決策**:

```swift
// AppState に追加（既存の owl_xp キーを読む）
var owlXP: Int {
    get { UserDefaults(suiteName: "group.com.yosuke.WasurenboAlarm")?.integer(forKey: "owl_xp") ?? 0 }
    set { UserDefaults(suiteName: "group.com.yosuke.WasurenboAlarm")?.set(newValue, forKey: "owl_xp") }
}
```

各ViewModelの `addXP()` を `appState.owlXP += amount` に置き換える。
ウィジェットも `AppState` 経由で読んでいるため整合性が保たれる。

---

### 8-4. ふくろうアセット段階化（Claude必須 - アセット追加が必要）

XPに応じてふくろう画像を切り替える:

| XP | アセット名 | 見た目 |
|----|---------|------|
| 0〜99 | `owl_stage0` | ひよっこ（現在の OwlIcon） |
| 100〜499 | `owl_stage1` | 学生ふくろう |
| 500〜999 | `owl_stage2` | 大人ふくろう |
| 1000〜 | `owl_stage3` | 博士ふくろう |

**実装**: `PersonHomeViewModel.owlImageName` を追加し、PersonHomeView の `owlImage` で参照。

```swift
var owlImageName: String {
    switch appState.owlXP {
    case 0..<100:   return "owl_stage0"
    case 100..<500: return "owl_stage1"
    case 500..<1000: return "owl_stage2"
    default:        return "owl_stage3"
    }
}
```

⚠️ アセット画像が用意できるまでは `"OwlIcon"` にフォールバックする。

---

### 8-5. WidgetKit 更新漏れ修正（Claude推奨）

`InputViewModel.confirmAndSchedule()` で `WidgetCenter.shared.reloadAllTimelines()` が呼ばれているか確認。
呼ばれていなければ追加する。

---

### 8-6. 実機テスト項目

| テスト | 担当 |
|--------|------|
| AlarmKit発火・RingingView表示 | 実機必須（洋介） |
| マナーモードONでアラームが鳴る | 実機必須（洋介） |
| ウィジェット表示・CompleteAlarmIntent | 実機必須（洋介） |
| Supabaseペアリング（2台使用） | 実機2台必須（洋介） |
| StoreKit購入フロー（Sandbox） | 実機必須（洋介） |

---

### 8-7. App Store提出前チェックリスト

- [ ] Bundle ID: `com.yosuke.WasurenboAlarm`
- [ ] Deployment Target: iOS 26.0
- [ ] Privacy Manifest（`PrivacyInfo.xcprivacy`）の作成
- [ ] App Store Connect に商品登録（月額/年額/買い切りの3つ）
- [ ] スクリーンショット6枚撮影（仕様: `仕様書/07_AppStore.md`）
- [ ] プライバシーポリシーURL設定
- [ ] TestFlightでの内部テスト

---

## 触らないファイル（Phase 8では変更禁止）

基本的に全ファイルを「修正ではなく確認」として扱う。
大きな機能追加はしない。
