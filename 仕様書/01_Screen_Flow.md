## STEP 2: 当事者モード（PersonHome）

> ⚠️ **v16アップデート（最重要）**: 本セクションの実装前に、必ず末尾の「[v16 パッチ P-1]」を確認すること。
> （手動入力UIの追加、折りたたみ件数動的変更、0件時ミニタスク、重複検知インターセプト等を追記済み）

### 2-1. 設計原則
- タブレス。1画面に全て集約
- ストレスを与えるUI（カウントダウン常時表示・リセット）を徹底排除

### 2-1-A. SwiftUIビュー階層（⚠️ ZStack崩壊防止・AIへの構造的指示）

AIがASCIIアートを見て独自にZStack/ZIndexをネストすると、ToastやFABが背景の裏に隠れる・キーボードが食い込む・SafeArea崩壊が起きる。以下の構造を**必ず**守ること。

**PersonHomeView の正規階層:**
```swift
ZStack(alignment: .bottomTrailing) {
    // レイヤー1（最背面）: 時間帯グラデーション
    TimeOfDayBackground()
        .ignoresSafeArea()

    // レイヤー2: メインコンテンツ（スクロール可能）
    ScrollView(.vertical, showsIndicators: false) {
        VStack(spacing: 0) {
            OwlSection()           // ふくろう + XPバー（タップ/長押しジェスチャ付き）
            CountdownSection()     // 次の予定カウントダウン
            EventListSection()     // 予定リスト（EventRow繰り返し）
            MiniTaskSection()      // 0件時デイリーミニタスク
        }
    }
    .refreshable { await viewModel.performManualSync() }

    // レイヤー3（最前面）: マイクFAB
    MicFABButton()
        .padding(.trailing, 20)
        .padding(.bottom, 20)
}
// .sheet → MicInputSheet（.medium → フォーカス時.large）
// .sheet → SettingsSheet（.large固定）
// .fullScreenCover → RingingView
// Toast → ToastWindowManager（UIWindowレベル・このZStack外）
```

**RingingView の正規階層:**
```swift
ZStack {
    // 背景: フルスクリーン（SafeArea無視）
    RingingBackground()
        .ignoresSafeArea()
    // コンテンツ: SafeArea内（Dynamic Islandは自動で回避される）
    VStack(spacing: 24) {
        Spacer()
        OwlAnimationSection()      // ふくろう揺れアニメ
        AlarmTitleSection()        // 絵文字 + タイトル
        CircularCountdownView()    // 残り時間リング
        CompleteButton()           // 「完了」ボタン（180pt, .owlAmber）
        SnoozeSkipSection()        // スヌーズ + スキップ（5秒後表示）
        Spacer()
    }
    .padding(.horizontal, 24)
    // SOS進捗バー（最下部固定）
    VStack {
        Spacer()
        SOSProgressBar()
            .padding(.horizontal, 20)
            .padding(.bottom, 16)
    }
}
// Toast → ToastWindowManager（UIWindowレベル・このZStack外）
```

**MicInputSheet の正規階層（⚠️ .presentationDetents キーボード対応）:**
```swift
// 呼び出し元: .sheet(isPresented: $showMicSheet) { ... }
//   .presentationDetents([.medium, .large], selection: $sheetDetent)
//   .onChange(of: isManualInputMode) { if $0 { sheetDetent = .large } }
VStack(spacing: 0) {
    SheetHandleBar()               // 上部グリップ（8×4pt, .secondary色, 角丸4pt）
    MicVisualizerView()            // 音声波形 or スピナー（高さ80pt）
    RecognizedTextView()           // 認識テキスト表示（.title3, 中央寄せ）
    Spacer()
    TextInputFallbackButton()      // 「テキストで入力する」→ isManualInputMode = true
}
// isManualInputMode == true の場合: PersonManualInputView を内部に表示
// ⚠️ detent を .large に変更してからキーボードを出すこと（順番厳守）
```

### 2-2. 画面レイアウト

```
┌─────────────────────────────────┐
│  🦉（進化した姿）         ⚙️    │ ← ふくろうの進化した見た目のみ（数字なし）
│                                 │
│     🦉 こんにちは！             │ ← ふくろう（状態連動アニメ）
│     今日の予定は3つだよ         │   + 時間帯あいさつ（20パターン以上）
│                                 │
│ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─   │
│                                 │
│  【残り60分以上 / 予定なし】     │
│     ふくろう（読書中・穏やか）  │  ← 円形カウントダウンは非表示
│     次は 12:00 お昼の薬         │    大きなテキストのみ。安心感を優先
│                                 │
│  【残り60分未満】                │
│   ┌──────────────────────┐      │
│   │  ╭──────────╮         │      │ ← 円形カウントダウン（ここで初めて出現）
│   │  │ あと 30分  │        │      │   10分未満: 赤+パルス
│   │  ╰──────────╯         │      │
│   │  12:00 お昼の薬        │      │
│   └──────────────────────┘      │
│                                 │
│  【30分以内に複数予定】          │
│   ┌──────────────────────┐      │
│   │  12:00 お昼の薬       │      │ ← 積み重ね表示（アニメ切り替えなし）
│   │  12:05 血圧を測る     │      │
│   └──────────────────────┘      │
│                                 │
│  ⚠️ 電波が届いていません         │ ← オフラインバナー（ネット未接続時のみ）
│  （予定が受け取れません）        │
│                                 │
│  🦉 家族から届きましたよ！       │ ← FamilyInboxBanner（条件付き）
│                                 │
│  ── 今日のご予定 ──────────     │
│  ┌─ ☕ 10:00 カフェ   👱‍♀️長女 ┐│ ← EventRow（左端に大きな絵文字・28pt+）
│  ├─ ⬤ 💊 12:00 お昼の薬       ┤│   絵文字は事前注意（pre-attentive）として機能
│  ├─ ✓ 💊 08:00 朝の薬（済み） ┤│   家族追加: 送信者名バッジ（右端）
│  └──────────────────────────┘  │
│                                 │
│  【今日の予定が0件の場合 ─ メッセージ分岐】      │
│  全完了 → 「🎉 お疲れ様！全部終わったよ！」  │
│  スキップ含む → 「🍵 今日は無理せず休もう。 │
│                明日は明日の風が吹くよ🦉」   │
│  最初から0件 → 「🌸 今日はのんびりだね」   │
│  （絶対に空白のままにしない）               │
│                                 │
│  ─── ここから明日 ─────────     │ ← 常時表示（折りたたみなし）
│  │ 09:00 デイサービス（グレー）  │   明日の予定は最大2件
│  │ 14:00 内科（グレー）         │   今日0件でも物理的にスクロール下に固定
│                                 │
│                          🎤     │ ← FAB（右下固定・72pt）
│                       予定を追加 │   アイコン＋テキスト常時表示
└─────────────────────────────────┘
```

### 2-2-A. EventRow 絵文字アイコン仕様（⚠️ 必須）

> 文字を読む前に絵文字が目に入ることで、次の予定の種類を瞬時に把握できる（pre-attentive処理）。
> ADHD・高齢者が「どれが自分に関係する予定か」を一瞬で判断するための重要な視覚的補助。

```
EventRow レイアウト（左端に絵文字アイコン）:
  │  [絵文字 28pt]  [時刻]  [タイトル]  [送信者バッジ右端]  │

絵文字の割り当てルール:
  - ユーザーが予定を追加する際、NLParserがタイトルから絵文字を自動推定する
  - タイトルに「薬」「服薬」→ 💊
  - タイトルに「病院」「診察」→ 🏥
  - タイトルに「買い物」→ 🛒
  - タイトルに「ゴミ」→ 🗑
  - タイトルに「電話」→ 📞
  - タイトルに「カフェ」「食事」→ ☕
  - その他・判定不能 → 📌（デフォルト）

実装仕様（AIへの指示）:
  - AlarmEvent モデルに `eventEmoji: String?` フィールドを追加
  - NLParserが推定できた場合に設定。ユーザーが手動変更可能（タップ → 絵文字ピッカー）
  - eventEmoji == nil の場合はデフォルト 📌 を表示（空欄にしない）
  - 絵文字のサイズ: .title2 相当（約 24pt）。Dynamic Type 追従
  - 完了（✓）状態: 絵文字を opacity: 0.4 でグレーアウト（テキストに合わせる）
```

### 2-2-B. 大量タスク折りたたみ（⚠️ v14追加: S-11 認知セーフティネット）

> **問題:** 予定が6件以上あると画面に全件表示され「タスクの山」として認知的オーバーロードを引き起こす。
> ADHD・高齢者にとって「たくさんある」という視覚情報だけでパニックになり、アプリを閉じる原因になる。

**直近3件表示 + 折りたたみルール:**

```
「── 今日のご予定 ──────────」の下に表示されるEventRowのルール:

  直近3件（時刻の近い順）: 常時表示（折りたたみなし）
  4件目以降: 折りたたみ表示

  折りたたみボタン（条件付き）:
  ┌─ 💊 12:00 お昼の薬 ────────────┐
  ├─ 🗑 15:00 ゴミ出し  ─────────┤
  ├─ 🏥 16:00 病院（内科）───────┤  ← ここまで常時表示（直近3件）
  └──────────────────────────────┘
  　＋ 残り3件を表示　▼          ← 折りたたみボタン（.secondary色・44pt）

  展開後（全件表示）:
  ┌─ 💊 12:00 お昼の薬 ────────────┐
  ├─ 🗑 15:00 ゴミ出し  ─────────┤
  ├─ 🏥 16:00 病院（内科）───────┤
  ├─ 📞 17:00 長男に電話 ─────────┤  ← 展開後に表示
  ├─ 🛒 18:00 夕飯の買い物 ───────┤
  └─ 💊 21:00 夜の薬  ────────────┘
  　▲ 折りたたむ                 ← 閉じるボタン
```

**実装仕様（AIへの指示）:**
- 「直近3件」は `completionStatus == nil`（未完了）の予定のみカウント
  - 完了済みはカウントしない（リスト下部にグレーアウト表示されるため）
- 展開状態は `PersonHomeViewModel.isEventListExpanded: Bool` で管理
- アニメーション: `.transition(.move(edge: .bottom).combined(with: .opacity))` + `.easeInOut(0.3)`
- 折りたたみボタンの文言: 「＋ 残り○件を表示」（○ = 未完了の残り件数）
  - ○ = 0 になったら（全件展開済み）: ボタンを非表示
- 3件以下の場合: 折りたたみボタンは表示しない（全件常時表示）
- `@SceneStorage("isEventListExpanded")` で状態を永続化（アプリ再起動後も維持）
- ⚠️ 完了アニメーション中に件数が変わる場合はアニメーション完了後に再計算すること

**⚠️ v15追加: Dynamic Type extreme（accessibility3〜5）時のフォールバック:**

> Dynamic Type を最大設定にすると1行が画面の1/3〜1/2を占めるため、「直近3件」でも画面から溢れる。
> この場合「3件」という固定件数ではなく「画面に収まる件数」を動的に算出するフォールバックが必要。

```swift
// PersonHomeViewModel 内で実装:
// 通常: 直近3件を表示
// accessibility3〜5 のとき: UIScreen.main.bounds.height の 50% を1行高さ(64pt)で割って件数を算出
// 最低でも1件は常に表示する（0件にはならない）

var maxVisibleEventCount: Int {
    let sizeCategory = UIApplication.shared.preferredContentSizeCategory
    let isExtremeSize = sizeCategory >= .accessibilityLarge  // accessibility3以上
    if isExtremeSize {
        let availableHeight = UIScreen.main.bounds.height * 0.5
        let rowHeight: CGFloat = 64
        return max(1, Int(availableHeight / rowHeight))
    }
    return 3  // 通常は直近3件
}
```

### 2-3. 「0件プレースホルダー」のメッセージ分岐（重要）

`completionStatus` を判定してメッセージを決定:

| 条件 | メッセージ |
|------|-----------|
| 全予定が「完了」 | 「🎉 お疲れ様！全部終わったよ！ふくろうも誇らしいよ」 |
| スキップが含まれる | 「🍵 今日は無理せず休もう。明日は明日の風が吹くよ 🦉」 |
| 最初から予定なし | 「🌸 今日はのんびり過ごしてね」 |

