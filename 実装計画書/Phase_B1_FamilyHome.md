# Phase B1：FamilyHome 本実装（UI先行）

## 担当: Claude（UIとViewModelの接続）、UI部品はCodex可
## 難易度: 高（新規View 5ファイル + ViewModel改修 + Supabase連携）

---

## 概要
`FamilyHomeView.swift` はプレースホルダーのみ。TabView 3タブ構成に本実装する。
バックエンド（Supabase）の準備状況が不明なため、**UI先行実装**とし、
データ取得部分は既存の `FamilyRemoteService.swift` を使うが、
接続が動かない場合もUIが表示されるようにフォールバックを用意する。

---

## 仕様書の重要テキストルール（必ず守ること）

仕様書 01_Screen_Flow.md 4-6 より：**家族モードのUXライティング指針**

| ❌ 禁止表現 | ✅ 使用必須 |
|-----------|----------|
| 「親の予定を管理する」 | 「お母さんの生活をサポートする」 |
| 「予定を設定してあげる」 | 「リマインダーをお届けする」「予定を贈る」 |
| 「確認する」「監視する」 | 「様子を気にかける」「つながっていることを感じる」 |
| 「完了させる」 | 「できた！を一緒に喜ぶ」 |
| 「未完了」「ステータス」 | 「まだお知らせが届いていないようです」 |

---

## タブ構成

| Tab | SF Symbol | ラベル | 内容 |
|-----|-----------|--------|------|
| 0 | `house.fill` | おやの今日 | 当事者の今日の予定・完了状況 |
| 1 | `paperplane.fill` | 予定を贈る | テンプレートカードから予定送信 |
| 2 | `gearshape.fill` | 設定 | ペアリング・通知設定 |

---

## 新規作成ファイル

### 1. FamilyHomeView.swift（既存を書き換え）

```swift
struct FamilyHomeView: View {
    @Environment(AppState.self) private var appState
    @State private var viewModel = FamilyHomeViewModel()
    @State private var selectedTab = 0
    
    var body: some View {
        Group {
            if appState.familyLinkId == nil && appState.familyChildLinkIds.isEmpty {
                // ペアリング未完了 → ペアリング画面へ
                FamilyPairingView()
            } else {
                TabView(selection: $selectedTab) {
                    FamilyDashboardTab(viewModel: viewModel)
                        .tabItem { Label("おやの今日", systemImage: "house.fill") }
                        .tag(0)
                    FamilySendTab(viewModel: viewModel)
                        .tabItem { Label("予定を贈る", systemImage: "paperplane.fill") }
                        .tag(1)
                    FamilySettingsTab()
                        .tabItem { Label("設定", systemImage: "gearshape.fill") }
                        .tag(2)
                }
                .tint(Color.owlAmber)
            }
        }
        .task { await viewModel.load() }
    }
}
```

### 2. FamilyDashboardTab.swift（新規作成）

**表示内容:**
- 当事者の最新予定リスト（`viewModel.remoteEvents`）
- 各行の左ボーダー色でステータス表示:
  - `pending` / `alerting` → `.owlAmber`
  - `dismissed_complete` → `.statusSuccess`
  - `dismissed_skip` → `.statusSkipped`
  - `missed` / `expired` → `.statusDanger`
  - `snoozed` → `.statusWarning`
- データ未取得時: 「まだ予定が届いていません」のPlaceholder
- エラー時: 「つながれませんでした。引っ張って更新してみてください」

**UI構造:**
```
ScrollView
  VStack
    ヘッダー（「お母さんの今日のご予定」+ 最終同期時刻）
    ForEach(remoteEvents) { RemoteEventRow }
    空状態Placeholder
  .refreshable { await viewModel.refresh() }
```

### 3. FamilySendTab.swift（新規作成）

**表示内容:**
テンプレートカードのグリッド（2列）:
```
💊 お薬の時間   🏥 病院へ行く
🍜 ご飯の時間   🛌 お昼寝して
🚶 散歩の時間   📞 電話してね
✏️ 自由に入力    （空）
```

カードをタップ → 時刻選択シートを表示 → 確認 → 送信

