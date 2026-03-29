## STEP 13: デザインシステム（Design Tokens）

> **AIエンジニアへの指示:** 以下のトークンを `Extensions/Color+Theme.swift` と `Extensions/Font+Theme.swift` に定義してから実装を始めること。勝手にシステムカラーや任意のフォントサイズを使わない。

### 13-1. カラーパレット

```swift
// Extensions/Color+Theme.swift

extension Color {
    // ── ブランドカラー ───────────────────────────
    /// ふくろうのアンバー（ブランドプライマリ）
    static let owlAmber = Color(hex: "#F5A623")
    // ダークモードでの owlAmber 使用ルール:
    // - ライトモード: #F5A623 背景 + 黒テキスト（コントラスト比 8.3:1 ✅）
    // - ダークモード: #F7B544（10%明度UP）背景 + 黒テキスト（暗い背景との分離を確保）
    // 実装: Color+Theme.swift で @Environment(\.colorScheme) で分岐するか
    //       Asset Catalog の Any/Dark で2値定義する
    static let owlAmberDark = Color(hex: "#F7B544")  // ダークモード専用
    // 使用方法:
    // @Environment(\.colorScheme) var colorScheme
    // let amber = colorScheme == .dark ? Color.owlAmberDark : Color.owlAmber
    /// ふくろうの羽の茶色（ダークモードは15%明度UP）
    static let owlBrown     = Color(hex: "#8B5E3C")  // ライトモード
    static let owlBrownDark = Color(hex: "#A87850")  // ダークモード（暗い背景での視認性確保）

    // ── ステータスカラー ─────────────────────────
    static let statusSuccess  = Color(hex: "#34C759")  // iOS systemGreen
    static let statusWarning  = Color(hex: "#FF9500")  // iOS systemOrange
    static let statusDanger   = Color(hex: "#FF3B30")  // iOS systemRed
    static let statusPending  = Color(hex: "#007AFF")  // iOS systemBlue
    static let statusSkipped  = Color(hex: "#8E8E93")  // iOS systemGray

    // ── XP・成長カラー ──────────────────────────
    static let xpGold = Color(hex: "#FFD700")

    // ── 時間帯オーバーレイ（必ずopacity指定で使う）──
    /// 朝 5:00-10:59 → .morning.opacity(0.12)
    static let morning  = Color(hex: "#87CEEB")  // sky blue
    /// 昼 11:00-16:59 → .afternoon.opacity(0.10)
    static let afternoon = Color(hex: "#FFF9C4")  // pale yellow
    /// 夕 17:00-20:59 → .evening.opacity(0.13)
    static let evening  = Color(hex: "#FFB347")  // warm orange
    /// 夜 21:00-4:59 → .night.opacity(0.16)
    static let night    = Color(hex: "#4B5EA3")  // soft indigo
}
```

**背景・テキスト: SwiftUIセマンティックカラーを使用（自動でLight/Dark対応）**

| 用途 | SwiftUI カラー | Light近似値 | Dark近似値 |
|------|---------------|------------|-----------|
| 画面背景 | `.background` | #F2F2F7 | #000000 |
| カード背景 | `.secondarySystemBackground` | #FFFFFF | #1C1C1E |
| テキスト（主） | `.primary` | #000000 | #FFFFFF |
| テキスト（副） | `.secondary` | #3C3C43 at 60% | #EBEBF5 at 60% |
| 区切り線 | `.separator` | 自動 | 自動 |

**WCAG 2.2 AA基準（必須）:**
- `primary`テキスト on `background` → **自動で21:1**（問題なし）
- 時間帯オーバーレイ（opacity 0.10〜0.16）は背景をほぼ変えないため**コントラストに影響なし**
- ⚠️ **致命的注意: `owlAmber(#F5A623)` + 白テキスト → コントラスト比 1.5:1（WCAG AA 3:1 を大幅に下回る。絶対にNGパターン）**
- `owlAmber` 背景上のテキスト・アイコンは **必ず黒（`#000000`）** を使う
  - owlAmber on #000000 → コントラスト比 **8.3:1**（WCAG AA 4.5:1 を大きく超える）
  - プライマリボタンの実装例: `.foregroundColor(.black)` を明示的に指定すること（白になるデフォルトを上書き）

### 13-2. タイポグラフィスケール

```swift
// Extensions/Font+Theme.swift
// SwiftUIのシステムフォント（SF Pro）を使う。Dynamic Type自動対応。

extension Font {
    /// ふくろうのあいさつ文
    static let owlGreeting = Font.title.bold()            // 28pt Bold → xxAcc: 38pt
    /// 次の予定タイトル（大）
    static let nextEventTitle = Font.title2.bold()         // 22pt Bold
    /// 円形カウントダウンの数字（⚠️ 固定サイズ禁止 → コンテナで上限制御する）
    static let countdownNumber = Font.system(.largeTitle, design: .rounded, weight: .bold)
    // ↑ Dynamic Typeに追従させる。ただしコンテナ側で .dynamicTypeSize(... .accessibility2) を設定し
    //   「system font size max=36pt相当（accessibility2）」で頭打ちにすることでレイアウト崩壊を防ぐ
    /// イベントリストのタイトル
    static let eventTitle = Font.headline                  // 17pt SemiBold
    /// イベントの時刻
    static let eventTime = Font.subheadline               // 15pt Regular
    /// セクションヘッダー
    static let sectionHeader = Font.footnote.weight(.semibold).uppercaseSmallCaps()
    /// バッジ・キャプション
    static let badge = Font.caption                        // 12pt Regular
    /// SOSプログレスバー
    static let sosLabel = Font.caption2                    // 11pt Regular
}
```

