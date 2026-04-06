## ■ 検証チェックリスト

> 記号: `[x]` = 確認済み / `-` = 対象外 / `[s]` = シミュレータ・自動テスト・1台ローカルで確認可能 / `[r]` = 実機1台必須 / `[2]` = 2台端末または外部環境必須

### 当事者モード
- [s] 残り60分以上: 円形非表示、ふくろう穏やか
- [s] 残り30〜59分: 青いリング出現
- [s] 残り10分未満: 赤+パルス
- [s] 30分以内の複数予定: グループ表示（アニメなし）
- [x] 今日0件（全完了）: 「🎉 お疲れ様！」
- [x] 今日0件（スキップ含む）: 「🍵 今日は無理せず休もう」
- [x] 今日0件（最初から予定なし）: 「🌸 のんびりしてね」
- [s] 明日の予定: 区切り線+グレーで常時2件表示（折りたたみなし・0件でもスクロール下固定）
- [s] オフライン: 上部に黄色バナー
- [s] FAB: 「🎤 予定を追加」ラベル常時表示
- [x] XP: 完了+10 / スキップ+3 正確に加算（アプリ起動XPなし）
- [x] XP: 予定追加XPは完了時のみ付与
- [x] XP: 1日上限50XP
- [s] ふくろう: 数字UI（Lv.7等）が存在しないこと
- [x] ふくろう: XP閾値で見た目が変化すること

### アラーム停止（2段階フロー）
- [r] Stage 1: AlarmKitのOSアラーム画面タイトルが「🦉 ふくろうからのお知らせ」
- [r] Stage 2: RingingView が Stage 1 の後に表示されること
- [s] スライドして完了のみが初期表示
- [s] 「今回はパス」は5秒後に出現
- [s] 「今回はパス」は長押し1.5秒で発動（タップでは発動しない）
- [s] SOSバー: `alarm.fireDate` から正しく経過時間を計算
- [r] イヤホン抜け: AVAudioPlayer停止 + AlarmManager.cancel() 両方呼ばれること
- [r] イヤホン抜け: RingingViewは閉じずに維持されること
- [s] 変動比率: スペシャル(5%)が偏りなく出現すること
- [s] スライド完了: Y軸80ptまでのズレがあってもドラッグが継続されること（斜め操作対応）
- [s] スライド完了: 長押し2秒でも完了発動すること（フォールバック）
- [s] スライド完了: 「または長押しで完了」テキストが常時表示されること
- [s] owlAmber背景のボタンのテキスト色が黒（#000000）であること（コントラスト8.3:1）
- [s] owlAmber背景に白テキストが1箇所も存在しないこと（ビジュアル検査）
- [s] `UIAccessibility.isReduceMotionEnabled = true` の時: 花火・星パーティクルが表示されないこと
- [s] `UIAccessibility.isReduceMotionEnabled = true` の時: フェードイン・テキストのみ表示されること
- ~~`CircularCountdownView` に `.dynamicTypeSize(...DynamicTypeSize.accessibility2)` が適用されていること~~ → **v16廃止（P-2-4）**
- [s] **[v16 P-2-4]** accessibility3以上の時: 円形リングが非表示になり巨大数字テキストのみが表示されること
- [s] システムフォントを最大設定にした時、カウントダウン数字 > イベントタイトルの階層が維持されること
- ~~完了/パス後3秒以内: Undoスナックバーが表示されること~~ → **v16廃止（P-2-1）**
- [s] **[v16 P-2-1]** 完了/パス後: DismissSheet（ハーフシート）が表示されること
- [s] **[v16 P-2-1]** DismissSheet に「取り消す」ボタンが表示されること
- [s] **[v16 P-2-1]** DismissSheet が10秒で自動閉じすること
- [2] Undoタップ: completionStatusがnilに戻り、Supabase送信がキャンセルされること
- [2] Undoタップ: スキップ時のPush通知が送信されないこと
- [2] 10秒タイムアウト後: Supabase送信が確定し、スキップ時Push通知が送信されること
- [r] スワイプキル検知: scenePhaseが.activeになった時にzombie alertingを検知しキャンセルすること

### 家族モード
- [s] 🔒 機能（履歴・SOS）: タップで FamilyPaywallView が表示されること
- [s] 当日の完了/スキップステータス（✓/❌）: 無料版でも表示されること（壁なし）
- [2] 当日の Last Seen: 無料版でも表示されること（壁なし）
- [s] 過去7日間の履歴: 無料版では🔒表示
- [2] Last Seen 詳細（時刻精度）: 無料版では🔒表示
- [2] 完了（✓✓）: 家族にPush通知が飛ばないこと（サイレント更新のみ）
- [2] スキップ（❌）: 家族にPush通知が飛ぶこと（ただしUndoの3秒後）
- [2] completionStatus: 家族がタイトル変更してもローカルの完了状態が保持されること
- [2] family_links にペアリングなしの他人の予定をINSERTしようとすると RLS で拒否されること
- [2] Last Seen: 1時間以内🟢 / 1-6時間🟡 / 6時間以上🔴

### ペアリング
- [2] Universal Link成功: LINEリンクタップのみで自動ペアリング
- [2] Universal Link失敗: 6桁コード入力UIに自動フォールバック
- [2] ペアリング完了直後: FamilyPaywallViewが表示されること

### マネタイズ
- [2] 家族: ペアリング完了直後にペイウォール表示
- [s] 「あとで」でスキップ可能
- [s] 無料版でロック機能にタップするとペイウォールが出ること
- [s] 親の初回✓✓到着時: 無料ユーザーにコンテキスチュアルバナーが出ること（2回目以降は出ない）
- [2] レビュー依頼: 月次サマリー（10回完了以上）または家族に初回✓✓後のみ発火すること
- [s] レビュー依頼: 起動直後・エラー後・スキップ後・ペイウォール後に発火しないこと

### オンボーディング
- [x] PermissionsCTAView: 通知プリプロンプト → システムダイアログの順に表示されること
- [x] PermissionsCTAView: カレンダープリプロンプト → システムダイアログの順に表示されること
- [r] MagicDemoView: 3秒後にAlarmKitアラームが発火すること
- [r] MagicDemoView: マナーモード中でもアラームが鳴ること（実機確認必須）
- [x] MagicDemoView: 「あとで試す」でスキップ可能なこと
- [r] マイクFAB初回: プリプロンプト（録音はサーバーに送られない旨）→ システムダイアログの順

### アラーム画面（Stage 2 タップボタン化）
- [s] RingingView: スライドではなく「薬を飲んだ」タップボタン（ComponentSize.actionGiant = 72pt）が表示されること
  注: 現行実装は「薬を飲んだ」ではなく全幅の「とめる」ボタン表示 (`ComponentSize.actionGiant`) に変わっている
- [r] 完了タップ: Haptic(.success)が完了確定時（ボタンタップ直後）に鳴ること
- [s] MagicDemoView（スライドUI）の .selection / .success タイミングが正しいこと

### 家族モード（追加項目）
- [s] 予定送信: 時間プリセット（朝/昼/夜）ボタンが3つ表示されること
  注: 現行 `FamilySendTab` は 朝/昼/夜 ではなく `今から / 15分後 / 30分後 / 1時間後 / カスタム` の選択式