→ 達成感と現実に応じたメッセージ。「全部逃げた日に🎉」という皮肉を絶対に避ける。

**Empty State の次アクション CTA（⚠️ v14追加: A-19）:**

> 0件メッセージを表示した後、何もアクションを提示しないと「読んで終わり」になる。
> ADHDの脳は「次に何をすればいいか」が曖昧だと止まってしまう。メッセージの直下に
> 軽いCTAを1つ置くことで「この流れで○○できる」という行動の橋渡しをする。

| 条件 | CTA（メッセージ直下に表示） |
|------|--------------------------|
| 全予定が「完了」 | 「🌙 明日の予定を追加しておく？」→ FABと同じマイク入力シートを開く |
| スキップが含まれる | 「🦉 体調が戻ったら声で教えてね」→ マイク入力シートを開く（強制しない・さりげなく） |
| 最初から予定なし | 「🎤 何か予定を追加してみよう」→ マイク入力シートを開く |

```
CTAの実装仕様（AIへの指示）:
  - CTAはメッセージ直下に配置（高さ: 44pt 以上、.secondary色のテキストスタイル）
  - ボタンスタイルではなく下線付きテキスト or シェブロン付きテキスト（PlainButtonStyle）
  - タップ → FABと同じ MicInputSheet を開く
  - CTAはあくまで「さりげない提案」。目立たせすぎない（owlAmber背景のボタンにしない）
  - CTAが表示される条件: scrollView の一番下まで見えている（isAtBottom = true）時のみ
    → スクロール中に邪魔にならないよう制御する
```

### 2-4. 「明日の予定」の表示ルール

- 折りたたみはNG
- 区切り線「─── ここから明日 ───」の下に最大2件グレーアウト常時表示
- **今日の予定が0件の場合**: プレースホルダーの後ろに、物理的にスクロールした位置に固定。画面上部にフロートしない。

### 2-5. ふくろうの成長システム（数字なし）

**ストリーク・レベル数字は採用しない。** リセット時の自己嫌悪（RSD）とノイズを防ぐ。

**採用するシステム: ふくろうの見た目の進化のみ**

| XP閾値 | ふくろうの見た目（数字はユーザーに見せない） |
|--------|--------------------------------------|
| 0〜99 XP | ひよこふくろう（小さい） |
| 100〜299 XP | 普通のふくろう |
| 300〜699 XP | りっぱなふくろう |
| 700〜 XP | 長老ふくろう（貫禄あり） |

- XPは裏側のロジックのみ。UIには**ふくろうの見た目の変化だけ**を出す
- ユーザーは「あれ、ふくろうが変わった？」と有機的に発見する

**XP獲得ルール（デイリーキャップあり）:**

| XP獲得条件 | XP | 備考 |
|-----------|-----|------|
| アラームを「完了」で止める | +10 XP | |
| 「スキップ」を選ぶ（正直申告） | +3 XP | |
| 予定を**入力した瞬間** | +2 XP | 即時付与（v14追加・下記参照） |
| 予定を追加し**かつ完了した** | +5 XP | 追加時点では付与しない（XPファーム防止） |

- ~~「アプリを開いた +1 XP/日」~~ → **削除**（無意味な行動を誘発する）
- **デイリーキャップ: 1日最大 50 XP**（無限稼ぎ防止）
- 予定追加XPは完了時に遅延付与（追加→即削除ではXP不付与）

**⚠️ v14変更: 予定入力に +2 XP 即時付与を追加（ADHD 行動心理学に基づく）:**

> ADHDの脳は「今やったこと（予定の入力）」に対して「即時報酬」がないと、
> 入力自体を面倒くさがってやらなくなる（先延ばし行動の典型）。
> **入力した瞬間に少し褒めることが、重い腰を上げるトリガーになる。**
>
> - 入力完了ボタンタップ直後: 「+2 ⭐ ゲット！」の小さなフィードバック（スナックバーorトースト）
> - ふくろうが小さくジャンプ（入力歓迎アニメーション）
> - XPファーム防止: 入力XP（+2）はデイリーキャップ50XPに含める
> - 入力直後削除: 削除した場合は入力XP（+2）を取り消す（完了XP +5 は影響なし）

**月次サマリー（月末に1回）:** 「今月は25回できたね！」とふくろうが伝える。

**SNSシェアボタン（⚠️ Phase F実装）:**
月次サマリー表示時に ShareLink ボタンを表示する。
```
月次サマリー画面 下部:
  ┌─────────────────────────────────────────┐
  │  🦉 今月もよく頑張りました！             │
  │  25回アラームを止めました               │
  │                                         │
  │  ┌─────────────────────────────────┐   │
  │  │  🦉 ふくろう（今の見た目）       │   │ ← シェア用画像（生成）
  │  │  今月25回達成！                 │   │   ふくろうの現在の進化形 + 月の実績
  │  │  #忘れ坊アラーム #ADHD          │   │
  │  └─────────────────────────────────┘   │
  │                                         │
  │  [📤 シェアする]                        │ ← ShareLink（iOS 16+）
  └─────────────────────────────────────────┘

実装（AIへの指示・Phase F）:
  - `ShareLink(item: summaryImage, subject: Text("今月も頑張りました！"), message: Text("..."))`
  - summaryImage: ふくろう現在形のアイコン + 月の完了回数を合成した UIImage
  - ふくろう進化（XP閾値到達）時にも同様の ShareLink ボタンを表示
    「○○（owlName）が進化しました！」 + 進化後のふくろう画像
  - SNS用テキストには予定のタイトルを含めない（プライバシー保護）
  - ハッシュタグ提案: 「#忘れ坊アラーム #ADHD #できた」

  ⚠️ **v14追加: シェア画像にウォーターマーク（アプリ導線）を必ず入れること**
  バズったところでアプリへの導線がなければダウンロードにつながらない。

  シェア用画像の合成レイヤー（下から順）:
  ┌─────────────────────────────────────────┐
  │  [ふくろう現在の進化形イラスト 大]        │  ← 中央上部
  │  今月25回できたよ！                      │  ← .title2.bold、owlAmber色
  │  ○○（owlName）と一緒にがんばりました    │  ← .body
  │  ─────────────────────────────────────  │
  │  [アプリアイコン 32pt]  忘れ坊アラーム  │  ← 下部フッター（背景: owlBrown 薄め）
  │  App Store で無料ダウンロード            │  ← .caption、.secondary
  └─────────────────────────────────────────┘

  実装仕様（⚠️ v15変更: `UIGraphicsImageRenderer` → `ImageRenderer`（SwiftUI）に変更）:

  > **変更理由:** `UIGraphicsImageRenderer` は UIKit ベースで SwiftUI コンポーネントとの連携が複雑。
  > iOS 16+ では SwiftUI の `ImageRenderer` を使うことで、SwiftUI View を直接 UIImage に変換できる。
  > コードがシンプルになりカラースキームや Dynamic Type の適用も自然に行える。

  ```swift
  // Views/Shared/ShareSummaryCardView.swift（新規作成）
  // ShareLink に渡す画像を生成する専用 SwiftUI View

  struct ShareSummaryCardView: View {
      let owlStageName: String   // 例: "owl_stage2_happy"
      let completionCount: Int   // 今月の完了回数
      let owlName: String        // ふくろうの名前

      var body: some View {
          VStack(spacing: 16) {
              // ふくろうイラスト
              Image(owlStageName)
                  .resizable().scaledToFit().frame(width: 200)

              Text("今月\(completionCount)回できたよ！")
                  .font(.title2.bold()).foregroundColor(.owlAmber)

              Text("\(owlName)と一緒にがんばりました")
                  .font(.body)

              // アプリウォーターマーク（フッター）
              HStack(spacing: 8) {
                  Image(uiImage: UIImage(named: "AppIcon") ?? UIImage())
                      .resizable().frame(width: 32, height: 32).cornerRadius(8)
                  VStack(alignment: .leading) {
                      Text("忘れ坊アラーム").font(.caption.bold())
                      Text("App Store で無料ダウンロード").font(.caption).foregroundColor(.secondary)
                  }
              }
              .padding()
              .background(Color.owlBrown.opacity(0.15))
              .cornerRadius(12)
          }
          .padding(24)
          .background(Color.secondarySystemBackground)
          .frame(width: 360, height: 360)  // 1080×1080px @ 3x
      }
  }

  // 使い方（月次サマリー画面から）:
  @MainActor
  func generateShareImage() async -> UIImage {
      let view = ShareSummaryCardView(
          owlStageName: appState.owlStageName,
          completionCount: appState.monthlyCompletionCount,
          owlName: appState.owlName
      )
      let renderer = ImageRenderer(content: view)
      renderer.scale = 3.0  // @3x = 1080×1080px
      return renderer.uiImage ?? UIImage()
  }
  ```

  - フッター部分の背景色: `owlBrown.opacity(0.15)`（主コンテンツを邪魔しない）
  - アプリアイコン: `UIImage(named: "AppIcon")` を 32pt でリサイズして配置
  - 「App Store で無料ダウンロード」テキストは固定文言（日本語のみ）
  - 合成後の画像サイズ: 1080×1080px（正方形・Instagram/X 最適・@3xで実現）
  - ⚠️ `ImageRenderer` は `@MainActor` での実行が必要（バックグラウンドスレッド不可）
```

### 2-6. ふくろうの状態定義

| 状態 | 条件 | ふくろうの表現 |
|------|------|--------------|
| 元気 | 最近7日以内にXP獲得あり | ぱっちり目、翼を広げる |
| 普通 | 通常時 | 通常 |
| 眠そう | 残り60分以上 or 今日の予定なし | 半目、読書中 |
| 心配 | 直近予定が5分以内で未対応 | 目を大きく |
| 特別 | XP閾値到達時 / 月次サマリー | 特別アニメーション |

あいさつ文は時間帯×ふくろう状態で20パターン以上。

### 2-7. 予定の「完了」と「スキップ」の定義

**完了:** RingingViewで「完了」→ XP +10 → グレーアウト → リスト下部
**スキップ:** RingingViewで「今回はパス」→ XP +3 → 「今日はゆっくりしてね」→ 異なる色でグレーアウト → 家族ダッシュボードに「❌ お休み」同期
**手動完了（アラームなし予定）:** EventRowを長押し or スワイプ → 「完了にする」
**削除:** RingingViewには絶対に出さない。スワイプ/長押しメニューの中にのみ存在。削除時は確認ダイアログ「この予定を削除しますか？（iPhoneのカレンダーからも消えます）」必須。
**完了状態のリセット:** 翌日00:00に自動リセット。繰り返し予定は消えない。

### 2-8. 変動比率スケジュール（予測不可能な報酬）

| 確率 | リアクション |
|------|-------------|
| 75% | 通常: ふくろうジャンプ + 褒め言葉 |
| 20% | レア: 翼バタバタ + 特別褒め言葉 + 星パーティクル |
| 5% | スペシャル: サングラスふくろう + ファンファーレ + 全画面花火 |

### 2-9. 時間帯背景（ダークモード互換）

透明度15〜20%のオーバーレイで実装:

| 時間帯 | 色調 |
|--------|------|
| 5:00-10:59 | soft blue, opacity 0.15 |
| 11:00-16:59 | pale yellow, opacity 0.12 |
| 17:00-20:59 | warm orange, opacity 0.15 |
| 21:00-4:59 | soft indigo, opacity 0.20 |

### 2-10. マイクFAB
- 「🎤 予定を追加」（アイコン＋テキスト常時表示・72pt）
- タップ → ハーフシート
- 初回のみコーチマーク

**初回マイクタップ時のプリプロンプト（⚠️ 必須）:**
```
マイク権限が未取得の場合、システムダイアログの前に1画面挟む:

  ┌─────────────────────────────┐
  │  🎤                         │
  │  ふくろうがあなたの声を      │
  │  文字にするためにマイクを    │
  │  使います                   │
  │                             │
  │  ✅ 録音はサーバーに         │
  │     送られません            │
  │  ✅ iPhoneの中だけで         │
  │     処理されます            │
  │                             │
  │  [マイクを許可する]         │ ← タップ → AVAudioSession権限ダイアログ
  │  [キャンセル]               │
  └─────────────────────────────┘

許可された場合: MicInputSheetを表示
拒否された場合: 「設定→プライバシー→マイクから許可できます」を表示してシートを閉じる
```

