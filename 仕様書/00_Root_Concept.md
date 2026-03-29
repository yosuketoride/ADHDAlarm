# 『ふくろう』UI/UX 全体構造リデザイン（v16）

> 最終更新: 2026-03-28（Round 6 P-9 追加）
> ステータス: 設計確定・実装開始前
> 累計採用: 86件（Round 1〜6）

---

> [!IMPORTANT]
> ## ⚠️ 実装者（AI）への最優先指示
>
> **この仕様書には「本文（STEP 1〜15）」と「末尾の v16 パッチ（P-0〜P-9）」の2層構造がある。**
> **必ず末尾の v16 パッチセクションを先に読み、本文と矛盾がある箇所はパッチ側を正とすること。**
>
> | 特に注意が必要な矛盾箇所 | 本文 | ✅ 正しい仕様（パッチ） |
> |--------------------------|------|----------------------|
> | RingingView 完了後の挙動 | STEP 3-2 「2.5秒後自動閉じ＋Undoスナックバー」 | **P-2-1「DismissSheet（ハーフシート・30秒バックグラウンド）」で置き換え** |
> | CircularCountdownView の Dynamic Type 上限 | STEP 13-2 `.accessibility2` キャップ | **P-2-4「accessibility3以上で円形UIを破棄＋巨大数字テキストに構造的フォールバック」** |
> | Toast 表示レイヤー | STEP 15-6「RootViewの.overlay」 | **P-7-1「UIWindowレベルで描画（ToastWindowManager）」** |
> | スキップ通知バッチ処理 | STEP 6-1「Edge Function 30分待機」 | **P-9-4「pg_cron で30分ごとに実行するジョブに変更」** |
> | DismissSheet 自動閉じ時間 | P-2-1「10秒自動閉じ」 | **P-9-13「UIは3秒で閉じ、Undoキャンセルタスクは30秒バックグラウンド継続」** |

---

## ■ アプリの本質的ポジション

**「アラームアプリ」ではなく「デジタルなペースメーカー（生活の相棒）」として設計する。**

```
朝: ふくろうに挨拶 → 今日の予定を確認 → 安心して出発
  ↓
日中: スマホをしまって生活（バックグラウンド待機）
  ↓
時間: AlarmKit発火 → OSアラーム → アプリ内RingingView（2段階）
  ↓
停止: ふくろうに褒められる → 次の予定へのカウントダウン開始
  ↓（くり返し）
夜: 「今月も25回できたね！」（月次サマリー）
```

---

## ■ 設計の大原則

| 原則 | 説明 |
|------|------|
| **1画面1アクション** | 今何をすれば良いかが3秒で分かる |
| **不安を煽らない** | カウントダウンは余裕がある時は見せない |
| **失敗を責めない** | スキップも正解。リセットより積み上げ |
| **予測不可能な報酬** | たまに特別なリアクション。期待感を作る |
| **引き算のUI** | 機能を足すより迷いの原因を消す |
| **課金壁はコア機能に立てない** | 価値を体験してから課金を提案 |
| **プライバシーをOSレベルで守る** | 「お昼の薬」はロック画面・通知バナーに出さない |

---

## STEP 1: モード選択

### 1-1. AppMode enum
```swift
// Models/AppMode.swift
enum AppMode: String, Codable {
    case person  // 当事者（ADHD・高齢者本人）
    case family  // 家族（見守る側・代理入力する側）
}
```

### 1-2. AppState 変更
- `var appMode: AppMode?` 追加（nil = 未選択）
- `Constants.Keys.appMode = "app_mode"` 追加
- UserDefaults 永続化

### 1-3. AppRouter 変更
```swift
enum Destination {
    case onboarding    // 初回起動フル
    case modeSelection // 既存ユーザーのモード未選択時
    case personHome    // 当事者ホーム
    case familyHome    // 家族ホーム
}
var familySelectedTab: Int = 0
```

**⚠️ ルーティングアーキテクチャ（v13追加: NavigationStack必須）:**

> iOS 16以降の標準は `NavigationStack` + `NavigationPath` によるデータドリブンなルーティング。
> `NavigationView`（非推奨）は絶対に使わない。AIが古いコードを書く最頻出ポイント。

```swift
// AppRouter の実装指針（AIへの明示的指示）:

// ① PersonHomeView はタブなし → NavigationStack のルートとして配置
NavigationStack(path: $appRouter.personPath) {
    PersonHomeView()
        .navigationDestination(for: PersonDestination.self) { dest in
            switch dest {
            case .settings: SettingsView()
            case .alarmDetail(let id): AlarmDetailView(id: id)
            }
        }
}

// ② モーダル表示のルール:
//    - 設定・ペイウォール・ペアリング: .sheet（.presentationDetents([.large])）
//    - アラーム停止（RingingView）: .fullScreenCover（戻れないため）
//    - ハーフシート（マイク入力）: .sheet（.presentationDetents([.medium, .large])）
//    ⚠️ .fullScreenCover を乱用しない（スタックに積まれてメモリを圧迫する）

// ③ FamilyHome は TabView を直接ルートとして配置（NavigationStackは各タブ内に持つ）
```

**⚠️ v15追加: 既存ユーザーが ModeSelection を通過した後のルーティング分岐（矛盾1解消）:**

> **問題:** ModeSelection は「初回起動 + appMode == nil の既存ユーザー」の2パターンで表示される。
> 初回ユーザーはその後オンボーディング（権限取得 → ふくろう命名 → MagicDemo）へ進むが、
> 既存ユーザー（すでに権限取得済み・予定データあり）が同じ全フローを通ると不自然で迷惑。
> 分岐条件を明示しないと実装バグの火種になる。

