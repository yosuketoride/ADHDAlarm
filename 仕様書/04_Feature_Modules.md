
## STEP 5: マネタイズ設計

> ⚠️ **v16アップデート**: 本セクションの実装前に、必ず末尾の「[v16 パッチ P-3]」を確認すること。
> （Paywallトリガーの微調整、SOS発火日のレビュー依頼ブロック等）

### 5-1. 家族モードの無料/PRO境界線（⚠️ AIへの明示的指示）

**AIへの指示: 有料機能のUIには必ず 🔒アイコンを付け、タップ時に FamilyPaywallView をモーダルで表示すること。境界線を曖昧にしない。**

**フリーミアムの設計方針:**
> 「当日に親が生きていて、予定を受け取ったかどうか」は**無料で見える**。
> 「より詳しく・より安全に・記録を残す」がPROの価値。
> Aha!モーメント（予定が届いた・止めた）を無料で体験させてから課金を提案する。

| 機能 | 無料 | PRO |
|------|------|-----|
| 予定を送る（テンプレ） | ✅ | ✅ |
| Tab 0: 当日の予定一覧（全件） | ✅ | ✅ |
| Tab 0: 当日の完了/スキップ ステータス（⬤/✓/❌） | ✅ | ✅ |
| Tab 0: Last Seen（親のオンライン状態・当日） | ✅ | ✅ |
| Tab 0: 過去7日間の履歴・ステータス | 🔒 | ✅ |
| Tab 0: Last Seen 詳細（最終アクセス時刻・精度高） | 🔒 | ✅ |
| SOS連携・エスカレーション | 🔒 | ✅ |
| 家族への完了通知（スキップ時Push） | 🔒 | ✅ |
| 生声アラーム（Phase H） | 🔒 | ✅ |

**無料状態でのLocked UI表示例（修正後: 当日は見える）:**
```
  最終同期: 2分前 🟢            ← 無料でも当日は見える
  ┌─ 12:00 お昼の薬 ─────────┐
  │  ✓ 完了！ 12:01           │ ← 無料でも当日ステータスは見える
  └───────────────────────────┘
  ┌─ 過去7日間の記録 ──────────┐
  │  🔒 PROで過去の記録を確認  │ ← 履歴のみロック
  └───────────────────────────┘
```

### 5-2. 当事者モードの課金タイミング

| タイミング | 表示内容 |
|-----------|---------|
| PRO機能に触れた時 | 「この機能はプレミアムです。7日間無料でお試しください。」 |
| 月次サマリー時 | 「今月もよく使えました！PRO機能でもっと便利に」 |


### 5-2-B. App Store レビュー依頼タイミング（⚠️ 適切なタイミングを厳守）

> 不適切なタイミングで出すと星1レビューを誘発する。機嫌が最高の瞬間のみに限定する。
> `SKStoreReviewManager.requestReview(in:)` は年3回までしか表示されないため、無駄打ちしない。

```
レビュー依頼を出して良いタイミング（いずれか1つ・早い方）:

① 当事者モード: 月次サマリーで「今月も○回できたね！」表示の直後
   条件: その月の完了回数 >= 10回（習慣化が確認できた後）

② 家族モード: 親が初めてタスクを完了し、家族の画面に ✓✓ が届いた直後
   条件: ペアリングから7日以上経過（ハニームーン期間でない）

❌ 出してはいけないタイミング:
   - アプリ起動直後
   - エラーが出た後
   - ペイウォールが表示された後
   - スキップ・失敗イベントの後
   - アプリ使用開始から7日未満
```

### 5-3. 家族モードのAha!モーメント課金（最重要・2段階トリガー）

**トリガー①: ペアリング完了直後**
```
ペアリング完了 → 「娘さんとつながりました！🦉」（3秒後に自動遷移）
  ↓
FamilyPaywallView:
  「リアルタイムの完了通知・SOS連携を使うには
   見守りプレミアムが必要です。
   7日間無料でお試しください（月額880円）」

  [7日間無料で始める]    [あとで]
```

**トリガー②: 親が初めてタスクを完了した瞬間（⚠️ 最高の課金タイミング）**
> 家族が最も価値を実感する瞬間（✓✓ が届いた！）に文脈に沿って再提案する。
> 対象はペアリング経路（Universal Link / 6桁コード）を問わず、PRO未加入の全家族ユーザー。

```
親がアラームを「完了」→ 家族のTab 0 に ✓✓ が届く
  → 初回のみ、Tab 0 の上部に以下のコンテキスチュアルバナーを表示:
  ┌─────────────────────────────────────────┐
  │  🦉 お母さんがお薬を飲みました！                  │
  │     お母さんの毎日の『できた！』を、               │
  │     1年後も振り返れるようにしませんか？            │
  │     [PRO を7日間無料で試す]    [閉じる]           │
  └─────────────────────────────────────────┘

  条件:
    - subscriptionTier == .free（PRO未加入の全家族ユーザー）
    - 初回完了通知のみ（2回目以降はバナーを出さない）
    ※ ペアリング直後にペイウォールを表示したかどうかは問わない
       → 誰が家族アカウントを使っても（父・母・兄弟等）必ず1回オファーを届ける
```