- [s] 重複検知: 警告バナーではなく「上書きする/やめる」2択が表示されること
- [s] 重複検知: 選択前は送信ボタンがブロックされること（強行突破不可）
- [2] 家族がキャンセル: 親のLast Seenが古い場合「電波が届いていない」警告が出ること
- [2] スキップ通知: 30分以内の複数スキップが1通にまとめられること

### データ保全（追加項目）
- [x] Undo中: `undoPendingUntil` が設定され、完了状態が即時確定しないこと
- [x] Undo猶予後: 30秒タスクの完了で確定処理が走ること
- [s] `isLowPowerModeEnabled = true` の時: パーティクルアニメーションがスキップされること

### State Out of Sync リカバリ（追加項目）
- [r] Apple Watch / OS側で停止後、アプリを開いた時にRingingViewが表示されないこと（15分超過）
- [x] 15分超過の場合: completionStatus が .missed として記録されること
- [s] 15分超過の場合: ふくろうトースト「さっきのお知らせ、時間が経っていたのでお休みにしておきました」が表示されること
- [r] 15分以内の場合: 通常どおり RingingView が表示されること
- [2] missed: 家族への Push 通知が送られないこと

### ペアリング同意（追加項目）
- [2] 親がリンクをタップした際、自動ペアリングではなく相互同意確認画面が表示されること
- [s] 同意確認画面に「できること / できないこと」が両方明記されていること
- [2] 「今はやめておく」タップ時: family_links にレコードが作成されないこと
- [2] 6桁コード経由でも同じ同意確認画面が表示されること

### 音声アクセシビリティ（追加項目）
- [x] クリアボイスモードON時: rate=0.40、pitchMultiplier=0.80 が適用されること
- [x] クリアボイスモードと高齢者モード（文字拡大）が独立して動作すること（片方だけON可能）
- [s] 設定画面のラベルにIT用語が1つも使われていないこと（翻訳表に従っていること）
  注: 現行実装ではカレンダー選択Pickerに `デフォルト` 文言が残っているため、未達

### オンボーディング（追加項目）
- [r] MagicDemoでアラームが鳴った後、Stage 2 RingingView まで通り抜けること
- [s] RingingViewで完了タップ → OwlCelebrationOverlay が表示されること
- [s] MagicDemoの +10 XP が本物のXPとして加算されること

### プライバシー
- [r] Stage 1（OSアラーム）: タイトルが「🦉 ふくろうからのお知らせ」
- [x] Stage 2（RingingView）: タイトルが表示されること
- [s] 通知バナー: 予定タイトルが含まれないこと
  注: 現行実装の `AlarmKitScheduler.scheduleActionableNotification()` では `content.title = alarm.title` になっているため、未達

### ウィジェット
- [r] Small: カウントダウン数字 + 次の予定タイトル
- [r] ロック画面: アイコン + 数字のみ

### ふくろう命名（v11追加）
- [x] OwlNamingView: PermissionsCTAViewの後、MagicDemoViewの前に表示されること
- [x] 名前入力: onChange でリアルタイムに「○○って呼んでもらえるの嬉しいよ！」が更新されること
- [x] 名前未入力でボタンを押した場合: デフォルト「ふくろう」として扱われること
- [x] PersonHomeView のあいさつ文に `owlName` が埋め込まれること
- [x] 設定画面から名前を変更できること

### EventRow 絵文字アイコン（v11追加）
- [s] EventRow左端に絵文字アイコン（.title2相当・Dynamic Type追従）が表示されること
  注: 現行実装は `Text(alarm.resolvedEmoji).font(.system(size: 20))` で固定サイズ表示のため、Dynamic Type 追従までは未確認
- [x] タイトルから絵文字が自動推定されること（💊薬 / 🏥病院 / 🛒買い物 等）
- [x] 推定不能の場合: デフォルト 📌 が表示されること（空欄にならない）
- [s] 完了状態: 絵文字が opacity 0.4 でグレーアウトされること

### EventRow インタラクション（v2変更）
> ゴミ箱ボタン廃止・ジェスチャー操作に統一
- [s] 右スワイプ: 緑「完了」ボタンが表示されること（allowsFullSwipe: false で誤操作防止）
- [s] 左スワイプ: 赤「削除」ボタンが表示されること（タップで confirmationDialog を表示）
- [r] 長押し（1秒）: 完了が発動し Haptic(.medium) が鳴ること
- [x] 繰り返し予定の削除: 「今回のみ削除」「繰り返しを全部削除」の2択が表示されること
- [x] 通常予定の削除: 「削除する / やめる」のダイアログが表示されること
- [s] 行内ヒント: 「長押しで完了 ・ 左スワイプで削除」テキストが未完了行に表示されること
- [x] 完了済み行: 右端にチェックマークアイコンのみ表示（ボタンなし）

### 連携解除UI（v11追加）
- [2] 設定 → つながっている家族の設定: ペアリング相手の名前と連携日が表示されること
- [s] 「連携を解除する」ボタン（.statusDanger色）が表示されること
- [s] タップ → 確認ダイアログ（ActionSheet）が表示されること
- [2] 確定後: `family_links.is_active = false` が Supabase に書き込まれること
- [2] 確定後: 相手側に解除Push通知が送信されること
- [s] 確定後: ローカルの familyLinkId / familyChildLinkIds がクリアされること

### アテンション音（v11追加）
- [r] 音声再生前にアテンション音（システム音 1057）が鳴ること
- [r] アテンション音 → 1秒無音 → ナレーション の順序で再生されること

### スキップ通知コピー（v11追加）
- [s] スキップ通知本文に「お休みしました」「体調が悪いのかもしれません」「☕️」が含まれること
- [s] バッチ通知（30分以内複数スキップ）: 「体調を確認してあげてください ☕️」が含まれること

### 音声ファイルクリーンアップ（v11追加）
- [s] 前回実行から7日以上経過している場合のみクリーンアップが実行されること
- [s] 対応する AlarmEvent が存在しない孤児 .caf ファイルが削除されること
- [s] 最終アクセスから14日以上経過したファイルが削除されること
- [s] クリーンアップ中にUIがブロックされないこと（バックグラウンドスレッド）
  注: 現時点では専用の `.caf` クリーンアップ実装や実行スケジューラをコードベース内でまだ確認できていない

### DatePickerアコーディオン（v11追加）
- [x] FamilySendTab: DatePicker がデフォルトで非表示（折りたたみ状態）なこと
- [s] 「⚙️ 時間を細かく設定する」タップ → DatePicker がアニメーションで展開されること
  注: 現行 `FamilySendTab` は `⚙️ 時間を細かく設定する` ボタンではなく、`今から / 15分後 / 30分後 / 1時間後 / カスタム` の選択式
- [s] プリセット（朝/昼/夜）タップ → 日時が即時設定され、アコーディオンは閉じたままなこと