**Dynamic Type ルール（AIへの指示）:**
- `eventTitle`（予定タイトル）は**最大2行まで折り返し**。`.lineLimit(2)` を必ず指定。3行目以降は切り捨て（末尾に「…」）
- ⚠️ **`countdownNumber` を固定サイズ（48pt）にすることは禁止。** 他のテキストが大きく拡大する中で数字だけ48ptに固定すると、アクセシビリティ設定のユーザーには「カウントダウンが本文より小さい」逆転現象が起きる。
- **⚠️ v16変更（P-2-4）: `.accessibility2` キャップを撤廃し、構造的フォールバックに変更。**
  ```swift
  // ❌ 旧実装（v15まで）: キャップで上限制限 → Apple アクセシビリティガイドライン違反
  // CircularCountdownView(...)
  //     .dynamicTypeSize(...DynamicTypeSize.accessibility2)

  // ✅ 新実装（v16〜）: sizeCategory に応じてUIを構造的に切り替え
  Group {
      if sizeCategory >= .accessibilityLarge {
          // accessibility3以上: 円形リングを完全に捨てて巨大数字テキストのみ表示
          VStack(spacing: 8) {
              Text(remainingTimeString)
                  .font(.system(.largeTitle, design: .rounded, weight: .bold))
                  .foregroundColor(isUrgent ? .statusDanger : .primary)
              Text(eventTitle)
                  .font(.headline)
                  .multilineTextAlignment(.center)
          }
          .frame(maxWidth: .infinity)
      } else {
          // 通常サイズ: 円形カウントダウンリング表示
          CircularCountdownView(...)
      }
  }
  ```
- `RootView` の `.dynamicTypeSize(...DynamicTypeSize.accessibility1)` は残す（他の要素のレイアウト崩壊防止）。`CircularCountdownView` だけは上記のように独立した構造フォールバックで対応する。
- その他すべての文字は Dynamic Type に自動追従する

### 13-3. スペーシング・サイズシステム（4pt grid）

```
Spacing:
  xs:  4pt  （バッジの内部パディング）
  sm:  8pt  （コンポーネント内の余白）
  md: 16pt  （カードの内部パディング、画面端マージン）
  lg: 24pt  （セクション間の余白）
  xl: 32pt  （ふくろうと次要素の余白）

Component sizes:
  eventRow:       64pt  （高齢者の指が収まる最低ライン）
  fab:            72pt  （FABボタン 正方形・corner radius: 36pt = 完全な円）
  templateCard:   80pt  （家族が親指で楽に押せるテンプレートカード高さ）
  settingRow:     52pt  （標準的な List セル）
  inputField:     52pt  （テキスト入力フィールドの高さ）
  small:          44pt  （Apple HIG 最小タップターゲット）
  primary:        56pt  （プライマリボタン高さ・高齢者向け・幅はfull width）
  actionGiant:    72pt  （RingingView完了ボタン等・特別大型アクション専用）
                          ⚠️ primary(56pt)と混同禁止。RingingViewのみ使用
  toggleChip:     36pt  （トグルチップス: 事前通知プリセット・フィルター等）

Corner radius:
  sm:    8pt  （バッジ・小アイコン）
  md:   12pt  （ボタン・テンプレートカード・小カード）
  lg:   16pt  （カード（大）・ダイアログ）
  input: 10pt （入力フィールド）
  fab:   36pt （FAB = 完全な円 = fab高さ/2）
  pill: .infinity （トースト・タグ・カプセル型）

Border width:
  thin:  1pt  （未選択ボーダー・区切り線）
  thick: 2pt  （選択中ボーダー・フォーカス）

Icon size:
  sm:  20pt （小アイコン・インラインアイコン）
  md:  24pt （通常アイコン）
  lg:  28pt （EventRow絵文字・テンプレートカードアイコン）
  xl:  56pt （許可プリプロンプト等の大アイコン）
```

**⚠️ AIへの明示的指示（余白・スペーシング・サイズ全般）:**

> UIの実装時は、上記 **8pt グリッドシステム（Apple HIG準拠）を厳格に守ること。**
> 具体的なルール:
> - `VStack` / `HStack` の `spacing` には必ず定義済みトークン（`xs=4`/`sm=8`/`md=16`/`lg=24`/`xl=32`）を使う
> - `.padding()` も同様。魔法の数値（`.padding(11)` など）を絶対に書かない
> - カード内部: `.padding(.md)` = 16pt（上下左右均等）
> - 画面端マージン: `.padding(.horizontal, .md)` = 左右各16pt
> - セクション間: `Spacer()` ではなく `VStack(spacing: .lg)` で管理する
> - ボタン高さ: `ComponentSize.primary`（56pt）か `ComponentSize.actionGiant`（72pt）のみ使用。直書き禁止
> - コーナー半径: `CornerRadius.md`（12pt）/ `CornerRadius.lg`（16pt）等のトークンを使う
> - ボーダー幅: `BorderWidth.thin`（1pt）/ `BorderWidth.thick`（2pt）のみ使用
> - アイコンサイズ: `IconSize.lg`（28pt）/ `IconSize.xl`（56pt）等のトークンを使う