**時刻選択シート:**
```
[☀️ 朝（8:00）] [🕛 昼（12:00）] [🌙 夜（19:00）]
[⏱ 15分後] [⏱ 30分後] [⏱ 1時間後]
[📅 細かく設定する] → DatePicker
[🦉 お届けする] ← 確定ボタン（.owlAmber）
```

確定後: Toast「🦉 明日15:00にお母さんにお届けします！」

### 4. FamilySettingsTab.swift（新規作成）

- ペアリング管理（現在のペアリング相手・解除ボタン）
- 「完了したら通知を受け取る」トグル（PRO機能・ロック表示）
- 「PROにアップグレードする」カード（非PROユーザーのみ）
- 「使い方を変える」→ ModeSelectionView へ

### 5. FamilyPairingView.swift（新規作成）

6桁コード入力UI。既存 `FamilyPairingViewModel` を使用。

```
┌──────────────────────────┐
│  🦉 一緒に使いはじめよう  │
│  「自分で使う」側の       │
│  6桁コードを入力してください │
│                          │
│  [○][○][○] - [○][○][○]  │
│                          │
│  [コードを入力してつながる] │
│  [自分でコードを確認する]  │
└──────────────────────────┘
```

---

## FamilyHomeViewModel.swift（新規作成 または 改修）

```swift
@Observable @MainActor
final class FamilyHomeViewModel {
    var remoteEvents: [RemoteEvent] = []
    var isLoading = false
    var errorMessage: String?
    
    private let remoteService = FamilyRemoteService()
    
    func load() async {
        isLoading = true
        do {
            // FamilyRemoteService の既存メソッドを使う
            // （接続できない場合は空配列のまま）
            remoteEvents = try await remoteService.fetchRecentEvents(
                for: /* familyLinkId から取得 */
            )
        } catch {
            errorMessage = "つながれませんでした"
        }
        isLoading = false
    }
    
    func refresh() async {
        await load()
    }
    
    func sendTemplate(title: String, emoji: String, date: Date) async {
        // FamilyRemoteService.sendRemoteEvent() を呼ぶ
    }
}
```

---

## Codex に依頼できる部分

以下のUIコンポーネントは Codex に依頼できる（仕様が明確・データ構造が単純）:

**RemoteEventRow（個別行UI）:**
```
依頼プロンプト:
RemoteEvent（id: UUID, title: String, startDate: Date, status: String, senderName: String）を
表示するSwiftUI Viewを作成してください。
- 左端に4ptの角丸縦ライン（色は status で決まる）
- 絵文字（28pt）+ タイトル（.body.bold）+ 時刻（.caption）の HStack
- status 色のルール: pending/alerting→owlAmber / dismissed_complete→statusSuccess / dismissed_skip→statusSkipped / missed/expired→statusDanger / snoozed→statusWarning
- デザイントークン使用（Spacing, ComponentSize, CornerRadius）
- タップターゲット最低 ComponentSize.eventRow（64pt）
```

**テンプレートカード（FamilySendTab内のカード）:**
```
依頼プロンプト:
FamilySendTabのテンプレートカードコンポーネントを作成してください。
- 絵文字（大：56pt）+ タイトル（.callout）の VStack
- .background(.regularMaterial) + cornerRadius: CornerRadius.md
- タップ時に軽いスケールアニメーション（0.95倍）
- タップターゲット: ComponentSize.templateCard
```

---

## 注意事項

- `actor SyncEngine` に触らない
- `@Observable @MainActor` パターンを守る（ObservableObject 禁止）
- 当事者側の EventKit データには一切書き込まない（家族は Supabase 経由のみ）
- `FamilyRemoteService.swift` の Supabase 接続ロジックに触らない
- PersonHomeView・EventRow・TimeOfDayBackground には触らない

---

## 完成確認

- [ ] FamilyHomeView が TabView で3タブ表示される
- [ ] Tab 0: 予定リストが表示される（データなし時はPlaceholder）
- [ ] Tab 1: テンプレートカードが2列で表示される
- [ ] Tab 1: カードタップ → 時刻選択 → 送信の流れが動く
- [ ] Tab 2: ペアリング状態が表示される
- [ ] ペアリング未完了時: FamilyPairingView が表示される
- [ ] 家族モードの全テキストが「管理・監視」ではなく「サポート・贈る」表現になっている
- [ ] ビルドエラーゼロ