### インタラクティブウィジェット（v12追加）
- [x] Small Widget に完了ボタンが存在しないこと（廃止が維持されていること）
- [x] ウィジェットから完了操作を行う導線が存在しないこと（旧AppIntent廃止の維持）
- [x] 完了済み状態をボタンで表現しないこと（旧「✓ 済み」ボタン仕様が復活していないこと）
- [x] 次の予定がない場合も旧完了ボタン領域が表示されないこと
- [x] 完了ボタン廃止後もタイムライン更新ロジックが破綻していないこと
- [r] ウィジェットテキストに owlName が埋め込まれること（「○○が待ってるよ」）
- [r] ふくろうのアイコン/状態（sleepy/happy/worried）がウィジェットに反映されること
- [s] App Group UserDefaults 経由で owlName/owlState が正しく読み取られること

### 音声入力リアルタイムフィードバック（v12追加）
- [r] MicInputSheet に「お話しください...」プレースホルダーテキストが表示されること
- [r] 録音開始後、SFSpeechRecognizer のリアルタイム文字起こしが波形下に表示されること
- [r] 認識中テキストが .italic + .secondary で表示されること（仮テキスト感）
- [r] 認識完了後、テキストが .primary に切り替わり予定タイトルフィールドに自動コピーされること
- [r] 認識結果が空の場合「うまく聞き取れませんでした」メッセージが表示されること
- [x] requiresOnDeviceRecognition = true が設定されていること（オフライン対応）

### 連携解除フリクション（v12変更）
- [s] 「連携を解除する」がテキストスタイル（.statusDanger色のテキストのみ）であること（目立つ赤ボタンでないこと）
- [s] タップ後に ActionSheet の確認ダイアログが表示されること
- [s] 「本当に解除する」ボタンが .destructive スタイルで表示されること
- [s] ボタンが `.buttonStyle(.borderedProminent)` になっていないこと（ビジュアル確認）

### オフラインキュー順序保証（v12追加）
- [s] 同一 eventID のエントリが複数存在する場合、最新 timestamp のみが送信されること
- [s] キューがシリアル処理（並列送信なし）で実行されること
- [s] オフライン中に complete → skip の2操作が発生した場合、skip のみが送信されること

### 同意画面ポジティブフレーミング（v12変更）
- [s] 同意確認画面に ❌マークが使われていないこと
- [s] 「娘さんの場所は見えません」ではなく「🛡️ プライバシーは守られます」の表現が使われていること
- [s] 6桁コード経由の同意確認画面にも同じポジティブフレーミングが適用されること

### AlarmKit権限プリプロンプト（v12追加）
- [s] MagicDemoViewの前に AlarmKit権限プリプロンプト画面が表示されること
- [s] プリプロンプトに「マナーモードでも鳴る」理由が説明されていること
- [s] 「アラームを許可する」→ AlarmManager権限リクエスト → 許可後MagicDemoViewに進むこと
- [s] 「あとで設定する」→ MagicDemoViewをスキップしてPersonHomeViewへ進むこと
- [s] 通知・カレンダーのプリプロンプトと同じデザインパターンが使われていること

### SNSシェア（v12追加・Phase F実装）
- [s] 月次サマリー画面に「📤 シェアする」ShareLink ボタンが表示されること
- [s] シェア画像にふくろうの現在の進化形 + 月の完了回数が含まれること
- [s] シェア内容に予定タイトルが含まれないこと（プライバシー保護）
- [s] ふくろう進化時にも ShareLink ボタンが表示されること
- [s] ハッシュタグ「#忘れ坊アラーム #ADHD #できた」がシェアテキストに含まれること

### 箱庭ウィジェット（v13追加）
- [x] Medium Widget が `.systemMedium` WidgetFamily で定義されていること
- [s] 左ペインにふくろうの部屋（1/3幅）、右ペインに予定情報（2/3幅）が配置されること
- [s] XP 0〜99: 部屋にふくろうのみ表示されること
- [x] XP 100〜: 本棚が出現すること（アイテムがフェードインで追加されること）
- [x] XP 300〜: 観葉植物が出現すること
- [x] XP 700〜: ランプが出現すること
- [x] XP 1000〜: 天体望遠鏡が出現すること
- [s] owlState が部屋の雰囲気に反映されること（sleepy→暗い / happy→明るい）
- [x] App Group UserDefaults 経由で owlXP が正しく読み取られること
- [s] WidgetCenter.shared.reloadAllTimelines がXP更新時に呼ばれること
  注: `reloadAllTimelines()` の呼び出し自体は複数箇所にあるが、`AppState.addXP()` 直結の保証としては未確認

### Liquid Glass マテリアル（v13追加）
- [s] ハーフシート背景が `.regularMaterial` で実装されていること
- [s] EventRow / テンプレートカードの背景が `.ultraThinMaterial` であること
- [s] FABボタンの背景が `.thickMaterial` + Circle clip であること
- [s] RingingViewの背景が `.ultraThickMaterial` + 時間帯オーバーレイの組み合わせであること
  注: 現行実装は一部に `.regularMaterial` / `.thickMaterial` はあるが、EventRow は独自ガラス背景、FAB は `Color.owlAmber` 背景、RingingView はグラデーション背景で、文言どおりの一致は未確認
- [x] ウィジェットが `.containerBackground(for: .widget)` を使っていること
- [s] `Color.white` / `Color(uiColor: .systemBackground)` が背景に直接使われていないこと

### NavigationStack アーキテクチャ（v13追加）
- [x] `NavigationView` が1箇所も使われていないこと
- [x] `RootView` が onboarding 状態と `appMode` に応じて `ModeSelection` / `PersonHomeView` / `FamilyHomeView` を分岐すること
- [x] 設定・ペイウォールが `.sheet` で表示されること（`.fullScreenCover` でないこと）
- [x] RingingView のみ `.fullScreenCover` で表示されること
- 現仕様では MicInputSheet は `.large` 寄りの運用に変更されているため、この項目は旧仕様として対象外

### 共通Toastシステム（v13追加）
- 現仕様では `ToastWindowManager` に移行しており `ToastModifier` は使わないため、この項目は対象外
- [x] 同時に表示されるトーストが1件のみであること
- [x] キューに複数ある場合、前のトーストが消えてから次が表示されること
- [x] 同一テキストの2秒以内の重複エンキューが無視されること
- [x] `.owlTip` トーストが `.regularMaterial` 背景（Liquid Glass）で表示されること
- [x] `.error` トーストが画面上部から降りてくること（下からではないこと）

### マイク沈黙タイムアウトUI（v13追加）
- [r] 録音開始から5秒間無音の場合、沈黙エラー状態に遷移すること
- [r] 沈黙エラー状態で「声が届きませんでした」メッセージが `.statusDanger` 色で表示されること
- [r] 「🎤 もう一度試す」ボタンで録音が再スタートできること
- [r] 「テキストで入力する」フォールバックが表示されること
- [r] 騒音エラー（認識できたが意味不明）の場合は認識結果をそのまま表示し手動修正できること
- [r] 沈黙エラーのメッセージが赤ボタンを伴わないこと（パニック防止）

