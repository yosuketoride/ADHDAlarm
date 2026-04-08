# Phase V16-2：DismissSheet（完了後ハーフシート + Undo）

## 担当: Claude
## 難易度: 高（非同期Undo・RingingView連携・バックグラウンドTask管理）
## 前提: Phase_V16_Toast.md 完了後に実施（ToastWindowManager が必要）

---

## 概要
仕様書 P-2-1（P-9-13が最優先）:
- アラーム「とめる」タップ後、現在は即時 RingingView が閉じてフルスクリーンが消える
- 変更後: **3秒でUIが閉じ**、その間 DismissSheet（ハーフシート）が表示される
- DismissSheet に「元に戻す」ボタンがあり、**30秒間** Undo が可能
- 30秒後: 完全確定（AlarmKit削除・EK削除）

---

## シーケンス図

```
ユーザーが「とめる」タップ
    ↓
RingingViewModel.dismiss() 呼び出し
    ↓
[即時] completionStatus = .completed（ローカル保存）
[即時] XP +10
[即時] 音声停止
    ↓
RingingView → DismissSheet をハーフシートとして表示
    ↓
[3秒後] DismissSheet を閉じる（onDismissed() 呼び出し）= フルスクリーンが消える
    ↓
[30秒間] バックグラウンドで undoTask が待機
    │
    ├─── [Undoタップ時]
    │     undoTask.cancel()
    │     completionStatus = nil に戻す
    │     XP -10（または0未満にはしない）
    │     DismissSheet を閉じる（undoして終わり）
    │
    └─── [30秒経過]
          AlarmKit から削除
          EventKit から削除
          undoTask 終了
```

---

## 変更ファイル

| ファイル | 変更内容 |
|---------|---------|
| `Views/Alarm/DismissSheet.swift` | **新規作成** |
| `Views/Alarm/RingingView.swift` | DismissSheet の表示ロジック追加 |
| `ViewModels/RingingViewModel.swift` | dismiss() の変更・undoTask の管理 |

---

## DismissSheet.swift（新規作成）

```swift
// ADHDAlarm/Views/Alarm/DismissSheet.swift
import SwiftUI

/// アラーム完了後のハーフシート（褒め + Undo）
struct DismissSheet: View {
    @Binding var isPresented: Bool
    let alarmTitle: String
    let onUndo: () -> Void

    var body: some View {
        VStack(spacing: Spacing.lg) {
            // 上部グリップ
            RoundedRectangle(cornerRadius: 2)
                .fill(Color.secondary.opacity(0.4))
                .frame(width: 36, height: 4)
                .padding(.top, Spacing.sm)

            // ふくろうの褒め言葉
            VStack(spacing: Spacing.sm) {
                Text("🦉")
                    .font(.system(size: 56))
                Text("よくできました！")
                    .font(.title2.weight(.bold))
                Text("「\(alarmTitle)」を完了にしたよ")
                    .font(.body)
                    .foregroundStyle(.secondary)
            }
            .multilineTextAlignment(.center)

            // Undoボタン
            Button {
                onUndo()
                isPresented = false
            } label: {
                Label("元に戻す", systemImage: "arrow.uturn.backward")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .frame(minHeight: ComponentSize.small)

            Spacer()
        }
        .padding(.horizontal, Spacing.lg)
        .presentationDetents([.height(280)])
        .presentationDragIndicator(.hidden)
    }
}
```

---

## RingingViewModel.swift の変更

### 追加するプロパティ
```swift
// MARK: - DismissSheet 用状態
var showDismissSheet = false
private var undoTask: Task<Void, Never>?
private var lastDismissedAlarm: AlarmEvent?
private var lastDismissedXP: Int = 0
```

### dismiss() の変更
```swift
func dismiss() {
    guard let alarm = activeAlarm else { return }
    
    // 1. 即時: ローカル状態を更新
    recordCompletion(for: alarm, status: .completed)
    syncReactionToRemote(alarm: alarm, status: "completed")
    lastDismissedAlarm = alarm
    lastDismissedXP = 10
    appState?.addXP(10)
    stopAudioPlayback()
    playPraisePhrase()
    
    // 2. DismissSheet を表示
    showDismissSheet = true
    
    // 3. 3秒後に RingingView を閉じる
    Task { @MainActor in
        try? await Task.sleep(for: .seconds(3))
        // onDismissed() は RingingView 側で DismissSheet dismiss後に呼ぶ
    }
    
    // 4. 30秒後に確定処理（undoTask がキャンセルされなければ実行）
    undoTask = Task { @MainActor in
        try? await Task.sleep(for: .seconds(30))
        guard !Task.isCancelled else { return }
        await commitFinalDeletion(alarm: alarm)
    }
}

/// Undo 実行
func undoDismiss() {
    undoTask?.cancel()
    undoTask = nil
    guard let alarm = lastDismissedAlarm else { return }
    // completionStatus を nil に戻す
    var restored = alarm
    restored.completionStatus = nil
    AlarmEventStore.shared.save(restored)
    // XP を戻す（0未満にはしない）
    if let appState, appState.owlXP >= lastDismissedXP {
        appState.owlXP -= lastDismissedXP
    }
    lastDismissedAlarm = nil
    showDismissSheet = false
    activeAlarm = alarm  // RingingView は再表示しない（Toast で通知）
    ToastWindowManager.shared.show(ToastMessage(
        text: "元に戻しておいたよ",
        style: .owlTip
    ))
}

/// 30秒後の確定削除
private func commitFinalDeletion(alarm: AlarmEvent) async {
    if let ekID = alarm.eventKitIdentifier {
        try? await calendarProvider.deleteEvent(eventKitIdentifier: ekID)
    }
    await AlarmKitScheduler.shared.cancel(for: alarm)
    lastDismissedAlarm = nil
    WidgetCenter.shared.reloadAllTimelines()
}
```

---

## RingingView.swift の変更

`dismiss()` 後に DismissSheet を表示する `.sheet` を追加。

```swift
// RingingView の body の最後に追加
.sheet(isPresented: Binding(
    get: { viewModel.showDismissSheet },
    set: { if !$0 { viewModel.showDismissSheet = false } }
), onDismiss: {
    // シートが閉じたら RingingView 全体を閉じる
    onDismissed()
}) {
    DismissSheet(
        isPresented: Binding(
            get: { viewModel.showDismissSheet },
            set: { viewModel.showDismissSheet = $0 }
        ),
        alarmTitle: pendingAlarm.title,
        onUndo: { viewModel.undoDismiss() }
    )
}
```

---

## 注意事項

- `undoTask` は `Task.isCancelled` でのキャンセルチェックが必須
- `commitFinalDeletion` は `async` で非同期処理。30秒待機中にアプリがバックグラウンドに入っても Task は継続する（バックグラウンド処理の許容範囲内）
- RingingView が既存の `dismiss()` 後の `onDismissed()` 呼び出しを DismissSheet の `onDismiss` に移動すること
- `playPraisePhrase()` は dismiss() 内で呼ぶ（UX変更なし）

---

## 完成確認

- [ ] 「とめる」タップ後、DismissSheetのハーフシートが表示される
- [ ] 3秒後にDismissSheetが自動で閉じ、RingingViewも閉じる（PersonHomeに戻る）
- [ ] 「元に戻す」タップ時: completionStatus が nil に戻り、XPが元に戻る
- [ ] 「元に戻す」後、Toast「元に戻しておいたよ」が表示される
- [ ] 30秒後: Undoボタンなしで自動確定し、AlarmKit・EventKit から削除される
- [ ] 実機テストでAlarmKit発火 → 完了 → 30秒後確定の動作が確認できる
