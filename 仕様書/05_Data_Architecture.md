## STEP 7: データ同期の競合解決ルール（⚠️ 実装の罠）

> ⚠️ **v16アップデート（最重要）**: 本セクションの実装前に、必ず末尾の「[v16 パッチ P-5]」を確認すること。
> （TTL判定、OfflineQueueデッドロック回避、繰り返し予定対応、家族削除ロック等を追記済み）

### 7-0. ローカル永続化レイヤーの定義

| データ種別 | 保存先 | 理由 |
|-----------|--------|------|
| AlarmEvent（予定） | EventKit（EKEvent） | Source of Truth。他カレンダーアプリとの共存 |
| アプリ設定・状態 | UserDefaults（App Group） | シンプル・ウィジェット共有が必要 |
| AlarmKit ID マッピング | UserDefaults（App Group）JSON | AlarmKit.listAll() 未確認のためローカル管理 |
| 音声ファイル | Library/Sounds/ | 直接ファイル管理 |

**SwiftData・CoreDataは使わない。**
理由: iCloudSyncを誤って有効化すると家族側にデータが漏洩するリスク、
      および Xcode 26 での SwiftData + @Observable の組み合わせが未成熟なため。

### 7-1. Source of Truth の定義（フィールド単位マージ）

> ⚠️ **「リモートが常に勝つ」は薬の二重服用事故を招く。フィールドごとにルールを分ける。**

| フィールド | 判定方法 | Source of Truth | 理由 |
|-----------|---------|----------------|------|
| `title` / `startDate` / `preNotificationMinutes` | `senderName != nil` | **Supabase（リモート）が勝つ** | 家族の意図した予定内容を守る |
| `title` / `startDate` | `senderName == nil` | EventKit（ローカル）が勝つ | 自分で作った予定は自分が正 |
| `completionStatus`（完了/スキップ/nil） | 常に | **ローカルが勝つ（絶対）** | 薬を飲んだ事実は上書き禁止 |
| `is_cancelled` | `senderName != nil` | Supabase が勝つ | 家族の取り消しを反映 |

**重要な理由（completionStatus ローカル優先の必要性）:**
> 「親がオフラインで薬を完了にした」同タイミングで「家族が予定タイトルを修正した」場合、
> タイトルだけリモートで上書きし、completionStatus はローカルの「完了」を維持する。
> これをしないと薬の完了記録が消え、家族に「未完了」と誤通知し、二重服用事故が起きる。

```
フィールド単位の競合判定ロジック:
  senderName != nil（家族送信の予定）の同期時:
    → title, startDate, preNotificationMinutes: remote で上書き
    → completionStatus: ローカルの値を絶対に保持（上書き禁止）
    → is_cancelled = true: 家族が取り消した → EventKit から削除 + AlarmKit キャンセル
    → 修復時にふくろうトースト: 「家族から届いた予定をもとに戻しておいたよ 🦉」

  senderName == nil（自分で作った予定）の同期時:
    → すべてのフィールド: local.updatedAt > remote.updatedAt → ローカルが勝つ
    → completionStatus: 常にローカルが勝つ
```

### 7-2. remote_events はアペンドオンリー

- 家族が「取り消す」→ `is_cancelled = true`（物理削除しない）
- 親のEventKitから削除された場合 → `status = "deleted_by_person"`
- 親の誤削除はSupabaseデータで次回同期時に修復

**オフライン時のキャンセル警告（⚠️ 家族側UIに必須）:**
```
家族が予定をキャンセルしようとした時:
  → Last Seen が30分以上前（または last_seen_at が古い）の場合:

  ┌─────────────────────────────────────────┐
  │  ⚠️ お母さんのスマホが電波に繋がって    │
  │     いないようです。                     │
  │                                         │
  │     アラームの時刻が近い場合は           │
  │     お知らせが間に合わず鳴ってしまう     │
  │     可能性があります。                   │
  │                                         │
  │  [それでもキャンセルする]  [やめる]     │
  └─────────────────────────────────────────┘

  「それでもキャンセルする」→ is_cancelled = true を Supabase に書く（既存フロー）
  「やめる」→ キャンセル操作を中止
```

### 7-3. オフライン時の挙動

- 親がオフライン中に家族が送信 → Supabase に保存（pending）
- 親がオンライン復帰 → SyncEngine が検知 → EventKit書き込み → AlarmKit登録
- 担当: `SyncEngine.syncRemoteEvents()`（既存実装の拡張）