### 大量タスク折りたたみ（v14追加・S-11）
- [x] 未完了の予定が4件以上の場合、直近3件のみ表示されること
- [x] 「＋ 残り○件を表示 ▼」ボタンが折りたたみ状態で表示されること
- [s] タップで全件が `.easeInOut(0.3)` アニメーションで展開されること
- [x] 展開後に「▲ 折りたたむ」ボタンが表示されること
- [x] 未完了が3件以下の場合、折りたたみボタンが表示されないこと（全件表示）
- [x] 完了済み予定はカウントに含まれないこと（完了後に3件未満になったら自動展開）
- [s] `@SceneStorage("isEventListExpanded")` で展開状態が再起動後も維持されること
- [x] 折りたたみボタンのタップ領域が `.contentShape(Rectangle())` + 44pt 以上であること

### MagicDemo 音量確認・Haptics分岐（v14追加・S-21）
- [r] ボタン直上に「🔊 音量を上げてからボタンを押してね」テキストが表示されること
- [r] `outputVolume > 0.1` の場合: 通常デモが実行されること（3秒後にアラーム発火）
- [r] `outputVolume <= 0.1` の場合: マナーモード説明テキストが表示された後にアラームが発火すること
- [r] 出力デバイスなし（特殊ケース）の場合: AlarmKitをスキップしHapticのみデモに切り替わること
- [r] Hapticデモ: 3秒後に `.heavy` 振動が3回発生すること
- [r] Hapticデモ: 「振動で感じられましたか？」メッセージと「わかった！」ボタンが表示されること

### TTSサニタイズ処理（v14追加・B-50）
- [x] `TTSSanitizer.sanitize()` がナレーション生成前に呼ばれること
- [x] 絵文字が除去されてから `AVSpeechSynthesizer` に渡されること
- [x] 括弧（`（）`）が「、」に変換されること
- [x] 連続する句読点（「、、」「。。」）が1つに整理されること
- [x] 英字略語（`MRI`、`CT` 等）が日本語読みに変換されること
- [x] `pronunciationMap` が外部ファイル（JSON or 定数）として切り出されていること（将来の拡充を考慮）

### タップ領域拡張（v14追加・B-16）
- [x] EventRow に `.contentShape(Rectangle())` が適用されていること
- [x] テンプレートカード（FamilySendTab）に `.contentShape(Rectangle())` が適用されていること
- [x] 設定行に `.contentShape(Rectangle())` が適用されていること
- [x] FABボタンに `.contentShape(Circle())` が適用されていること
- [x] 折りたたみボタン（2-2-B）に `.contentShape(Rectangle())` が適用されていること
- [x] 全タップターゲットの最小高さが 44pt 以上であること（Apple HIG 準拠）

### 家族LTV・継続利用インセンティブ（v14追加・A-9）
- [2] 月末に家族向け「今月のまとめ」カードが Tab 0 最上部に表示されること（1日のみ）
- [s] まとめカードに先月比較（+○回増加）が表示されること（PRO限定）
- [s] 無料版では先月比較が🔒表示されること
- [2] 累計10回完了・連続7日・ペアリング30日のマイルストーンバナーが1回だけ表示されること
- [s] 解約フロー: 「プレミアムを解約する」タップ時に今月の実績チェックイン画面が表示されること
- [s] チェックイン画面から「続けて使う」タップで画面が閉じるだけで追加の引き止めがないこと

### v15 追加項目

#### アカウント削除機能（v15追加・App Store 義務）
- [x] 設定画面の最下部セクションに「アカウントを削除する」ボタンが表示されること
- [s] ボタンが `.statusDanger` 色のテキストスタイル（赤い目立つボタンではないこと）
- [x] タップ → ActionSheet の確認ダイアログが表示されること（2段階確認）
  注: 現行実装は `ActionSheet` ではなく `confirmationDialog` を使用
- [2] 「本当に削除する」確定後: Supabase の全ユーザーデータが削除されること（Edge Function 経由）
- [s] ローカル UserDefaults が全クリアされること
- [r] AlarmKit の登録済みアラームがすべてキャンセルされること
- [s] EventKit のアプリ作成イベント（wasure-bou マーカー付き）が削除されること
- [s] .caf ファイルがすべて削除されること
- [s] 処理中に ProgressView + 「削除中...」オーバーレイが表示されること（Dismiss不可）
- [2] Supabase失敗時にエラー表示 + ローカルデータは保持されること（再試行のため）
- [s] 削除完了後: オンボーディング画面に遷移すること

#### Dynamic Type extreme 時のフォールバック（v15追加・S-11修正）
- [x] `UIApplication.shared.preferredContentSizeCategory >= .accessibilityLarge` の時: 表示件数が画面高さから動的計算されること
- [x] 最低でも1件は常に表示されること（0件にならないこと）

#### MagicDemo「音が出ます」警告画面（v15追加・S-21強化）
- [x] デモボタンタップ前に「音が出ます」警告画面（MagicDemoWarningView）が表示されること
- [x] 警告画面に「🔊 これから音が鳴ります」と「周りに人がいますか？」の説明が含まれること
- [r] 「鳴らしてみる！」タップ時に `.impact(.medium)` Haptic が鳴ること
- [r] 「音を出さずにスキップ」タップ → Hapticのみデモに直接進むこと

#### missed → complete 後からの手動完了（v15追加）
- [s] EventRow 長押しメニューで `missed` 状態の予定に「完了にする」が選べること
- [s] 選択後: completionStatus が `.complete` に更新されること
- [2] Supabase に dismissed_status = "complete" が PATCH されること（missed の上書き）
- [s] XP +10 が付与されること
- [s] EventRow の表示が ⏰グレーアウト → ✓完了グレーアウトに変わること

#### 折りたたみアニメ・マイク波形の減動作対応（v15追加・項目10）
- [s] `isReduceMotionEnabled = true` の時: EventRow 折りたたみが `.move` でなく `.opacity` のみになること
- [r] `isReduceMotionEnabled = true` の時: マイク波形バーの高さ変化アニメーションが停止すること
- [r] `isReduceMotionEnabled = true` の時: 波形の代わりに赤マイクアイコン + 「録音中...」テキストが表示されること

#### MicInputSheet キーボード展開時 detent 固定（v15追加・あいまい2）
- [s] TextField フォーカス時（キーボード展開）に `.presentationDetents` が `.large` に自動切り替わること
- [s] `.presentationDetents([.medium, .large], selection: $binding)` の selection binding が使われていること

#### 既存ユーザーのオンボーディングスキップ（v15追加・矛盾1）
- [s] `isOnboardingComplete == true` かつ `appMode == nil` の場合: ModeSelection のみ表示されること
- [s] ModeSelection 完了後: 権限・OwlNaming・MagicDemo をスキップして直接 Home へ遷移すること
- [s] 既存ユーザーの ModeSelection ボタンラベルが「この設定で使う」であること（「はじめる」ではないこと）

#### オフラインキュー上限（v15追加・項目3）
- [s] キューが 100 件を超えた場合、最古エントリから順に破棄されること
- [s] キューサイズがデバッグビルドでログ出力されること

#### pronunciationMap リモート化（v15追加・項目4）
- [s] Phase 1: バンドルの JSON ファイルが静的辞書として使われること
- [2] Phase 4 以降: Supabase からフェッチした辞書をキャッシュして使うこと（TTL: 24時間）
- [s] フェッチ失敗時: バンドル JSON にフォールバックすること