```swift
// AppRouter の初期 Destination 計算ロジック（init 時 or scenePhase .active 時に評価）:

func resolveInitialDestination(appState: AppState) -> Destination {
    // ① 完全な初回起動（オンボーディング未完了）
    if !appState.isOnboardingComplete {
        return .onboarding  // ModeSelection → 権限 → OwlNaming → MagicDemo → Home
    }

    // ② 既存ユーザーだが appMode が未選択（アップデートでモード選択が追加された場合 etc.）
    if appState.appMode == nil {
        return .modeSelection  // ModeSelection のみ表示。権限・Demo はスキップ
        // ModeSelection 完了後は直接 personHome or familyHome へ
    }

    // ③ 通常起動（既存ユーザー・appMode 設定済み）
    switch appState.appMode {
    case .person:  return .personHome
    case .family:  return .familyHome
    case nil:      return .modeSelection  // ② と同じ（念のため）
    }
}

// ModeSelectionView から呼ばれるコールバック:
// 既存ユーザー（isOnboardingComplete == true）の場合:
//   appState.appMode = selectedMode
//   appRouter.currentDestination = selectedMode == .person ? .personHome : .familyHome
//   ⚠️ PermissionsCTAView / OwlNamingView / MagicDemoView には遷移しない

// 初回ユーザー（isOnboardingComplete == false）の場合:
//   appState.appMode = selectedMode
//   appRouter.currentDestination = .onboarding（次のオンボーディング画面へ）
```

**既存ユーザーの ModeSelection 画面でのUI差分（AIへの指示）:**
- 初回ユーザー: ボタンラベル「はじめる」→ オンボーディング全フローへ
- 既存ユーザー: ボタンラベル「この設定で使う」→ ホームへ直行（説明文も短縮）
- 判定: `appState.isOnboardingComplete == true` → 既存ユーザー扱い

---

## ■ 将来フェーズ（今回は実装しない）

### Phase G: 信頼性強化（親オフライン通知）
- `last_seen_at` をSupabaseに記録
- 予定時刻2時間前にsynced未完了 → 家族にPush通知
- APN Silent Push + バックグラウンドフェッチ

### Phase H: 家族の生声アラーム
- Supabase Storage へのアップロード + Silent Push + ダウンロード

### Phase I: ふくろう着せ替え（マイクロトランザクション・v14追加: C-6）

> **設計根拠（Tamagotchi / Finch 分析）:**
> サブスクリプションより「一回買い切り」の小額課金の方がライトユーザーの購入障壁が低い。
> 「毎月880円」は高いと感じる人でも「ふくろうの冬服 250円」は衝動買いしやすい。
> SNSシェア（Phase F）でふくろうの見た目が拡散されると、「かわいい服のふくろうを使いたい」需要が生まれる。

**着せ替えアイテム案:**

| アイテム種類 | 価格帯 | 具体例 |
|------------|--------|--------|
| 季節コスチューム | 250〜380円 | 🎃 ハロウィン帽子 / 🎅 サンタ帽子 / 🌸 花かんむり / ⛄ マフラー |
| 特別アクセサリー | 120〜250円 | 🎓 卒業帽 / 🕶️ サングラス（通常5%でランダム出現だが所有で固定化）/ 💎 王冠 |
| 声の着せ替え（Phase H連携）| 380〜500円 | 男性声・方言（関西弁・東北弁）・子供の声 |

**実装方針（AIへの指示・Phase I）:**
- StoreKit 2 の `Product.purchase()` で非消耗型（Non-Consumable）として実装
- 購入したアイテムは `AppState.unlockedOwlCosmetics: Set<String>` に保存
- 着せ替え選択UI: 設定画面「ふくろうの見た目」→ CollectionView グリッド（未解放はロック表示）
- 価格表示: 必ず地域の通貨で表示（StoreKit 2 の `displayPrice` を使う）
- **PRO サブスクリプション保有者に 1 アイテム無料提供（ロイヤルティ特典）**:
  `subscriptionTier == .pro` の場合、季節コスチューム1点を自動解放する
  → 「PRO会員特典」として設定画面に表示

**⚠️ Apple ガイドライン準拠:**
- Non-Consumable アイテムは必ず「復元」機能を提供すること
- 設定画面に「購入を復元する」ボタンを追加（`AppStore.sync()` を呼ぶ）
- アイテムを「ランダムガチャ」形式で販売することは App Store ガイドライン 4.3 (Spam) 抵触の恐れがあるため、個別単品販売のみとする

**⚠️ v15追加: 着せ替えアイテムの家族間同期（親端末への反映）:**

> 家族が子ページでふくろうに着せ替えアイテムを付けても、親端末のウィジェットやアラーム画面に反映されなければ
> 「プレゼントした実感がない」。家族コミュニケーションの価値を高めるため、選択中アイテムを Supabase 経由で同期する。

