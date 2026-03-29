## STEP 3: アラーム停止画面（⚠️ 2段階フロー必須）

> ⚠️ **v16アップデート（最重要）**: 本セクションの実装前に、必ず末尾の「[v16 パッチ P-2]」を確認すること。
> （「スヌーズ機能」と「DismissView（ハーフシート）」の追加、レイアウトシフト防止等）

### 3-1. AlarmKitの仕様制約（AIが誤実装する罠）

**AlarmKitはOSレベルのシステムUIを持つ（CallKitと同じ構造）。**
SwiftUIのカスタムビューを直接配置することはできない。
「長押しスキップ」「SOSバー」等のカスタム要素はOSアラーム画面には入れられない。

**正しい2段階フロー:**

```
【Stage 1: OSネイティブアラーム画面】
  AlarmKit発火 → iOSが標準アラーム画面を表示
  カスタマイズ可能な範囲:
    - AlarmPresentation.Alert.title = "🦉 ふくろうからのお知らせ"（プライバシー保護）
    - 停止ボタンのラベル = "確認する"
  ユーザーが「確認する」をスライド → アプリがフォアグラウンドへ

【Stage 2: アプリ内RingingView（SwiftUI）】
  alarmUpdates で .alerting を検知 → appRouter.ringingAlarm に設定
  → fullScreenCover で RingingView が表示される（ここが初めてカスタムUI）
  ここに: スライド完了 / 長押しスキップ / SOSプログレスバー を配置
```

**SOSタイマーの扱い:**
- タイマーは Stage 1 でアラームが発火した瞬間（`alarm.fireDate`）から起算
- Stage 2 (RingingView) が表示された時点で「経過時間」を計算してバーに反映
- `escalationTimer` は `startAudioPlayback()` 呼び出し時に開始（既存実装を維持）

### 3-1-B. スワイプキル対応（⚠️ 未実装だとゾンビLive Activityが残る）

**問題:** ユーザーが Stage 1 の通知バナーを「確認する」スライドではなく**上方向スワイプで消した場合**、AlarmKit の `.alerting` 状態は解消されず、Dynamic Island に空のアクティビティが残り続ける。アプリの `alarmUpdates` が `.alerting` を検知し続け、Stage 2 は永遠に起動しない。

**対策（AIへの実装指示）:**
```swift
// ADHDAlarmApp.watchAlarmUpdates() の中で、
// scenePhase が .active になった時点で alerting 中の AlarmKit アラームが
// 既に RingingView に表示中かどうかを照合する。

// アラームが alerting のままで RingingView が未表示の場合:
//   → AlarmManager.shared.cancel(id: alertingAlarm.id) を呼び、ゾンビ状態を解消
//   → Supabase の当該イベントに dismissed_status = "swipe_killed" を記録
//   → ふくろうトースト: 「さっきのお知らせ、見逃してしまったようです 🦉」

// scenePhase 監視（.onChange(of: scenePhase)）の .active ブランチに追加実装すること
```

**チェック条件:**
- `appRouter.ringingAlarm == nil`（Stage 2 未表示）
- `AlarmManager.shared` が当該IDのアラームを `.alerting` で返している

### 3-1-C. State Out of Sync リカバリ（⚠️ 最頻発バグ・必須実装）

**問題:** Apple Watch での停止・OS側（コントロールセンター等）での停止・アプリを開かずに放置など、Stage 2（RingingView）を経由しない停止パターンが多数存在する。この場合、次にアプリを開いたとき「過去のアラームの RingingView が無音で全画面表示される」ゾンビ状態が発生する。

**対策（AIへの実装指示）: `scenePhase == .active` 時に必ず走らせる「ステートリカバリ処理」**