### v16 追加項目

#### DismissSheet（v16 P-2-1・RingingView 完了後ハーフシート）
- [s] RingingView 完了後: DismissSheet（ハーフシート）が PersonHome 直前に表示されること
- [s] DismissSheet に「✓ 完了しました！」+ XPアニメーション + 「取り消す」ボタンがあること
- [2] 「取り消す」タップ: completionStatus が nil に戻り Supabase送信がキャンセルされること
- [s] 10秒後に DismissSheet が自動閉じすること
- ~~Undoスナックバー（3秒・スクリーン下部）~~ が表示されないこと（廃止確認）

#### スヌーズ機能（v16 P-2-2）
- [x] RingingView に「⏱️ 30分後にまた教えて」スヌーズボタンが表示されること
- [x] スヌーズタップ後: AlarmKit に now+30min で再登録されること
- [x] completionStatus が変更されないこと（nil のまま）
- [x] 同一予定のスヌーズ最大3回制限が機能すること（4回目はスヌーズ非表示）

#### ToastWindowManager（v16 P-7-1・UIWindowレベル）
- [s] Toast が `.fullScreenCover`（RingingView）の上層に表示されること（裏に隠れないこと）
- [s] `UIWindow.windowLevel = .alert + 1` で実装されていること
- ~~ToastModifier の `.overlay`~~ が使われていないこと（廃止確認）

#### ScenePhase デバウンス（v16 P-5-4）
- [x] `scenePhase == .active` 連打時: 前回フェッチから60秒未満ならスキップされること
- [x] `lastSyncCheckTimestamp` が管理されていること

#### OfflineQueue デッドロック回避（v16 P-5-2）
- [2] Supabase から 404 返却時: そのエントリを破棄して後続処理が継続されること（デッドロックしないこと）

#### PersonManualInputView（v16 P-1-3）
- [x] MicInputSheet の「テキストで入力する」から PersonManualInputView に遷移できること
- [x] テンプレート大ボタン（薬・ゴミ・病院・電話・カフェ・その他）が表示されること
- [x] 時間プリセット（朝・昼・夜・10分後・30分後・1h後・細かく設定）が表示されること

#### 重複検知インターセプト（v16 P-1-7）
- [x] MicInputSheet で予定確定後、7日以内の類似予定を検索すること
- [s] 類似予定発見時: 「すでに○○が登録されてるよ！」ふくろう提案UIが表示されること
  注: 現行UIは「🦉 もしかして、もう登録されているかも？」+ 「『○○』（時刻）が見つかりました。」表現で実装されているため、文言一致としては未確認
- [x] 「追加しない」「別の予定として追加する」の2択が表示されること

#### WidgetGuideView（v16 P-6-1）
- [r] MagicDemo 後・PersonHome 前にウィジェット設置ガイド画面が表示されること
- [s] 「あとで」でスキップ可能なこと
- [s] 設定画面から再閲覧できること

#### 通知権限剥奪リカバリ（v16 P-6-2）
- [x] `scenePhase == .active` のたびに通知権限を確認していること
- [s] `denied` 時: PersonHome 操作がブロックされ全画面警告が表示されること
- [s] 設定アプリへのディープリンクボタンが表示されること

#### TTS マナーモード消音対策（v16 P-4-1）
- [x] AVSpeechSynthesizer 起動前に `.playback` + `.voicePrompt` セッションが設定されること
- [r] マナーモード中でもふくろうの声が聞こえること（実機確認必須）

### Round 6 追加項目（P-9）

#### 薬の二重服用防止（P-9-1）
- [x] AlarmEvent に `undoPendingUntil: Date?` フィールドが追加されていること
- [2] Undo直後5分以内にリモートから complete が来ても上書きされないこと
- [s] DismissSheet 30秒タスク確定後に `undoPendingUntil = nil` がセットされること

#### スヌーズの家族ダッシュボード表示（P-9-2）
- [2] 家族Tab 0 に `snoozed` ステータス（🟡オレンジ・⏱アイコン）が表示されること
- [s] スヌーズ中のテキストが「○分後にまたお知らせ中」と表示されること
- [2] スヌーズ時に家族への Push 通知が送信されないこと
- [s] スヌーズ3回目以降: `snoozed_count` が表示されること

#### バッテリー死対応（P-9-3）
- [s] バッテリー10%未満 + 2時間以内のアラームがある場合にトーストが表示されること
- [s] `lowBattery` 条件でアニメーションが削減されること（`reduceMotion` と同等）

#### スキップ通知バッチ処理（P-9-4）
- [2] Edge Function が30分間 sleep するコードが一切ないこと（タイムアウト禁止）
- [2] `skip_notification_queue` テーブルが Supabase に存在すること
- [2] pg_cron が `*/30 * * * *` で `send-skip-batch` を呼び出す設定があること

#### Supabase Token 自動リフレッシュ（P-9-5）
- [s] `ensureValidSession()` が全 API 呼び出し前に実行されること
- [s] セッション期限5分前に `refreshSession()` が呼ばれること
  注: 現行 `FamilyRemoteService` には `ensureValidSession()` / `refreshSession()` はなく、各所で `client.auth.session` 取得または `ensureDeviceRegistered()` を使う構成
- [x] セッションなし時に `signInAnonymously()` が呼ばれること

#### データマイグレーション（P-9-6）
- [s] `DataMigrationService.migrateIfNeeded()` が `ADHDAlarmApp.init()` の最初に呼ばれること
  注: 現行実装では `ADHDAlarmApp.init()` ではなく `AppDelegate.didFinishLaunchingWithOptions` の先頭付近で呼ばれている
- [x] `dataModelVersion` が UserDefaults に保存・比較されること
- [x] v1→v2マイグレーションで `eventEmoji == nil` が `"📌"` に補完されること
- [r] 既存データが破壊されずアップデート後も正常動作すること（実機確認必須）

#### CallKit アラーム競合対応（P-9-7）
- [r] 通話中に RingingView が起動した場合、ふくろうトーストが表示されること
- [s] `CXCallObserverDelegate` で通話終了を検知していること
- [s] 通話終了後に `recoverStaleAlarmState()` が呼ばれること
  注: 現行コードベースでは `CXCallObserverDelegate` / `recoverStaleAlarmState()` の実装をまだ確認できていない

#### マナーモード判定の注記（P-9-8）
- [x] `outputVolume` によるマナーモード判定コードに⚠️警告コメントが記載されていること
- [x] 「この検知は不確実であり AlarmKit の動作には影響しない」旨がコメントに含まれること

#### App Group Race Condition 防止（P-9-9）
- [x] Widget Extension が App Group UserDefaults に書き込む箇所が0件であること
- [x] `CompleteAlarmIntent` が App Group UserDefaults に直接書き込まないこと
- [x] XP の加算処理がメインアプリプロセスのみで行われること

#### 「今日」の日付境界定義（P-9-10）
- [x] `isToday()` の判定が `Calendar.current.isDateInToday(date)` で実装されていること
- [x] UTC変換していないこと（端末ローカルタイムゾーン基準）
- [s] 無料/PRO境界の判定ロジックに `isToday` / `within7Days` / `olderThan7Days` の3分岐があること