```
データフロー（家族が装備変更 → 親端末に反映）:

  家族の端末:
    1. ふくろう着せ替え設定で「冬のマフラー 🧣」を装備
    2. `AppState.equippedCosmeticID = "winter_muffler"` をローカルに保存
    3. Supabase の `user_profiles` テーブルに即時同期:
       UPDATE user_profiles SET equipped_cosmetic_id = 'winter_muffler'
       WHERE user_id = auth.uid()

  親端末:
    4. SyncEngine が `user_profiles` の変更を検知（Realtime or 定期ポーリング）
    5. `AppState.owlEquippedCosmetic` を更新
    6. PersonHomeView のふくろうアイコン・ウィジェットの部屋画像が自動更新

Supabase テーブル（追加フィールド）:
  ALTER TABLE user_profiles
    ADD COLUMN equipped_cosmetic_id TEXT,           -- 現在装備中のアイテムID
    ADD COLUMN unlocked_cosmetic_ids TEXT[] DEFAULT '{}';  -- 購入済みアイテムIDの配列

同期タイミング:
  - アプリ起動時（scenePhase == .active）: user_profiles を取得してローカルに反映
  - 装備変更時: 即時 UPSERT（オフライン時はキューに積む）
  - ⚠️ 着せ替え情報は「購入済み = Non-Consumable 購入」とは別に管理すること
    （購入確認は StoreKit 2 が Source of Truth。Supabase はUI表示用のキャッシュとして扱う）
```

---


## ■ ファイル変更一覧

### 新規作成（26ファイル）

| ファイル | 内容 |
|---------|------|
| `Models/AppMode.swift` | AppMode enum ✅ 作成済み |
| `Views/Onboarding/ModeSelectionView.swift` | モード選択画面 |
| `Views/Onboarding/OwlNamingView.swift` | ふくろう命名画面（Finch方式・所有感形成） |
| `Views/Onboarding/FamilyHookView.swift` | 家族フック |
| `Views/Onboarding/FamilyPairingOnboardingView.swift` | Universal Link + 6桁コード |
| `Views/Onboarding/FamilyPaywallView.swift` | ペアリング完了直後ペイウォール |
| `Views/Person/PersonHomeView.swift` | 当事者ホーム（全機能込み） |
| `Views/Person/CircularCountdownView.swift` | 円形カウントダウン（60分未満表示） |
| `Views/Person/MicInputSheet.swift` | マイク入力ハーフシート（リアルタイム文字起こし含む） |
| `Views/Family/FamilyHomeView.swift` | 家族モードTabView |
| `Views/Family/FamilyDashboardTab.swift` | 親の今日タブ（🔒表示含む） |
| `Views/Family/FamilySendTab.swift` | 予定送信タブ（重複確認含む） |
| `Views/Family/FamilySettingsTab.swift` | 家族用設定 |
| `Views/Shared/TimeOfDayBackground.swift` | 時間帯グラデーション |
| `Views/Shared/OwlCelebrationOverlay.swift` | 変動比率スケジュール演出 |
| `Views/Shared/SOSProgressBar.swift` | RingingView Stage 2 内SOSバー |
| `Views/Shared/OfflineBanner.swift` | オフライン警告バナー |
| `ViewModels/PersonHomeViewModel.swift` | XP管理・デイリーキャップ・ふくろう状態 |
| `ViewModels/FamilyDashboardViewModel.swift` | LastSeen・競合解決・🔒状態管理 |
| `Services/NetworkMonitor.swift` | NWPathMonitorラッパー |
| `AppIntents/CompleteAlarmIntent.swift` | インタラクティブウィジェット用AppIntent |
| `Services/OfflineActionQueue.swift` | SwiftData ベースのオフラインアクションキュー（順序保証含む） |
| `Views/Shared/MonthlySummaryShareView.swift` | SNSシェア用月次サマリー画像生成（Phase F） |
| `Views/Widget/OwlRoomMediumWidget.swift` | Medium Widget 箱庭（ふくろうの部屋・XP連動アイテム） |
| `Views/Shared/ToastModifier.swift` | ~~共通Toastシステム（ViewModifier + キュー管理）~~ → **v16廃止（P-7-1）。ToastWindowManager に置き換え** |
| `Services/TTSSanitizer.swift` | TTS読み間違いサニタイズ（絵文字除去・発音辞書・記号変換）|
| `Models/ToastMessage.swift` | Toast メッセージモデル（種別・テキスト・表示ルール） |
| `Views/Onboarding/MagicDemoWarningView.swift` | デモ前「音が出ます」警告画面（v15追加・S-21強化）|
| `Views/Shared/ShareSummaryCardView.swift` | SNSシェア用サマリーカード View（ImageRenderer ベース・v15変更）|
| `Services/PronunciationMapService.swift` | 発音辞書サービス（Phase 4 以降で Supabase リモート化）|
| `Views/Alarm/DismissSheet.swift` | 完了後ハーフシート（褒め＆Undo・3秒閉じ＋30秒バックグラウンドUndo・v16 P-2-1/P-9-13）|
| `Views/Input/PersonManualInputView.swift` | ブロック組み立て式手動入力画面（v16 P-1-3）|
| `Views/Onboarding/WidgetGuideView.swift` | ウィジェット設置ステップガイド（v16 P-6-1）|
| `Services/ToastWindowManager.swift` | UIWindowレベルToast表示マネージャー（v16 P-7-1・ToastModifier を置き換え）|
| `Services/DataMigrationService.swift` | データマイグレーション（v1→v2補完・P-9-6）|

### 修正（9ファイル）