**⚠️ expired ゾンビ防止：SyncEngine フェッチ時の防御的プログラミング（必須）**

> **問題:** `pending` イベントの TTL チェックをViewModelのComputedPropertyだけで行うと、Supabase側のデータは永遠に `pending` のまま残る。親が長時間オフライン後にオンラインになった瞬間、「昨日の14:00の病院予定」がAlarmKitに登録されてしまう事故が起きる。

**実装（AIへの指示）: `SyncEngine.syncRemoteEvents()` の冒頭で必ず実行:**

```swift
actor SyncEngine: SyncEngineProtocol {

    func syncRemoteEvents() async throws {
        let now = Date()

        // ① Supabase から pending イベントをフェッチ
        let remoteEvents = try await fetchPendingEvents()

        // ② TTLチェック: 期限切れイベントを分類
        let (validEvents, expiredEvents) = remoteEvents.reduce(
            into: ([RemoteEvent](), [RemoteEvent]())
        ) { result, event in
            let ttl = event.startDate.addingTimeInterval(60 * 60)  // startDate + 1時間
            if now > ttl {
                result.1.append(event)  // expired
            } else {
                result.0.append(event)  // 有効
            }
        }

        // ③ 期限切れはSupabaseを即座にPATCH（EventKit/AlarmKitには絶対登録しない）
        if !expiredEvents.isEmpty {
            try await supabase
                .from("remote_events")
                .update(["status": "expired"])
                .in("id", values: expiredEvents.map(\.id))
                .execute()
        }

        // ④ 有効なイベントのみをEventKit/AlarmKitに登録
        for event in validEvents {
            try await registerToEventKitAndAlarmKit(event)
        }
    }
}
```

**ルール:**
- `startDate + 1時間` を超えた `pending` イベントは、フェッチ時に即 `expired` にPATCHする
- `expired` になったイベントは EventKit にも AlarmKit にも絶対に書き込まない
- このチェックは `scenePhase == .active` 時の `performFullSync()` に含まれるため、アプリ起動のたびに自動クリーニングされる

---

#### P-9-23. サーバーサイド強制タイムアウト（⚠️ 見守りアプリの生命線・クライアント依存禁止）

> **問題:** `recoverStaleAlarmState()` は `scenePhase == .active` でトリガーされるため、親がアプリを開かない限りSupabaseのステータスが `pending` / `alerting` のまま残り続ける。家族は「お母さんのアラームが今も鳴り続けている」と誤解して深夜にパニックの電話をかける可能性がある。見守りアプリにおいてクライアント起動への依存は致命的。

**実装（Supabase pg_cron・AIへの指示）:**

```sql
-- 「起動を待たずに確実に期限切れにする」pg_cronジョブ
-- Supabase Dashboard → Database → Extensions → pg_cron を有効化してから設定

-- ① 30分ごと: startDate + 1.5時間 を超えた pending を expired に自動変更
SELECT cron.schedule(
    'expire-stale-pending-events',
    '*/30 * * * *',
    $$
    UPDATE remote_events
    SET status = 'expired', updated_at = now()
    WHERE status = 'pending'
      AND start_date < now() - INTERVAL '90 minutes';
    $$
);

-- ② 15分ごと: startDate + 30分 を超えた alerting（鳴動中）を missed に自動変更
-- （AlarmKitが鳴って30分経っても親がアプリを開かなかった = 対応なしと判断）
SELECT cron.schedule(
    'mark-unresponded-alarms-missed',
    '*/15 * * * *',
    $$
    UPDATE remote_events
    SET status = 'missed', updated_at = now()
    WHERE status = 'alerting'
      AND start_date < now() - INTERVAL '30 minutes';
    $$
);
```

**Supabase Realtimeによる家族への反映:**
- `remote_events` テーブルの `status` カラムを Supabase Realtime の変更監視に含める
- `status` が `expired` / `missed` に変わった瞬間、家族アプリがリアルタイムで更新される
- 家族Tab 0の表示: `expired` → 「⚠️ 届きませんでした」、`missed` → 「😔 対応がなかったようです」

**クライアントサイドとの二重化（意図的）:**
- クライアント（SyncEngine）でのTTLチェック（P-9-23の冒頭ルール）は引き続き実行する
- サーバーサイドのpg_cronは「クライアントが起動しなかった場合のフェイルセーフ」
- 両方が走っても冪等（すでに `expired` のものを再度 `expired` にしても問題なし）