#### Android 対応方針の明記（P-9-11）
- [s] FamilyPairingOnboardingView に「現在iPhoneのみ対応」の注記が表示されること
- [s] 招待リンク生成時に「iPhoneをお使いの方のみ」のガイドが表示されること

#### ミニタスクの家族同期除外（P-9-12）
- 現仕様ではデイリーミニタスクは `AlarmEvent` 化せず、`UserDefaults` で1日1回状態のみ管理するためこのセクションは対象外

#### DismissSheet UX 改善（P-9-13）
- [s] DismissSheet が3秒後（または「閉じる」タップ）で即座に閉じること（10秒ブロックしないこと）
- [s] PersonHomeView の EventRow 上部に「↩ 取り消す（○秒）」リンクが30秒間表示されること
  注: 現行実装は EventRow 上部リンクではなく、下部バナーの「もとに戻す」導線で Undo を提供している
- [2] 30秒後に Supabase PATCH が確定し XP が確定付与されること
- [s] `undoDeadline` タイマーがバックグラウンドでも継続することを確認すること

#### ToDo 翌日持ち越しルール（P-9-14）
- [x] `isToDo == true` かつ `completionStatus == nil` の予定が翌日に持ち越されること
- [s] 持ち越し予定に `isCarriedOver == true` フラグがセットされること
- [x] EventRow に「🔁 昨日から」バッジが表示されること
- [x] `isToDo == true` かつ `completionStatus == .complete` の予定が日付変更時に削除されること

#### スヌーズ上限 UI（P-9-15）
- [x] AlarmEvent に `snoozeCount: Int` フィールドがあること
- [x] スヌーズ3回目のボタンラベルが「⏱️ 30分後にまた教えて（最後の1回）」に変わること
- [x] スヌーズ上限到達後: ボタン非表示ではなく「🦉 何度もお知らせしたよ」メッセージが表示されること
- [x] スヌーズ上限到達後: 「今回はパス」ボタンへの矢印が表示されること

---

### データ同期・競合防止（追加項目）
- [s] scenePhase == .active 時: `OfflineActionQueue.shared.flush()` が `await` で完全終了してから `SyncEngine.performFullSync()` が開始されること
- [s] オフライン中に complete 操作がキューに積まれた状態でフル同期を走らせても、ローカルの完了状態が上書きされないこと

### CallKit・通話中の挙動（追加項目）
- [r] 通話中（hasActiveCall == true）: `playNarration()`（AVSpeechSynthesizer）が呼ばれないこと
- [r] 通話中: ふくろうトーストと Haptic（.warning）のみで代替通知されること
- [r] 通話中: AlarmKit のOSアラーム音は継続して鳴ること（TTSのみスキップ）

### MagicDemo・フォアグラウンド通知（追加項目）
- [x] `AppDelegate` で `UNUserNotificationCenter.current().delegate` に `ForegroundNotificationDelegate.shared` が設定されること
- [x] フォアグラウンド中にデモのローカル通知が届いた際、`.banner, .sound, .list` が返されバナーが表示されること
- [r] AlarmKit の3秒後発火デモが実機で成立しない場合、AVAudioPlayer フォールバックに切り替わること（実機確認必須）

---

## ■ 実機テスト専用チェックリスト

> ⚠️ このセクションの全項目はシミュレーターで検証不可。必ずiPhone実機で確認すること。
> 「📱×2」表記の項目は**2台のiPhone**が必要。

---

### 🔔 AlarmKit（シミュレーター完全非対応）

- [r] アラーム発火: Stage 1 のOSアラーム画面タイトルが「🦉 ふくろうからのお知らせ」と表示されること
- [r] アラーム発火: Stage 2 の RingingView が Stage 1 の後に自動表示されること
- [x] マナーモード: マナーモードONの状態でアラームが鳴ること（AlarmKit の核心機能）
- [x] MagicDemo: デモボタンタップから3秒後にAlarmKitアラームが発火すること
- [x] MagicDemo: マナーモードONの状態でデモアラームが鳴ること
- [x] MagicDemo → RingingView: デモアラーム停止後、RingingView が表示されること
- [r] スワイプキル後リカバリ: アプリをスワイプキルして再起動後、zombie alerting（15分以内）を検知してRingingViewが表示されること
- [r] スワイプキル後リカバリ（15分超過）: zombie alertingが15分超過の場合 RingingView が表示されないこと
- [r] スヌーズ再登録: スヌーズタップ後、AlarmKit に now+30min で再登録されていること（設定アプリ→アラームで確認）
- [r] スヌーズ上限: 同一予定のスヌーズが3回に達したらスヌーズボタンが非表示になること
- [r] AVAudioPlayer フォールバック: AlarmKit 発火前に `AVAudioPlayer` でナレーションが再生されること（RingingView 表示後）

---

### 📳 Haptics（振動・実機必須）

- [r] MagicDemoView（Hapticデモ）: 「鳴らしてみる！」タップから3秒後に `.heavy` 振動が3回発生すること
- [x] MagicDemoWarningView: 「鳴らしてみる！」タップ直後に `.impact(.medium)` Haptic が鳴ること
- [r] RingingView 完了: 完了ボタンタップ直後（確定時）に `.success` Haptic が鳴ること
- [r] RingingView スライド: ドラッグ開始時に `.selection` 、完了確定時に `.success` の順で鳴ること
- [r] Hapticデモ確認テキスト: 振動後に「振動で感じられましたか？」と「わかった！」ボタンが表示されること

---

### 🔊 オーディオ・音声（スピーカー・イヤホン確認）

- [r] アテンション音: ナレーション再生前にシステム音1057が鳴ること
- [r] 再生順序: アテンション音 → 1秒無音 → ナレーション の順序が守られていること
- [r] TTS マナーモード: マナーモードON状態でふくろうのナレーションが聞こえること（`.playback` + `.voicePrompt` セッション）
- [r] クリアボイスモード: 設定でONにすると `rate=0.40`、`pitchMultiplier=0.80` で読み上げられること（速度・音程が変わること）
- [r] イヤホン抜け: イヤホンを抜いた瞬間に `AVAudioPlayer` が停止 + `AlarmManager.cancel()` が呼ばれること
- [r] イヤホン抜け: イヤホン抜け後も RingingView が閉じずに表示されたままであること
- [r] 通話中 TTS スキップ: 通話中は `AVSpeechSynthesizer` が呼ばれず、Haptic（.warning）のみで代替されること
- [r] 通話中 AlarmKit 継続: 通話中でも AlarmKit の OS アラーム音は継続して鳴ること

---

### 🎤 マイク・音声認識（実機推奨）

- [r] リアルタイム文字起こし: 録音開始後、話した言葉がリアルタイムで画面に表示されること
- [r] 文字起こし完了: 認識完了後にテキストが確定し、予定タイトルフィールドに自動入力されること
- [r] 無音タイムアウト: 5秒間無音のとき「声が届きませんでした」エラーが表示されること
- [r] 認識失敗: 認識結果が空のとき「うまく聞き取れませんでした」が表示されること
- [r] オフライン認識: 機内モード状態でも音声認識が動作すること（`requiresOnDeviceRecognition = true`）