```swift
// Extensions/Spacing+Theme.swift（新規作成を推奨）
enum Spacing {
    static let xs: CGFloat =  4
    static let sm: CGFloat =  8
    static let md: CGFloat = 16
    static let lg: CGFloat = 24
    static let xl: CGFloat = 32
}

enum ComponentSize {
    static let eventRow:     CGFloat = 64
    static let fab:          CGFloat = 72
    static let templateCard: CGFloat = 80
    static let settingRow:   CGFloat = 52
    static let inputField:   CGFloat = 52
    static let small:        CGFloat = 44  // Apple HIG 最小タップターゲット
    static let primary:      CGFloat = 56  // プライマリボタン（全画面共通）
    static let actionGiant:  CGFloat = 72  // RingingView完了ボタン専用
    static let toggleChip:   CGFloat = 36  // トグルチップス
}

enum CornerRadius {
    static let sm:   CGFloat = 8
    static let md:   CGFloat = 12
    static let lg:   CGFloat = 16
    static let input: CGFloat = 10
    static let fab:   CGFloat = 36
    static let pill:  CGFloat = .infinity
}

enum BorderWidth {
    static let thin:  CGFloat = 1
    static let thick: CGFloat = 2
}

enum IconSize {
    static let sm: CGFloat = 20
    static let md: CGFloat = 24
    static let lg: CGFloat = 28  // EventRow絵文字・テンプレートカード
    static let xl: CGFloat = 56  // 権限プリプロンプト等の大アイコン
}
```

**フォールバック制約（オンボーディング・全画面共通）:**

> マジックナンバー（例: `.padding(11)`, `VStack(spacing: 13)`）は**禁止**。
> 以下の最小値をデバイスサイズに関わらず下回らないこと。

| 用途 | 最小値 | トークン |
|------|--------|---------|
| 画面横マージン | 16pt | `Spacing.md` |
| 関連要素の間隔 | 8pt | `Spacing.sm` |
| セクション間余白 | 24pt | `Spacing.lg` |
| プライマリボタン高さ | 56pt | 固定値（`.frame(height: 56)`） |
| セカンダリ/スキップボタン最小タップ高さ | 44pt | `.frame(minHeight: 44)` |
| オンボーディングボタン下余白 | 32pt | `Spacing.xl` |

```swift
// ✅ 正しい実装例（オンボーディング画面共通テンプレート）
VStack(spacing: 0) {
    Spacer()
    owlImageArea  // 高さ 120pt
    Spacer().frame(height: Spacing.xl)  // 32pt（画像↔テキスト間）
    VStack(spacing: Spacing.sm) {       // 8pt（タイトル↔サブタイトル間）
        Text(title).font(.title2).bold().multilineTextAlignment(.center)
        Text(subtitle).font(.body).foregroundStyle(.secondary).multilineTextAlignment(.center)
    }
    .padding(.horizontal, Spacing.md)   // 16pt
    Spacer()
    VStack(spacing: Spacing.md) {       // 16pt（ボタン間）
        PrimaryButton(height: 56).padding(.horizontal, Spacing.md)
        SecondaryButton().frame(minHeight: 44)
    }
    .padding(.bottom, Spacing.xl)       // 32pt（ボタン下余白）
}
// ❌ 禁止（マジックナンバー）: VStack(spacing: 13), .padding(11), .frame(height: 50)
```

**タップ領域の拡張（⚠️ v14追加: B-16 必須ルール）:**

> **問題:** SwiftUI の `Button` は `label` のコンテンツ部分しかヒットテストを受け付けない。
> 高齢者の指先は広く、かつ狙いが外れやすい。「押したつもりが反応しなかった」という
> アクセシビリティ障害が多発する最頻発バグ。

**⚠️ AIへの強制指示: 以下のルールを全コンポーネントに適用すること（例外なし）。**

```swift
// ✅ EventRow（リスト行全体をタップ可能にする）
Button(action: { ... }) {
    HStack { ... }
        .frame(maxWidth: .infinity, minHeight: 64)  // 高齢者対応: 最小高さ64pt
}
.contentShape(Rectangle())  // ← これがないと HStack の空白部分が反応しない

// ✅ 設定行・リストセル（Formの外側で実装する場合）
Button(action: { ... }) {
    HStack { ... }
}
.contentShape(Rectangle())

// ✅ カードコンポーネント全体がタップ可能な場合
ZStack { ... }
    .contentShape(Rectangle())
    .onTapGesture { ... }

// ❌ やってはいけないこと（タップ領域が狭くなる）:
Button(action: { ... }) {
    Text("完了")  // テキスト部分しか反応しない
}
// → 正しい修正: .contentShape(Rectangle()) を Button に追加 + minHeight を確保

// ⚠️ FAB（円形ボタン）の場合:
Button(action: { ... }) { ... }
.contentShape(Circle())  // 円形の場合は Circle() を使う（Rectangle だと角が反応しなくなる）
```

**チェックリスト（AIへの指示）:**
- EventRow: `.contentShape(Rectangle())` + `.frame(minHeight: 64)`
- テンプレートカード（FamilySendTab）: `.contentShape(Rectangle())`
- 設定行: `.contentShape(Rectangle())`
- FAB: `.contentShape(Circle())`
- 折りたたみボタン（2-2-B）: `.contentShape(Rectangle())` + `.frame(minHeight: 44)`

### 13-4-A. マテリアル（Liquid Glass）使用ルール（⚠️ v13追加: iOS 26対応）