### 5-4. サブスクリプション共有（Entitlement Sharing）⚠️ 必須アーキテクチャ

> **二重課金の炎上を防ぐ最重要設計。「家族グループで1契約」を徹底する。**
>
> 「親のアプリ」と「子のアプリ」で別々に月額880円を要求した場合、
> App Storeレビューは「二重取りの悪徳アプリ」という星1レビューで埋め尽くされる。

**ルール: 1つの `family_link_id` につき1つの PRO 契約で全員がPRO扱いになる**

```
契約者（例: 娘）が PRO を購入
    ↓
RevenueCat Webhook (or Supabase Edge Function) が購入イベントを受信
    ↓
family_links テーブルで当該ユーザーの全ペアリング相手を検索
    ↓
ペアリング相手（親・他の兄弟）の is_premium フラグも true に同期
    ↓
次回アプリ起動時に相手端末が checkEntitlement() → is_premium = true を確認
```

**Supabase テーブル設計（追加フィールド）:**

```sql
-- family_links テーブルに追加
ALTER TABLE family_links
  ADD COLUMN is_premium BOOLEAN NOT NULL DEFAULT false,
  ADD COLUMN premium_granted_by UUID REFERENCES auth.users(id),  -- 課金したユーザー
  ADD COLUMN premium_granted_at TIMESTAMPTZ;
```

**iOS 実装（AIへの指示）:**

```swift
// StoreKitService.checkEntitlement() の中で:
// 1. 自分の購入で is_pro = true の場合 → Supabase の propagatePROToFamilyGroup() を呼ぶ
// 2. Supabase の family_links.is_premium = true の場合でも subscriptionTier = .pro を設定する
//    （自分が課金していなくても、家族が課金していればPRO扱い）

func checkEntitlement() async -> Bool {
    // StoreKit 2 で自身の購入を確認
    let ownPurchase = await checkOwnPurchase()
    if ownPurchase { return true }

    // family_links で家族の is_premium を確認
    let familyPremium = await checkFamilyGroupPremium()
    return familyPremium
}
```

**RevenueCat 使用時:**
- `purchases.logIn(appUserID: supabaseUserID)` でユーザーを紐づける
- Webhook: `INITIAL_PURCHASE` / `RENEWAL` イベント → Supabase Edge Function で family propagation

**⚠️ 解約時の処理:**
- 課金ユーザーが解約 → `premium_granted_by` でひもづく全員の `is_premium = false` に同期
- ただし解約当月末まではグレースピリオドを設ける（App Store のルールに準拠）

### 5-6. 価格設定の根拠と変更方針

**月額880円（税込）の根拠:**
| 比較対象 | 価格 | 参考 |
|---------|------|------|
| 競合見守りアプリA | 月額980円 | 位置情報中心 |
| 競合見守りアプリB | 月額770円 | 通知のみ |
| 当アプリ | 月額880円 | 中間価格帯 |
- 機能価値（マナーモード貫通）から見ると安価に設定。認知障壁を下げるため端数なし（880円）。

**値上げ時のグランドファザリング方針:**
- 値上げ前のサブスクライバーは旧価格を維持（iOSのStoreKit仕様による自動保護）
- 値上げ時はアプリ内に「旧価格保護中」バッジを表示してロイヤルティを訴求する
- 月額880円→980円への変更は、DAU 5,000人到達後に検討

### 5-7. リファラル（紹介）設計

ペアリングの本質は「子が親を招待する」口コミ伝播。これをグロース施策として設計する。

**トリガー: ペアリング成功後の紹介フロー**
- ペアリング成功の「🎉 繋がりました！」画面に「他のご兄弟・ご家族にも紹介する」ボタンを追加
- タップ → ShareLink で「お母さんの見守りアプリを使い始めました #忘れ坊アラーム」をシェア
- 招待URLにリファラルコードを付与（Supabaseのreferral_codeカラムで追跡）

**継続的な紹介促進:**
- ふくろう進化時: 「家族に紹介してふくろうにプレゼントを贈る」導線
- 月次サマリー画面: 「このアプリを誰かに紹介する」ShareLinkボタン

**計測:**
- referral_sent イベント（紹介リンク送信）
- referral_installed イベント（紹介経由インストール）
- 目標: 月次新規ユーザーの20%がリファラル経由

### 5-8. 家族リアクション機能（⚠️ チャーン構造的解消・Phase B必須）