---

### 📨 Push通知・Supabase連携（APNs実機必須）

- [2] スキップ通知: 予定をスキップしてUndoせず10秒待つと、家族端末に Push 通知が届くこと 📱×2
- [2] 完了はサイレント: 予定を完了しても家族端末に Push 通知が届かないこと（サイレント更新のみ）📱×2
- [2] Undo → 通知キャンセル: スキップ後すぐ「取り消す」をタップすると Push 通知が届かないこと 📱×2
- [2] バッチ通知: 30分以内に複数スキップすると1通にまとめられた Push 通知が届くこと 📱×2
- [2] missed 通知なし: TTL判定で `.missed` になった予定は家族への Push 通知が送られないこと
- [2] 連携解除通知: 「連携を解除する」確定後、相手の端末に解除 Push 通知が届くこと 📱×2
- [2] Undo中クラッシュ保護: Undo猶予中（30秒以内）にアプリをクラッシュ→再起動すると、完了状態が Supabase に送信されること

---

### 🔗 ペアリング（2台のiPhone必須）

- [2] Universal Link: 家族にLINEで送ったリンクをタップすると自動ペアリング画面が開くこと 📱×2
- [2] Universal Link失敗時: Universal Link が開けない場合、6桁コード入力UIに自動フォールバックすること 📱×2
- [2] 6桁コード: 当事者側の6桁コードを家族側で入力するとペアリングが完了すること 📱×2
- [2] 同意確認画面: ペアリング承認前に「できること / できないこと」を明示した同意確認画面が表示されること 📱×2
- [2] 「今はやめておく」: 同意確認画面で拒否すると `family_links` にレコードが作られないこと 📱×2
- [2] ペアリング完了→ペイウォール: ペアリング完了直後にペイウォールが表示されること 📱×2
- [2] RLS拒否: ペアリングしていない他人の予定を Supabase に INSERT しようとすると拒否されること（Supabase ダッシュボードで確認）
- [2] Last Seen: 当事者がアプリを開くと家族のタブに Last Seen が更新されること（🟢1h以内 / 🟡1-6h / 🔴6h以上）📱×2
- [2] 家族キャンセル検知: 親の Last Seen が古い状態（6h以上）で家族が予定をキャンセルすると「電波が届いていない」警告が表示されること

---

### 💳 StoreKit Sandbox（Sandbox購入フロー）

- [2] PRO購入: Sandbox アカウントで月額/年額/買い切りの購入フローが完了すること
- [s] 購入後: `subscriptionTier == .pro` になり、PRO機能（カレンダー選択・複数事前通知等）が解放されること
- [s] 「あとで」: ペイウォールで「あとで」をタップしてもアプリが継続使用できること
- [s] 無料→PRO: 無料版でロック機能（履歴・SOS）にタップするとペイウォールが出ること
- [2] レビュー依頼タイミング: 完了10回到達後、または家族に初回✓✓が届いた後にのみレビューダイアログが出ること
- [s] レビュー依頼ブロック: 起動直後・エラー後・スキップ後・ペイウォール表示直後にレビューダイアログが出ないこと

---

### 🔲 ウィジェット（ホーム画面・実機必須）

> **[v2変更]** Small Widget の完了ボタンを廃止。ウィジェットはカウントダウン表示専用とし、完了操作はアプリ本体（長押し/スワイプ）で行う。

- [r] Small Widget: ホーム画面でカウントダウン数字 + 次の予定タイトルが表示されること（文字切れしないこと）
- [r] Small Widget: 完了ボタンが**表示されないこと**（廃止）
- [x] ロック画面 Widget: アイコン + 数字のみが表示されること
- ~~インタラクティブ: Small Widget 下部の「✓ 完了にする」をタップすると `completionStatus = .completed` が記録されること~~ → **v2廃止（完了ボタン廃止）**
- インタラクティブ完了後: ウィジェットの表示が「✓ 済み」に切り替わること
- [r] `owlName` 埋め込み: ウィジェットに「○○が待ってるよ」のように `owlName` が表示されること
- [r] App Group: ウィジェットが `AlarmEventStore().loadAll()` でメインアプリと同じデータを読めていること（予定追加後にウィジェットが更新されること）
- [r] タイムライン更新: 予定追加・完了・削除後にウィジェットの表示が更新されること

---

### ♿ アクセシビリティ（実機設定変更が必要）

- [r] 文字サイズ最大（accessibility3以上）: RingingView の円形カウントダウンが非表示になり、巨大数字テキストのみ表示されること
- [x] 文字サイズ最大: EventRow のレイアウトが崩れず、最低1件は表示されること
- [r] 省エネモード（低電力モード）: 花火・星パーティクルアニメーションがスキップされること（設定→バッテリー→低電力モードをON）
- [r] 視差効果を減らす（Reduce Motion ON）: 花火・星パーティクルが表示されないこと
- [r] 視差効果を減らす（Reduce Motion ON）: EventRow の折りたたみアニメが `.opacity` のみになること（`.move` なし）
- [r] 視差効果を減らす（Reduce Motion ON）: マイク波形アニメが停止し赤マイクアイコン+「録音中...」になること
- [r] バッテリー10%未満: 2時間以内のアラームがある場合、低バッテリー警告トーストが表示されること

---

### 🗑️ アカウント削除・データ保全（Supabase連携・実機必須）

> **実装方針**: クライアントから直接 `auth.admin.deleteUser` は呼べないため、Supabase Edge Function `delete-account` 経由で削除する。
> - Edge Function が JWT を受け取り → family_links 無効化 → remote_events 削除 → devices 削除 → Auth ユーザー削除 の順で実行
> - ローカルの AlarmEvent データ（iPhoneのカレンダー連携）は削除しない

- [2] アカウント削除: 詳細設定→「アカウントを削除する」→確認ダイアログ→確定すると Supabase の全ユーザーデータが削除されること
- [2] アカウント削除: family_links が is_active = false になること（相手側に解除が伝わること）
- [2] アカウント削除: remote_events / devices レコードが削除されること
- [2] アカウント削除: Supabase Auth ユーザーが削除されること（Edge Function経由）
- [s] アカウント削除: 完了後に `appState.familyLinkId = nil` がセットされること
- [s] アカウント削除: ローカルの予定データ（AlarmEventStore）は保持されること
- [s] アカウント削除: 削除中に `ProgressView + 「削除中...」` オーバーレイが表示され、途中でシートを閉じられないこと
- [s] アカウント削除: 完了後にオンボーディング画面（ModeSelectionView）に遷移すること
- [2] アカウント削除: Supabase失敗時にエラーが表示され、ローカルデータが保持されること（再試行可能）
- [r] データマイグレーション: v1 からのアップデート後に既存の予定データが消えずに表示されること
- [r] CalllKit 競合: 通話中にアラームが発火した場合、通話終了後に `recoverStaleAlarmState()` が呼ばれてアラームが再評価されること

---

> **テスト実行推奨端末**: iPhone（実機）2台
> **テスト環境**: 本番ビルド + TestFlight（Sandboxアカウント用意）
> **優先順位**: AlarmKit → Push通知 → ペアリング → StoreKit → その他