| ファイル | 変更内容 |
|---------|---------|
| `App/AppState.swift` | `appMode: AppMode?`、XP/OwlStage追加 |
| `App/AppRouter.swift` | Destination enum刷新 |
| `App/Constants.swift` | `Keys.appMode` 追加 ✅ 完了 |
| `ADHDAlarmApp.swift` | RootView分岐更新 |
| `Views/Onboarding/OnboardingContainerView.swift` | 3画面に削減・ModeSelection挿入 |
| `Views/Alarm/RingingView.swift` | Stage 2 UI（スライド完了・長押しスキップ・SOSバー・イヤホントースト） |
| `Views/Settings/AdvancedSettingsView.swift` | 「使い方を変える」モード切替追加 |
| `Models/AlarmEvent.swift` | `senderName`, `senderEmoji`, `completionStatus`, `isToDo`, `isMiniTask`, `snoozeCount`, `undoPendingUntil`, `isCarriedOver` 追加（P-9） |
| `Services/SyncEngine.swift` | 競合解決ルール・カレンダー変更検知トースト・TTL判定・`ensureValidSession()`・ミニタスク同期除外 |
| `ADHDAlarmApp.swift` | `DataMigrationService.migrateIfNeeded()` を init 冒頭に追加 |

### 非推奨化（削除はしない）

| ファイル | 理由 |
|---------|------|
| `Views/Main/MainTabView.swift` | PersonHome + FamilyHome で置き換え |
| `Views/Main/VoiceInputTab.swift` | MicInputSheetに移行 |
| `Views/Main/AlarmListTab.swift` | PersonHomeに統合（機能は残る） |
| `Views/Main/SettingsTab.swift` | シート表示に変更（機能は残る） |
| `Views/Dashboard/DashboardView.swift` | PersonHomeで完全置き換え |

---

## ■ 成功指標（KPI）と計測設計

### 目標値
| 指標 | 目標値 | 根拠 | 測定タイミング |
|------|--------|------|--------------|
| Day 1 継続率 | 40% | iOSヘルスケアアプリ業界平均 30%より高め（ペルソナの継続動機が強い） | インストール翌日起動 |
| Day 7 継続率 | 20% | 業界平均 15%。薬アラームは毎日使うため上振れ想定 | 7日後も起動 |
| Day 30 継続率 | 10% | 業界平均 5〜8%。習慣化ループで上振れ狙い | 30日後も起動 |
| PRO転換率（全体） | 5% | SaaS 平均（freemium→有料）3〜5%の上限値を目標 | ペイウォール表示後 |
| PRO転換率（ペアリング済み） | 15% | ペアリング完了＝家族価値を実感済み。転換動機が3倍強い | ペアリング完了直後 |
| ペアリング完了率 | 65% | LINEリンク送信後の受諾率。カジュアルな招待文面で上振れを狙う | リンク送信→受諾 |
| MagicDemo完了率 | 75% | オンボーディング完走率。強制的に体験させる設計で損失を最小化 | オンボーディング完走 |
| App Store評価 | 4.5以上 | 「感謝される機能」なので高評価を期待。在宅介護・ADHD当事者コミュニティ口コミ狙い | 累計評価 |

### 計測イベント（Firebase Analytics または Amplitude）
実装者（AI）は以下のイベントを各画面・操作に仕込むこと。

| イベント名 | 発火タイミング |
|-----------|--------------|
| onboarding_mode_selected | ModeSelectionViewで選択 |
| onboarding_magic_demo_started | MagicDemoViewのボタンタップ |
| onboarding_magic_demo_completed | RingingViewで完了タップ |
| onboarding_widget_guide_completed | WidgetGuideViewの最終ページ |
| pairing_link_sent | LINEリンク送信 |
| pairing_completed | ペアリング成功 |
| paywall_shown | FamilyPaywallView表示 |
| paywall_converted | 課金完了 |
| alarm_completed | RingingViewで完了タップ |
| alarm_snoozed | スヌーズボタンタップ |
| alarm_skipped | 「今回はパス」タップ |

---

## ■ AppState 設計ルール（肥大化防止）

AppState はグローバル状態の保管庫であり、適切な範囲を超えて肥大化させてはいけない。

**AppState に追加して良いプロパティの条件（全て満たすこと）:**
1. 複数のViewが同時に参照する必要がある
2. NavigationPath/ルーティングに影響する
3. アプリ全体で1つだけ存在する設定値

**AppState に追加してはいけないもの:**
- 特定のViewModelだけが使うデータ → そのViewModelに持たせる
- ネットワーク取得データ → 対応するServiceに持たせる
- 一時的なUI状態（ローディング・エラー）→ 各ViewModelに持たせる

**現在のAppStateに許可されているプロパティ:**
- appMode, owlName, owlXP, owlStage
- navigationPath（当事者・家族それぞれ）
- familyLinkId / familyChildLinkIds
- toastQueue（ToastWindowManager経由）
- isOnboardingComplete

---

## ■ @Observable 並行性ルール（Xcode 26 strict concurrency対応）

`SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor` を設定しているため、
@Observable クラスは原則 MainActor 上で動く。
バックグラウンド処理（SyncEngine・OfflineActionQueue）との橋渡し時に以下を守ること。

**ルール:**
1. @Observable クラスのプロパティ更新は MainActor で行う
   ```swift
   @Observable @MainActor
   final class PersonHomeViewModel { ... }
   ```
2. バックグラウンドで行った処理結果をUIに反映する場合は `await MainActor.run { }` を使う
3. SyncEngine・OfflineActionQueue は actor として定義し、MainActor との境界を明確にする
   ```swift
   actor SyncEngine: SyncEngineProtocol { ... }
   ```