> ⚠️ **v16追加（P-1-3）: MicInputSheet内の「テキストで入力する」ボタンからPersonManualInputViewへ遷移する仕様が追加。末尾 P-1-3 を参照。**

### 2-10-B. ふくろう長押し → 設定アクセス（高齢者向け代替導線）

「歯車アイコン」が認識しにくい高齢者向けに、ふくろうを長押しすると設定が開く導線を追加する。

**仕様:**
- PersonHomeのふくろうImageViewに `.onLongPressGesture(minimumDuration: 0.8)` を設定
- 発動時: `.impact(.medium)` Haptic + ふくろうが驚く表情に一瞬変化（0.3秒）
- その後: 設定シートが `.sheet` で表示される（歯車アイコンと同じシート）
- 長押しヒントとして初回のみ「🦉 長く押すと設定が開きます」トーストを表示（3秒後に自動消去）

### 2-10-C. ふくろうとの日常インタラクション（愛着形成・長期継続率向上）

**目的:** タスク完了とは無関係な「遊びの余白」を作り、数ヶ月後に「ただの時計」になることを防ぐ。
ふくろうはアラームツールであると同時に「育てるペット」でもある。

**タップ反応 `.onTapGesture`（ランダム4種・シングルタップ）:**
| 確率 | リアクション | 実装 |
|------|------------|------|
| 40% | ふくろうが `happy` 表情に0.2秒変化 + `.owlBounce` アニメ | 表情切り替え + Spring animation |
| 30% | 「つつかれた！🦉」トースト（3秒） | ToastWindowManager.show() |
| 20% | ふくろうが `normal` のまま首を小さく傾ける（rotation 15°往復0.3秒） | `.rotationEffect` + repeatCount(1) |
| 10% | 特別メッセージ「今日も一緒にがんばろうね 🌟」トースト | 1日1回のみ発火（UserDefaultsで制御） |

**シェイク反応（CoreMotion / motionBegan）:**
- デバイスを振ると → ふくろうが `worried` 表情 + 回転エフェクト（`.rotationEffect(360°)` 0.5秒）
- ランダムな一言をトーストで表示（3秒）:
  - 「ふらふら…🌀」
  - 「酔いそうだよ！」
  - 「もう少しやさしくして！」
  - 「わあ、地震かと思った」
- 実装: `UIResponder.motionBegan(_:with:)` を RootView で受け取り、AppStateに `owlShakeCount` を持つ

**10回タップ隠しイベント（Easter Egg）:**
- 1分以内に10回タップ → `sunglasses` 表情 + 「実はカッコいいやつだよ 😎」トースト
- `UserDefaults[owlTapCount]` と `owlTapLastTime` で管理（1分以上経過したらリセット）

**アニメーション定義:**
```swift
// owlBounce: 02_Design_System.md に定義済み
// 首傾け
withAnimation(.interpolatingSpring(stiffness: 200, damping: 10)) {
    owlNeckAngle = 15
}
DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
    withAnimation(.interpolatingSpring(stiffness: 200, damping: 10)) {
        owlNeckAngle = 0
    }
}
// 回転（シェイク）
withAnimation(.linear(duration: 0.5)) {
    owlRotation += 360
}
```

> **注意:** 長押し（0.8秒）は設定を開く（2-10-B）。タップ（通常）のみ上記リアクション。ジェスチャの競合に注意。

### 2-11. カレンダー連携の説明はUIで伝える
- 削除時: 「この予定を削除しますか？（iPhoneのカレンダーからも消えます）」ダイアログ
- SyncEngine変更検知時: 次回起動時にふくろうトースト「カレンダーで変更があったから直しておいたよ！」

### 2-12. オフライン表示
- NWPathMonitor でネット監視
- オフライン時: 上部に黄色バナー「⚠️ 電波が届いていません（予定が受け取れません）」
- IT用語は使わない

---

## STEP 4: 家族モード（FamilyHome）

### 4-1. 設計原則
- 「親に関する情報」が主役
- 安心の可視化（送った予定がちゃんと届いた・止めた）
- 重複送信防止

### 4-2. タブ構成
| Tab | ラベル | アイコン | 内容 |
|-----|--------|---------|------|
| 0 | おやの今日 | house.fill | 親の予定一覧 + 同期状態 |
| 1 | 予定を送る | paperplane.fill | テンプレ入力 + 送信 |
| 2 | 設定 | gearshape.fill | ペアリング・PRO・モード切替 |

### 4-3. Tab 0: おやの今日

**同期状態:**
- `pending`: 🔄 青（Supabase送信済み・親端末未受信）
- `synced`: ✓ 緑（親のアプリがダウンロード済み）
- `failed`: ✗ 赤 + 再送ボタン
- `alerting`: 🔔 オレンジ（今アラームが鳴っている）
- `dismissed_complete`: ✓✓ 濃緑（「完了！」押下）
- `dismissed_skip`: ❌ グレー（「今回はパス」押下）
- `expired`: ⚠️ 黄（送信期限切れ）

**pending の有効期限（TTL）:**
`pending` 状態のまま予定の `startDate + 1時間` を経過した場合、そのイベントを `expired` 扱いにする。
- 家族側 Tab 0 の表示: 「⚠️ お母さんの端末に届きませんでした」
- 親が後からオンラインになっても、`expired` 予定は受信を拒否する（EventKit への登録を行わない）
- `expired` のまま翌日になった場合はリストから自動削除する
- 理由: 昨日の14:00の病院予定が翌日に届いてもパニックを招くだけで意味がない

**Last Seen（親のオフライン検知）:**
- 🟢 1時間以内 / 🟡 1〜6時間 / 🔴 6時間以上 → **PRO機能（🔒表示）**
- 6時間以上かつ予定時刻が迫っている → 「直接ご確認をおすすめします」

### 4-4. Tab 1: 予定を送る

- テンプレートグリッド: 💊薬 / 🗑ゴミ出し / 🏥病院 / 📞電話 / 🛒買い物 / ✏️自由入力
- 重複確認: 送信前に「同じ日時に息子さんから似た予定があります」
- 確認メッセージ（ポジティブ宣言）: 「🦉 明日15:00にお母さんにお知らせします！」

### 4-5. Tab 2: 設定
- ペアリング管理
- 「お母さんが完了したら通知を受け取る」設定（PRO）
- PROアップグレードカード
- 「使い方を変える」→ ModeSelectionへ

### 4-6. 家族モードのUXライティング指針（⚠️ v14追加）

> **「家族が親をコントロールしたい」というニーズに対して、親の自尊心を奪わない言葉選びが命になる。**
> アプリが「監視ツール」や「管理ツール」に見えてしまうと、
> 親が「子どもに監視されている」と感じてアプリを使わなくなる。

**⚠️ AIへの強制指示: 家族モードの画面テキストは必ず以下の言い換えを使うこと。**

| ❌ 使用禁止（コントロール表現） | ✅ 使用必須（サポート表現） |
|-------------------------------|--------------------------|
| 「親の予定を管理する」 | 「お母さんの生活をサポートする」 |
| 「予定を設定してあげる」 | 「リマインダーをお届けする」「予定を贈る」 |
| 「確認する」「監視する」 | 「様子を気にかける」「つながっていることを感じる」 |
| 「完了させる」「止めさせる」 | 「できた！を一緒に喜ぶ」 |
| 「通知を受け取る」（Push通知設定） | 「お母さんが完了したら一緒に喜べるようにする」 |
| 「親がアラームをスキップした」 | 「お母さんが今日お休みしたみたい」 |
| 「アクティビティログ」「履歴」 | 「これまでの『できた！』の記録」 |
| 「未完了」「ステータス」 | 「まだお知らせが届いていないようです」 |

**トーン原則（AIへの指示）:**
- 主体は常に「親」。家族は「サポートする側」「贈る側」
- 動詞は「〜してあげる」より「〜をお届けする」「〜が届く」の受け身・贈与表現
- 達成を「させた」ではなく「一緒に喜んだ」として表現する
- 失敗（スキップ・未完了）は「異常事態」ではなく「今日の様子」として伝える

---

## STEP 10: オンボーディング（トークンベース決定版）

> ⚠️ **v16アップデート（最重要）**: 本セクションの実装前に、必ず末尾の「[v16 パッチ P-6]」を確認すること。
> （WidgetGuideViewの復活、通知権限剥奪リカバリ、Hapticデモ追記等）

### 10-0. オンボーディング共通レイアウトルール（AIへの指示）

**全オンボーディング画面はこのテンプレートを基本とする。マジックナンバー禁止。**

```swift
// オンボーディング画面共通テンプレート
VStack(spacing: 0) {
    Spacer()                                        // 上部 可変余白（画面高さに追従）

    // ── イメージ・アイコン領域 ──────────────────
    owlImageOrIcon                                  // 高さ 120pt（ふくろう）/ 56pt（記号）

    Spacer().frame(height: Spacing.xl)              // 32pt（画像 ↔ テキスト間）

    // ── テキスト領域 ───────────────────────────
    VStack(spacing: Spacing.sm) {                   // 8pt（タイトル ↔ サブタイトル間）
        Text(title)
            .font(.title2).bold()
            .multilineTextAlignment(.center)
        Text(subtitle)
            .font(.body)
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.center)
    }
    .padding(.horizontal, Spacing.md)               // 16pt（テキスト左右マージン）

    Spacer()                                        // テキスト ↔ ボタン間 可変余白

    // ── ボタン領域 ─────────────────────────────
    VStack(spacing: Spacing.md) {                   // 16pt（ボタン間）
        primaryButton
            .frame(height: 56)                      // ⚠️ 56pt 固定（例外なし）
            .padding(.horizontal, Spacing.md)       // 16pt
        secondaryOrSkipButton
            .frame(minHeight: 44)                   // Apple HIG 最小タップターゲット
    }
    .padding(.bottom, Spacing.xl)                   // 32pt（ボタン下余白・ホームインジケーター回避）
}
// ❌ 禁止: VStack(spacing: 13), .padding(11), .frame(height: 50) などマジックナンバー
```

**フォールバック制約（デバイスサイズ・Dynamic Type 拡大時）:**
- 横マージン `Spacing.md`（16pt）は最小値。SE 第3世代（幅 375pt）でも下回らない
- テキスト領域は `Spacer()` で上下を吸収し、文字数・フォントサイズに対応する
- ボタン 56pt は Dynamic Type の影響を受けない（`.font(.body)` を使用）

---

### 10-1. 画面遷移全体図

**当事者モード（体験と愛着のフロー: 6画面）:**
```
ModeSelectionView
  → PersonWelcomeView     (ふくろうとの出会い)
  → PermissionsCTAView    (通知 → カレンダー 権限プリプロンプト・2ステップ)
  → OwlNamingView         (命名・愛着の形成)
  → MagicDemoWarningView  (音が出ます警告)
  → MagicDemoView         (Aha体験！コアループ体験)
  → WidgetGuideView       (ウィジェット設置・継続率担保)
  → PersonHomeView
```

**家族モード（共感と納得のフロー: 5画面）:**
```
ModeSelectionView
  → FamilyPainQuestionView  (課題のヒアリング)
  → FamilySolutionView      (解決策と価値の提示)
  → FamilyPairingIntroView  (ペアリング説明 + プライバシー同意)
  → FamilyPairingActiveView (リンク送信 / 6桁コード実行)
  → FamilyPaywallView       (納得感のピークで課金オファー)
  → FamilyHomeView
```

**設計方針（AIへの指示）:**
- 当事者モード: 「読ませる説明」をゼロにし、「1画面1アクション」でテンポよく進める。MagicDemoでコアループ（アラームが鳴る → RingingViewで完了 → XP獲得）を体験させることが最大の目的。
- 家族モード: いきなりペアリングや課金を要求しない。親の物忘れへの不安に共感し、解決策を理解した上でペアリング → 課金の順序を守る（コミットメント・オンボーディング）。

