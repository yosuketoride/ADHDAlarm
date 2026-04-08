# Phase 5: FamilyHomeView 本実装

> 担当: UI部分はCodex可、Supabase連携部分はClaude推奨
> 仕様参照元: `仕様書/01_Screen_Flow.md` STEP 3〜5, `仕様書/04_Feature_Modules.md`
> 前提: Phase 4完了済み

---

## 現状

`FamilyHomeView.swift` はプレースホルダーのみ（「ただいま準備中です」テキスト）。
`FamilyInputView.swift` は既存実装あり（改修が必要）。
`FamilyRemoteService.swift` は既存実装あり（Supabase Realtime）。
`FamilyPairingViewModel.swift` は既存実装あり。

---

## 完成基準（Done = これが全部✅）

- [ ] FamilyHomeView が3タブ構成で表示される（ダッシュボード / 送信 / 設定）
- [ ] Tab 0（ダッシュボード）: 当事者の最新ステータスが一覧表示される
- [ ] Tab 1（送信）: テンプレートカード一覧から予定を送信できる
- [ ] Tab 2（設定）: ペアリング管理・通知設定
- [ ] ペアリング未完了時: ペアリング画面（6桁コード）にリダイレクト
- [ ] ModeSelectionView の「家族の見守り」 → オンボーディング → FamilyHomeView に遷移
- [ ] ビルドエラーゼロ

---

## 変更ファイル一覧

| ファイルパス | 操作 | 担当 |
|-----------|------|------|
| `Views/Family/FamilyHomeView.swift` | **書き換え（本実装）** | Codex可（UI） |
| `Views/Family/FamilyInputView.swift` | 改修（テンプレートカード対応） | Codex可 |
| `Views/Family/FamilyDashboardTab.swift` | **新規作成** | Codex可 |
| `Views/Family/FamilySendTab.swift` | **新規作成** | Codex可 |
| `Views/Family/FamilySettingsTab.swift` | **新規作成** | Codex可 |
| `Views/Family/FamilyPairingView.swift` | **新規作成**（6桁コード） | Codex可 |
| `ViewModels/FamilyHomeViewModel.swift` | **新規作成** | Claude推奨 |
| `Services/FamilyRemoteService.swift` | 改修（Realtime購読修正） | Claude必須 |
| `ADHDAlarmApp.swift` | 家族オンボーディングフロー追加 | Claude推奨 |

---

## 画面構成仕様

### FamilyHomeView（ルートビュー）

```swift
@Observable @MainActor
final class FamilyHomeViewModel {
    var isPaired: Bool        // FamilyPairingViewModelから取得
    var selectedTab = 0
    var pairedPersonName: String  // "お母さん" 等
}

struct FamilyHomeView: View {
    @State private var viewModel = FamilyHomeViewModel()
    
    var body: some View {
        if !viewModel.isPaired {
            FamilyPairingView()  // ペアリング未完了時は強制表示
        } else {
            TabView(selection: $viewModel.selectedTab) {
                FamilyDashboardTab().tabItem { Label("見守り", systemImage: "eye.fill") }.tag(0)
                FamilySendTab().tabItem { Label("送る", systemImage: "paperplane.fill") }.tag(1)
                FamilySettingsTab().tabItem { Label("設定", systemImage: "gearshape.fill") }.tag(2)
            }
        }
    }
}
```

### Tab 0: FamilyDashboardTab（見守りダッシュボード）

表示するもの:
- 当事者の「最終確認時刻」（Last Seen）
- 今日の予定リスト（送信済みのもの）と完了/スキップ/未対応の状態
- 左ボーダー色でステータス表示:
  - `pending/alerting` → `.owlAmber`（黄）
  - `completed` → `.statusSuccess`（緑）
  - `skipped` → `.statusSkipped`（グレー）
  - `missed` / `expired` → `.statusDanger`（赤）
  - `snoozed` → `.statusWarning`（オレンジ）
- SOSバナー（`appState.sosStatus != nil` の時）

データソース: `FamilyRemoteService` から Supabase Realtime で購読

### Tab 1: FamilySendTab（予定を送る）

テンプレートカードの一覧（横スクロール）:
```
💊 お薬の時間   🏥 病院へ行く   🍜 ご飯の時間
🛌 お昼寝して   🚶 散歩の時間   📞 電話してね
```

カードをタップ → 時刻選択ピッカー（今から/15分後/30分後/1時間後/カスタム）→ 送信確認 → Supabase INSERT

### Tab 2: FamilySettingsTab（設定）

- ペアリング解除ボタン
- 通知設定（完了通知 ON/OFF、未対応通知 ON/OFF）
- 当事者名の編集

### FamilyPairingView（ペアリング画面）

```
┌──────────────────────────┐
│  🦉 ペアリングしよう      │
│  「自分で使う」側の       │
│  6桁コードを入力してね    │
│                          │
│  [  ] [  ] [  ] - [  ] [  ] [  ]  │
│                          │
│  [コードを入力してペアリング]       │
└──────────────────────────┘
```

既存 `FamilyPairingViewModel` を使用。6桁コードはSupabase Edge Functionで生成。

---

## FamilyRemoteService の主要メソッド（既存）

```swift
// 既存実装あり（確認してから使う）
func sendRemoteEvent(_ event: RemoteEvent) async throws
func subscribeToStatus(for deviceID: String) async
func fetchRecentEvents(for deviceID: String) async throws -> [RemoteEvent]
```

---

## Codexへのプロンプトテンプレート（UI部分を依頼する時）

```
以下のSwiftUIプロジェクトのFamilyDashboardTab.swiftを新規作成してください。

【制約】
- @Observable @MainActor を使う（ObservableObjectは使わない）
- デザイントークン: Spacing.xs/sm/md/lg/xl, ComponentSize.*, CornerRadius.*, Color.owlAmber等を使う
- タップターゲット最低44pt
- コメントは日本語

【表示するデータ】
struct RemoteEvent: Identifiable {
    let id: UUID
    var title: String
    var startDate: Date
    var status: String  // "pending"/"alerting"/"completed"/"skipped"/"missed"/"expired"/"snoozed"
    var senderName: String
}

【左ボーダー色のルール】
pending/alerting → Color.owlAmber
completed → Color.statusSuccess
skipped → Color.statusSkipped（グレー）
missed/expired → Color.statusDanger
snoozed → Color.statusWarning（オレンジ）

【既存ファイルのパターン参照】
EventRow.swift（Views/Dashboard/）のレイアウトパターンを参考にすること。
```

---

## 注意事項（変更禁止ルール）

- `actor SyncEngine` を `final class` に戻さない
- `@Observable @MainActor` パターンを守る
- FamilyRemoteService の Supabase 接続ロジックに触らない（接続先が変わるリスク）
- 当事者側の EventKit データには一切書き込まない（家族は Supabase 経由のみ）

---

## 触らないファイル（Phase 5では変更禁止）

```
Services/SyncEngine.swift
Services/AlarmKitScheduler.swift
Services/AppleCalendarProvider.swift
ViewModels/PersonHomeViewModel.swift
Views/Dashboard/（全て）
Views/Alarm/（全て）
```