> **問題（ビジネスパラドックス）:** 「アプリが優秀で親が自立する → 家族が解約する」。
> 見守り機能だけでは「監視ツール」になりLTV（顧客生涯価値）が最大3〜6ヶ月で頭打ちになる。
> 「親子が小さな達成感を共有し続けるツール」に昇華させ、解約動機を消す。

**トリガー: 10回連続完了バナー（FamilyHome Tab 0）**

親が10回連続でアラームを「完了」した瞬間、家族側の FamilyHome Tab 0 上部に以下のバナーが**1度だけ**表示される:

```
┌─────────────────────────────────────────┐
│ 🎉 お母さんが10回連続で完了しました！      │
│    「おめでとう」を送りますか？            │
│                                         │
│  [🎊 おめでとうを送る！]  [あとで]        │
└─────────────────────────────────────────┘
```

**「おめでとうを送る！」タップ時の処理:**
1. FamilyHome側: 花火エフェクト（`CAEmitterLayer`）が画面全体に2秒間展開
2. Supabase の `family_reactions` テーブルに INSERT（type: "congrats", from: familyUserID, to: parentUserID）
3. 親端末へプッシュ通知: 「🎉 長女から「おめでとう！」が届きました」
   - アプリが前面にある場合: ふくろうが `happy` 表情 + `.owlBounce`（3秒）+ トースト
   - バックグラウンドの場合: 通常のプッシュ通知（sound: default）

**バナーUIの仕様:**
- 高さ: 80pt
- 背景: `LinearGradient(colors: [.owlAmber, Color.pink.opacity(0.4)], startPoint: .leading, endPoint: .trailing)`
- テキスト: `.headline`（黒） + `.caption`（黒・opacity 0.7）
- ボタン高さ: 44pt、背景: 白、テキスト: `.owlAmber`
- 花火エフェクト: `CAEmitterCell` 5種（confetti・star・circle）、速度方向: 上から下
- バナーは「送る」または「あとで」タップ後、UserDefaultsに表示済みフラグを保存して二度と表示しない

**Supabase テーブル（追加）:**
```sql
CREATE TABLE family_reactions (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  from_user_id    UUID NOT NULL REFERENCES auth.users(id),
  to_user_id      UUID NOT NULL REFERENCES auth.users(id),
  reaction_type   TEXT NOT NULL DEFAULT 'congrats',
  created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
  read_at         TIMESTAMPTZ
);

ALTER TABLE family_reactions ENABLE ROW LEVEL SECURITY;
CREATE POLICY "send own reactions"
  ON family_reactions FOR INSERT
  WITH CHECK (auth.uid() = from_user_id);
CREATE POLICY "read reactions to me"
  ON family_reactions FOR SELECT
  USING (auth.uid() = to_user_id);
```

**計測イベント:**
- `family_reaction_sent`（送り手がタップ）
- `family_reaction_received`（受け取り手に届いた）

**将来拡張（Phase F以降）:**
- リアクション種類を増やす（👏 拍手・❤️ 応援・🌸 ありがとう）
- 週次サマリー画面に「今月〇回おめでとうを送り合いました」表示

### 5-5. 家族LTV差別化・継続利用インセンティブ（⚠️ v14追加: A-9）

> **問題:** ハニームーン期間（ペアリング直後）に課金しても、3ヶ月後には「お母さんが自分でできるように
> なったから解約」という離脱が起きる。解約後に再課金させるのは新規獲得の2〜3倍コストがかかる。
> 継続的な価値を定期的に可視化して「まだ必要」と感じさせる設計が必須。

**継続利用インセンティブの3軸:**

**① 月次サマリーの家族版（月末）:**
```
家族の Tab 0 に月1回表示される「今月のまとめ」カード:

  ┌─────────────────────────────────────────┐
  │  🦉 今月もお母さんのサポートありがとう！  │
  │                                         │
  │  ✅ 完了: 18回  ❌ お休み: 4回          │
  │  🔔 アラームに気づいた率: 82%            │
  │                                         │
  │  先月（13回完了）より +5回 増えました！   │ ← 成長の可視化（数字比較）
  │                                         │
  │  🦉「お母さん、今月もよく頑張りました！  │
  │       ぜひ一言声をかけてあげてください」 │ ← ふくろうの行動提案（温かい）
  └─────────────────────────────────────────┘

表示条件:
  - PRO ユーザーのみ（無料版: 先月比較は🔒。完了・お休みの件数のみ表示）
  - 月末最終日に1回だけ表示（スクロール最上部に固定・1日で消える）
  - 消えた後は履歴タブで過去7日間の集計として参照可能
```

**② 節目の「一緒に喜ぶ」バナー:**
```
以下のマイルストーン達成時に Tab 0 上部に1回だけ表示:

  - 累計完了10回目: 「🎉 お母さんが10回目の『できた！』！」
  - 連続7日間ノースキップ: 「🌟 今週1週間、全部できたよ！すごい！」
  - ペアリングから30日: 「🦉 つながって1ヶ月！お母さんとの信頼が育ってます」

実装: `family_milestone_shown_{milestone_key}` を UserDefaults に記録して重複表示防止
AIへの指示: バナーはコンテキスチュアル（条件付き表示）のみ。定期的なポップアップは禁止。
```