4. Completion handler は使わない。async/await のみ。
5. **CalendarProviding プロトコルは @MainActor に隔離する（⚠️ 必須）**
   EKEventStore はメインスレッドで操作する必要があるため、CalendarProviding（および EventKitService）は `@MainActor` で宣言する。
   SyncEngine（actor）から呼ぶ場合、プロトコルメソッドが `async` であれば Swift が自動でアクター境界を越えてくれる。
   ```swift
   @MainActor
   protocol CalendarProviding {
       func fetchEvents(from: Date, to: Date) async throws -> [AlarmEvent]
       func saveEvent(_ event: AlarmEvent) async throws
       func deleteEvent(id: UUID) async throws
   }

   @MainActor
   final class EventKitService: CalendarProviding { ... }
   ```
6. **WidgetCenter更新の責任は ViewModel に持たせる**
   アラーム完了・追加・削除を行う ViewModel（PersonHomeViewModel 等）が操作完了後に
   `WidgetCenter.shared.reloadAllTimelines()` を呼ぶ。Service・actor 内からは呼ばない（MainActor との混在を避けるため）。
7. **AlarmKit IDマッピングの保存構造**
   UserDefaults（App Group）のキー `Constants.Keys.alarmKitIDMap` に以下の JSON を保存:
   ```swift
   // [AlarmEventUUID（文字列）: AlarmKit.Alarm.ID（文字列）]
   let map: [String: String] = ...
   UserDefaults(suiteName: Constants.appGroupID)?.set(try JSONEncoder().encode(map), forKey: Constants.Keys.alarmKitIDMap)
   ```
8. **XP・OwlStage の永続化タイミング**
   `owlXP` / `owlStage` を AppState で変更するたびに、即時 UserDefaults（App Group）に書き込む。
   ウィジェットは UserDefaults を直接読むため、アプリ終了時まとめて書き込む方式は禁止。
   ```swift
   // AppState.swift
   var owlXP: Int = 0 {
       didSet { UserDefaults(suiteName: Constants.appGroupID)?.set(owlXP, forKey: Constants.Keys.owlXP) }
   }
   ```
9. **Deep Link受信時の全シート一括 dismiss 実装**
   `@Environment(\.dismiss)` は最前面の1枚しか閉じられない。AppStateに `dismissAllSheets: Bool` フラグを持ち、
   RootView の `.onChange(of: appState.dismissAllSheets)` でシートを連鎖的に閉じる。
   または `UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), ...)` パターンは使わない。
   正式実装は 01_Screen_Flow.md P-1-6 のdeep linkリセット仕様を参照。

---

## ■ 実装フェーズ

### Phase A: 基盤（非破壊）✅ 進行中
1. ✅ `AppMode` enum 作成
2. ✅ `Constants.Keys.appMode` 追加
3. `AppState.appMode` + XP/OwlStage フィールド追加
4. `AppRouter` Destination 刷新
5. `ADHDAlarmApp.swift` RootView分岐
6. `NetworkMonitor.swift` 作成
7. `TimeOfDayBackground.swift`
8. `CircularCountdownView.swift`（60分未満表示 + 近接グループ化）

### Phase B: 当事者モード
1. `PersonHomeViewModel`（XP管理・デイリーキャップ・ふくろう状態・0件メッセージ分岐）
2. `PersonHomeView`（全要素）
3. `MicInputSheet`
4. `AlarmEvent` に `senderName` + `completionStatus` 追加
5. `EventRow` 送信者バッジ
6. RootView に `.personHome` ワイヤリング

### Phase C: 家族モード
1. `FamilyDashboardViewModel`（LastSeen・競合解決・🔒状態管理）
2. `FamilyDashboardTab`（🔒表示・送信者バッジ含む）
3. `FamilySendTab`
4. `FamilySettingsTab`
5. `FamilyHomeView` TabView
6. RootView に `.familyHome` ワイヤリング

### Phase D: オンボーディング刷新
1. `ModeSelectionView`
2. `OwlNamingView`（ふくろう命名・`owlName` を AppState に追加）
3. `FamilyHookView` + `FamilyPairingOnboardingView`（二段構え）
4. `FamilyPaywallView`（ペアリング完了直後）
5. `OnboardingContainerView` 3画面削減
6. 既存ユーザー: `appMode == nil` → ModeSelection直行