```swift
// ADHDAlarmApp.swift の .onChange(of: scenePhase) の .active ブランチに追加。
// スワイプキル対策（STEP 3-1-B）と同じタイミングで実行する。

private func recoverStaleAlarmState() async {
    // AlarmKit の alerting 中アラームを全件取得
    for await alarms in AlarmManager.shared.alarmUpdates {
        let alertingAlarms = alarms.filter { $0.state == .alerting }
        for alertingAlarm in alertingAlarms {
            guard let event = AlarmEventStore.shared.find(alarmKitID: alertingAlarm.id) else { continue }

            let elapsed = Date().timeIntervalSince(event.fireDate)

            // 発火時刻から15分以上経過している場合:
            if elapsed > 15 * 60 {
                // 1. RingingView は絶対に表示しない（appRouter.ringingAlarm に設定しない）
                // 2. AlarmKit アラームをキャンセル（ゾンビ解消）
                try? await AlarmManager.shared.cancel(id: alertingAlarm.id)
                // 3. completionStatus を .missed としてローカル記録
                //    → PersonHomeViewModel が EventRow を「見逃し」表示に切り替える
                // 4. Supabase に dismissed_status = "missed" をサイレント同期
                // 5. ふくろうトースト（1回のみ表示）:
                //    「さっきのお知らせ、時間が経っていたのでお休みにしておきました 🦉」
            }
            // 15分未満かつ RingingView 未表示 → 通常のスワイプキル対策（3-1-B）に委ねる
        }
        break  // 1回だけチェックすればよい（alarmUpdates は常時ストリーム）
    }
}
```

**missed（見逃し）のUI表示:**
- EventRow: スキップと同じグレーアウトだが、アイコンは ⏰（時計）にして区別する
- 家族ダッシュボード: `dismissed_skip`（❌）と同様の表示（家族への Push 通知はしない）
- XP: 付与なし（見逃しに対してペナルティも与えない）

**⚠️ v15追加: `missed` 記録後に手動で「完了」した場合の状態遷移:**

> **問題:** ユーザーが見逃した後に「実は対応した」と後から記録したい場合がある（例: アラームを見逃したが実際には薬を飲んだ）。
> EventRow の長押しメニューから「完了にする」が選べる設計（STEP 2-7）と矛盾しないよう、`missed` 後の `complete` 上書きを明示的に許容する。

```
missed → complete への上書きルール（AIへの指示）:

  1. EventRow 長押しメニュー → 「完了にする」を選択
  2. completionStatus を .missed → .complete に上書き
     ⚠️ この遷移は許可する（missed はあくまで「自動判定」であり、ユーザーの意思が優先される）
  3. XP +10 を付与（missed 時点での XP 未付与分を後から付与）
  4. Supabase に dismissed_status = "complete" を PATCH（missed の上書き）
  5. EventRow: ⏰ グレーアウト → ✓ 完了グレーアウト（通常の完了表示）に変更
  6. ふくろうトースト: 「後から完了にしましたよ！えらいですね 🦉」

  ❌ 逆方向（complete → missed への上書き）は許可しない
     → 一度「完了」になったものを「見逃し」に変更する操作は混乱を招くため禁止
  ❌ skip → missed への上書きも不可（スキップは意思決定、見逃しは自動判定であり意味が異なる）
```

**しきい値（15分）の根拠:**
- アラームが発火してから15分後まで RingingView を出すのは現実的（会議中など）
- 15分を超えると「そのアラームの目的はとっくに終わっている」と判断できる
- デバッグビルドでは定数として切り出し、テストしやすくする

### 3-2. RingingView（Stage 2）完全なUIフロー

> ⚠️ **v16追加（P-2-2）: スヌーズボタン（30分後・最大3回）が追加。末尾 P-2-2 および P-9-15 を必ず参照。**
> ⚠️ **ダブルスライド問題の解決（設計変更）:**
> Stage 1 で「スライドして確認する」を既に行っているため、Stage 2 に再度スライドを要求するのは
> 朝の寝起きに二重の摩擦を与える。Stage 2 は**タップボタン**にして摩擦をゼロにする。
> 誤操作防止は Stage 1 のスライドが担保済み。「パス」だけは長押しで誤操作を防止する。