---

### 10-2. ModeSelectionView（モード選択）

**⚠️ 既存ユーザーとの分岐（AIへの指示・必須）:**

`appState.isOnboardingComplete` の値でボタンラベルと遷移先を切り替えること。

| 条件 | ボタンラベル | 遷移先 |
|------|------------|------|
| `isOnboardingComplete == false`（初回） | 「🦉 はじめる」 | オンボーディング全フロー（PersonWelcomeView or FamilyPainQuestionView） |
| `isOnboardingComplete == true`（既存・モード変更時） | 「この設定で使う」 | PersonHomeView または FamilyHomeView へ**直行**（オンボーディングスキップ） |

```
┌─────────────────────────────────┐   .background(.ultraThickMaterial)
│  padding(.top, Spacing.xl)      │   32pt 上余白
│                                 │
│        🦉（大・中央）           │   高さ 160pt（モード選択はやや大きめ）
│                                 │
│  Spacer().frame(height:         │
│       Spacing.lg)               │   24pt
│                                 │
│  どなたがお使いですか？         │   .title2.bold、中央
│                                 │
│  Spacer().frame(height:         │
│       Spacing.md)               │   16pt
│                                 │
│  ┌─────────┐  ┌─────────┐      │   2カード横並び
│  │  👤     │  │  👨‍👩‍👧   │      │   各カード高さ 100pt
│  │ 自分で  │  │ 家族の  │      │   spacing: Spacing.md（16pt）
│  │ 使う    │  │ 見守り  │      │   cornerRadius: 16pt
│  └─────────┘  └─────────┘      │   選択中: .owlAmber border 2pt
│                                 │
│  padding(.horizontal,           │
│       Spacing.md)               │   16pt
│                                 │
│  [🦉 はじめる / この設定で使う]│   高さ 56pt、.owlAmber、テキスト黒
│                                 │
│  padding(.bottom, Spacing.xl)   │   32pt
└─────────────────────────────────┘
```

```swift
// ModeSelectionView 実装
Button(appState.isOnboardingComplete ? "この設定で使う" : "🦉 はじめる") {
    if appState.isOnboardingComplete {
        appState.appMode = selectedMode
        appState.navigationPath.append(selectedMode == .person ? .personHome : .familyHome)
    } else {
        appState.appMode = selectedMode
        appState.navigationPath.append(selectedMode == .person ? .personWelcome : .familyPainQuestion)
    }
}
// ⚠️ 既存ユーザーの場合、isOnboardingComplete を再度 true に設定しない（二重更新禁止）
```

> 詳細: P-6-5（同ファイル末尾）も参照。

---

### 10-3. 当事者フロー（7画面・各画面トークンベースレイアウト）

#### 10-3-1. PersonWelcomeView（ふくろうとの出会い）

```
┌─────────────────────────────────┐
│  Spacer()                       │   可変（上部余白）
│                                 │
│  🦉（羽ばたきアニメーション）   │   高さ 120pt、3秒ループ
│                                 │
│  Spacer().frame(height:         │
│       Spacing.xl)               │   32pt
│                                 │
│  忘れても大丈夫。               │   .title2.bold、中央
│  ふくろうが代わりに             │
│  覚えておきます。               │
│                                 │
│  Spacer()                       │   可変（テキスト ↔ ボタン間）
│                                 │
│  [🦉 はじめる]                  │   高さ 56pt、.owlAmber、テキスト黒
│                                 │   padding(.horizontal, Spacing.md)
│  padding(.bottom, Spacing.xl)   │   32pt
└─────────────────────────────────┘
```

- サブテキストなし（シンプルさ優先）
- ボタンは1つのみ（迷わせない）

#### 10-3-2. PermissionsCTAView（通知 → カレンダー 権限プリプロンプト）

> iOSはシステムダイアログを一度「許可しない」されると、設定アプリ以外から再要求できない。
> 理由なく連続で要求するとユーザーが恐怖を感じて拒否する。必ずプリプロンプトを挟む。

**① 通知プリプロンプト（1画面目）:**
```
┌─────────────────────────────────┐
│  Spacer()                       │
│                                 │
│  🦉（大・中央）                 │   高さ 120pt
│                                 │
│  Spacer().frame(height:         │
│       Spacing.xl)               │   32pt
│                                 │
│  VStack(spacing: Spacing.sm) {  │   8pt
│    マナーモードでも              │   .title2.bold
│    必ずお知らせするために        │
│    「通知」を使います            │
│  }                              │
│  .padding(.horizontal,          │
│       Spacing.md)               │   16pt
│                                 │
│  Spacer().frame(height:         │
│       Spacing.lg)               │   24pt
│                                 │
│  VStack(spacing: Spacing.sm) {  │   8pt（注意事項）
│  📵 通知をオフにすると           │   .body、.secondary
│    アラームが鳴りません          │
│  }                              │
│  .padding(.horizontal,          │
│       Spacing.md)               │   16pt
│                                 │
│  Spacer()                       │   可変
│                                 │
│  VStack(spacing: Spacing.md) {  │   16pt
│    [通知を許可する]              │   56pt、.owlAmber
│    あとで →                     │   minHeight 44pt、.secondary
│  }                              │
│  .padding(.horizontal,          │
│       Spacing.md)               │   16pt
│  .padding(.bottom, Spacing.xl)  │   32pt
└─────────────────────────────────┘
```

タップ: `[通知を許可する]` → `UNUserNotificationCenter.requestAuthorization()`

**② カレンダープリプロンプト（通知許可後に次画面として表示）:**
```
┌─────────────────────────────────┐
│  Spacer()                       │
│                                 │
│  📅（56pt アイコン）            │
│                                 │
│  Spacer().frame(height:         │
│       Spacing.xl)               │   32pt
│                                 │
│  いつもの予定を読み込むために   │   .title2.bold
│  「カレンダー」を使います       │
│  .padding(.horizontal,          │
│       Spacing.md)               │   16pt
│                                 │
│  Spacer().frame(height:         │
│       Spacing.lg)               │   24pt
│                                 │
│  VStack(spacing: Spacing.sm) {  │   8pt（メリット一覧）
│  ✅ iPhoneにある予定が自動      │   .body
│     でアラームになります        │
│  ✅ 他のカレンダーアプリと      │
│     同期されます               │
│  }                              │
│  .padding(.horizontal,          │
│       Spacing.md)               │   16pt
│                                 │
│  Spacer()                       │   可変
│                                 │
│  VStack(spacing: Spacing.md) {  │   16pt
│    [カレンダーを連携する]        │   56pt、.owlAmber
│    あとで →                     │   minHeight 44pt、.secondary
│  }                              │
│  .padding(.horizontal,          │
│       Spacing.md)               │   16pt
│  .padding(.bottom, Spacing.xl)  │   32pt
└─────────────────────────────────┘
```

タップ: `[カレンダーを連携する]` → `EKEventStore.requestFullAccessToEvents()`

拒否された場合:
- 「後で設定から変更できます」を表示してスキップ可能
- PersonHomeView 起動後、必要な権限が不足していればバナーで再案内

#### 10-3-3. OwlNamingView（ふくろう命名）

> **設計根拠（Finch分析）:** 名前を一度でも付けると「私のふくろう」になり、アプリを開くことが義務から楽しみに変わる。離脱率を下げるために最も効果的な1画面。

```
┌─────────────────────────────────┐
│  Spacer()                       │
│                                 │
│  🦉（ひよこ・ぱちぱち瞬き）     │   高さ 120pt
│                                 │
│  Spacer().frame(height:         │
│       Spacing.xl)               │   32pt
│                                 │
│  このふくろうに名前をつけてね   │   .title2.bold、中央
│  .padding(.horizontal,          │
│       Spacing.md)               │   16pt
│                                 │
│  Spacer().frame(height:         │
│       Spacing.lg)               │   24pt
│                                 │
│  TextField("ふくろう", text: …) │   高さ 52pt、.font(.title3)
│  .padding(.horizontal,          │   cornerRadius: 10pt（token）
│       Spacing.md)               │   16pt
│                                 │
│  Spacer().frame(height:         │
│       Spacing.sm)               │   8pt
│                                 │
│  🦉「よろしくね！○○って         │   onChange でリアルタイム反映
│    呼んでもらえるの嬉しいよ！」 │   .body、.secondary、中央
│  .padding(.horizontal,          │
│       Spacing.md)               │   16pt
│                                 │
│  Spacer()                       │   可変
│                                 │
│  VStack(spacing: Spacing.sm) {  │   8pt
│    [🦉 さあ、はじめよう！]      │   56pt、.owlAmber、テキスト黒
│    名前は後から変えられます      │   .caption、.secondary、minHeight 44pt
│  }                              │
│  .padding(.horizontal,          │
│       Spacing.md)               │   16pt
│  .padding(.bottom, Spacing.xl)  │   32pt
└─────────────────────────────────┘
```

**実装仕様（AIへの指示）:**
- `owlName: String` を `AppState` に追加（UserDefaults永続化）。デフォルト値: 「ふくろう」
- 名前未入力（空文字）のままボタンを押した場合: デフォルト「ふくろう」として扱う
- PersonHomeViewのふくろうあいさつ文に `owlName` を埋め込む: 「○○、おはよう！」
- 名前は設定画面から変更可能（STEP 15-3 の設定項目に「ふくろうの名前」を追加）

#### 10-3-4. MagicDemoWarningView（「音が出ます」警告）

> iOS には `isMuted` を取得する公開 API が存在しない。「ボタンを押した瞬間に爆音が出る」トラブルを防ぐ唯一の手段は、事前に明示的な警告を出すことだけ。ボタンに小テキストを添えるだけでは不十分。**1枚の専用確認画面が必須。**

```
┌─────────────────────────────────┐
│  Spacer()                       │
│                                 │
│  🔊（56pt スピーカーアイコン）  │
│                                 │
│  Spacer().frame(height:         │
│       Spacing.xl)               │   32pt
│                                 │
│  VStack(spacing: Spacing.sm) {  │   8pt
│    これから音が鳴ります          │   .title2.bold
│    今、周りに人がいますか？      │   .body
│    イヤホンを使うか、            │
│    音量を確認してから            │
│    ボタンを押してください        │
│  }                              │
│  .padding(.horizontal,          │
│       Spacing.md)               │   16pt
│                                 │
│  Spacer()                       │   可変
│                                 │
│  VStack(spacing: Spacing.md) {  │   16pt
│    [🔔 鳴らしてみる！]          │   56pt、.owlAmber、テキスト黒
│    音を出さずにスキップ →        │   minHeight 44pt、.secondary
│  }                              │
│  .padding(.horizontal,          │
│       Spacing.md)               │   16pt
│  .padding(.bottom, Spacing.xl)  │   32pt
└─────────────────────────────────┘
```

**実装仕様（AIへの指示）:**
- MagicDemoView の直前に NavigationStack で表示する（`.sheet` ではなく遷移）
- 「鳴らしてみる！」タップ → MagicDemoView へ遷移（通常デモフロー①②）
- 「音を出さずにスキップ →」タップ → MagicDemoView（Hapticのみ・フロー③）
- 「鳴らしてみる！」ボタンタップ時に `.impact(.medium)` Haptic 1回（注意喚起）

#### 10-3-5. MagicDemoView（Aha体験・マナーモード貫通デモ）

> このアプリの核心価値「マナーモードを貫通する」を、インストール直後の30秒で体験させる。これが初動離脱防止とSNS拡散の起点。

**【実装必須】フォアグラウンドでの通知表示設定:**
```swift
// AppDelegate.swift（または ForegroundNotificationDelegate.swift）
extension AppDelegate: UNUserNotificationCenterDelegate {
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound, .list])  // フォアグラウンド中でもバナー・音表示
    }
}
```

**【実装注意】AlarmKit の最小リードタイム:**
「3秒後に発火」が最小リードタイム制約に引っかかる場合は AVAudioPlayer 直接再生にフォールバック。フォールバック実装を先に用意しておくこと。