### 7-4. Supabase RLS（Row Level Security）設計（⚠️ セキュリティ必須要件）

**問題:** 匿名認証（Anonymous Auth）のユーザーが、ペアリング無しで任意の親の `device_id` を指定して `remote_events` にINSERTできてしまう脆弱性を防ぐ。

**必須のRLSポリシー（AIへの実装指示）:**

```sql
-- remote_events テーブルのRLS

-- ① INSERT: family_links テーブルで有効なペアリングが存在する場合のみ許可
CREATE POLICY "ペアリング済みの家族のみ予定を送れる"
ON remote_events FOR INSERT
WITH CHECK (
  EXISTS (
    SELECT 1 FROM family_links
    WHERE family_links.child_user_id = auth.uid()   -- 送信者 = ログイン中のユーザー
      AND family_links.parent_device_id = remote_events.target_device_id  -- 送信先 = 自分がペアリングしている親
      AND family_links.is_active = true
  )
);

-- ② SELECT: 自分が送信した予定、または自分の device_id 宛の予定のみ読める
CREATE POLICY "自分に関係する予定のみ読める"
ON remote_events FOR SELECT
USING (
  sender_user_id = auth.uid()   -- 自分が送った
  OR target_device_id = (SELECT device_id FROM user_devices WHERE user_id = auth.uid())  -- 自分宛
);

-- ③ UPDATE: completionStatus など、受信者（親）のみが更新可能
CREATE POLICY "受信者のみステータスを更新できる"
ON remote_events FOR UPDATE
USING (
  target_device_id = (SELECT device_id FROM user_devices WHERE user_id = auth.uid())
)
WITH CHECK (
  -- 変更可能なフィールドは dismissed_status のみ（title等は家族のみ変更可）
  target_device_id = (SELECT device_id FROM user_devices WHERE user_id = auth.uid())
);
```

**ペアリングコード生成のセキュリティ:**
- 6桁コードは Supabase Edge Function で生成（クライアント側生成禁止）
- 有効期限: 15分（それ以降は無効・再生成が必要）
- 使用済みコードは即時無効化（1回限り）
- レート制限: 同一IPから1分間に5回以上の試行 → 10分ブロック

---

### P-5. データ同期・オフラインキュー パッチ

> ⚠️ **CLAUDE.md の「scenePhase == .active で毎回フル同期」ルールはP-5-4により修正。60秒以内の連続起動はスキップする。以下のP-5-4を参照。**

**P-5-1. オフライン遅延アラーム防止 — TTL判定（R1-⑨・⚠️ 必須）:**
- SyncEngine内に Time-to-Live 判定を実装
- 「現在時刻より15分以上過去の予定を受信した場合」→ AlarmKitに登録しない
- 直接 missed としてローカルDBに保存
- 家族には「電波が届かずお知らせできませんでした」と逆同期

**P-5-2. OfflineQueue デッドロック回避（R4-⑥・⚠️ 必須）:**
- キュー送信で Supabase から 404 Not Found/エラー時:
  - そのエントリを破棄（またはエラーログ化してスキップ）
  - 後続のキュー処理を継続（デッドロック禁止）

**P-5-3. オフラインキューのリトライポリシー（R1-⑰・⚠️ 必須）:**
- Exponential Backoff: 1秒→2秒→4秒→8秒→最大60秒
- 3回失敗したら次の `scenePhase == .active` まで再送しない
- Supabase API BAN防止

**P-5-4. ScenePhase `.active` のデバウンス処理（R4-⑦・⚠️ 必須）:**
- `lastSyncCheckTimestamp` を持ち、前回チェックから最低60秒未経過の場合は `.active` でもフェッチをスキップ
- コントロールセンター開閉や通知センター操作で `.active` が連打されるのを防止

**P-5-5. 繰り返し予定のデータ構造（R1-⑧・⚠️ 必須）:**
- `AlarmEvent` に `recurrenceRule: String?`（iCalendar RRULE形式）を追加
- 家族の送信タブに「🔄 毎日」「🔄 毎週○曜日」のオプション追加
- クライアント側: RRULE を解析し、向こう1週間分のインスタンスを生成してUI表示・AlarmKit登録
- Phase 1 では「毎日」「毎週」のみ。複雑なルールは将来対応

**P-5-6. 完了済み予定の家族削除ロック（R3-⑫・⚠️ 必須）:**
- `completionStatus` が complete/skip の予定は家族側から削除・変更不可（ロック）
- RLSとUIの両方で制約を実装