```
RingingView全画面表示
┌───────────────────────────────┐
│  ○○（ふくろう名）からのお知らせ │ ← ふくろうの名前（owlName）をサブタイトルに（Face ID解除後）
│  🦉 お昼の薬                  │ ← 予定タイトル（メイン）
│  12:00                        │
│                               │
│  「焦らなくて大丈夫ですよ。   │
│   ゆっくり準備してください。」 │
│                               │
│  ┌─────────────────────────┐  │
│  │  ✓  薬を飲んだ          │  │ ← プライマリボタン（タップ1回で完了）
│  └─────────────────────────┘  │   高さ: ComponentSize.actionGiant（72pt）
│                               │   ⚠️ primary（56pt）ではなく actionGiant を使う
│                               │   色: .statusSuccess, テキスト白
│                               │   フォント: .title2.bold
│                               │
│  （5秒後に出現）               │
│  ● ● 今回はパス （長押し）  │ ← Hold to Skip（長押し1.5秒）
│                               │   5秒後出現（衝動的スキップ防止）
│                               │   長押し中: プログレスリング表示
│  ─────────────────────────    │
│  あと 4:22 で家族にお知らせ   │ ← SOSプログレスバー（SOS設定時のみ）
│  ████████████░░░░░░░░░░░    │   alarm.fireDate から経過時間を計算
└───────────────────────────────┘

完了（タップ）:
  → Haptic(.success) + OwlCelebrationOverlay（変動比率スケジュール）
  → XP +10 を仮付与（Undo期間中は確定しない）
  → Supabase: dismissed_status = "complete" の送信を10秒後に遅延（DismissSheet表示中）
  → ⚠️ v16変更（P-2-1）: 2.5秒後自動閉じ + Undoスナックバー → 廃止
      → DismissSheet（ハーフシート）を表示: 「✓ 完了しました！」+ XPアニメ + [取り消す] + [閉じる]
      → 10秒自動閉じ。[取り消す]タップで STEP 3-2-B のUndoロジックを実行

パス（長押し1.5秒完了）:
  → 「今日はゆっくりしてね 🦉」
  → XP +3 を仮付与（Undo期間中は確定しない）
  → Supabase: dismissed_status = "skip" の送信を3秒後に遅延（Undo対応・家族Push通知も同様）
  → 1.5秒後自動閉じ → PersonHomeView に戻りUndoスナックバー表示

⚠️ STEP 14-1（スライドして完了）はMagicDemoView専用に用途を変更。
   RingingView本番での「スライドして完了」は廃止し、タップボタンに置き換える。
```

### 3-2-B. Undo（取り消し）スナックバー

> ⚠️ **v16変更（P-2-1）: このセクションのスナックバー仕様は廃止。末尾「P-2-1. DismissView 復活」に置き換えられた。**
> **実装時は P-2-1 の「DismissSheet（ハーフシート）」仕様を正としてください。ただし自動閉じ時間は P-9-13 で10秒→3秒に変更済み（同ファイル末尾参照）。**
> 以下の記述は「Undoの内部ロジック（UserDefaults クラッシュ復帰、deduplicateQueue）」のリファレンスとして参照用に残す。

~~**RingingViewが閉じた直後**（PersonHomeViewに戻った瞬間）、スナックバーを3秒間表示する。~~

```
スナックバー仕様:
  表示位置: 画面下部 safeArea + 8pt 上（FAB下）
  高さ: 52pt
  背景: .secondarySystemBackground（ライト・ダーク自動対応）
  テキスト（完了時）: 「完了にしました         取り消す」
  テキスト（パス時）: 「今回はパスにしました   取り消す」
  「取り消す」部分: .statusPending（青）、タップエリア最低44pt
  表示時間: 3秒後に opacity: 1→0（.easeOut, 0.4s）
  アニメーション（出現）: offset(y: 60pt → 0) + opacity(0→1), .spring(response: 0.4)

取り消しタップ時:
  1. スナックバー即座に消える
  2. completionStatus を nil（未完了）に戻す
  3. Supabase の delayed 送信をキャンセル（まだ送っていないので PATCH 不要）
  4. XP 仮付与分を取り消す
  5. ふくろうトースト: 「元に戻しておいたよ 🦉」（1秒表示）

3秒タイムアウト後:
  1. Supabase PATCH（dismissed_status を確定）
  2. XP を確定付与
  3. skip 時のみ家族へ Push 通知を送信

⚠️ 実装の罠:
  - Undo期間中にアプリをバックグラウンドに送った場合 → 3秒タイムアウトはキャンセルせず継続
  - PersonHomeViewModelに `pendingUndoTask: Task<Void, Never>?` を持ち、Undoタップで `.cancel()`

クラッシュ・OSキル対応（⚠️ 必須）:
  Undo期間中（Supabase未送信）にアプリがクラッシュすると、完了ステータスが永遠に送信されない。
  → 完了/スキップ操作の直後、3秒タイマー起動と同時に UserDefaults に一時書き込みをする:
    UserDefaults.standard.set([
      "eventID": alarm.id.uuidString,
      "dismissedStatus": "complete" or "skip",
      "timestamp": Date().timeIntervalSince1970
    ], forKey: "pendingCompletion")
  → 3秒確定後（または Undo後）: UserDefaults の pendingCompletion を削除
  → アプリ起動時（AppDelegate/scenePhase .active）: pendingCompletion が残っていれば
    Supabase にリトライ送信してからキーを削除（クラッシュ復帰フォールバック）
```