```
┌─────────────────────────────────┐
│  Spacer()                       │
│                                 │
│  🦉（通常ポーズ）               │   高さ 120pt
│                                 │
│  Spacer().frame(height:         │
│       Spacing.xl)               │   32pt
│                                 │
│  VStack(spacing: Spacing.sm) {  │   8pt
│    本当にマナーモードでも        │   .title2.bold
│    鳴るか試してみよう！          │
│    スマホをマナーモードにして    │   .body、.secondary
│    下のボタンを押してみてください│
│  }                              │
│  .padding(.horizontal,          │
│       Spacing.md)               │   16pt
│                                 │
│  🔊 音量を上げてから押してね     │   .caption、.secondary（常時表示）
│                                 │
│  Spacer()                       │   可変
│                                 │
│  VStack(spacing: Spacing.md) {  │   16pt
│    [🔔 3秒後にアラームを鳴らす] │   56pt、.owlAmber
│    あとで試す →                  │   minHeight 44pt、.secondary
│  }                              │
│  .padding(.horizontal,          │
│       Spacing.md)               │   16pt
│  .padding(.bottom, Spacing.xl)  │   32pt
│                                 │
│  （カウントダウン中）            │
│  🦉「3…2…1…」                  │   .title.bold、中央
│  ※ スマホをしっかり持ってね！   │   .caption、.secondary
└─────────────────────────────────┘
```

**ボタンタップ時の分岐ロジック（outputVolume判定）:**
```
① outputVolume > 0.1 → 通常デモ（3秒後にアラーム発火）

② outputVolume <= 0.1（消音状態とみなす）:
   → 「マナーモードでも鳴るんですよ！AlarmKitは音量設定を無視します。」
      「体験してみてください →」テキスト表示
   → そのまま3秒後にアラーム発火（音が鳴ることをあえて体験させる）

③ 出力デバイスなし（特殊ケース）:
   → Hapticのみデモ（AlarmKitスキップ）
   → 3秒後 UIImpactFeedbackGenerator(.heavy) × 3回
   → 「振動で感じられましたか？これが時間を知らせる感触です 🦉」
   → [わかった！] → PersonHomeView

// ⚠️ isMuted は iOS 公開API非対応のため使用禁止（P-9-8参照）
// ⚠️ outputVolume <= 0.1 をサイレント状態の唯一の判定基準とする
```

**AlarmKit権限プリプロンプト（権限未取得時・必須）:**
```
┌─────────────────────────────────┐
│  🔔                             │   56pt
│  マナーモードでも               │   .title2.bold
│  必ず鳴るアラームを             │
│  使うための許可をください       │
│                                 │
│  VStack(spacing: Spacing.sm) {  │   8pt
│  ✅ 大事な予定の時間に          │   .body
│     確実にお知らせします        │
│  ✅ iPhoneのサイレントモードを  │
│     上書きして音を出します      │
│  📵 許可しないと、              │
│     アラームが鳴りません        │
│  }                              │
│  .padding(.horizontal,          │
│       Spacing.md)               │
│                                 │
│  [アラームを許可する]           │   56pt、.owlAmber
│  [あとで設定する]              │   minHeight 44pt
└─────────────────────────────────┘
```

**フルチュートリアル化（⚠️ 実装フェーズで対応）:**
- デモ用アラームが発火 → RingingView（Stage 2）が通常と同じフローで開く
- 完了ボタンをタップ → OwlCelebrationOverlay → 「+10 XPゲット！」を初回のみ表示
- MagicDemoの +10 XP は本物のXPとして計上する
- デモ後に「♪ 音は無事に鳴りましたか？」確認ダイアログ（P-6-3参照）

#### 10-3-6. WidgetGuideView（ウィジェット設置・継続率担保）

`TabView(selection:)` を使ったカルーセル（スワイプ式紙芝居）UIで実装する。高齢者向けにテキスト大きく・ステップ短く分割。

```
各ページ共通レイアウト:
┌─────────────────────────────────┐
│  padding(.top, Spacing.lg)      │   24pt
│                                 │
│  [プレースホルダー画像]          │   ImageView、横幅 max、アスペクト比 16:9
│  （ホーム画面の操作場面GIF）     │   ⚠️ 後で洋介が実素材を差し替える
│                                 │
│  Spacer().frame(height:         │
│       Spacing.lg)               │   24pt
│                                 │
│  ① ホーム画面の何もない         │   .title3.bold、中央
│    ところを長押しします          │   各ページ1文のみ
│                                 │
│  Spacer().frame(height:         │
│       Spacing.md)               │   16pt
│                                 │
│  ● ○ ○ ○                        │   ページインジケーター（TabViewのdots）
│                                 │
│  HStack(spacing: Spacing.md) {  │   16pt
│    [あとでやる]  [次へ →]        │   各 minHeight 44pt
│  }                              │
│  .padding(.horizontal,          │
│       Spacing.md)               │   16pt
│  .padding(.bottom, Spacing.xl)  │   32pt
└─────────────────────────────────┘
```

ページ構成（4ページ）:
1. 「① ホーム画面の何もないところを長押しします」
2. 「②「+」ボタンをタップします」
3. 「③「忘れ坊アラーム」を探してタップします」
4. 「④ ふくろうをホーム画面に置きます」 → ボタン: `[できた！]`

- 「あとでやる」はいつでも選択可。設定画面の「ウィジェットの設置方法」から再閲覧可能。
- 各ページに1文のみ（箇条書き・説明文なし）。

---

### 10-4. 家族フロー（4画面・各画面トークンベースレイアウト）

#### 10-4-1. FamilyPainQuestionView（課題のヒアリング）

```
┌─────────────────────────────────┐
│  padding(.top, Spacing.lg)      │   24pt
│                                 │
│  どんなことが心配ですか？        │   .title2.bold、中央
│  （複数選んでください）          │   .body、.secondary
│  .padding(.horizontal,          │
│       Spacing.md)               │   16pt
│                                 │
│  Spacer().frame(height:         │
│       Spacing.lg)               │   24pt
│                                 │
│  VStack(spacing: Spacing.sm) {  │   8pt（チェックリスト行間）
│  ┌─────────────────────────┐   │   各行 minHeight 56pt（高齢者対応）
│  │ ☑ お薬の飲み忘れ        │   │   選択済み: .owlAmber 背景
│  └─────────────────────────┘   │   未選択: .secondary 背景 opacity 0.1
│  ┌─────────────────────────┐   │
│  │ ☑ 病院・通院の日程      │   │
│  └─────────────────────────┘   │
│  ┌─────────────────────────┐   │
│  │ □ ゴミ出し              │   │
│  └─────────────────────────┘   │
│  ┌─────────────────────────┐   │
│  │ □ 電話に出ない          │   │
│  └─────────────────────────┘   │
│  ┌─────────────────────────┐   │
│  │ □ 外出・迷子            │   │
│  └─────────────────────────┘   │
│  }                              │
│  .padding(.horizontal,          │
│       Spacing.md)               │   16pt
│                                 │
│  Spacer()                       │   可変
│                                 │
│  [次へ →]                       │   56pt、1つ以上選択で.owlAmber（未選択時グレー）
│  .padding(.horizontal,          │
│       Spacing.md)               │   16pt
│  .padding(.bottom, Spacing.xl)  │   32pt
└─────────────────────────────────┘
```

回答はローカルのみ保存。FamilySolutionView でメリット出し分けに使う。

#### 10-4-2. FamilySolutionView（解決策と価値の提示）

```
┌─────────────────────────────────┐
│  Spacer()                       │
│                                 │
│  🦉（うなずきアニメーション）   │   高さ 120pt
│                                 │
│  Spacer().frame(height:         │
│       Spacing.xl)               │   32pt
│                                 │
│  ふくろうが、あなたに代わって   │   .title2.bold、中央
│  毎日やさしくお知らせします。   │
│  .padding(.horizontal,          │
│       Spacing.md)               │   16pt
│                                 │
│  Spacer().frame(height:         │
│       Spacing.lg)               │   24pt
│                                 │
│  VStack(spacing: Spacing.sm) {  │   8pt（メリット一覧）
│    ✅ マナーモードでも必ず鳴る  │   .body
│    ✅ 飲んだかどうかがわかる    │   FamilyPainQuestion回答に応じて
│    ✅ SOSが届きます             │   強調するメリットを先頭に出す
│  }                              │
│  .padding(.horizontal,          │
│       Spacing.md)               │   16pt
│                                 │
│  Spacer()                       │   可変
│                                 │
│  [お母さんと繋げてみる →]       │   56pt、.owlAmber
│  .padding(.horizontal,          │
│       Spacing.md)               │   16pt
│  .padding(.bottom, Spacing.xl)  │   32pt
└─────────────────────────────────┘
```

#### 10-4-3. FamilyPairingIntroView（ペアリング説明 + プライバシー同意）

```
┌─────────────────────────────────┐
│  Spacer()                       │
│                                 │
│  🔗（56pt リンクアイコン）      │
│                                 │
│  Spacer().frame(height:         │
│       Spacing.xl)               │   32pt
│                                 │
│  VStack(spacing: Spacing.sm) {  │   8pt
│    お母さんのスマホと            │   .title2.bold
│    連携しましょう               │
│    LINEで招待リンクを送るか、   │   .body、.secondary
│    6桁のコードで繋ぎます        │
│  }                              │
│  .padding(.horizontal,          │
│       Spacing.md)               │   16pt
│                                 │
│  Spacer().frame(height:         │
│       Spacing.lg)               │   24pt
│                                 │
│  VStack(spacing: Spacing.sm) {  │   8pt（プライバシー同意欄）
│  ⚠️ ❌マーク使用禁止・         │
│     ポジティブフレーミング厳守  │
│  ┌─────────────────────────┐   │   各行 minHeight 44pt
│  │ ✅ 予定のお知らせ        │   │
│  │ ✅ 完了・スキップの確認  │   │
│  │ 🛡️ 位置情報は見えません  │   │
│  │ 🛡️ メッセージは読めません│   │
│  └─────────────────────────┘   │
│  }                              │
│  .padding(.horizontal,          │
│       Spacing.md)               │   16pt
│                                 │
│  Spacer()                       │   可変
│                                 │
│  [わかった、繋いでみる →]       │   56pt、.owlAmber
│  .padding(.horizontal,          │
│       Spacing.md)               │   16pt
│  .padding(.bottom, Spacing.xl)  │   32pt
└─────────────────────────────────┘
```

#### 10-4-4. FamilyPairingActiveView（リンク送信 / 6桁コード実行）

```
┌─────────────────────────────────┐
│  Spacer()                       │
│                                 │
│  🦉（待機ポーズ）               │   高さ 100pt
│                                 │
│  Spacer().frame(height:         │
│       Spacing.xl)               │   32pt
│                                 │
│  お母さんに招待を送りましょう   │   .title2.bold、中央
│  .padding(.horizontal,          │
│       Spacing.md)               │   16pt
│                                 │
│  Spacer().frame(height:         │
│       Spacing.lg)               │   24pt
│                                 │
│  VStack(spacing: Spacing.md) {  │   16pt（ボタン間）
│    [📤 LINEで招待リンクを送る]  │   56pt、.owlAmber（プライマリ）
│    [🔢 6桁のコードでつなぐ]     │   minHeight 56pt、border（セカンダリ）
│  }                              │
│  .padding(.horizontal,          │
│       Spacing.md)               │   16pt
│                                 │
│  Spacer()                       │   可変
│                                 │
│  （送信後: スピナー表示）        │
│  🔄 お母さんのタップを          │   .body、.secondary、中央
│    待っています...               │
│                                 │
│  padding(.bottom, Spacing.xl)   │   32pt
└─────────────────────────────────┘
```

繋がった瞬間: 「🎉 繋がりました！」アニメーション → FamilyPaywallView へ遷移

---

### 10-5. 2-10-B. ふくろう長押し → 設定アクセス（高齢者向け代替導線）

「歯車アイコン」が認識しにくい高齢者向けに、ふくろうを長押しすると設定が開く導線を追加する。