> **iOS 26のデザインランゲージ「Liquid Glass」:**
> 半透明ですりガラスのような多層的な素材感がiOS 26のネイティブUIの基本。
> 単色ベタ塗りで実装すると一気に「2020年のアプリ」に見える。
> AIへの指示: **モーダル・シート・ウィジェット背景には必ずマテリアルを使うこと。**

```swift
// マテリアル使用ルール（AIへの明示的指示）

// ① ハーフシート・モーダル背景
.background(.regularMaterial)

// ② カード背景（EventRow、テンプレートカード等）
.background(.ultraThinMaterial)

// ③ FABボタンの背景
.background(.thickMaterial)
.clipShape(Circle())

// ④ ナビゲーションバー・タブバー
// → iOS 26では自動でLiquid Glassが適用される（SwiftUIのデフォルト）
// → カスタマイズは .toolbarBackground(.regularMaterial, for: .navigationBar) で

// ⑤ RingingView（全画面）の背景
// → .background(.ultraThickMaterial) + 時間帯カラーオーバーレイを重ねる
//   Color.morning.opacity(0.12)  ← 時間帯オーバーレイ
//   .background(.ultraThickMaterial)

// ⑥ ウィジェット背景
// → .containerBackground(for: .widget) を使う（iOS 17以降の標準）
//   WidgetKit では .background() は効かないため注意

// ❌ やってはいけないこと:
// .background(Color.white) や .background(Color(uiColor: .systemBackground))
// → Liquid Glassの透明感が失われ、旧世代のデザインになる
// → ただし一部のリストセルや入力フィールドは例外（視認性確保のため）

// ⚠️ コントラスト確認:
// マテリアル背景上のテキストは .primary / .secondary を使えばLight/Dark両対応
// owlAmber背景（opaque）は例外として .black テキストを使う（WCAG 8.3:1）
```

### 13-4. シャドウとエレベーション

```swift
// カード: 浮いている感（過剰にしない）
.shadow(color: .black.opacity(0.06), radius: 12, x: 0, y: 4)

// FAB: 明確な浮上感
.shadow(color: .black.opacity(0.20), radius: 16, x: 0, y: 8)

// 円形カウントダウン外周リング:
// グロー効果（危機感を演出）
// 10分未満のみ: .shadow(color: .red.opacity(0.4), radius: 20, x: 0, y: 0)
```

### 13-5. クリアボイスモード（⚠️ 加齢性難聴対応・必須）

> 高齢者は高音域から聞こえづらくなる（加齢性難聴）。デフォルト設定の甲高い女性音声では
> 「何か鳴っているが聞き取れない」という致命的なアクセシビリティ障害が起きる。

**アテンション音 + 無音ギャップ（⚠️ 全モード共通・必須）:**

> 突然ナレーションが始まると、脳が「聞く準備」をする前に最初の単語を聞き逃す。
> 特に高齢者・ADHD当事者はこの問題が顕著。「ピンポン音 → 1秒無音 → ナレーション」の3段構えで
> 100%の聞き取り率を目指す。

> ⚠️ **v14修正: `AudioServicesPlaySystemSound(1057)` はサイレントモードを貫通しない。**
> `AudioServicesPlaySystemSound` は通常のシステム音量に依存するため、
> iPhoneがマナーモードの場合は無音になる。AlarmKit の強みが活かせない。
>
> **解決策: 「ピンポン音 + 1秒無音」を .caf ファイルとしてバンドルし、AlarmKit のサウンドとして設定する。**
> アテンション音は AlarmKit（OS レベル）が再生するため、マナーモードを貫通する。
> その後 AVSpeechSynthesizer を起動するタイミングは音声ファイルの再生完了を待ってから。

```swift
// ✅ 正しい音声再生シーケンス（v14修正後）:

// 【設計変更】AlarmKit のサウンドとして設定するファイルを分ける:
//   owl_alarm.caf      = ピンポン音（約0.8秒）+ 1秒無音 + アラーム本体ループ
//                        → AlarmPresentation.Alert.sound = .named("owl_alarm")
//                        → マナーモード貫通（AlarmKit = OS レベル）

// RingingView（Stage 2）が表示された後の AVSpeechSynthesizer 起動タイミング:
// AlarmKit のアラーム音が鳴り始めてから約2秒後（= ピンポン音 + 無音ギャップの長さ）
// に AVSpeechSynthesizer を起動する。二重再生を防ぐため下記の順序を厳守。

Task { [weak self] in
    guard let self else { return }
    // 1. AlarmKit の音が先頭で鳴っている（Stage 1 → Stage 2 移行中）
    // 2. 2秒待機（アテンション音 + 無音ギャップ分）
    try? await Task.sleep(for: .seconds(2.0))
    guard self.activeAlarm != nil else { return }
    // 3. ナレーション開始（TTSまたは .caf ファイル）
    self.playNarration(alarm: alarm)
}

// ❌ 廃止（マナーモードを貫通しないため削除）:
// AudioServicesPlaySystemSound(1057)
```

**owl_alarm.caf の構成（洋介が用意するファイルの仕様を追記）:**
```
owl_alarm.caf の内部構造:
  [0.0〜0.8秒]  ピンポン音（アテンション音・500Hz〜2kHz帯域）
  [0.8〜1.8秒]  無音（脳が「次に言葉が来る」と準備する時間）
  [1.8秒〜]     アラーム本体（マリンバ系・シームレスループ）

⚠️ この設計のメリット:
  - AlarmKit が OS レベルでマナーモードを貫通して全体を再生する
  - アテンション音とアラーム音が1ファイルに入っているため同期がずれない
  - AVSpeechSynthesizer は Stage 2 で 2 秒後に起動するだけでよい（タイミング計算が不要）
```