### 3-3. イヤホン抜け時の処理（⚠️ AlarmKit実装の罠）

AVAudioPlayerを止めるだけでは不十分。AlarmKitのOSアラームは継続してスピーカーから鳴り続ける。

```swift
@objc private func handleRouteChange(_ notification: Notification) {
    guard hadHeadphones else { return }
    DispatchQueue.main.async { [weak self] in
        guard let self, let alarm = self.activeAlarm,
              let alarmKitID = alarm.alarmKitIdentifier else { return }

        // 1. AVAudioPlayer停止
        self.stopAudioPlayback()

        // 2. 【必須】AlarmKitのOSアラームをキャンセル（これをしないと爆音継続）
        Task { try? await AlarmManager.shared.cancel(id: alarmKitID) }

        // 3. RingingViewは閉じない（activeAlarmを維持）
        // 4. トースト表示
        self.showEarphoneDisconnectedToast = true
    }
}
```

トースト: 「🎧 イヤホンが外れたため音を止めました。完了ボタンを押してください。」
RingingView は閉じない。ユーザーが完了/スキップを選ぶまで維持。

### 3-4. OwlCelebrationOverlay（変動比率スケジュール）

### 3-5. AlarmKit カスタムサウンド設計（⚠️ 高齢者・ADHD聴覚特性対応）

> **問題:** iOSデフォルトのアラーム音（レーダー、木琴等）は高音域に強いピーク周波数を持つ。
> 高齢者の加齢性難聴は4kHz以上から始まり、「鳴っているが聞こえない」事故が起きる。
> ADHD当事者には高音の急激な立ち上がりが聴覚過敏を引き起こし、パニックに繋がることがある。

**バンドル音源の要件:**

```
アプリバンドルに以下の .caf ファイルを用意する（Assets/Sounds/ 配下）:

ファイル名: owl_alarm.caf

音響特性:
  - 主周波数帯域: 500Hz〜2kHz（加齢性難聴が起きにくい中低音域）
  - 音のキャラクター: 柔らかい木琴 or マリンバ系（金属性・電子音は避ける）
  - 立ち上がり（Attack）: ゆるやか（10ms以上）。突然の爆音立ち上がり禁止
  - 音量: -3dBFS 以下（クリッピング禁止）
  - ループ対応: seamless ループポイントを設定済み
  - サンプリングレート: 44100Hz / ステレオ

AlarmKit への設定:
  AlarmPresentation.Alert.sound = .named("owl_alarm")

⚠️ .caf が見つからない場合のフォールバック:
  AlarmKit はデフォルトサウンドにフォールバックする（アプリはクラッシュしない）。
  ただし高齢者・ADHD対応の観点から、リリース前に必ず実機で音量・音質を確認すること。

⚠️ 権利関係:
  - 社内制作 or ロイヤリティフリー素材を使用すること（App Store 審査で引っかかる）
  - freesound.org (Creative Commons) や Zapsplat などを候補とする
```

| 確率 | 演出 |
|------|------|
| 75% | ふくろうジャンプ + ランダム褒め言葉（20フレーズ） |
| 20% | 翼バタバタ + 特別褒め言葉 + 星パーティクル |
| 5% | サングラスふくろう + ファンファーレ + 全画面花火 |

---

## STEP 6: 通知設計（アラート・ファティーグ防止）

### 6-1. 家族へのPush通知は「異常事態のみ」に限定
> ⚠️ **v16変更（P-9-4）: 以下のEdge Function直接実装は技術的に不可能（タイムアウト150秒制限）。`05_Data_Architecture.md` の P-9-4「pg_cronで30分ごとに実行するジョブ」に置き換え。**

**Push通知（音・バイブあり）を送る条件:**
| 条件 | 通知内容 |
|------|---------|
| 親がアラームをスキップした | 「お母さんが〇〇をお休みしました。体調が悪いのかもしれません、優しく様子を聞いてみましょう ☕️」（〇〇 = 予定タイトル） |
| SOSエスカレーション発火 | 「⚠️ お母さんがアラームに気づいていないかもしれません。確認してみましょう。」 |
| Phase G: 予定時刻2時間前で未同期 | 「お母さんの端末と通信できていません」 |