**③ 解約前の「やめちゃうの？」チェックイン:**
```
解約フロー（App Store の購読管理から解約しようとした場合ではなく、
設定画面の「プレミアムを解約する」ボタンタップ時）:

  ┌─────────────────────────────────────────┐
  │  🦉 解約する前に確認させてください      │
  │                                         │
  │  今月のお母さんの記録:                  │
  │  ✅ 完了 18回 / 🗓 31日間               │
  │                                         │
  │  解約するとこれらが使えなくなります:    │
  │  • 過去の記録を振り返る                │
  │  • スキップ時の通知                    │
  │  • SOS連携                             │
  │                                         │
  │  [続けて使う（解約しない）]            │ ← owlAmber
  │  [それでも解約する →]                  │ ← .secondary（目立たない）
  └─────────────────────────────────────────┘

実装の注意:
  - 解約ボタンは App Store の購読管理へのリンク（内部キャンセルは不可）
  - このチェックイン画面は「解約を阻止する」のではなく「現在の価値を可視化する」のが目的
  - 「続けて使う」タップ → 画面を閉じる（それ以上の引き止めなし）
  - 「それでも解約する」タップ → App Store 購読管理へ遷移
```

---

## STEP 8: ペアリングUX（親の操作を限りなくゼロに）

### 8-1. Universal Link + 6桁コードの二段構え（どちらも必須）

**Universal Link方式（メインフロー）:**
```
子: 設定 → 「おかあさんとつなげる」→ 招待リンク生成 → 「LINEで送る」
親: LINEのリンクをタップ1回 → iOSがアプリ起動 → 【相互同意確認画面】→ ペアリング完了
```

**⚠️ 相互同意確認（オプトイン）画面 ── 必須（プライバシー法的要件）:**

> 「タップ1回で自動ペアリング完了」は監視アプリと同じ挙動であり、App Store ガイドライン 5.1.1（プライバシー・同意）違反のリスクがある。
> 親が自分の予定・行動状況が子に共有されることを**明示的に理解して同意する**1枚が必須。

```
┌─────────────────────────────────────────┐
│  🦉                                     │
│  〇〇さん（娘さん）から                  │
│  お手伝いのリクエストが届いています      │
│                                         │
│  ✅ 娘さんがあなたに予定を送れるように   │
│     なります                           │
│  ✅ アラームが止まったかどうかが         │
│     娘さんに伝わります                  │
│                                         │
│  🛡️ プライバシーは守られます             │
│     （あなたの居場所などが              │
│     勝手に伝わることはありません）      │
│                                         │
│  [つながる]          [今はやめておく]   │
│  （.owlAmber、黒テキスト）（.secondary）│
└─────────────────────────────────────────┘

「つながる」タップ → ペアリング完了 → FamilyPaywallView へ
「今はやめておく」タップ → アプリのホームへ（ペアリングしない）
```

**この画面の実装要件（AIへの指示）:**
- リンクを受け取った親のデバイスで必ず表示する（子側では表示しない）
- 「できること（✅）」と「プライバシー保護（🛡️）」の2点を必ず明記する（安心の提示）
- ❌マーク（否定表現）を使わず、🛡️マーク（保護表現）で安心感を伝える（ポジティブフレーミング）
- 同意なしに `family_links` テーブルへのレコード挿入を行ってはならない
- 「今はやめておく」を選んだ場合でも、後で設定画面から自分で「つなげる」ことができる旨を表示する

**6桁コードフォールバック（必須）:**

> iOSのプライバシー制限により Deferred Deep Linking はアプリ未インストール時に高確率で失敗する。
> 「リンクを押したのに何も起きない」パニックを防ぐため、手動コード入力を必ず実装する。

```
子の画面: 「招待コード: 483921」を表示
親の画面: 「コードを入力してつなげる」→ 6桁入力 → 【相互同意確認画面】→ ペアリング完了
```

- Universal Link 成功 → コード不要（スキップ）、同意画面は表示
- Universal Link 失敗 → コード入力画面に自動フォールバック、同意画面は表示

---

## STEP 11: ウィジェット仕様

### 11-1. Small Widget
```
┌──────────────┐
│ 🦉           │  ← ふくろうの状態（sleepy/happy/worried）をイラストで表現
│  あと 28分   │  ← 大きなテキスト
│ お昼の薬     │
│ 12:00        │
│ [✓ 完了にする]│  ← インタラクティブボタン（AppIntent）
└──────────────┘
```

**インタラクティブウィジェット仕様（iOS 17+ AppIntent・⚠️ v12追加）:**