**P-5-7. 親の予定削除時の家族UIフィードバック（R1-⑩）:**
- `senderName != nil` の予定を親が削除 → 物理削除せず `is_deleted_by_person = true`（論理削除）
- 家族UI: 「🗑️ お母さんがこの予定を削除しました [再送する]」表示（翌日消去）

**P-5-8. マルチファミリー権限（R3-⑪）:**
- 「送信者本人のみ編集・削除可。他の家族が作った予定は閲覧のみ」
- RLSとUIの両方に明記

---

#### P-9-2. スヌーズ時の家族ダッシュボード表示定義（⚠️ 仕様追加）

**スヌーズステータスの追加（家族Tab 0 の左ボーダー色・ステータステキスト）:**

| ステータス | 色 | アイコン | テキスト |
|-----------|-----|--------|---------|
| `snoozed` | 🟡 オレンジ（`.statusWarning`） | ⏱ | 「○分後にまたお知らせ」|

```swift
// AlarmEvent.CompletionStatus（または FamilySyncStatus）に追加:
case snoozed(until: Date)  // スヌーズ中・次回発火時刻付き

// 家族Tab 0 の EventRow:
case .snoozed(let until):
    leftBorderColor = .statusWarning  // オレンジ
    statusText = "⏱ \(until.formatted(.dateTime.hour().minute()))にまたお知らせ中"
```

**家族への Push 通知:** スヌーズ時は**送らない**（スヌーズ = 「対応中」であり異常でない）。
**スヌーズが切れてアラームが再発火し、再度スヌーズされた場合:** family_links の `snoozed_count` をインクリメントし、3回目以降は「⏱ 3回スヌーズ中」と表示（異常サインとして視覚的に目立たせる）。

---

#### P-9-3. バッテリー死対応（高齢者端末の劣化電池）

**電池残量の低下検知と事前通知強化:**

```swift
// AppDelegate / scenePhase .active 時に確認:
UIDevice.current.isBatteryMonitoringEnabled = true
let batteryLevel = UIDevice.current.batteryLevel  // 0.0〜1.0。-1.0 = 取得不可

// 10%未満 かつ AlarmKit に登録中のアラームがある場合:
if batteryLevel > 0 && batteryLevel < 0.10 {
    // 次のアラームが2時間以内なら追加プッシュ通知を送信
    // 「🪫 バッテリーが少なくなっています。充電してからアラームを使ってね」
    showToast(ToastMessage(text: "🪫 充電残量が少なくなっています", style: .error))
}
```

**アニメーション削減（低電力モード確認の二重チェック）:**
- `isLowPowerModeEnabled` は既存。バッテリー10%未満でも同等の削減を適用する
- 具体的: OwlCelebrationOverlay、箱庭ウィジェットのアニメーション → `reduceMotion || lowBattery` で一律スキップ

---

#### P-9-4. スキップ通知バッチ処理の pg_cron 化（⚠️ 技術的必須変更）

> **問題:** STEP 6-1 の「Edge Function で30分待機」は技術的に不可能。Supabase Edge Function（Deno Runtime）の最大実行時間は約150秒。30分間スリープするコードは確実にタイムアウトで強制終了する。

**正しいアーキテクチャ（AIへの実装指示）:**

```sql
-- Supabase: skip_notification_queue テーブルを作成
CREATE TABLE skip_notification_queue (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    family_link_id UUID REFERENCES family_links(id),
    event_title TEXT,
    skipped_at TIMESTAMPTZ DEFAULT NOW(),
    notified_at TIMESTAMPTZ,  -- NULL = 未送信
    skip_count INT DEFAULT 1  -- 同一ウィンドウ内のスキップ数
);

-- pg_cron で30分ごとに実行（Supabase Dashboard → Database → pg_cron で設定）
SELECT cron.schedule(
    'batch-skip-notifications',
    '*/30 * * * *',  -- 毎30分
    $$
    SELECT net.http_post(
        url := current_setting('app.edge_function_base_url') || '/send-skip-batch',
        headers := '{"Authorization": "Bearer ' || current_setting('app.service_role_key') || '"}'::jsonb,
        body := '{}'::jsonb
    )
    $$
);
```

**フロー変更:**
1. 親がスキップ → `skip_notification_queue` にINSERT（Edge Functionは呼ばない）
2. pg_cron が30分ごとに `send-skip-batch` Edge Function を起動
3. Edge Function: 未送信の行を取得 → バッチ化 → LINE/Push送信 → `notified_at` を更新（短時間で完了）