> **コピーライティング方針（⚠️ 家族のパニック防止）:**
> スキップ通知は「緊急事態」ではなく「気にかけるきっかけ」として届ける。
> 「パスしました」という断定語は不安を煽る。「お休みしました」＋「☕️ 様子を聞いてみましょう」の
> 穏やかなトーンにすることで、家族が深呼吸して連絡できる気持ちを作る。

**サイレント更新（Push通知なし）:**
| 条件 | 対応 |
|------|------|
| 親がアラームを「完了」した | Tab 0 のUIがサイレントに ✓✓ 濃緑になる（No news is good news） |
| 予定が同期完了 | Tab 0 のUIがサイレントに ✓ 緑になる |

→ 「完了」のたびに家族のスマホが鳴り続けると通知オフ → SOS通知まで見逃す悪循環を防ぐ

**スキップ通知のデバウンス（バッチ処理）:**
> 朝の薬・昼の薬・夜の薬を連続でスキップした場合、3通知が連続して鳴るとスパムになる。

```
バッチ処理ルール（バックエンド Supabase Edge Function 側で実装）:
  - 同一の family_link_id から 30分以内に複数の skip イベントが来た場合:
    → 1通の通知にまとめる: 「お母さんが今日〇回お休みしました。体調を確認してあげてください ☕️」
  - 30分以内の1件のみ: 通常通り「お母さんが〇〇をお休みしました。体調が悪いのかもしれません、優しく様子を聞いてみましょう ☕️」
  - デバウンスウィンドウ: 最初のスキップから30分間、後続のスキップを蓄積して1通にまとめる
    （30分経過したら次のウィンドウが始まる）
```

---

## STEP 9: プライバシー設計（OS連携）

### 9-1. ロック画面 / Live Activity（AlarmKit）
- `AlarmPresentation.Alert.title` = `"🦉 ふくろうからのお知らせ"` で固定（Stage 1）
- 具体的なタイトルはFace ID解除後のRingingView（Stage 2）にのみ表示

### 9-2. 通知バナー（UNUserNotification）
- タイトル: 「🦉 ふくろうからお知らせ」/ 本文: 「アプリを開いて確認してください」
- 予定タイトル・薬名は一切バナーに出さない

---

### P-2. STEP 3 関連パッチ（RingingView・アラーム停止）

**P-2-1. DismissView 復活 — 褒め＆Undoハーフシート（R4-③・⚠️ 必須）:**
> 3秒Toastへの格下げを撤回。高齢者が3秒で読んで判断するのは認知心理学的に不可能。

- RingingView閉じた後、PersonHomeに直接戻らず「DismissSheet」をハーフシートで表示
- 内容: 「✓ 完了しました！」+ XPアニメーション + [間違えたので取り消す] + [閉じる]
- 10秒で自動閉じ（ユーザーが自分のペースで閉じることも可能）
- Undo押下時: STEP 3-2-B のロジックを実行
- ⚠️ STEP 3-2-B の「2.5秒後自動閉じ → Undoスナックバー」を本仕様で置き換え

#### P-9-13. DismissSheet のUX改善（10秒ブロック問題の解決）

> **問題1:** DismissSheet が10秒間表示されると、完了直後の達成感が「待たされる」体験に変わる。特に高齢者は「次に何をすれば良いか」が分からずパニックになる可能性がある。
>
> **問題2:** 高齢者には10秒で「取り消す」ボタンを読んで判断するのは短すぎる（R4-③の元の指摘）。

**解決案（UIは素早く閉じ、Undoの猶予はバックグラウンドで確保）:**

```swift
// DismissSheet の新しい挙動:

// 1. 表示: DismissSheet を表示（通常通り）
// 2. 「閉じる」ボタンまたは外タップ: シートを即座に閉じる（10秒待たない）
// 3. ただし Undo Task は PersonHomeViewModel でバックグラウンド継続（30秒間）
// 4. PersonHomeView の EventRow に「↩ 取り消す」の小さなテキストリンクを30秒間表示

// DismissSheet はあくまで「褒め演出」。Undo の主導線は PersonHomeView 上のリンクに移動。

// PersonHomeView のEventRow（完了直後30秒間のみ）:
if let recentlyCompleted = vm.recentlyCompletedEvent,
   Date() < vm.undoDeadline {
    HStack {
        Text("↩ さっきの完了を取り消す")
            .font(.caption)
            .foregroundColor(.statusPending)
        Spacer()
        Text("\(Int(vm.undoDeadline.timeIntervalSinceNow))秒")
            .font(.caption2)
            .foregroundColor(.secondary)
    }
    .contentShape(Rectangle())
    .onTapGesture { vm.undoLastCompletion() }
}
```