**仕様:**
- PersonHomeのふくろうImageViewに `.onLongPressGesture(minimumDuration: 0.8)` を設定
- 発動時: `.impact(.medium)` Haptic + ふくろうが驚く表情に一瞬変化（0.3秒）→ `owl_stageN_surprised.png` を使用
- その後: 設定シートが `.sheet` で表示される（歯車アイコンと同じシート）
- 長押しヒントとして初回のみ「🦉 長く押すと設定が開きます」トーストを表示（3秒後に自動消去）

---

### 10-6. 2-10-C. ふくろうインタラクション（アイドル・タップ・シェイク）

ふくろうをただの装飾にせず、インタラクティブなキャラクターとして育てることで日次起動動機を作る。

**タップ（4バリエーション、ランダム選択）:**
- 「○○、今日もよろしく！」（owlName を埋め込む）
- 「予定あったっけ？大丈夫、ちゃんと覚えてるよ！」
- 「今日も一緒に頑張ろうね。」
- （残り1バリエーションは実装フェーズで洋介が決定）

**シェイク（CoreMotion）:**
- `CMMotionManager` でシェイク検知 → ふくろうがくるくる回るアニメーション（0.5秒）
- セリフ: 「わわっ！揺らさないでよ〜 😅」

**イースターエッグ（10連続タップ）:**
- 10連続タップを検知（1秒以内）
- CAEmitterLayer で画面全体に紙吹雪 + 「🎉 すごい！ふくろう名人だ！」トースト

**Haptic:**
- タップ: `.impact(.light)` × 1
- シェイク検知時: `.impact(.medium)` × 1
- イースターエッグ: `UINotificationFeedbackGenerator(.success)` × 1

---


## STEP 12: マルチ家族対応（送信者バッジ）

```swift
// AlarmEvent への追加
var senderName: String?   // 家族追加: 送信者名 / nil = 自分
var senderEmoji: String?  // アバター絵文字
```
- `senderName` が非nil → EventRow右端に「👱‍♀️ 長女」バッジ

---

## STEP 15: 未定義画面の詳細レイアウト

### 15-1. FamilySendTab（予定を送る）全画面レイアウト

```
┌─────────────────────────────────┐
│ ── 予定を送る ──────────────────  │ ← NavigationTitle（inline スタイル）
│                                 │
│  ┌─────────┐  ┌─────────┐      │ ← テンプレートグリッド
│  │   💊    │  │   🗑    │      │   「2列 × 3行」固定
│  │  お薬   │  │ゴミ出し │      │   各カード高さ: ComponentSize.templateCard（80pt）
│  └─────────┘  └─────────┘      │   カードコーナー半径: CornerRadius.md（12pt）
│  ┌─────────┐  ┌─────────┐      │   選択中ボーダー: BorderWidth.thick（2pt）.owlAmber
│  │   🏥    │  │   📞    │      │   未選択ボーダー: BorderWidth.thin（1pt）.separator
│  │  病院   │  │  電話   │      │   カード内: IconSize.lg（28pt）+ テキスト(.badge)
│  └─────────┘  └─────────┘      │
│  ┌─────────┐  ┌─────────┐      │
│  │   🛒    │  │   ✏️    │      │
│  │ 買い物  │  │自由入力 │      │
│  └─────────┘  └─────────┘      │
│                                 │
│  ───────── 日時を選ぶ ──────────  │
│  [🌅 朝 8:00] [☀️ 昼 12:00] [🌙 夜 19:00] │ ← プリセットボタン（横並び、高さ44pt）
│                                 │   タップ1回で日時を設定（8割の予定はこれで完結）
│                                 │   選択中: .owlAmber ボーダー(2pt)
│                                 │
│  ⚙️ 時間を細かく設定する ▼      │ ← アコーディオン開閉トリガー（デフォルト: 非表示）
│  （タップで DatePicker が展開）  │   .font(.subheadline)、.secondary、高さ: 44pt
│                                 │   ▼ = 閉じた状態 / ▲ = 開いた状態（ChevronDown/Up）
│  ┌─────────────────────────┐   │ ← DatePicker（アコーディオン内。デフォルト非表示）
│  │  明日  12 ▲  00 ▲      │   │   style: .compact（コンパクト表示）
│  └─────────────────────────┘   │   タップ → .graphical ピッカーがインライン展開
│  （展開アニメーション: .easeInOut(0.25s)）│   プリセット選択後でも日時を微調整できる
│                                 │
│  ───── 事前にお知らせ ──────────  │
│  [ 5分前 ]  [15分前]  [30分前]  │ ← トグルチップス（複数選択可）
│                                 │   高さ: ComponentSize.toggleChip（36pt）、横並び
│                                 │
│  ┌─────────────────────────┐   │
│  │  🦉 明日12:00に送信する  │   │ ← プライマリボタン
│  └─────────────────────────┘   │   高さ: 56pt、色: .owlAmber、テキスト黒（⚠️ 白は絶対NG: 1.5:1）
│  （重複がある場合のみ表示・⚠️ 送信ボタンはブロックされる）   │
│  ┌──────────────────────────────┐  │ ← 重複コンフリクト解決UI（条件付き）
│  │  ⚠️ 息子さんが同じ時間に      │  │   単なる警告ではなく選択を強制する
│  │  「お昼の薬」を登録済みです   │  │   ⚠️ 警告無視で二重送信させてはいけない
│  │                              │  │
│  │  [上書きする]  [やめる]      │  │   「上書きする」: 既存の予定を自分の内容で置き換える
│  └──────────────────────────────┘  │   「やめる」: 送信をキャンセルして画面に戻る
└─────────────────────────────────┘
```

**自由入力選択時:**
テキストフィールドがグリッドの下に展開（.transition(.move(edge: .top).combined(with: .opacity))）。
キーボードが出ると画面全体がスクロールアップ（ScrollView + `.scrollDismissesKeyboard(.interactively)`)。

### 15-2. 6桁コード入力画面（ペアリングフォールバック）

```
┌─────────────────────────────────┐
│  ふくろうとつなげる              │ ← タイトル（.title2.bold）
│  コードを入力してね              │ ← サブタイトル（.body、.secondary）
│                                 │
│  ┌──┐ ┌──┐ ┌──┐  ┌──┐ ┌──┐ ┌──┐  │ ← 入力表示（6桁の見た目）
│  │4 │ │8 │ │3 │  │  │ │  │ │  │  │   各マス: HStack均等割付（固定幅禁止）
│  └──┘ └──┘ └──┘  └──┘ └──┘ └──┘  │   .frame(maxWidth: .infinity).aspectRatio(0.75, contentMode: .fit)
│      3桁目まで入力済みの例       │   ⚠️ SE(幅375pt)〜Pro Max(幅440pt)で自動スケール
│                                 │   入力済み: .primary テキスト
│                                 │   未入力: .separator ボーダー BorderWidth.thin（1pt）
│                                 │   中央の「─」で3桁ずつ区切り
│                                 │   HStack(spacing: Spacing.xs) × 2グループ
│  ─────────────────────────────  │
│   （iOSネイティブナンバーパッド）  │ ← ⚠️ v14修正: カスタムキーボード廃止
│   （自動でシステムキーボードが出る）│   TextField に .keyboardType(.numberPad)
│                                 │   + .textContentType(.oneTimeCode) を設定
│  ─────────────────────────────  │   1Password 等の自動入力が使える
│  招待コードは家族の画面に表示    │ ← ヘルプテキスト（.caption）
└─────────────────────────────────┘
```

**実装仕様（v14修正: ネイティブキーボード採用）:**

```swift
// ✅ ネイティブキーボードを使う（カスタムキーボード廃止）
TextField("コードを入力", text: $pairingCode)
    .keyboardType(.numberPad)
    .textContentType(.oneTimeCode)   // 1Password 等の自動入力が使える
    .font(.system(size: 28, weight: .bold, design: .monospaced))
    .multilineTextAlignment(.center)
    // 6文字を超えたら自動でトリムする
    .onChange(of: pairingCode) { _, newValue in
        pairingCode = String(newValue.prefix(6))
    }

// 6桁揃ったら自動でAPIを呼ぶ（送信ボタン不要）
.onChange(of: pairingCode) { _, newValue in
    if newValue.count == 6 { Task { await verifyCode(newValue) } }
}
```

> ⚠️ **カスタムキーボードを廃止した理由（v14変更）:**
> - 高齢者は自分のiPhoneキーボード（文字サイズ・ショートカット）に慣れている
> - カスタムキーボードでは 1Password・iCloud キーチェーンの自動入力が使えない
> - `.textContentType(.oneTimeCode)` により SMSコードの自動入力も可能になる
> - 実装コストの削減にもなる

確認中は ProgressView をオーバーレイ。

### 15-3. 設定画面レイアウト（歯車アイコンから開くシート）

**⚠️ IT用語禁止ルール（AIへの強制指示）: 設定のラベルには以下の翻訳表を必ず使うこと。動詞ベースの文章にする。**

| IT用語（使用禁止） | 日常語ラベル（実装時に使用） |
|-------------------|---------------------------|
| 通知タイプ | お知らせの方法 |
| オーディオ出力 | 音の出し方（スマホから / イヤホンから） |
| 事前通知タイミング | アラームが鳴る何分前にお知らせするか |
| マイク入力モード | 予定を声で入力するときの操作方法 |
| SOS設定（分数） | 気づいていないようなら家族に連絡するまでの時間 |
| ペアリング管理 | つながっている家族の設定 |
| プライバシーポリシー | 個人情報の取り扱いについて |
| 高齢者モード | 文字を大きく表示する |
| クリアボイスモード | ゆっくり・はっきり読み上げる |
| 使い方を変える | 使う人を変える（当事者 / 家族） |

**UIコンポーネントの使い分け（AIへの明示的指示）:**

| 日常語ラベル | UIコンポーネント | 備考 |
|------------|----------------|------|
| お知らせの方法（音+声 / 音のみ） | `Picker` (segmented) | |
| 音声キャラクター | `Picker` → 別画面 (`NavigationLink`) | プレビュー再生ボタンあり |
| アラームが鳴る何分前にお知らせするか | Multi-select `Toggle` グループ | 複数選択可 |
| 音の出し方 | `Picker` (segmented) | |
| 予定を声で入力するときの操作方法 | `Picker` (segmented) | |
| 気づいていないようなら家族に連絡するまでの時間 | `Stepper` (1〜30分) | SOS未設定時はグレーアウト |
| 文字を大きく表示する | `Toggle` | ON: フォントが一段階大きくなる |
| ゆっくり・はっきり読み上げる | `Toggle` | ON: クリアボイスモード（STEP 13-5） |
| カレンダーを選ぶ | `NavigationLink` → 別画面 | PRO 🔒 |
| 使う人を変える | `Button` (NavigationLink風 >) | |
| つながっている家族の設定 | `NavigationLink` → 別画面 | |
| ふくろうの名前 | `TextField`（インライン編集） | |
| 個人情報の取り扱いについて | `Link` (外部ブラウザ) | |
| バージョン情報 | テキストのみ（Formの下部） | |
| **アカウントを削除する** | `Button`（.statusDanger色・テキストスタイル） | **⚠️ App Store 義務** |

**レイアウト:** `Form` を使用。各グループをセクションで区切る。シートは `.presentationDetents([.large])` 固定。

**⚠️ v15追加: 15-3-B. アカウント削除機能（App Store ガイドライン 5.1.1(v) 義務）**

> **法的必須要件:** App Store ガイドライン 5.1.1(v) は、アカウントを作成できるすべてのアプリに対して
> 「アプリ内からアカウントを削除できる機能」の提供を義務付けている。
> このアプリは Supabase Anonymous Auth でアカウントを作成しているため対象。
> **実装なしでの App Store 提出はリジェクト確定。**