---

#### P-9-5. Supabase Anonymous Token の自動リフレッシュ（⚠️ 必須）

> **問題:** Supabase Anonymous Authのセッションは1時間でexpire。長時間オフラインから復帰すると全APIコールが401エラーになり、同期が無音で失敗し続ける。

**実装（AIへの指示）:**

```swift
// SyncEngine または SupabaseClient ラッパーに追加:

func ensureValidSession() async throws {
    // セッションが期限切れ or 残り5分未満なら更新
    if let session = supabase.auth.currentSession {
        let expiresAt = session.expiresAt
        let threshold = Date().addingTimeInterval(5 * 60)  // 5分余裕
        if expiresAt < threshold {
            try await supabase.auth.refreshSession()
            print("DEBUG: Supabase session refreshed")
        }
    } else {
        // セッションなし（初回 or 完全期限切れ）→ 匿名サインイン
        try await supabase.auth.signInAnonymously()
    }
}

// 全てのAPI呼び出し前に必ず実行:
// SyncEngine.syncRemoteEvents() / OfflineQueue.flush() / SOSService.sendSOS() の冒頭
```

**scenePhase == .active 時の追加処理順序（厳守）:**
1. `ensureValidSession()`（最初に実行）
2. `recoverStaleAlarmState()`（STEP 3-1-C）
3. `lastSyncCheck` デバウンス確認（P-5-4）
4. `await OfflineActionQueue.shared.flush()` ← **完全終了を待ってから次へ進む**
5. `SyncEngine.performFullSync()`

**4番と5番の順序は絶対に逆にしない。**
オフライン中に「薬を飲んだ（complete）」操作がキューに積まれている状態でフル同期を先に走らせると、リモートの「未完了」状態がローカルを上書きし、完了実績が消滅する（薬の二重服用トラップが再発する）。flush() で未送信データを確定させてから、最新状態を取得する順序を守ること。

---

#### P-9-6. データマイグレーション戦略（⚠️ 既存ユーザー対応必須）

> **問題:** v16で `recurrenceRule`, `isToDo`, `eventEmoji`, `undoPendingUntil` 等を AlarmEvent に追加する。既存ユーザーのデータは古い構造のため、アップデート後にクラッシュまたはデータ消失のリスクがある。

**実装（AIへの指示）:**

```swift
// Services/DataMigrationService.swift（新規作成）

final class DataMigrationService {
    static let currentVersion = 2  // v16 = version 2

    static func migrateIfNeeded() {
        let storedVersion = UserDefaults.standard.integer(forKey: "dataModelVersion")
        guard storedVersion < currentVersion else { return }

        if storedVersion < 2 {
            migrateToV2()
        }
        UserDefaults.standard.set(currentVersion, forKey: "dataModelVersion")
    }

    // v1 → v2: 新フィールドのデフォルト値補完
    private static func migrateToV2() {
        // AlarmEvent を全件読み込んで新フィールドを補完して書き戻す
        // eventEmoji == nil → "📌" (デフォルト)
        // isToDo == nil → false
        // recurrenceRule == nil → nil (そのまま)
        // undoPendingUntil == nil → nil (そのまま)
        print("DEBUG: DataMigration v1 → v2 completed")
    }
}

// ADHDAlarmApp.init() の最初に呼ぶ:
DataMigrationService.migrateIfNeeded()
```

**原則:** 追加フィールドは全てオプショナル（`?`）か安全なデフォルト値を持つこと。既存データを破壊する型変更は禁止。

---

#### P-9-21. Anonymous認証からの昇格パス（⚠️ データ保全必須）

> **問題:** 匿名サインインで作成したデータ（Supabase user_id = anonymous-xxx）は、
> 後でApple IDサインアップした場合の正規user_idと別人として扱われ、データが孤児になる。

**実装（AIへの指示）:**

```swift
// SupabaseService.swift に追加

func linkAnonymousUserToAppleID(credential: ASAuthorizationAppleIDCredential) async throws {
    // 1. 現在の匿名user_idを保存
    let anonymousUID = supabase.auth.currentUser?.id

    // 2. Apple IDでサインイン（新規 or 既存アカウント）
    let session = try await supabase.auth.signInWithIdToken(
        credentials: .init(provider: .apple, idToken: credential.identityToken)
    )

    // 3. 匿名user_idのデータを新user_idに移行（Edge Function経由）
    if let anonUID = anonymousUID, anonUID != session.user.id {
        try await supabase.functions.invoke("migrate-anonymous-user",
            body: ["from_uid": anonUID, "to_uid": session.user.id])
    }
}
```