> ウィジェットからアプリを開かずに「完了」を記録できることで、
> ロック画面やホーム画面から一瞬で達成感を得られる。
> 特に「今すぐ薬を飲んだのにスマホを開くのが面倒」な高齢者・ADHD当事者の操作摩擦をゼロに近づける。

```swift
// AppIntents/CompleteAlarmIntent.swift
struct CompleteAlarmIntent: AppIntent {
    static var title: LocalizedStringResource = "予定を完了にする"

    @Parameter(title: "予定ID")
    var eventID: String

    func perform() async throws -> some IntentResult {
        // 1. AlarmEventStore で eventID を検索
        // 2. completionStatus = .complete を設定
        // 3. XP +10 を付与（デイリーキャップ確認）
        // 4. Supabase に dismissed_status = "complete" を送信（Undoなし・ウィジェット操作のため）
        // 5. ウィジェットの更新は AppIntent の ReturnsValue / invalidatesContext で自動反映させる
        //    ⚠️ WidgetCenter.shared.reloadAllTimelines() を ここで呼ばないこと（下記参照）
        return .result()
    }
}
```

**ウィジェット実装仕様（AIへの指示）:**
- `Button(intent: CompleteAlarmIntent(eventID: entry.nextEvent?.id.uuidString ?? ""))` を Small Widget 下部に配置
- ボタンラベル: 「✓ 完了にする」（.caption、.statusSuccess色）
- 次の予定がない場合はボタン非表示
- 完了済み予定の場合: 「✓ 済み」テキストのみ（ボタンなし）
- ウィジェット操作からの完了は Undo なし（スナックバーはアプリ内のみ）

**ふくろう状態のウィジェット表示:**
```
ふくろうの状態（AppState.owlState）をウィジェット背景/アイコンに反映する:
  idle/normal → 通常のふくろうアイコン
  sleepy → 半目のふくろう（予定なし・60分以上余裕）
  worried → 目が大きいふくろう（10分未満）
  happy → にっこりふくろう（完了直後・XP閾値到達）

ふくろう名（owlName）をウィジェットテキストに反映:
  次の予定がある場合: 「[owlName]が待ってるよ」（サブタイトル）
  例: 「ふくろうが待ってるよ」「ポチが待ってるよ」
  次の予定がない場合: 「[owlName]と一緒にのんびりしてね」

実装: EntryView が AppState（App Group UserDefaults 経由）から owlName / owlState を読み取る
WidgetKit は App Group でのみ AppState を参照可能。
Constants.appGroupID = "group.com.yosuke.WasurenboAlarm" を使用すること。
```

### 11-2. Medium Widget（ふくろうの部屋・⚠️ v13追加: SNSバイラルの核心）

> **設計根拠（Pixel Pals / Finch 分析）:**
> バズるウィジェットは「情報を表示するツール」ではなく「生活している世界の窓」。
> ホーム画面を見るたびに「あ、部屋が豪華になってる」という発見がSNSシェアを生む。
> Small Widgetが「便利な時計」なら、Medium Widgetは「見たくなる窓」として機能させる。

```
Medium Widget（横長 2:1 比率）:

┌────────────────────────────────────────────┐
│ ┌──────────┐   ふくろう（owlName）         │
│ │          │   あと 28分                   │
│ │  [部屋]  │   お昼の薬                    │
│ │  🦉📚🪴  │   12:00                       │
│ │          │   [✓ 完了にする]              │
│ └──────────┘                               │
└────────────────────────────────────────────┘

左ペイン（1/3）: ふくろうの部屋（箱庭）
右ペイン（2/3）: 次の予定情報 + 完了ボタン
```

**ふくろうの部屋 アイテム解放仕様（XP連動）:**

| XP段階 | 部屋の様子 | 追加されるアイテム |
|--------|----------|-----------------|
| 0〜99 XP | 空の部屋 | ふくろうのみ |
| 100〜299 XP | 小さな部屋 | 🪵 木製の本棚 |
| 300〜699 XP | 心地よい部屋 | 🪴 観葉植物 |
| 700〜999 XP | 豪華な部屋 | 🕯️ アンバー色のランプ |
| 1000〜 XP | 賢者の塔 | 🔭 天体望遠鏡 |

**実装仕様（AIへの指示）:**

> ⚠️ **v14修正: ふくろうPNG + アイテムPNGをただ重ねるだけでは、遠近感のない「安っぽいコラージュ」になる。**
> 部屋の奥行きを表現する「背景画像（床と壁のパース付き）」を最背面に配置し、
> その上にアイテム・ふくろうを重ねることでリッチな箱庭感を出す。

**レイヤー構造（ZStack・背面から前面の順）:**