```
設定画面 最下部セクション（「危険ゾーン」セクション）:

  ── アカウントについて ─────────────────────
  アカウントを削除する                     →   ← .statusDanger 色のテキスト、NavigationLink 風
  （すべてのデータが完全に消去されます）       ← .caption、.secondary

「アカウントを削除する」タップ時:
  【第1段階】ActionSheet:
    タイトル: 「アカウントを削除しますか？」
    メッセージ:
      「以下のデータがすべて削除されます:\n
      • 予定の記録（すべて）\n
      • ふくろうのXP・成長記録\n
      • 家族とのつながり\n
      • 購入済みアイテム（Non-Consumable は App Store で復元可能）\n
      \n
      この操作は取り消せません。」
    ボタン:
      [本当に削除する]（.destructive）
      [キャンセル]（.cancel）

「本当に削除する」確定後の処理:
  1. Supabase: 当該ユーザーの全データを削除
     - `remote_events` の sender_user_id / target_device_id に関連するレコード
     - `family_links` の child_user_id に関連するレコード
     - `user_profiles` のレコード
     - `user_devices` のレコード
     ⚠️ Supabase Auth のユーザー自体の削除は Edge Function 経由で行う（クライアントからは直接削除不可）
  2. ローカル UserDefaults を全クリア
  3. AlarmKit の登録済みアラームをすべてキャンセル
  4. EventKit のアプリ作成イベント（`<!-- wasure-bou:` マーカー付き）をすべて削除
  5. `Library/Sounds/WasurebuAlarms/` 配下の .caf ファイルをすべて削除
  6. `AppState` を初期化（新規ユーザー状態にリセット）
  7. AppRouter.currentDestination = .onboarding（オンボーディングに戻る）
  8. トースト: 「アカウントを削除しました。またいつでも使えます 🦉」

⚠️ 実装の注意:
  - 処理中は ProgressView + 「削除中...」テキストを全画面オーバーレイで表示する（Dismiss不可）
  - Supabase Edge Function が失敗した場合: 「削除できませんでした。もう一度試してください」のエラー表示
    → ローカルデータは削除しない（再試行可能にするため）
  - Non-Consumable 購入の払い戻しは行わない（App Store のポリシーに従う）
  - アカウント削除後は Supabase Anonymous Auth で新しい匿名アカウントが次回起動時に自動生成される
```

**15-3-A. 連携解除UI（⚠️ 法的必須要件）**

> App Store ガイドライン 5.1.1 および GDPR/個人情報保護法は、ユーザーが自分のデータ共有を
> いつでも解除できる手段を提供することを義務付けている。
> 「つながっている家族の設定」ページ内に**連携解除ボタン**を必ず実装すること。

```
「つながっている家族の設定」ページ内のレイアウト:

  ┌─────────────────────────────────────────┐
  │  つながっている家族                      │ ← セクションヘッダー
  │                                         │
  │  👱‍♀️ 長女さん（Yuki）                   │ ← ペアリング相手の表示名
  │     つながった日: 2026年2月1日          │   .subheadline、.secondary
  │                                         │
  │  連携を解除する                          │ ← テキストスタイルリンク（.statusDanger色）
  │                                         │   通常のボタンより小さく・目立たない
  │                                         │   高さ: 44pt（タップ領域は確保）、.body
  └─────────────────────────────────────────┘

> ⚠️ **誤タップ防止設計（v12修正）:**
> 目立つ赤ボタン（`.buttonStyle(.borderedProminent)`）は誤タップを誘発する。
> テキストスタイル（装飾なしリンク風）にすることで「見える・押せる・でも目立ちすぎない」を実現。
> 2段階確認（ActionSheet）でさらに誤操作を防ぐ。

「連携を解除する」タップ時:
  → 確認ダイアログ（ActionSheet）2段階:
    【第1段階】
    タイトル: 「長女さんとの連携を解除しますか？」
    メッセージ: 「解除すると、お互いの予定のやり取りができなくなります。再度つなげる場合は招待コードが必要です。」
    ボタン:
      [本当に解除する]（.destructive） ← 第1段階は .destructive
      [キャンセル]（.cancel）

「連携を解除する」確定後:
  1. `family_links.is_active = false` を Supabase に書き込む（物理削除しない）
  2. ローカルの `familyLinkId` / `familyChildLinkIds` をクリア
  3. 「〇〇さんとの連携を解除しました」トースト表示
  4. FamilyDashboardTab の予定リストをクリア
  5. 相手側（ペアリング相手）にも解除通知を Push で送信
     通知本文: 「連携が解除されました。再度つなげる場合はアプリから招待をお送りください。」

⚠️ 実装の罠（AIへの指示）:
  - ボタンを `.buttonStyle(.borderedProminent)` や明確な赤ボタンにしない（誤タップを誘発する）
    → `.foregroundColor(.statusDanger)` のみのテキストスタイルを使う
  - is_active = false にしてもデータは残す（監査ログ目的）。再ペアリング時は新レコードを作る
  - 解除後もローカルに残った AlarmEvent（家族送信分）は削除しない（過去記録の保持）
```

### 15-4. 家族ダッシュボード Tab 0 詳細レイアウト

```
┌─────────────────────────────────┐
│  おかあさんの今日         🔄    │ ← タイトル（.title3.bold）+ 更新アイコン
│  最終同期: 3分前 🟢             │   🔒 無料版: "--- 🔒" + タップでPaywall
│                                 │
│  ┌─────────────────────────┐   │ ← 送信済み予定リスト（ScrollView）
│  │ ○ 左ボーダー  12:00 お昼の薬 │   │   左ボーダー色 = 同期ステータス色
│  │   ✓ 完了！           👱‍♀️長女│   │   （pending=青, synced=緑, etc.）
│  │   12:01 完了         高さ:80pt│   │   行の高さ最小: 72pt（2行になることも）
│  └─────────────────────────┘   │
│  ┌─────────────────────────┐   │
│  │ ○             15:00 血圧測定 │
│  │   🔄 同期中...      👱‍♀️長女 │ ← pending: ProgressView(.circular,.small)
│  └─────────────────────────┘   │   スピナー = 同期中の唯一の表現
│  ┌─────────────────────────┐   │
│  │ ○ （赤ボーダー）10:00 朝の薬 │
│  │   ✗ 同期失敗   [再送信]  │ ← failed: 赤ボーダー + 再送信ボタン
│  └─────────────────────────┘   │   「再送信」: .caption、.statusDanger色
│                                 │   タップで該当イベントを再送
│  プルリフレッシュ可             │ ← .refreshable { await vm.refresh() }
└─────────────────────────────────┘
```

### 15-5. ローディング・エラー状態（全画面共通）

**ローディング（スケルトン）:**
```
EventRowの代わりに RoundedRectangle を表示:
  幅: full, 高さ: 64pt, cornerRadius: 16pt
  色: .secondary.opacity(0.1)
  アニメーション: opacity 0.3 → 0.7 → 0.3（1.5秒周期、.easeInOut, .repeatForever）
  表示数: 3行分
```

**エラー状態（通信失敗）:**
```
スナックバー（画面上部）:
  高さ: 52pt, 背景: .statusDanger, テキスト: 白
  テキスト: 「通信できませんでした。再度お試しください」
  表示時間: 3秒後に opacity: 1→0 (.easeOut, duration: 0.5)
  位置: safeArea上部 + 8pt の下（下からではなく上から出る）
```

**プルリフレッシュ:**
```
.refreshable 修飾子を使う（標準のスピナーが自動で出る）
完了後: List/ScrollView が自動でスクロールトップへ戻る
```

### 15-6. 共通Toastシステム

> ⚠️ **v16変更（P-7-1）: このセクションの `ToastModifier`（ViewModifier）アーキテクチャは廃止。**
> **`ToastWindowManager`（UIWindowレベル描画）に置き換えられた。末尾 P-7-1 を正として実装すること。**
> 以下は `ToastMessage` モデルの定義と表示スタイルのリファレンスとして残す。

> **問題:** SwiftUIには標準のトーストUIが存在しない。AIに任せると画面ごとにZStackで
> バラバラのトーストを作り、重なったり消えなかったりするバグを生む。
> `.fullScreenCover` (RingingView) の裏側に Toast が隠れる問題があり、UIWindowレベルで描画する必要がある。

**Toastのメッセージ種別:**

| 種別 | 表示位置 | 持続時間 | 用途例 |
|------|---------|---------|-------|
| `.owlTip` | 画面下部（FAB上） | 3秒 | 「元に戻しておいたよ 🦉」等のふくろうメッセージ |
| `.error` | 画面上部（safeArea下） | 3秒 | 「通信できませんでした」 |
| `.success` | 画面下部 | 2秒 | 「連携を解除しました」 |

```swift
// AppState または専用の ToastState に追加:

struct ToastMessage: Identifiable {
    let id = UUID()
    let text: String
    let style: ToastStyle  // .owlTip / .error / .success
}

enum ToastStyle { case owlTip, error, success }

// AppState:
var toastQueue: [ToastMessage] = []

func showToast(_ message: ToastMessage) {
    toastQueue.append(message)
}

// 表示ルール:
//   - 同時に表示できるのは1件のみ
//   - キューに複数ある場合は前のトーストが消えた後（0.3s後）に次を表示
//   - 同一テキストの重複は無視（2秒以内の再エンキューは破棄）
```

**ToastModifier（ViewModifier）実装仕様（AIへの指示）:**
```swift
// RootView に1箇所だけ適用する。各画面ごとに実装しない。

struct ToastModifier: ViewModifier {
    @Environment(AppState.self) private var appState

    func body(content: Content) -> some View {
        content
            .overlay(alignment: .bottom) {
                if let toast = appState.toastQueue.first {
                    ToastView(message: toast)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                        .onAppear {
                            Task {
                                try? await Task.sleep(for: .seconds(toast.style == .owlTip ? 3.0 : 2.0))
                                withAnimation { appState.toastQueue.removeFirst() }
                            }
                        }
                }
            }
            .animation(.spring(response: 0.4), value: appState.toastQueue.count)
    }
}

// 使い方（各ViewModelから）:
appState.showToast(ToastMessage(text: "元に戻しておいたよ 🦉", style: .owlTip))
```

**ToastView 外観仕様:**
```
.owlTip:
  背景: .regularMaterial（Liquid Glass）
  テキスト: 🦉 + メッセージ、.body
  コーナー半径: 20pt
  影: .shadow(radius: 8, y: 4)
  下端からの距離: FABがある場合 ComponentSize.fab（72pt）+ Spacing.md（16pt）= 88pt相当
               ⚠️ 直書き禁止。FABサイズ変更時に連動するよう必ずトークン参照すること
               ない場合: safeAreaInsets.bottom + Spacing.md（16pt）

.error:
  背景: .statusDanger
  テキスト: 白、.body
  表示位置: 画面上部（下からではなく上から降りてくる）

.success:
  背景: .statusSuccess
  テキスト: 白、.body
  表示位置: 画面下部（.owlTip と同じ位置）
```

### 15-7. AlarmDetailView（予定の詳細画面）

Push通知のディープリンクや家族ダッシュボードからタップして開く画面。NavigationPushまたは .sheet で表示。

```
┌─────────────────────────────────┐
│  [← 戻る]                       │
│                                 │
│  💊 お昼の薬                     │ ← .title.bold（絵文字は自動推定）
│  2024年1月15日（月）12:00        │ ← .title3、.secondary
│                                 │
│  ┌─────────────────────────┐   │
│  │ ❌ 今日はお休みしました   │   │ ← 現在の completionStatus をバッジ表示
│  └─────────────────────────┘   │   complete: ✅緑 / skip: ❌グレー
│                                 │   missed: ⏰オレンジ / nil: 🔔青
│  👤 登録者: 👱‍♀️ 長女（あなた）   │ ← 家族モードのみ表示
│  🔔 事前通知: 15分前             │
│  🔄 繰り返し: なし               │
│                                 │
│  ┌─────────────────────────┐   │
│  │  ✏️ 予定を編集する       │   │ ← 登録者本人のみ表示
│  └─────────────────────────┘   │
│                                 │
│  この予定を削除する              │ ← .statusDanger色のテキストのみ
└─────────────────────────────────┘
```

**実装仕様（AIへの指示）:**
- `AlarmEvent` を受け取って表示するだけのシンプルな読み取り専用画面
- 「✏️ 予定を編集する」タップ → EditEventView（15-8）を .sheet で表示
- 「削除する」タップ → ActionSheet の2段階確認

### 15-8. EditEventView（予定の編集画面）