**標準モードとクリアボイスモードの音声パラメータ比較:**

| パラメータ | 標準（デフォルト） | クリアボイスモード（高齢者推奨） |
|-----------|------------------|-------------------------------|
| `rate`（読み上げ速度） | 0.48 | **0.40**（単語と単語の間に意図的な間） |
| `pitchMultiplier`（音の高さ） | 1.10（やや高め） | **0.80**（中低音域・聞き取りやすい） |
| `preUtteranceDelay` | **0.0秒**（アテンション音後1秒の無音で代替） | **0.0秒**（同様） |
| 音声キャラクター推奨 | femaleConcierge など | 低音域の音声を優先的に提案 |

> ⚠️ `preUtteranceDelay` は `AVSpeechUtterance` の API が iOS バージョンにより不安定なため、
> 代わりに上記の `Task.sleep(1.0)` パターンで統一する。効果は同等かそれ以上。

**設定画面への追加（STEP 15-3 の設定項目テーブルに反映）:**
```
「ゆっくり・はっきり読み上げる」Toggle
  ON  → クリアボイスモード（上記パラメータ適用）
  OFF → 標準モード
  デフォルト: OFF（ただし onboarding で高齢者モードをONにした場合は自動でON）
```

**実装の罠（AIへの指示）:**
- `AVSpeechSynthesizer` は発話開始後に `rate`/`pitch` を変更できない。設定変更は次回発話から反映。
- クリアボイスモードと「高齢者モード（文字拡大）」は独立したトグルにする（セットにしない）。
  「文字は大きくしたいが声のスピードは普通でいい」というユーザーが存在するため。

**TTS読み間違いサニタイズ処理（⚠️ v14追加: B-50 Phase 1必須）:**

> `AVSpeechSynthesizer` はそのまま渡すと絵文字を「えもじ」と読み上げ、英単語を片仮名読みし、
> 予定タイトルを不自然に区切る。高齢者・ADHD当事者が「何を言っているのか分からない」と感じて
> アプリを閉じる原因になる。**渡す前に必ずサニタイズすること（Phase 1 必須）。**

```swift
// Services/TTSSanitizer.swift（新規作成）

struct TTSSanitizer {

    /// AVSpeechSynthesizerに渡す前にテキストを整形する
    static func sanitize(_ text: String) -> String {
        var result = text

        // 1. 絵文字を除去（AVSpeechSynthesizer は絵文字を「えもじ」と読み上げる）
        result = result.unicodeScalars
            .filter { !$0.properties.isEmojiPresentation && !$0.properties.isEmoji }
            .map { String($0) }
            .joined()

        // 2. 単語辞書による読み替え（フリガナマップ）
        //    ⚠️ 英字・略語・専門用語は必ずここに登録すること
        let pronunciationMap: [String: String] = [
            "Dr." : "ドクター",
            "ST"  : "エスティー",     // 作業療法士等
            "OT"  : "オーティー",
            "PT"  : "ピーティー",
            "MRI" : "エムアールアイ",
            "CT"  : "シーティー",
            "kg"  : "キログラム",
            "mg"  : "ミリグラム",
            "ml"  : "ミリリットル",
            "km"  : "キロメートル",
            "TEL" : "テル",
            "tel" : "テル",
            "No." : "ナンバー",
            "&"   : "と",
            "/"   : "スラッシュ",     // 例: "薬/体温" → "薬スラッシュ体温"（状況による。要検討）
        ]
        for (word, pronunciation) in pronunciationMap {
            result = result.replacingOccurrences(of: word, with: pronunciation)
        }

        // 3. 記号の除去・変換（読み上げノイズを防ぐ）
        let symbolMap: [String: String] = [
            "（" : "、",   // 括弧は読み飛ばし（例: 「病院（内科）」→「病院、内科、」）
            "）" : "、",
            "（" : "、",
            "）" : "、",
            "【" : "",
            "】" : "",
            "「" : "",
            "」" : "",
            "…" : "。",
            "・" : "、",
        ]
        for (symbol, replacement) in symbolMap {
            result = result.replacingOccurrences(of: symbol, with: replacement)
        }

        // 4. 連続する句読点を1つにまとめる
        //    例: "病院、、、内科、" → "病院、内科、"
        while result.contains("、、") { result = result.replacingOccurrences(of: "、、", with: "、") }
        while result.contains("。。") { result = result.replacingOccurrences(of: "。。", with: "。") }

        // 5. 前後の余白を除去
        result = result.trimmingCharacters(in: .whitespacesAndNewlines)

        return result
    }
}

// 使い方（RingingViewModel.speakAlarmTitle から呼ぶ）:
// let sanitizedTitle = TTSSanitizer.sanitize(title)
// let text = "お時間です。\(sanitizedTitle)\(minutesText)。準備はよろしいですか？"
```

**サニタイズ対象の優先度（AIへの指示）:**
- **Phase 1 必須**: 絵文字除去、括弧変換、連続句読点整理
- **Phase 4 対応（NLParser導入後）**: 発音辞書の自動拡充（NLParser で固有名詞を検出して登録）
- ⚠️ `pronunciationMap` は今後増やしやすいよう外部ファイル（JSON）に切り出すことを推奨
- **⚠️ v15追加: Phase 4 以降で Supabase Remote Config から `pronunciationMap` をフェッチする設計に移行する:**
  ```
  Phase 1〜3: アプリバンドルの JSON ファイル（静的辞書）
  Phase 4 以降: Supabase の `pronunciation_map` テーブル or Storage JSON から取得
               → アプリ更新なしで辞書を追加・修正できる
               → 取得失敗時はバンドルの静的 JSON にフォールバック（オフライン対応）
               → キャッシュTTL: 24時間（毎回ネット通信しない）
  実装: `PronunciationMapService` として独立させ、TTSSanitizer はこのサービスに依存注入する
  ```