### Phase E: 演出・安全性強化
1. `OwlCelebrationOverlay`（変動比率スケジュール）
2. RingingView Stage 2 UI 完全実装
3. `SOSProgressBar`（`alarm.fireDate` から経過計算）
4. イヤホン抜け → `AlarmManager.cancel()` + トースト
5. Live Activity / 通知タイトル匿名化
6. SyncEngine: 競合解決・家族送信予定の強制修復・カレンダー変更トースト
7. 【注記: オフラインアクションキューイング】
   完全オフライン状態での完了/スキップ操作が Supabase に届かない問題。
   UserDefaults の pendingCompletion はクラッシュ対応のみで、長時間オフライン時には不十分。
   → CoreData または SwiftData を使ったローカルアクションキューを実装する。
   → NetworkMonitor がオンライン復帰を検知した瞬間に、アプリがバックグラウンドにいても
     BackgroundTask API 経由で Supabase に一括再送（Sync）する。
   → キューには操作種別（complete/skip/missed）+ eventID + timestamp を保存。
   → 送信成功後にキューからエントリを削除する（冪等性を保証する eventID で重複送信を防ぐ）。
   **【⚠️ v12追加: キュー順序保証ルール】**
   → 同一 eventID のエントリが複数存在する場合（例: オフライン中に complete → 取り消し → skip の3操作が発生）:
     **最新の timestamp を持つエントリのみを送信し、それ以前の同一 eventID エントリは破棄する。**
   → キューはシリアルに（1件ずつ）処理すること（並列送信での競合を防ぐ）。
   → 処理順: timestamp の昇順（古い順）でキューを処理し、同一 eventID は最新のみ残すフィルタリングを事前に実施。
   **【⚠️ v15追加: キュー上限ルール】**
   → キューの最大件数: **100件**
   → 100件を超えた場合は、timestamp が最も古いエントリから順に破棄する（FIFO で捨てる）
   → 破棄されたエントリは Supabase に送信されない（ロストとして扱う）
   → デバッグビルドではキューサイズを毎回ログ出力する（`print("DEBUG: offline queue size: \(queue.count)")`）
   → ⚠️ 極端な長期オフライン（3日以上等）は想定外ユースケースとして受け入れ、上限超えのロストは許容する

   **【⚠️ v14追加: 完了 + Undo の相殺ルール】**
   → 「完了（complete）」とその直後の「Undo（未完了に戻す = nil）」がキュー内に存在する場合:
     **両エントリは互いに相殺（Cancel out）され、どちらも Supabase に送信しない。**
   → 相殺の判定: 同一 eventID で `complete` → `nil（Undo）` の順のエントリが存在する場合
   → 同様に `skip` → `nil（Undo）` も相殺する
   → これにより無駄な Supabase 通信を防ぎ、「完了した・していない」の矛盾した状態を防ぐ

   ```swift
   // 相殺ロジックの実装例（フィルタリング関数）:
   func deduplicateQueue(_ queue: [OfflineAction]) -> [OfflineAction] {
       // 1. eventID でグループ化
       var grouped = Dictionary(grouping: queue, by: \.eventID)
       var result: [OfflineAction] = []
       for (_, actions) in grouped {
           let sorted = actions.sorted { $0.timestamp < $1.timestamp }
           // 2. 最後のアクションが nil（Undo）の場合: グループ全体を捨てる（相殺）
           if sorted.last?.dismissedStatus == nil {
               continue  // Supabase に何も送らない
           }
           // 3. それ以外: 最新のエントリのみを残す
           if let last = sorted.last { result.append(last) }

           // ⚠️ v15追加: missed → complete の競合時の処理
           // キュー内に missed エントリと complete エントリが共存する場合:
           //   → 最新 timestamp のエントリを採用する（complete が後なら complete が勝つ）
           // 具体例:
           //   1. アラーム発火 → 15分後に自動 missed 記録（オフライン中）
           //   2. ユーザーが EventRow 長押し → 「完了にする」選択（missed より後の timestamp）
           //   3. deduplicateQueue: sorted.last = complete → complete を送信（missed を上書き）
           // ⚠️ 逆方向（complete → missed は起こらない。ユーザー操作で missed を付与しないため）
       }
       return result.sorted { $0.timestamp < $1.timestamp }
   }
   ```
8. 音声ファイル（.caf）自動クリーンアップ
   - `Library/Sounds/WasurebuAlarms/` 配下の .caf ファイルを定期的に監査し、
     対応する AlarmEvent が削除済みのファイルを自動削除する。
   - 実行タイミング: アプリ起動時（scenePhase == .active）に前回実行から7日以上経過している場合
     → バックグラウンドスレッドで非同期実行（UIブロッキングしない）
   - クリーンアップ対象:
     ① 対応する AlarmEvent が存在しない .caf ファイル（孤児ファイル）
     ② 最終アクセスから14日以上経過した .caf ファイル（スケジュール外の古いファイル）
   - 削除前チェック: `AlarmEventStore.shared` で eventID を検索して存在確認
   - 削除後ログ: 削除ファイル数・解放容量を print で出力（デバッグビルドのみ）
   - ⚠️ 実装の罠: `.caf` ファイルの最終アクセス日時は `FileManager.attributesOfItem` で取得。
     `URLResourceValues.contentAccessDate` を使うと iOS 26 以降で精度が低下する可能性。
9. 【注記: BGTaskSchedulerによる missed ステータスのバックグラウンド送信】
   アラームが発火してから15分間ユーザーがアプリを開かなかった場合、
   missed ステータスを Supabase に送信する必要があるが、アプリが起動しないため
   scenePhase == .active では検知できない。
   → `BGTaskScheduler` に `BGAppRefreshTask` を登録し、アラーム発火直後にスケジューリング。
   → システムが15〜20分後にバックグラウンドでアプリを起動させ、missed 送信を試みる。
   → ⚠️ ベストエフォートであり、iOSのシステムポリシーによっては実行されないことがある。
     確実な送信が必要な場合は、Supabase Edge Function による定期チェック（Server-side）を併用。
   → 実装タスク: `BGTaskScheduler.shared.register(forTaskWithIdentifier: "...alarm.missed-sync", ...)` を
     `ADHDAlarmApp.init()` に追加。Info.plist に `BGTaskSchedulerPermittedIdentifiers` を記載。

### Phase F: クリーンアップ・バイラル
1. 旧タブ系ファイルを `Views/Legacy/` に移動
2. 「使い方を変える」設定追加
3. ウィジェット仕様更新
4. **SNSシェア機能（ShareLink）**
   - 月次サマリー画面: ふくろう現在形 + 月の完了回数を合成した画像をシェア
   - ふくろう進化時: 進化後のふくろう + 達成メッセージをシェア
   - シェアテキストには予定タイトルを含めない（プライバシー）
   - ハッシュタグ提案: 「#忘れ坊アラーム #ADHD #できた」