```
ZStack（ふくろうの部屋 左ペイン）:
  Layer 1（最背面）: room_background_light.png / room_background_dark.png
                     → colorScheme に応じて切り替え
                     → 床と壁にパース（奥行き）がついたイラスト背景
  Layer 2: アイテムアイコン（解放済みのみ表示）
           配置ルール: 床面の奥→手前の順に重なるよう y座標を設定
           例: 本棚は奥の壁際（y: 8pt）、観葉植物は床の手前側（y: 24pt）
  Layer 3（最前面）: ふくろうイラスト（常に一番手前に表示）
```

- アイテムは XP 段階が上がった瞬間に `.spring(response: 0.6)` アニメーションでフェードイン
- WidgetKit では `.containerBackground` を使う（`.background()` は効かない）
- ふくろうの状態（owlState）が部屋の雰囲気に反映:
  - sleepy → 背景の照明を暗くする（`room_background_dark.png` + `.colorMultiply(.gray.opacity(0.7))`）
  - worried → ふくろうを窓側に寄せる（`offset(x: -8pt)`）
  - happy → 背景に `.colorMultiply(.yellow.opacity(0.1))` で暖かい光を足す
- SNSシェアしたくなるよう、**アイテムは「実用的な家具」ではなく「可愛い・ちょっと不思議な物」**を選ぶ
- WidgetKit から App Group UserDefaults 経由で `owlXP`（Int）を読み取り、段階を算出する

**⚠️ 実装の罠:**
- WidgetKit の Widget サイズは `WidgetFamily` で分岐する（`.systemSmall`, `.systemMedium`）
- 部屋のアイテム増加は Widget のタイムライン更新（`WidgetCenter.shared.reloadAllTimelines`）でのみ反映される
- アニメーションは WidgetKit では自動で適用されない。`.transition()` は Timeline Entry 切り替え時に有効

**⚠️ WidgetKit 更新 Budget 制限（v14追加・必須知識）:**

> iOS は1日あたりのウィジェット更新回数を **約40〜70回** に制限している（Battery/Performance Budget）。
> ユーザーが完了ボタンを毎回押すたびに `WidgetCenter.shared.reloadAllTimelines()` を呼ぶと、
> 昼過ぎには Budget が枯渇し、夕方にウィジェットがフリーズして動かなくなる。

**正しい更新戦略（AIへの指示）:**

```swift
// ✅ AppIntent 経由の完了操作:
//    iOS 17以降、AppIntent の結果として UI が自動的に invalidate される。
//    CompleteAlarmIntent.perform() では reloadAllTimelines を呼ばない。
//    WidgetKit が AppIntent の完了を検知して必要最小限の更新を行う（OS が最適化する）。

// ✅ XP 上昇でアイテムが解放された瞬間（アプリ内・稀なイベント）のみ呼んでよい:
if owlXPJustCrossedThreshold {
    WidgetCenter.shared.reloadAllTimelines()  // これは OK（1日に数回以下）
}

// ❌ 毎回完了ボタンを押した時:
// WidgetCenter.shared.reloadAllTimelines()  // Budget 消費。呼ばない。

// ✅ アプリが foreground に戻った時（scenePhase == .active）のみ呼んでよい:
// これは1日に数十回以下なので Budget 内に収まる
```

### 11-3. ロック画面ウィジェット
- ふくろうアイコン + カウントダウン数字のみ（タイトル非表示・プライバシー保護）
- ふくろうアイコンはowlStateに連動（状態絵文字で代替可）

---

### P-3. STEP 5 関連パッチ（マネタイズ・レビュー）

**P-3-1. Paywall トリガー②の調整（R4-⑪）:**
- 「初回完了（✓✓）」時は全画面Paywallではなく小さなコンテキスチュアルバナーに留める
- 全画面Paywallは「🔒ロック機能タップ時」のみに限定（In-Context Paywall）

**P-3-2. 初回 missed/skip 時の Paywall トリガー追加（R2-⑦）:**
- 親が初めて missed または skip した時、家族Tab 0 上部にバナー表示:
  「⚠️ お母さんがアラームを見逃しました。SOS連携（PRO）でより安全に見守りませんか？」

**P-3-3. ReviewManager SOS日の発火ブロック（R4-⑮）:**
- レビュー依頼の許可条件に `!appState.hasSOSFiredToday` を追加
- SOS発火した日はレビュー依頼を一切出さない

**P-3-4. 解約チェックイン 低完了率時の表示切替（R3-⑯）:**
- 完了率20%未満: 実績数字を出さず、トラブルシューティング誘導に切替
  「🦉 最近お母さんの調子はいかがですか？アラームの音量や時間を調整できます」

**P-3-5. 週次フィードバック追加（R1-⑮）:**
- 日曜日にウィークリーショートフィードバック（アプリ内のみ、シェア画像なし）
- ふくろうが「今週は○回できたね！」とPersonHomeで褒める

