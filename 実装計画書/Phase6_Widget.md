# Phase 6: WidgetKit

> ステータス: **ほぼ完成 ✅**
> 仕様参照元: `仕様書/04_Feature_Modules.md` ウィジェットセクション

---

## 実装済み内容（触らなくてOK）

`ADHDAlarmWidget/` フォルダに以下が実装済み:

| ファイル | 内容 |
|---------|------|
| `ADHDAlarmWidget.swift` | Small/Medium/Large の3サイズ対応ウィジェット |
| `WidgetDataProvider.swift` | App Group経由でAlarmEventを読む |
| `WidgetSharedModels.swift` | WidgetAlarmEvent（軽量モデル）|
| `AppIntent.swift` | CompleteAlarmIntent（ウィジェットから完了操作）|
| `ADHDAlarmWidgetBundle.swift` | Bundle登録 |
| `ADHDAlarmWidgetControl.swift` | Control Widget（Lock Screen用）|

App Group ID: `group.com.yosuke.WasurenboAlarm`（設定済み）

---

## 残タスク（小）

- [ ] Medium サイズのふくろう部屋アニメーション（XP連動アイテム）の動作確認
- [ ] Large サイズで予定が0件の時の表示確認
- [ ] `CompleteAlarmIntent` が実機で動作するか確認（AlarmKit実機必須）
- [ ] ウィジェットの更新タイミング確認（予定追加・削除時に `WidgetCenter.shared.reloadAllTimelines()` が呼ばれているか）

---

## 更新トリガー（チェック済みの箇所）

```swift
// PersonHomeViewModel.commitDelete() で呼ばれている
WidgetCenter.shared.reloadAllTimelines()

// TODO: InputViewModel.confirmAndSchedule() でも呼ぶ必要あり（確認）
```

---

## Phase 8で対応

- `OwlIcon` → `owl_stage0`〜`owl_stage3` アセット切り替え（XP段階連動）