---

## ■ 洋介が準備するもの（アセット一覧）

> 以下のファイルは **AI（実装コード）では生成できない** ため、洋介が別途用意してプロジェクトに追加してください。
> 追加先: `ADHDAlarm/Assets.xcassets/` または `ADHDAlarm/Assets/Sounds/` を使用します。
> 実装者（AI）はファイル名を参照するだけなので、**ファイル名を変えないこと**。

---

### 1. ふくろうイラスト — 成長段階別（4種）

XP が閾値に達するとふくろうの「見た目」が変化します。数字は一切ユーザーに見せません。

| ファイル名 | XP 範囲 | 見た目イメージ | サイズ | 備考 |
|-----------|---------|--------------|-------|------|
| `owl_stage1.png` | 0〜99 XP | ひよこふくろう（小さい・ふわふわ） | 360×360px（@3x = 120pt） | 背景透過PNG |
| `owl_stage2.png` | 100〜299 XP | 普通のふくろう（丸くてかわいい） | 360×360px（@3x = 120pt） | 背景透過PNG |
| `owl_stage3.png` | 300〜699 XP | りっぱなふくろう（少し貫禄が出る） | 360×360px（@3x = 120pt） | 背景透過PNG |
| `owl_stage4.png` | 700〜 XP | 長老ふくろう（威厳あり・羽が豊か） | 360×360px（@3x = 120pt） | 背景透過PNG |

---

### 2. ふくろうイラスト — 感情状態別（5種）

同じ成長段階でも「状態」によって表情・ポーズが変わります。
各段階（`stage1`〜`stage4`）で同じ状態セットが必要ですが、まず **stage2（普通のふくろう）で5種を揃え**、残りは実装進捗に合わせて追加するので問題ありません。

> **優先度:** `owl_stage2_*.png` の5種を最初に用意してください。

| ファイル名パターン | 状態 | 表情・ポーズ | サイズ |
|-----------------|-----|------------|-------|
| `owl_stageN_sleepy.png` | 眠そう（残り60分以上・予定なし） | 半目、うとうとしている、読書中のポーズ | 360×360px |
| `owl_stageN_normal.png` | 通常 | ぱっちり目、穏やか | 360×360px |
| `owl_stageN_worried.png` | 心配（予定5分以内で未対応） | 目を大きく開けてそわそわ | 360×360px |
| `owl_stageN_happy.png` | 元気（最近XP獲得あり） | にっこり、翼を少し広げた笑顔 | 360×360px |
| `owl_stageN_sunglasses.png` | スペシャル（5%リアクション） | サングラスをかけてドヤ顔 | 360×360px |
| `owl_stageN_surprised.png` | 驚き（ふくろう長押し時・2-10-B） | 目が真ん丸・翼を広げてびっくり | 360×360px |

> **命名例（stage2の場合）:** `owl_stage2_sleepy.png`, `owl_stage2_normal.png`, ...
> N には段階番号（1〜4）が入ります。

---

### 3. 箱庭ウィジェット用アイテムアイコン（4種）+ 背景画像（2種）

Medium Widget の「ふくろうの部屋」に XP 段階に応じて追加されるアイテムです。

**アイテムアイコン（4種）:**

| ファイル名 | 解放 XP | アイテム内容 | サイズ | 備考 |
|-----------|--------|------------|-------|------|
| `room_shelf.png` | 100 XP〜 | 🪵 木製の本棚（温かみのある木材） | 120×120px（@3x = 40pt） | 背景透過PNG |
| `room_plant.png` | 300 XP〜 | 🪴 観葉植物（小さめの鉢植え） | 120×120px（@3x = 40pt） | 背景透過PNG |
| `room_lamp.png` | 700 XP〜 | 🕯️ アンバー色のテーブルランプ | 120×120px（@3x = 40pt） | 背景透過PNG |
| `room_telescope.png` | 1000 XP〜 | 🔭 小さな天体望遠鏡 | 120×120px（@3x = 40pt） | 背景透過PNG |

> **デザイン方針:** アイテムは「実用家具」より「かわいい・ちょっと不思議な雰囲気」にする（SNSシェアしたくなる見た目）。タッチ・絵本イラスト風が合います。

**⚠️ 部屋の背景画像（2種）— v14追加: 必須**

> ふくろうPNGとアイテムPNGをただ重ねるだけでは平面的な「コラージュ」になる。
> 床と壁にパース（奥行き）がついた背景を最背面に置くことで、本物の「部屋感」が生まれる。

| ファイル名 | 用途 | サイズ | 備考 |
|-----------|------|-------|------|
| `room_background_light.png` | Light モード用の部屋の背景 | 360×360px（@3x = 120pt） | 背景不透過PNG |
| `room_background_dark.png` | Dark モード用の部屋の背景（暗め） | 360×360px（@3x = 120pt） | 背景不透過PNG |

**部屋の背景デザイン要件:**
- 奥の壁と手前の床が見えるような軽いパース（等角投影でもOK）
- 壁は淡いベージュ〜クリーム色（Light）/ 深いインディゴ〜チャコール（Dark）
- 床はフローリング調（木目）。細かすぎない
- 窓（右上）または天窓を入れると光の方向感が出てふくろうが映える
- アイテムが配置されることを前提に、床面中央〜左寄りにスペースを確保すること
- WidgetKit の左ペイン（1/3幅 = 約130pt）に収まるよう構図を中央寄りで作る