**P-3-6. アカウント削除時のサブスク案内（R1-⑬・⚠️ 必須）:**
- 削除フロー開始時に `StoreKit.showManageSubscriptions(in:)` を先に呼び出し
- ActionSheetに免責テキスト追記: 「※Appleの定期購読は自動で解約されません」

**P-3-7. XPキャップルール（確定・⚠️「検討」廃止）:**
- **💊 薬を含む全カテゴリ、デイリーキャップ 50XP/日 の対象とする（例外なし）**
- 理由: 例外ロジックはApp/Widget間でのXP計算ズレを生む。シンプルなキャップが最も安全
- ウィジェット（AppIntent）・アプリ本体・デイリーミニタスク、いずれのXP付与も50XP上限を共有する

---

### P-7. システム基盤・ウィジェット パッチ

**P-7-1. ToastのZ-Indexレイヤー問題（R4-⑤・⚠️ 必須）:**
> `RootView` の `.overlay` では `.fullScreenCover`（RingingViewなど）の裏側に隠れてしまう。
> **→ 解決策A「UIWindowレベル描画」を採用。解決策Bは廃止。**

```swift
// Services/ToastWindowManager.swift（新規作成）

@MainActor
final class ToastWindowManager {
    static let shared = ToastWindowManager()
    private var toastWindow: UIWindow?

    func show(_ message: ToastMessage) {
        guard let windowScene = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene }).first else { return }

        let window = UIWindow(windowScene: windowScene)
        window.windowLevel = .alert + 1  // .fullScreenCover (.normal + 200) を超えるレベル
        window.backgroundColor = .clear
        window.isUserInteractionEnabled = true

        let hostVC = UIHostingController(rootView: ToastView(message: message))
        hostVC.view.backgroundColor = .clear
        window.rootViewController = hostVC
        window.makeKeyAndVisible()
        self.toastWindow = window

        // 表示時間後に自動的にウィンドウを破棄
        let duration = message.style == .owlTip ? 3.0 : 2.0
        Task {
            try? await Task.sleep(for: .seconds(duration + 0.4))  // フェードアウト余裕分
            await MainActor.run {
                self.toastWindow = nil
            }
        }
    }
}

// ⚠️ 変更点:
// - ToastModifier（ViewModifier）は廃止。RootView の `.overlay` は削除する
// - ToastModifier.swift の代わりに ToastWindowManager.swift を使う
// - AppState.showToast() は ToastWindowManager.shared.show() を呼ぶよう変更
// - 各ViewModel から: appState.showToast(ToastMessage(...)) の呼び出し方は変わらない

// ⚠️ UIWindow の makeKeyAndVisible() に注意:
// これにより他のUIへのタッチが遮断される可能性があるため、
// ToastView 自体の isUserInteractionEnabled は false にすること（タップ不要なToastの場合）
// 「取り消す」ボタン付きToastのみ true に設定
```

**P-7-2. Widget 日付変更線での更新（R2-⑤）:**
- `WidgetTimelineProvider.getTimeline` の実装にて、必ず「翌日 00:00」のEntryをスケジュールに追加する
- これがないと、日付が変わっても「昨日の予定」が表示され続ける

**P-7-3. TabView内の NavigationStack ディープリンク（R4-⑬）:**
- AppRouter内に以下を定義し、Push通知タップ時のルーティングを確実に行う:
  - `familyTabSelection: Int`
  - `pathTab0: NavigationPath` / `pathTab1: NavigationPath` / `pathTab2: NavigationPath`
- 例: 親がスキップした通知タップ時 → `familyTabSelection = 0`, `pathTab0.append(AlarmDetailView)`

**P-7-4. 家族モードの Pull to Refresh（R4-⑨）:**
- Tab 0（PersonHome）に `.refreshable` を設定
- 親が自身のアプリで予定を完了した際、家族側が手動再取得できる導線

---

### P-9-1. 薬の二重服用トラップ防止（⚠️ 必須・医療安全）

> **問題:** `completionStatus` を Undo で nil に戻した直後、家族側から同一イベントへの `complete` PATCH が届くと、ユーザーは「Undoした」つもりなのに completionStatus が再び complete になる。次のアラームが発火せず薬を二重服用する事故が起きる。

**防止ルール（AIへの実装指示）:**

```swift
// SyncEngine.applyRemoteCompletionStatus() 内に追加:

// ⚠️ 「Undo の直後（5分以内）に remote から complete が来た場合」は絶対に上書きしない
// undoPendingUntil: Date? を AlarmEvent に追加し、Undo操作直後にnow+5分をセット
if let protectUntil = event.undoPendingUntil, Date() < protectUntil {
    print("DEBUG: Remote complete blocked — undo protection active until \(protectUntil)")
    return  // 上書き禁止
}
```