- ⚠️ `AVSpeechSynthesisVoice` の `AVSpeechSynthesisIPANotationAttribute` を使う高度な発音制御は
  将来フェーズで対応（現時点では辞書置換で十分）

---

## STEP 14: アニメーション物理定義

> **AIエンジニアへの指示:** SwiftUI の `animation(_:value:)` と `withAnimation` を使う。独自タイマーで座標を動かすような実装はしない。

### 14-1. スライドして完了（Slide-to-Complete）

```
トラック:
  幅: screen.width - 32pt（左右16ptマージン）
  高さ: 60pt
  背景色: .statusSuccess.opacity(0.15)
  corner radius: 30pt（半円）
  テキスト: "→ スライドして完了"（.eventTitle）

サム（つまみ）:
  幅・高さ: 56pt（円）
  色: .statusSuccess
  アイコン: checkmark（白）

インタラクション（AIへの厳密な実装指示）:
  1. ドラッグ中: サムがDragGestureのtranslation.widthに追従
     最小位置: 0pt、最大位置: トラック幅 - 56pt
     ⚠️ Y軸ヒットボックス: DragGesture の minimumDistance は X軸のみ判定
       → |translation.height| が 80pt を超えてもドラッグを継続する（指が斜めでも止まらない）
       → サムのY座標はトラック中央に固定（Y方向に動かない）
  2. 完了しきい値: サムがトラック幅の70%を超えた時点で **Haptic(.selection)**（カチッという軽い音）
     ⚠️ ここで .success を鳴らさない。指を離す前に「成功」バイブが鳴るのは不自然。
  3. 指を離した時:
     if 位置 < しきい値:
       → .spring(response: 0.4, dampingFraction: 0.65) で元の位置へ戻る
     else:
       → .spring(response: 0.25, dampingFraction: 0.8) でゴールへ吸い込まれる
       → サムがゴールに到達した瞬間（吸い込み完了）に **Haptic(.success)**（重いブルッ）
       → 0.1秒後に完了コールバック

フォールバック（スライドが難しい高齢者向け・⚠️ 必須実装）:
  トラック全体への「長押し2秒」でも完了を発動させる。
  LongPressGesture(minimumDuration: 2.0) を DragGesture と .simultaneously で組み合わせる。
  長押し中: トラック背景が .statusSuccess.opacity(0.15 → 0.40) に変化（視覚的フィードバック）
  長押し2秒完了: Haptic(.success) → サムがゴールへアニメーション → 完了コールバック
  ボタン直下に小さく「または長押しで完了」と常時表示（.caption、.secondary）
```

### 14-2. 長押しでスキップ（Hold-to-Skip）

```
ボタン外観:
  高さ: 44pt、テキスト: "今回はパス"（.secondary、.badge）
  5秒後にフェードイン（opacity: 0 → 1, duration: 0.5）

プログレスリング:
  直径: 28pt、線幅: 3pt、色: .statusSkipped
  長押し開始: リングが0→1に1.5秒で塗られる
    animation: .linear(duration: 1.5)
  1.5秒完了: Haptic(.medium) + スキップ発動
  指を離したら: リングが即座にリセット（.interactiveSpring()）
```

**⚠️ v15追加: `isReduceMotionEnabled` 時の折りたたみアニメーション代替:**

> `UIAccessibility.isReduceMotionEnabled = true` のユーザーは「動くUI」が苦手（前庭覚過敏・ASD等）。
> EventRow の折りたたみアニメーション（`.move(edge: .bottom).combined(with: .opacity)`）を停止させる。

```swift
// PersonHomeView の折りたたみトランジション:
let transition: AnyTransition = UIAccessibility.isReduceMotionEnabled
    ? .opacity  // 動きなし・フェードのみ
    : .move(edge: .bottom).combined(with: .opacity)  // 通常

.transition(transition)
.animation(UIAccessibility.isReduceMotionEnabled
    ? .easeInOut(duration: 0.2)
    : .easeInOut(duration: 0.3),
    value: isExpanded)
```

### 14-3. FABタップ → ハーフシート表示