PersonManualInputView（P-1-3）および FamilySendTab と全く同じコンポーネントを再利用し、初期値（State）に既存のイベントデータをバインディングすること。新しいフォーム画面を別途作成しないこと。

```swift
// 実装イメージ
PersonManualInputView(
    initialEvent: existingAlarmEvent,  // 既存データを初期値として渡す
    onSave: { updatedEvent in
        alarmEventStore.update(updatedEvent)
    }
)
```

- タイトル・日時・繰り返しを編集可能
- 「保存する」タップ → AlarmKit のスケジュールを更新 + EventKit を更新（Write-Through）

---

### P-1. STEP 2 関連パッチ（PersonHome）

**P-1-1. OwlNamingView 文字数制限（R1-②）:**
- `owlName` は最大8文字。`onChange` で `.prefix(8)` を適用
- TextField下に「8文字まで」の補足テキスト（`.caption`, `.secondary`）
- 10秒間無入力で「あとで名前をつける」ボタンが出現するフォールバック
- 画面外タップでキーボードを閉じる（`.onTapGesture { UIApplication.shared.endEditing() }`）

**P-1-2. 折りたたみのチラ見せインジケーター（R1-③）:**
- 折りたたみボタン横に、隠れている予定の絵文字アイコンを最大3つ表示
- 例: 「＋ 残り3件を表示 💊🏥📞 ▼」
- Dynamic Type Extreme時: 折りたたみボタンを `.primary` 色 + `.bordered` スタイルに自動切り替え

**P-1-3. 手動入力UI — PersonManualInputView（R2-①・⚠️ 必須新規画面）:**
> MicInputSheetの「テキストで入力する」フォールバックから遷移。キーボード入力を極限まで排除した「ブロック組み立て式」。

```
PersonManualInputView レイアウト:
┌─────────────────────────────────┐
│  🦉 何をする？                   │
│                                 │
│  [💊 くすり] [🗑 ゴミ] [🏥 病院] │ ← テンプレ大ボタン（高さ56pt）
│  [📞 電話]  [☕ カフェ]          │   タップで eventEmoji + title 自動設定
│  [✏️ その他]                    │ ← ここで初めてキーボード表示
│                                 │
│  🦉 いつ？                       │
│                                 │
│  [☀️ 朝] [🕛 昼] [🌙 夜]       │ ← 時間プリセット（設定で時刻カスタマイズ可）
│  [⏱ 10分後] [⏱ 30分後] [⏱ 1h後]│
│  [⚙️ 細かく設定]               │ ← ここで初めてDatePicker表示
│                                 │
│  [🦉 ふくろうにお願いする]      │ ← 確定ボタン（.owlAmber, 56pt）
└─────────────────────────────────┘
```

- 「朝・昼・夜」のデフォルト時刻は設定画面でカスタマイズ可能（P-8-1参照）
- CTAボタン（STEP 2-3）の「✏️ テキストで追加」リンクからも直接遷移可能

**⚠️ MicInputSheet → PersonManualInputView のキーボード対応（必須実装）:**
MicInputSheet が `.medium` 状態で PersonManualInputView に切り替えた直後にキーボードが出ると、入力フィールドがシートの外に押し出されて操作不能になる。

```swift
// MicInputSheet の呼び出し元（PersonHomeView）での実装
@State private var sheetDetent: PresentationDetent = .medium
@State private var isManualInputMode = false

.sheet(isPresented: $showMicSheet) {
    MicInputSheet(isManualInputMode: $isManualInputMode)
        .presentationDetents([.medium, .large], selection: $sheetDetent)
        .onChange(of: isManualInputMode) { newValue in
            if newValue {
                // ⚠️ detentを先に.largeにしてからTextFieldフォーカスを当てること（順番厳守）
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    sheetDetent = .large
                }
            } else {
                sheetDetent = .medium
            }
        }
}

// PersonManualInputView 本体はScrollViewでラップ
ScrollView {
    VStack(spacing: 16) { /* テンプレボタン + 時間プリセット + 確定ボタン */ }
        .padding(.horizontal, 20)
}
.scrollDismissesKeyboard(.interactively)  // キーボードをスワイプで閉じられるようにする
```

**P-1-4. Empty State CTA 改善（R1-④/R3-⑧/R3-⑳）:**
- CTA表示条件を「スクロール最下部」→「未完了予定2件以下」に変更
- GeometryReaderで「コンテンツが画面高さ未満なら最初から表示」するロジック追加
- CTA横に「✏️ テキストで追加」リンクを並記

**P-1-5. 予定0件時のデイリーミニタスク（R4-⑫）:**
- 全完了時、メッセージ下に「🍵 お水飲んだ？」「🧘 ストレッチした？」等のミニタスクボタンを1つ表示
- ミニタスクは `dailyMiniTasks: [String]` から日替わりでランダム選出

**ミニタスクのタップ後状態遷移（AIへの指示）:**
タップ後はボタンをそのまま残さないこと。以下の遷移を実装すること。
1. タップ → `.owlBounce` アニメーション再生（0.3秒）
2. アニメーション後 → ボタンのテキストが「✅ できた！（+5XP）」に変化
3. ボタンを `disabled(true)` にして再タップ不可にする（グレーアウト）
4. XPカウンターに +5 を反映（当日1回のみ）

画面全体のリロード・再描画は行わないこと。ボタンの状態変化のみでフィードバックを完結させる。

**P-1-6. NLParser 実装方式の明確化（R2-⑩/R4-⑭）:**
> ⚠️ AIへの制約: 複雑なNLParserは作るな。

- Phase 1: `Dictionary<String, String>`（キーワード→絵文字の辞書マッパー）のみ
- 辞書にないタイトルはデフォルト 📌 を返す
- 絵文字ピッカー: iOS標準キーボードではなく、アプリ内蔵の「よく使う10個の絵文字グリッド」をシートで表示

**P-1-7. マイク入力時の重複検知インターセプト（R5-A・⚠️ 必須）:**
> 高齢者の二重登録を根本から防ぐ。STEP 15-1の家族向け重複検知を当事者にも応用。

- MicInputSheetで予定タイトル確定後、既存の未来の予定（7日以内）と類似度判定
- 判定: タイトルの部分一致 OR 同一日時（±30分）の予定が存在
- 検知時: ふくろう提案UI「🦉 来週の木曜に、すでに『○○』が登録されてるよ！」
  - [追加しない（安心した！)] [別の予定として追加する]
- 音声読み上げ: 検知メッセージもTTS対応

**P-1-8. 「📅 カレンダーで先を見る」リンク（R5-B）:**
- 「明日の予定」セクションの下に `secondary` 色のテキストリンクを1つ配置
- タップ → iOS標準カレンダーアプリへのディープリンク（`calshow://`）
- 普段は目立たない。不安になった時だけ使える「逃げ道」

**P-1-9. PersonHome 手動同期ボタン（R4-⑨）:**
- 画面右上（⚙️ の左）に「🔄」ボタンを配置
- タップで SyncEngine.syncRemoteEvents() を手動実行
- NetworkMonitorオンライン復帰時にも自動サイレントフェッチを併用

**P-1-10. カレンダー選択UI（R3-④）:**
- 設定画面に「ふくろうに読み込むカレンダーを選ぶ」チェックボックスUI
- EKEventStoreの全カレンダーを一覧表示、ユーザーが選択/除外
- 対象外: 祝日カレンダー、天気カレンダー等のシステムカレンダーはデフォルトOFF

**P-1-11. 「時間指定なし（ToDo）」タスク対応（R3-①）:**
- `AlarmEvent` に `isToDo: Bool` フラグ追加
- `isToDo == true`: アラーム不発火。ホーム画面リスト最上部に常駐
- 手動入力UIで「⏱ 時間は決めない」ボタンを追加

**P-1-12. EventRow の Dynamic Type 対応（R3-②/R2-②）:**
- `ViewThatFits` を使用し、accessibility3以上で HStack→VStack に自動切り替え
- 絵文字を上に、時刻+タイトルをその下に配置するレイアウトBパターン

---

### P-6. オンボーディング パッチ

**P-6-1. WidgetGuideView（⚠️ 必須）詳細レイアウト:**

WidgetGuideView は `TabView(selection:)` を使ったカルーセル（スワイプ式紙芝居）UIで実装すること。高齢者が「ホーム画面長押し」を理解できないと判断した場合のために、テキストを大きく・ステップを短く分割する。

```
┌─────────────────────────────────┐
│                                 │
│  [プレースホルダー画像 大]        │ ← 後で洋介が用意するGIF/動画を入れる枠
│  （ホーム画面を長押しする場面）    │   ImageView、横幅 max、アスペクト比 16:9
│                                 │
│  ① ホーム画面の何もない          │ ← .title3.bold、中央
│    ところを長押しします           │
│                                 │
│  ● ○ ○ ○                       │ ← ページインジケーター
│                                 │
│  [あとでやる]  [次へ →]          │
└─────────────────────────────────┘

ページ2: 「②「+」ボタンをタップします」（追加ボタンの画像）
ページ3: 「③「忘れ坊アラーム」を探してタップします」（検索画面の画像）
ページ4: 「④ ふくろうをホーム画面に置きます」（配置完了の画像）
         ボタン: [できた！PersonHomeへ]
```

- 各ページに1文のみ。箇条書き・説明文なし。
- 画像のプレースホルダーには枠線 + 「（ここに画像が入ります）」テキストを仮置きする。
- 「あとでやる」はいつでも選択可。設定画面の「ウィジェットの設置方法」から再閲覧可能。

**P-6-2. 通知権限剥奪リカバリ（R2-⑬/R3-⑲・⚠️ 必須）:**
- `scenePhase == .active` のたびに `UNUserNotificationCenter.getNotificationSettings` をチェック
- 権限が `denied` の場合: PersonHome操作をブロックして全画面警告表示
  - 「⚠️ お知らせが届かない状態です！設定で『通知』をオンにしてください」
  - 設定アプリへのディープリンクボタン付き

**P-6-3. MagicDemo「鳴りましたか？」確認（R3-⑱）:**
- デモ後に「♪ 音は無事に鳴りましたか？」ダイアログ表示
- [鳴った！] → PersonHome遷移
- [鳴らなかった] → 設定アプリ「通知」「集中モード」確認方法のトラブルシューティング画面

**P-6-4. Hapticデモのフォローアップテキスト（R1-⑫）:**
- Hapticデモ終了時: 「今は振動だけでしたが、本当はマナーモードでも必ず音が鳴るアラームです。明日を楽しみにしていてください！」

**P-6-5. 既存ユーザーのオンボーディングスキップ（v15仕様確認）:**
- `isOnboardingComplete == true` かつ `appMode == nil`: ModeSelectionのみ表示
- ボタンラベル: 「この設定で使う」（「はじめる」ではない）

**P-6-6. 「朝・昼・夜」時刻カスタマイズ（R3-③）:**
- 設定画面に「いつもの時間設定」項目追加
  - 朝: デフォルト 8:00（DatePicker）
  - 昼: デフォルト 12:00
  - 夜: デフォルト 19:00
- P-1-3（手動入力UI）と家族送信タブのプリセットに連動

---

## ■ Push通知ディープリンク時の画面遷移ルール

Push通知タップ → アプリ起動時に特定画面へ遷移する処理（handleDeepLink）の実装要件。

**問題:** ユーザーが設定画面（.sheet）を開いていたり、すでに別の画面を深く開いている状態でディープリンクが飛んでくると、画面遷移が競合してUIが操作不能になる。

**実装ルール（必須）:**

```swift
func handleDeepLink(_ destination: AppDestination) {
    // 1. 表示中のすべてのシートを閉じる
    appState.dismissAllSheets()

    // 2. NavigationPath を空にしてルートに戻す
    appState.navigationPath.removeAll()

    // 3. 非同期で1フレーム待ってから遷移（SwiftUI の状態更新を確定させる）
    Task { @MainActor in
        try? await Task.sleep(nanoseconds: 16_000_000) // 1フレーム（約16ms）
        appState.navigationPath.append(destination)
    }
}
```

この「dismiss → removeAll → 1フレーム待機 → append」の順序を守らないと、NavigationStack と sheet の状態が競合してクラッシュまたは操作不能になる。