### 家族送信予定のTTL（追加項目）
- [2] `pending` 状態のまま `startDate + 1時間` を経過した予定が `expired` に遷移すること
- [2] 家族 Tab 0 の `expired` 予定に「⚠️ お母さんの端末に届きませんでした」が表示されること
- [2] 親がオンラインになっても `expired` 予定が EventKit に登録されないこと
- [2] `expired` のまま翌日になった予定がリストから削除されること

### ディープリンク画面遷移（追加項目）
- [2] Push通知タップ時: 表示中のすべてのシートが dismiss されること
- [2] Push通知タップ時: NavigationPath が `removeAll()` でリセットされること
- [2] `removeAll()` 後、1フレーム（約16ms）待機してから遷移先が `append` されること
- [2] 設定画面を開いた状態でPush通知をタップしても操作不能にならないこと

### 新規オンボーディング画面（追加項目）
- [s] PersonWelcomeView: ふくろうの羽ばたきアニメーションが表示されること
- [s] PersonWelcomeView: [はじめる] ボタン以外のUI要素がないこと
- [s] NotificationAuthView・CalendarAuthView: 権限ごとに独立した1画面として表示されること
- [s] FamilyPainQuestionView: 1つ以上選択するまで [次へ] が非活性であること
- [s] FamilySolutionView: FamilyPainQuestionView の回答内容に応じてメリットテキストが出し分けられること
- [s] FamilyPairingIntroView: ❌マークが1箇所も使われていないこと（🛡️マークで代替）
- [2] FamilyPairingActiveView: ペアリング成功後 FamilyPaywallView に自動遷移すること

### AlarmDetailView（追加項目）
- [2] Push通知タップ（ディープリンク）で AlarmDetailView が表示されること
- [s] completionStatus に応じてバッジ（✅緑 / ❌グレー / ⏰オレンジ / 🔔青）が正しく表示されること
- [s] 登録者が自分でない場合、「✏️ 予定を編集する」ボタンが非表示であること
- [s] 「この予定を削除する」タップで ActionSheet の2段階確認が表示されること

### EditEventView（追加項目）
- [s] EditEventView が PersonManualInputView と同じコンポーネントを再利用していること（新規フォームが別途作られていないこと）
- [s] 既存イベントのタイトル・日時・繰り返し設定が初期値として表示されること
- [r] 「保存する」タップで AlarmKit + EventKit の両方が更新されること

### WidgetGuideView（追加項目）
- [x] `TabView(selection:)` を使ったカルーセル（スワイプ式）UIであること
- [x] ページ数が4ページであること（長押し / + ボタン / アプリ選択 / 配置完了）
- [x] 各ページに画像プレースホルダー枠と1行のみのテキストが表示されること
- [x] ページインジケーターが表示されること
- [x] 「あとでやる」でスキップ可能なこと
- [s] 設定画面から再閲覧できること

### デイリーミニタスク状態遷移（追加項目）
- [s] タップ後: `.owlBounce` アニメーションが再生されること
- [s] アニメーション後: ボタンのテキストが「✅ できた！（+5XP）」に変化すること
- [s] タップ後: ボタンが `disabled` になり再タップできないこと
- [s] 画面全体のリロード・チラつきが発生しないこと（ボタン状態の変化のみ）
- [x] 1日1回の制限が機能すること（翌日リセット）

### 実機テスト環境定義（QA必須要件）

**必須確認機種（最低限）:**
| 機種 | OS | 確認項目 |
|------|----|---------|
| iPhone 15 以降 | iOS 26.0 | AlarmKit動作確認（メイン検証機） |
| iPhone SE 第3世代 | iOS 26.0 | 小画面レイアウト崩れ確認 |
| iPhone 16 Pro | iOS 26.2+ | Dynamic Island・AlarmKit最新動作 |

**確認OS範囲:** iOS 26.0 以上（AlarmKit最低要件）

**リグレッションテスト方針:**
- iOS マイナーバージョンアップ（例: 26.0→26.1）後: AlarmKit動作・マナーモード貫通を最優先で再確認
- Xcode ベータ更新後: strict concurrency のビルドエラーが新たに発生していないか確認
- リリース前: 上記3機種全てで06_Checklistの「アラーム停止」「MagicDemo」セクションを通し確認

### @Observable 並行性（追加項目）
- [x] SyncEngine が `actor` として定義されていること（`class` ではないこと）
- [s] @Observable ViewModel のプロパティ更新が MainActor 上で行われていること
  注記: 現行コードは `@MainActor` 付きViewModelと非付与ViewModelが混在しているため、この文言のままでは一律に `x` 判定しない
- [x] バックグラウンドからUIへの反映で `await MainActor.run { }` が使われていること
- [s] Xcode の strict concurrency チェックでエラー・警告がゼロであること
  注記: 現在の `xcodebuild` では strict concurrency 関連 warning が残っているため、未達として保留

### Anonymous認証昇格（追加項目）
- [s] 匿名ユーザーが Apple ID と連携できる「Apple IDと連携する」ボタンが設定画面に表示されること（匿名ユーザーのみ）
- [2] 連携後: 匿名user_idのSupabaseデータが新user_idに移行されること
- [2] 連携後: 旧匿名セッションのデータが孤児にならないこと（Edge Functionで移行確認）

### TestFlight ベータ配布計画

**外部テスター配布の目標:**
- Phase 5（オンボーディング）完了後に TestFlight 外部テスト開始
- 目標テスター数: 10名（内訳: ADHD当事者3名・高齢者親を持つ家族3名・一般ユーザー4名）
- テスト期間: 最低2週間（実際の薬/予定アラームを日常使いしてもらう）

**リリース判定基準:**
| 指標 | 合格ライン |
|------|----------|
| クラッシュ率 | 1,000セッションあたり1件未満 |
| AlarmKit 発火成功率（実機） | 100%（1件の失敗もNG） |
| MagicDemo完了率（テスター） | 70%以上 |
| テスター満足度（1〜5点） | 平均4.0以上 |

**TestFlight チェックリスト:**
- [2] App Store Connect で TestFlight 外部テストグループ作成済みであること
- [r] テスター向け「テスト手順書」（日本語）を配布していること（AlarmKit実機確認手順含む）
- [s] クラッシュレポートを Xcode Organizer で確認していること
- [r] テスター10名以上から「AlarmKitが実際に鳴った」フィードバックを収集していること
- [s] フィードバックで指摘された文言・UIの修正が完了していること

### リファラル機能（追加項目）
- [2] `profiles.referral_code` が全ユーザーで6文字英数字で自動生成されていること
- [2] Universal Link（`/invite?ref=XXXX`）でアプリを開いた場合、referral_codeが UserDefaults に保存されること
- [2] アカウント作成後、`applyPendingReferralIfNeeded()` が呼ばれ、`profiles.referred_by` に記録されること
- [2] referral_events テーブルに `installed` イベントが記録されること
- [2] ペアリング成功画面に「他のご兄弟・ご家族にも紹介する」ボタンが表示されること
- [2] referral_sent イベントが Firebase に送信されること

---