```
FABタップ時:
  1. スケール: 1.0 → 0.92（duration: 0.1）
  2. Haptic: .impact(.light)
  3. スケール: 0.92 → 1.0（spring, response: 0.3, dampingFraction: 0.6）
  4. .sheet(isPresented: ..) detents: [.medium, .large]

シート内 - MicInputSheet全体レイアウト（⚠️ v12更新: リアルタイムフィードバック追加）:

  ┌─────────────────────────────────┐
  │                                 │
  │  🎤                             │ ← マイクアイコン（録音中: 赤・パルス / 待機中: グレー）
  │                                 │
  │  お話しください...               │ ← 大きなプレースホルダーテキスト（録音前）
  │  （録音開始後は以下に変わる）    │   .title2.bold、.secondary色
  │                                 │
  │  ████████████████████████████   │ ← 音声波形（Waveform）
  │                                 │
  │  [録音中のリアルタイム文字起こし]│ ← SFSpeechRecognizerのリアルタイム結果
  │  「明日の 12時に お昼の薬」     │   .body、.primary色
  │  （文字が流れてくるように表示）  │   最大3行・.lineLimit(3)
  │                                 │
  │  [停止して予定を作る]           │ ← 録音停止ボタン（高さ: 56pt、.owlAmber）
  └─────────────────────────────────┘

シート内 - 録音中の波形（Waveform）:
  バー数: 20本
  各バーの高さ: (audioLevel × 60pt) + 4pt（最小4pt）
  更新頻度: 60fps（AVAudioRecorderのpeakPower取得）
  アニメーション: .spring(response: 0.08, dampingFraction: 0.5)
  カラー: Gradient(colors: [.blue, .cyan])
  配置: 横に均等分布（各バーの幅: (containerWidth - (バー数-1) × 3) / バー数）
  録音していない時: すべてのバーが最小高さ（4pt）でフラット

  **⚠️ v15追加: `isReduceMotionEnabled` 時のマイク波形代替:**
  ```swift
  // UIAccessibility.isReduceMotionEnabled = true の場合:
  //   → 波形アニメーション（バーの高さ変化）を停止する
  //   → 代わりに「録音中」テキスト + 点滅なしの静的マイクアイコン（赤・塗りつぶし）に置き換える
  //   → 録音中の視覚的フィードバックは「マイクアイコンが赤になる」だけで十分

  if UIAccessibility.isReduceMotionEnabled {
      // 波形 View を非表示 → 代替の静的 UI を表示
      HStack {
          Image(systemName: "mic.fill").foregroundColor(.red)  // 赤マイク
          Text("録音中...").font(.body).foregroundColor(.secondary)
      }
  } else {
      WaveformView(audioLevel: $audioLevel)  // 通常の波形
  }
  ```

リアルタイム文字起こし（⚠️ v12追加）:
  - `SFSpeechRecognizer` + `SFSpeechAudioBufferRecognitionRequest` でストリーミング認識
  - `result.bestTranscription.formattedString` を TextField下に即時反映
  - 認識中: テキストを `.italic` + `.secondary` で表示（確定前の仮テキスト感を出す）
  - 認識完了（停止後）: テキストを `.primary` に切り替え + 予定タイトルフィールドに自動コピー
  - 認識結果が空の場合: 「うまく聞き取れませんでした。もう一度お話しください」を表示
  - ⚠️ プライバシー: SFSpeechRecognizer はオンデバイス認識を優先
    （`requiresOnDeviceRecognition = true` を設定。オフラインでも動作させる）

**沈黙・エラー時のUIステート（⚠️ v13追加: 高齢者対応必須）:**

> 高齢者はマイクボタンを押してから話し始めるまで3〜5秒かかることが多い。
> タイムアウトがないと「気づいたら何も録れていなかった」という無言の失敗が発生する。

```
MicInputSheet の状態遷移:

  [idle（未録音）]
     ↓ 録音ボタンタップ
  [recording（録音中）]
     ↓ 5秒間、認識結果の文字数が0のまま変化なし → タイムアウト
  [silenceError（沈黙エラー）]
     ↓ 「再試行」タップ
  [recording（録音中）] ← 再スタート

沈黙エラー状態のUI:
  ┌─────────────────────────────────┐
  │  🎤（赤・点滅なし）              │ ← 派手な演出なし（パニック防止）
  │                                 │
  │  声が届きませんでした            │ ← .title3、.statusDanger 色
  │  もう一度お話しください         │ ← .body、.secondary 色
  │                                 │
  │  ████████████████（フラット）    │ ← 波形はフラットに戻る
  │                                 │
  │  [🎤 もう一度試す]              │ ← .owlAmber、テキスト黒、高さ56pt
  │  [テキストで入力する]           │ ← .secondary テキストスタイル（代替手段）
  └─────────────────────────────────┘

実装仕様:
  - 沈黙検知: 録音開始から5秒後に `SFSpeechRecognitionResult` の transcription が空文字の場合
  - タイマー: `Task.sleep(for: .seconds(5))` で実装。認識結果が届いた瞬間にキャンセル
  - 「テキストで入力する」: TextField を直接表示するフォールバック（音声入力を諦めた場合）
  - 騒音エラー（認識できたが意味不明なテキストの場合）:
    → 認識結果をそのまま表示し「こんな感じでよろしいですか？」と確認する（消さない）
    → ユーザーが手動修正できるようにする（強制的にエラーにしない）
  - ⚠️ 「声が届きませんでした」のメッセージは .statusDanger 色だが赤ボタンは出さない
    （高齢者が「失敗した」と感じてアプリを閉じるのを防ぐ）

  **⚠️ v15追加: キーボード展開時の `.presentationDetents` 強制 `.large` 固定（あいまい2解消）:**

  > `MicInputSheet` は `.sheet(isPresented:)` + `.presentationDetents([.medium, .large])` で表示される。
  > `.medium` 状態で「テキストで入力する」フォールバックを選んだ場合、TextField をタップすると
  > キーボードが展開され、`.medium` シートとキーボードが重なってコンテンツが隠れる問題が起きる。

  ```swift
  // MicInputSheet.swift の実装指示:

  @State private var presentationDetent: PresentationDetent = .medium
  @FocusState private var isTextFieldFocused: Bool

  var body: some View {
      // ... シートのコンテンツ
      TextField("予定のタイトルを入力", text: $manualInputText)
          .focused($isTextFieldFocused)
          .onChange(of: isTextFieldFocused) { _, focused in
              // キーボードが出る（TextField フォーカス時）→ .large に強制切り替え
              if focused {
                  withAnimation { presentationDetent = .large }
              }
              // キーボードが閉じる（フォーカスが外れる）→ .medium に戻す（任意）
              // ⚠️ 戻さない場合: ユーザーが自分で縮小できるのでどちらでもよい
          }
  }
  .presentationDetents([.medium, .large], selection: $presentationDetent)
  // ⚠️ selection: binding を使うことが必須。.presentationDetents([.medium, .large]) だけでは
  //    コードから detent を変更できない（selection パラメータなしは読み取り専用）
  ```