---

### 4. アラームサウンド（1種）

| ファイル名 | 格納先 | 仕様 |
|-----------|-------|------|
| `owl_alarm.caf` | `ADHDAlarm/Assets/Sounds/owl_alarm.caf` | 下記参照 |

**音響要件（ADHD・高齢者対応）:**

| 項目 | 要件 |
|------|------|
| 主周波数帯域 | **500Hz〜2kHz**（加齢性難聴が起きにくい中低音域） |
| 音のキャラクター | 柔らかい木琴 or マリンバ系（金属性・電子音は避ける） |
| 立ち上がり（Attack） | ゆるやか（10ms以上）。突然の爆音立ち上がり禁止 |
| 音量 | **-3dBFS 以下**（クリッピング禁止） |
| ループ | **シームレスループ対応**（ループポイントを設定済みであること） |
| フォーマット | `.caf`、サンプリングレート 44100Hz、ステレオ |
| 権利 | 自作 or ロイヤリティフリー素材（App Store 審査で著作権問題が出ないもの）|

> **素材候補:** freesound.org（Creative Commons）、Zapsplat など。
> **必ず実機で音量・音質を確認**してからプロジェクトに追加してください（シミュレータ不可）。

---

### 5. 追加予定（将来フェーズ）

以下は Phase F 以降で必要になりますが、**今すぐ用意しなくても実装は進められます**。

| アセット | 用途 | 優先度 |
|---------|------|-------|
| `owl_stage1〜4_celebrate.png` | ふくろう進化時・月次サマリーのSNSシェア画像用 | Phase F |
| ふくろうアニメーション（Lottie JSON）| 翼バタバタ・ジャンプ演出（20%・5%リアクション） | Phase E |

> **Lottieについて:** Lottie アニメーションを使う場合、`lottie-ios` を Swift Package Manager で追加します。
> JSON ファイルは Adobe After Effects や LottieFiles.com で作成・調達できます。
> Lottieが難しい場合は、SwiftUIの `.spring()` + `scaleEffect` / `rotationEffect` で代替実装します（実装者が判断します）。

---

## ■ v16 レビューパッチ（63件反映）

> **適用日:** 2026-03-28
> **根拠:** v15レビュー評価（Round 1-5・全71件中63件採用）

### P-0. 設計原則への追記

**ふくろうのトーン＆マナー定義（⚠️ 必須・AIへの制約）:**
> AIエンジニアがふくろうの台詞を実装する際、口調がブレないように以下を厳守する。

| 項目 | ルール |
|------|--------|
| 一人称 | 「ふくろう」（「僕」「私」は使わない） |
| 語尾 | 「〜だよ」「〜だね」「〜してね」（温かいタメ口） |
| 禁止 | 説教・命令・叱責（「なんで○○しなかったの？」は絶対禁止） |
| スキップ時 | 「今日はゆっくりしてね」（肯定のみ） |
| エラー時 | 「うまくいかなかったみたい。もう一度やってみてね」（責めない） |

---

### P-8. 将来フェーズ（Phase 2以降）へのロードマップ記載

> 以下の項目は Phase 1（MVPリリース）には含めないが、将来のアーキテクチャ拡張として方針を明記する。

**P-8-1. Siri / App Intents の復活（R4-②）:**
- Phase B以降: 「ヘイSiri、ふくろうに3時の薬を追加して」を実現する `AddEventIntent` の実装

**P-8-2. スマホ不携帯検知（R3-⑬）:**
- Phase G以降: CoreMotionを利用し、デバイスが数時間動いていない場合に「不携帯（放置）」を検知して家族に通知

**P-8-3. アセット動的ダウンロード（R3-⑳/R4-④）:**
- Phase F以降（着せ替え・新音声追加時）: アプリサイズ膨張を防ぐため、追加アセットはオンデマンドリソース（ODR）または Supabase Storage から動的ダウンロードする設計へ移行
- `VoiceStoreView`（プレビューUI）もこのタイミングで実装

**P-8-4. タイムゾーン（Floating Time）対応（R3-⑤）:**
- 現状は端末ローカル時刻依存。海外旅行ユーザー等向けに、将来的に `timeZone` と `isFloating` フィールドを追加する拡張枠を考慮

**P-8-5. SOS双方向同期（R4-⑩）:**
- Phase G以降: 家族がSOSを確認（Acknowledge）した瞬間に、親端末の AlarmKit を強制キャンセルし「家族が確認してくれました📞」画面へ切り替える Supabase Realtime 同期の実装

---

## ■ 仕様書ファイル構成

このフォルダ（仕様書/）は以下のファイルで構成されています。

| ファイル | 内容 |
|---|---|
| 00_Root_Concept.md | 全体像・設計原則・実装フェーズ・アセット一覧 |
| 01_Screen_Flow.md | 画面遷移・当事者/家族モードUI・オンボーディング・詳細レイアウト |
| 02_Design_System.md | デザイントークン・カラー・タイポ・アニメーション物理定義 |
| 03_Alarm_Engine.md | AlarmKit・通知・TTS・スヌーズ・イヤホン抜け |
| 04_Feature_Modules.md | マネタイズ・ペアリング・ウィジェット |
| 05_Data_Architecture.md | データ同期・Supabase・オフライン・マイグレーション |
| 06_Checklist.md | 検証チェックリスト全件 |
| 07_AppStore.md | App Storeメタデータ・ASO・スクリーンショットコピー |