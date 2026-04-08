# Phase A3：デッドコード削除 + XP統合

## 担当: Codex
## 難易度: 低（削除 + リファクタリング）

---

## 概要
1. デッドコードのファイルを削除（ビルドエラーがないことを確認）
2. `addXP()` ロジックが `PersonHomeViewModel` と `RingingViewModel` に全く同じコードで重複しているため、`AppState` に移動して一元化する

---

## 事前確認（重要）

以下3ファイルが「Xcodeのプロジェクトに含まれている」かどうかを確認すること。
含まれていればXcodeのターゲットから除外 + ファイル削除が必要。
含まれていなければ、ファイルシステム上にゴミファイルが残っているだけなのでファイル削除のみ。

```
ADHDAlarm/ViewModels/DashboardViewModel.swift
ADHDAlarm/Views/Dashboard/NextAlarmCard.swift
ADHDAlarm/Views/Dashboard/WidgetStatusBanner.swift
```

---

## Codex 向けプロンプト

---

以下の変更を順番に実行してください。各ステップでビルドが通ることを確認してから次へ進む。

### ステップ1: デッドコード削除

以下のファイルを削除する（Xcode プロジェクトからも除外すること）:

- `ADHDAlarm/ViewModels/DashboardViewModel.swift`
- `ADHDAlarm/Views/Dashboard/NextAlarmCard.swift`
- `ADHDAlarm/Views/Dashboard/WidgetStatusBanner.swift`

削除後、`NextAlarmCard`・`DashboardViewModel`・`WidgetStatusBanner` への参照がコードに残っていないか検索して確認する。

### ステップ2: AppState に addXP を移動

`ADHDAlarm/App/AppState.swift` に以下のメソッドを追加する（`// MARK: - グローバルトースト` セクションの直前に追加）。

```swift
// MARK: - XP管理

/// XPを加算する（1日の上限50XP。日付をまたいだ場合は今日のXPをリセット）
func addXP(_ amount: Int) {
    let cap = 50
    let defaults = UserDefaults.standard
    // 日付が変わっていたら今日のXPをリセット
    let lastDate = defaults.object(forKey: Constants.Keys.owlXPLastDate) as? Date ?? .distantPast
    var dailyAdded = defaults.integer(forKey: Constants.Keys.owlXPToday)
    if !Calendar.current.isDateInToday(lastDate) {
        dailyAdded = 0
        defaults.set(0, forKey: Constants.Keys.owlXPToday)
    }
    let actual = min(amount, cap - dailyAdded)
    guard actual > 0 else { return }
    owlXP += actual
    defaults.set(dailyAdded + actual, forKey: Constants.Keys.owlXPToday)
    defaults.set(Date(), forKey: Constants.Keys.owlXPLastDate)
}
```

### ステップ3: PersonHomeViewModel の addXP を削除 → AppState経由に変更

`ADHDAlarm/ViewModels/PersonHomeViewModel.swift` の `addXP(_ amount: Int)` メソッド（おおよそ line 487〜503）を**削除**し、
このメソッドを呼んでいた箇所（`addXP(10)`, `addXP(3)`, `addXP(5)` 等）を以下のように書き換える:

```swift
appState?.addXP(10)  // 完了時
appState?.addXP(3)   // スキップ時
appState?.addXP(5)   // ミニタスク時
```

### ステップ4: RingingViewModel の addXP を削除 → AppState経由に変更

`ADHDAlarm/ViewModels/RingingViewModel.swift` の `private func addXP(_ amount: Int)` メソッド（おおよそ line 381〜397）を**削除**し、
呼び出し箇所を以下のように書き換える:

```swift
appState?.addXP(10)  // dismiss() 内の完了時
appState?.addXP(3)   // skip() 内のスキップ時
```

---

## 完成確認

- [ ] ビルドエラーゼロ
- [ ] 削除した3ファイルへの参照が残っていない
- [ ] `addXP` のロジックが AppState.swift のみに存在する
- [ ] アラーム停止時・スキップ時にXPが正しく加算される（デバッグで確認）