```

### 14-4. ふくろうの状態遷移アニメーション

```
状態変化のルール（AIへの指示）:
  状態が変わるとき、ふくろうは「パッと切り替わる」のではなく
  必ず「瞬き→新状態へ変化」の補間を行う。

実装:
  1. 瞬き（まぶたが下りる）: scaleEffect(y: 0.1, anchor: .bottom)
     duration: 0.08s, curve: .easeIn
  2. まぶたが開く: scaleEffect(y: 1.0)
     duration: 0.08s, curve: .easeOut
  3. ふくろう本体のクロスフェード: opacity: 0 → 1
     duration: 0.3s, curve: .easeInOut

各状態の定義（Lottieファイルまたはシンプルなアイコンで実装）:
  idle     → ふくろう静止。2-3秒ごとに瞬き
  sleepy   → 半目。読書するようなポーズ
  happy    → 目を大きく開ける。翼を少し広げる
  worried  → 目をさらに大きく。小刻みにフラつく
  jump     → scaleEffect(1.0→1.2, anchor: .bottom) + offset(y: -20pt)
              .spring(response: 0.3, dampingFraction: 0.5) → 元に戻る

ふくろうの翼バタバタ（20% レアリアクション）:
  rotation3DEffect: -10° → 10° → 0°, duration: 0.2s, 3回繰り返し

2秒ごとのアイドル瞬き:
  Timer.publish(every: 2.5, on: .main, in: .common)
  ランダムに±0.5秒のジッターを加えて自然に見せる
```

### 14-5. OwlCelebrationOverlay（紙吹雪パーティクル）

```swift
// 5% スペシャルのみ。20% レアは星パーティクルのみ（紙吹雪なし）
// ⚠️ 必須: UIAccessibility.isReduceMotionEnabled を必ずチェックすること（ADHD・ASD・前庭覚過敏への配慮）

アクセシビリティ制御（AIへの厳密な実装指示）:
  let reduceMotion = UIAccessibility.isReduceMotionEnabled
  let lowPower = ProcessInfo.processInfo.isLowPowerModeEnabled
  // いずれかが true の場合、重いパーティクルをスキップする
  // 低電力モードは旧iPhone（SE2等）での発熱・バッテリー急消耗を防ぐ

  if reduceMotion || lowPower:
    // すべてのアニメーション演出をシンプルに格下げ
    75% 通常  → ふくろうが1回瞬き + 褒め言葉テキストのフェードイン（opacity: 0→1, 0.5s）
    20% レア  → 同上（星パーティクルなし）
    5% スペシャル → 同上 + ゴールドの輝きオーバーレイ（opacity 0→0.3→0, 1.0s）のみ
                    花火・ファンファーレなし。静的な演出のみ。
    // フラッシュ・点滅・高速な動きは一切出さない（光過敏・てんかん対応）

  if !reduceMotion:
    // 通常の変動比率スケジュール演出（以下）

紙吹雪仕様（reduceMotion=false の5%スペシャルのみ）:
  粒子数: 80個
  初速度: x = CGFloat.random(in: -200...200) pt/s
           y = CGFloat.random(in: -600...(-200)) pt/s
  重力加速度: +300 pt/s²
  回転: .random(in: -180...180)° → .random(in: -540...540)°（3秒間）
  フェードアウト: 2.0秒後から opacity: 1.0 → 0.0（1.0秒）
  サイズ: 8×8pt の角丸矩形（cornerRadius: 2pt）
  色: [.red, .blue, .yellow, .green, .orange, .purple] からランダム
  実装: Canvas + TimelineView（60fps）
  ⚠️ 点滅・フリッカーなし。各パーティクルは単調に落下のみ（逆方向への反射なし）

星パーティクル（reduceMotion=false の20%・5%共通）:
  粒子数: 20個
  アイコン: "star.fill"
  サイズ: 12pt → 4pt（1.5秒でスケールダウン）
  初速度: 360°方向にランダム、距離 50〜120pt
  .spring(response: 0.6, dampingFraction: 0.5)
```

### 14-6. 円形カウントダウンリングの出現

```
60分→59分のしきい値を超えた時（出現）:
  scaleEffect: 0.8 → 1.0
  opacity: 0 → 1
  .spring(response: 0.5, dampingFraction: 0.8)

残り時間の更新（1秒ごと）:
  リングの strokeEnd: 残り秒 / 合計秒
  .animation(.linear(duration: 1.0), value: progress)
  ※ .easeInOut ではなく .linear で単調に減らす（チカチカ防止）

10分未満でパルスが始まる:
  scaleEffect: 1.0 → 1.04 → 1.0（2秒周期）
  .easeInOut(duration: 1.0) + .repeatForever(autoreverses: true)
  同時に: リング色が .statusDanger（赤）に変化
    .animation(.easeInOut(duration: 1.0), value: isUrgent)
```

---