**AlarmEvent モデルへの追加:**
- `undoPendingUntil: Date?` フィールド追加（UserDefaults永続化）
- Undoタップ直後に `undoPendingUntil = Date().addingTimeInterval(5 * 60)` をセット
- DismissSheetの30秒タスク確定後（P-9-13参照）: `undoPendingUntil = nil` に戻す

---

#### P-9-10. 無料/PRO 境界線「今日」の定義明記

> **問題:** 「当日のステータスは無料で見える」「過去7日間は有料」と言うが、「今日」の境界が端末ローカル時刻依存であることが未定義。

**定義（AIへの指示）:**

```swift
// FamilyDashboardViewModel 内で統一して使う:
static func isToday(_ date: Date) -> Bool {
    Calendar.current.isDateInToday(date)
    // ⚠️ UTC変換しない。端末のローカルタイムゾーンで「今日」を判定する。
    // 日本国内ユーザー前提。タイムゾーン対応は Phase 8-4 で行う。
}

// PRO境界線の判定:
// - isToday(event.startDate) == true → 無料でも表示
// - !isToday(event.startDate) && within7Days(event.startDate) → PRO限定（🔒）
// - !isToday(event.startDate) && olderThan7Days → 表示しない（ストレージから削除可）

// 「昨日」の定義: Calendar.current.isDateInYesterday(event.startDate)
// 日付変更は Calendar.current.startOfDay(for: Date()) を基準とする
```

---

#### P-9-11. Android 親への対応方針（Phase 1 スコープ外の明記）

> **現実:** 子（家族）が iOS アプリを使い、親が Android スマートフォンを使っている家庭は珍しくない。Universal Link も 6桁コードも iOS アプリのインストールが前提のため、Android 親への招待は詰まる。

**Phase 1 の方針（AIへの実装指示）:**

```
FamilyPairingOnboardingView に注記を追加:
「⚠️ 現在、このアプリはiPhoneのみ対応しています。
  お母さんのスマホがAndroidの場合、見守り機能はご利用いただけません。
  将来のアップデートでAndroid対応を検討しています。」

招待リンク生成時の追加情報:
「このリンクはiPhoneをお使いの方のみ使えます。
  LINEでリンクと一緒に『iPhoneでご確認ください』と添えて送ることをおすすめします。」
```

**ロードマップ（P-8 への追記）:** Android対応は Phase 2 以降で Web版（PWA）または React Native クロスプラットフォーム対応を検討。

---

#### P-9-12. ミニタスクの家族ダッシュボード同期除外

> **問題:** P-1-5 で追加したデイリーミニタスク（「お水飲んだ？」+5XP）が、Supabase 同期経由で家族ダッシュボードに「謎の完了イベント」として届く可能性がある。

**AlarmEvent モデルへの追加（AIへの指示）:**

```swift
// AlarmEvent に追加:
var isMiniTask: Bool = false  // デイリーミニタスクフラグ

// SyncEngine.pushToRemote() 内に追加:
guard !event.isMiniTask else {
    // ミニタスクはSupabaseに同期しない（ローカルXP付与のみ）
    return
}

// FamilySendTab からは isMiniTask == true のイベントを一切表示しない
// FamilyDashboardTab のフィルタ: events.filter { !$0.isMiniTask }
```

---

#### P-9-14. ToDo タスクの翌日持ち越しルール

> **問題:** P-1-11 で `isToDo: Bool` を追加したが、日付変更時（00:00）の挙動が未定義。通常の時刻付きアラームは「完了ステータスをリセットして翌日0件プレースホルダーに戻す」が、ToDo は別の挙動が必要。

**ToDo の日付変更挙動（AIへの指示）:**

```
通常のアラーム予定（isToDo == false）:
  → 翌日00:00: completionStatus をリセット（nil）してリスト下部からトップへ
  → 繰り返し予定の場合: 次インスタンスを生成（RRULE に従う）
  → 一回限りの予定: EventKit から削除（AlarmKit も cancel）

ToDo タスク（isToDo == true）:
  → 翌日00:00: completionStatus == .complete なら EventKit から削除（達成済みのため）
  → 翌日00:00: completionStatus == nil（未完了）なら「持ち越し」— 削除しない
  → 持ち越されたToDoはリスト最上部に「🔁 昨日から」バッジ付きで表示
  → ユーザーが手動で削除するか、完了するまで持ち越しが続く

実装:
  SyncEngine.performDailyReset() の中に:
    let expiredToDos = allEvents.filter {
        $0.isToDo && $0.completionStatus == .complete
    }
    expiredToDos.forEach { alarmEventStore.delete($0) }

    let carriedOverToDos = allEvents.filter {
        $0.isToDo && $0.completionStatus == nil
    }
    carriedOverToDos.forEach { $0.isCarriedOver = true }  // バッジ表示フラグ
```

**AlarmEvent への追加フィールド:** `isCarriedOver: Bool = false`（持ち越しバッジ表示用）

---