**タイムライン:**
- T+0: RingingView 完了タップ
- T+0〜3秒: DismissSheet 表示（ふくろうの褒め + XPアニメーション）
- T+3秒: DismissSheet 自動閉じ OR ユーザーが「閉じる」タップ → PersonHome表示
- T+0〜30秒: PersonHomeView のEventRow上部に「↩ 取り消す（○秒）」表示
- T+30秒: Undo期間終了 → Supabase PATCH確定・XP確定・スキップ時Push通知送信

---

**P-2-2. スヌーズ機能の追加（R2-④/R3-②・⚠️ 必須）:**
> 「パス」と「スヌーズ」は全く異なるニーズ。服薬は「今は手が離せないから後で」が頻出。

- RingingViewの「今回はパス」の横に「⏱️ 30分後にまた教えて」スヌーズボタンを追加
- スヌーズ選択時: AlarmKitに `fireDate = now + 30min` で再登録
- completionStatus は変更しない（nil のまま）
- スヌーズ回数: 1予定あたり最大3回（4回目以降はスヌーズ不可、パスのみ）
- 家族には通知しない（スヌーズは「対応中」であり「放棄」ではないため）

**P-2-3. 「今回はパス」レイアウトシフト防止（R2-②）:**
- 5秒間は透明プレースホルダーとして空間を確保
- 5秒後に `.opacity(0→1)` でフェードイン。他のボタンをミリ単位も動かさない

**P-2-4. Dynamic Type キャップの撤廃（R4-⑧）:**
- `CircularCountdownView` の `.dynamicTypeSize(...accessibility2)` キャップを削除
- accessibility3以上: 円形リングUIを破棄 → 画面いっぱいの巨大数字テキストのみに構造的フォールバック

---

### P-4. 音声・TTS・アクセシビリティ パッチ

**P-4-1. TTS マナーモード消音問題（R2-⑥・⚠️ 必須）:**
- AVSpeechSynthesizer 起動前に必ず以下を実行:
```swift
let session = AVAudioSession.sharedInstance()
try? session.setCategory(.playback, mode: .voicePrompt, options: [.duckOthers])
try? session.setActive(true)
```
- これがないとマナーモード中に「アラーム音は鳴るがふくろうが喋らない」致命的バグ

**P-4-2. TTSの時刻読み上げ対応（R1-⑪）:**
- TTSSanitizerに正規表現パターン追加: `([0-9]{1,2}):([0-9]{2})` → 「○時○分」に変換
- 「00分」→「ちょうど」に置換

**P-4-3. アテンション音のOFFオプション（R3-⑥）:**
- 設定画面に「アテンション音をOFFにする」「フェードインで鳴らす」オプション追加
- ADHD/ASD聴覚過敏ユーザー向け

**P-4-4. マイクシート バックグラウンド移行時の処理（R1-⑱）:**
- `scenePhase == .background` で録音を強制停止
- そこまでの文字起こしテキストは保持して idle 状態に戻す

---

#### P-9-7. CallKit によるアラーム音量抑制対応（⚠️ 必須）

> **問題:** iPhone が通話中（CallKit アクティブ）の場合、iOS はアプリの AVAudioSession を duck または suspend し、AlarmKit の音量も抑制されることがある。「電話中に薬のアラームが聞こえなかった」という事故が起きる。

**対策（AIへの実装指示）:**

```swift
// RingingViewModel.startAudioPlayback() 内に追加:

// CallKit の通話状態を確認
let callObserver = CXCallObserver()
let hasActiveCall = callObserver.calls.contains { !$0.hasEnded }

if hasActiveCall {
    // 通話中: TTS（playNarration）の起動を完全にスキップする。
    // CallKit がアクティブな状態で AVSpeechSynthesizer を強制起動すると
    // AVAudioSession がエラーを返すか、最悪アプリがクラッシュする。
    // AlarmKit のOSアラーム音はOS制御なので継続して鳴る。
    // ユーザーへの通知はトーストと Haptic（.heavy × 3回）のみで代替する。
    appState.showToast(ToastMessage(
        text: "📞 お電話中でもアラームは鳴っています。終わったら確認してね 🦉",
        style: .owlTip
    ))
    UINotificationFeedbackGenerator().notificationOccurred(.warning)
    return // playNarration() を呼ばずに終了
}
```