- 匿名ユーザーが Apple ID サインアップを選択した場合に呼ぶ
- 設定画面の「アカウント設定」セクションに「Apple IDと連携する」ボタンを追加（匿名ユーザーのみ表示）

**migrate-anonymous-user Edge Function の移行対象テーブル（全件必須）:**

| テーブル | 移行カラム | 備考 |
|---------|----------|------|
| profiles | id → 新user_id | referred_by_code も保持 |
| family_links | child_user_id / parent_user_id | 双方向でチェック |
| family_schedules | created_by | 家族から届いた予定 |
| alarm_completions | user_id | 完了ログ（薬の記録） |
| offline_actions | user_id | 未送信キュー |

---

#### P-9-22. リファラル（紹介）DB設計

**Supabase テーブル変更:**

```sql
-- profilesテーブルに追加
ALTER TABLE profiles
  ADD COLUMN referral_code  TEXT UNIQUE,   -- 自分が人に渡す紹介コード（6文字英数字）
  ADD COLUMN referred_by    TEXT,           -- 自分が使った紹介コード（招待した人のコード）
  ADD COLUMN referred_at    TIMESTAMPTZ;   -- 紹介経由インストール日時

-- referral_code の自動生成トリガー
CREATE OR REPLACE FUNCTION generate_referral_code()
RETURNS TRIGGER AS $$
BEGIN
  NEW.referral_code = upper(substring(md5(gen_random_uuid()::text) from 1 for 6));
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER set_referral_code
  BEFORE INSERT ON profiles
  FOR EACH ROW EXECUTE FUNCTION generate_referral_code();

-- 紹介イベント追跡テーブル（分析用）
CREATE TABLE referral_events (
  id               UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  event_type       TEXT NOT NULL CHECK (event_type IN ('sent', 'installed', 'pro_converted')),
  referrer_user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  referee_user_id  UUID REFERENCES auth.users(id) ON DELETE SET NULL,
  created_at       TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- RLS
ALTER TABLE referral_events ENABLE ROW LEVEL SECURITY;
CREATE POLICY "referrer can read own referrals"
  ON referral_events FOR SELECT
  USING (auth.uid() = referrer_user_id);
CREATE POLICY "referee can insert own event"
  ON referral_events FOR INSERT
  WITH CHECK (auth.uid() = referee_user_id);
```

**Universal Links 設計:**
- リファラルURL形式: `https://wasure-bou.jp/invite?ref=XXXXXX`
- `apple-app-site-association` をドメインルートに配備（Supabase Edge FunctionまたはVercelで配信）
- `ref` パラメータを AppRouter の handleDeepLink で受け取り、UserDefaults に一時保存

**iOS 実装（AIへの指示）:**

```swift
// AppRouter.handleDeepLink() に追加（既存のdeep linkハンドラに統合）
if let refCode = components.queryItems?.first(where: { $0.name == "ref" })?.value {
    UserDefaults.standard.set(refCode, forKey: Constants.Keys.pendingReferralCode)
}

// SupabaseService.swift に追加: アカウント作成後に呼ぶ
func applyPendingReferralIfNeeded() async {
    guard let refCode = UserDefaults.standard.string(forKey: Constants.Keys.pendingReferralCode),
          !refCode.isEmpty,
          let currentUID = supabase.auth.currentUser?.id else { return }

    // 紹介コードの所有者を特定
    let referrer = try? await supabase
        .from("profiles")
        .select("id")
        .eq("referral_code", value: refCode)
        .single()
        .execute()

    // profiles に referred_by を記録
    try? await supabase
        .from("profiles")
        .update(["referred_by": refCode, "referred_at": ISO8601DateFormatter().string(from: Date())])
        .eq("id", value: currentUID)
        .execute()

    // referral_events に installed イベントを記録
    if let referrerUID = referrer?.data["id"] as? String {
        try? await supabase
            .from("referral_events")
            .insert(["event_type": "installed",
                     "referrer_user_id": referrerUID,
                     "referee_user_id": currentUID])
            .execute()
    }

    UserDefaults.standard.removeObject(forKey: Constants.Keys.pendingReferralCode)
}
```

**Constants.Keys に追加:**
```swift
static let pendingReferralCode = "pendingReferralCode"
```

---