**通話終了時の State Out of Sync リカバリ:**
- `CXCallObserverDelegate.callObserver(_:callChanged:)` を監視
- 通話が終了し `call.hasEnded == true` になった瞬間に `recoverStaleAlarmState()` を実行

---

#### P-9-8. マナーモード判定ハックへの注記強化（⚠️ 実装者向け制約）

> 現状の `outputVolume` による判定はiOSのプライベートAPIや状況によって信頼性が低い。実装者が「確実に検知できる」と誤解しないよう明記する。

**AIへの強制注記（コメントとして必ずコードに入れること）:**

```swift
// ⚠️⚠️⚠️ マナーモード検知の制限について（実装者必読）⚠️⚠️⚠️
//
// iOS には公開APIでマナーモード状態を確実に取得する方法が存在しない。
// AVAudioSession.outputVolume は以下の場合に誤判定する:
//   - ユーザーが意図的に音量を0にしている（マナーモードではない）
//   - Bluetooth接続時に音量が自動変動する
//   - アクセシビリティ設定で音量動作が変わっている
//
// 本実装は「警告を出す」ためのヒューリスティックであり、
// 「マナーモードを確実に検知する」ものではない。
// AlarmKit がマナーモードを貫通して鳴ることが本アプリの根幹であるため、
// この検知ロジックに依存した「アラームが鳴らない」ケースを作ってはいけない。
```

---

#### P-9-9. App Group Race Condition 防止（⚠️ 必須）

> **問題:** メインアプリとWidget Extension が同時に App Group UserDefaults を読み書きすると、部分的な書き込みが読まれ（Torn Read）データが壊れる。特に `owlXP`（Int）の加算時に競合すると XP が消える。

**防止ルール（AIへの実装指示）:**

```swift
// App Group への書き込みは「メインアプリ → App Group」の一方向のみ
// Widget Extension は App Group から読み取りのみ行う（絶対に書き込まない）

// ✅ メインアプリ（AppState.didSet）:
UserDefaults(suiteName: Constants.appGroupID)?.set(owlXP, forKey: "owlXP")
// WidgetCenter.shared.reloadAllTimelines() は XP閾値超え時のみ（P-7-2参照）

// ✅ Widget Extension（EntryProvider）:
let xp = UserDefaults(suiteName: Constants.appGroupID)?.integer(forKey: "owlXP") ?? 0
// 読み取りのみ。XP加算などの計算はしない。

// ❌ Widget Extension からの書き込み禁止:
// UserDefaults(suiteName: Constants.appGroupID)?.set(...) // Widget内ではこれを書かない

// ⚠️ AppIntent（CompleteAlarmIntent）経由の完了操作:
// AppIntent は Widget Extension プロセスで実行されるが、
// completionStatus の書き込みは必ず AlarmEventStore.shared（メインアプリの共有ストア）経由で行う。
// App Group UserDefaults への直接書き込みは行わない。
```

---

#### P-9-15. スヌーズ上限到達時のUI表現

> **問題:** P-2-2 に「3回でスヌーズボタンを非表示」とあるが、ボタンが突然消えた理由が高齢者には分からない。「壊れた」と思われる可能性がある。

**スヌーズ上限到達時の表示変更（AIへの指示）:**

```
スヌーズ0〜2回目: 通常の「⏱️ 30分後にまた教えて」ボタンを表示

スヌーズ3回目（最後の1回）:
  ボタンラベルを変更: 「⏱️ 30分後にまた教えて（最後の1回）」
  ボタン下に小さなテキスト: 「次はパスか完了を選んでね」（.caption、.secondary）

スヌーズ上限到達後（4回目以降）:
  ボタンを非表示にする代わりに、以下のメッセージを表示:
  「🦉 何度もお知らせしたよ。今日は無理せず『今回はパス』にしてね」
  → 「今回はパス」ボタンへの注意を引く視覚的な矢印（→）も追加

実装仕様:
  AlarmEvent に `snoozeCount: Int = 0` フィールドを追加
  スヌーズ毎にインクリメント。P-2-2 のスヌーズ登録時に +1
  RingingView がこの値を参照してUIを切り替える
```

---