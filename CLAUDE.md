# 忘れ坊アラーム 開発ガイド

## 技術スタック
- iOS 26.2+ / Xcode 26.3 / Swift 5.0（厳格並行性: `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`）
- AlarmKit（iOS 26専用・マナーモード貫通）/ EventKit / AVFoundation / Speech
- StoreKit 2 / WidgetKit / SwiftUI

## アーキテクチャの鉄則
- **EventKit が主（データの真実源）、AlarmKit が従（通知手段）**
- **Write-Throughのみ**：入力はアプリ内マイクから、外部カレンダーからの吸い込み（双方向同期）は禁止
  - **例外（手動インポート）**：PRO機能「カレンダーから取り込む」は自動同期ではなくユーザーが明示的に選択して実行する一回限りの取り込みであり、禁止事項の対象外とする
- **アプリ起動時に強制フル同期**（`scenePhase == .active`でSyncEngine.performFullSync()を必ず呼ぶ）
- **Protocol指向**：CalendarProviding / AlarmScheduling / VoiceSynthesizing / NLParsing の4プロトコルを介してアクセスする。Serviceクラスを直接参照しない

## ディレクトリ構成
```
ADHDAlarm/
├── App/            AppState, AppRouter, Constants
├── Models/         AlarmEvent（コアモデル）, ParsedInput, SyncDiff, SubscriptionTier
├── Protocols/      4つのプロトコル定義
├── Services/       プロトコルの実装クラス（Phase毎に本実装）
├── ViewModels/     @Observable VM（各View対応）
├── Views/          Onboarding/ Dashboard/ Input/ Alarm/ Settings/ Paywall/ Shared/
└── Extensions/     Date+Formatting, Color+Theme
```

## 実装フェーズ（進捗）
詳細計画: `~/.claude/plans/mutable-moseying-manatee.md`

| Phase | 内容 | 状態 |
|-------|------|------|
| 0 | プロジェクト骨格・Protocol・モデル | ✅ 完了 |
| 1 | AlarmKit本実装・音声ファイル生成・RingingView | 🔄 進行中 |
| 2 | EventKit Write-Through・PermissionsService | ⏳ 待機 |
| 3 | SyncEngine（差分同期） | ⏳ 待機 |
| 4 | NLParser・音声認識・マイク入力UI | ⏳ 待機 |
| 5 | ダッシュボード・オンボーディング | ⏳ 待機 |
| 6 | WidgetKit拡張 | ⏳ 待機 |
| 7 | StoreKit 2・PRO機能ゲート | ⏳ 待機 |
| 8 | 設定・仕上げ・テスト | ⏳ 待機 |

## コーディングルール
- **コメントは日本語**で書く
- **IT用語禁止**（例: 同期→「読み込む」、デフォルト→「いつもの設定」、プッシュ通知→「お知らせ」）
- **タップターゲット最低60pt**（高齢者対応）、スワイプには必ずタップ代替ボタンを用意
- ポジティブなエラーメッセージ（「遅刻です！」→「少し過ぎてしまいましたが、慌てずに向かいましょう！」）
- `@Observable`を使う（`ObservableObject`は使わない）
- `async/await`を使う（Completion handlerは使わない）

## AlarmKit 重要注意事項
- AlarmKitはシミュレータ非対応、**実機テスト必須**
- カスタム.cafをAlarmKitに渡す方法は未確定（Phase 1で検証）
  - フォールバック1: AlarmPresentation.Alert のテキスト読み上げ使用
  - フォールバック2: アプリ内RingingViewでAVAudioPlayer再生
- AlarmKit.listAll() APIの存在は未確認。ローカルJSONマッピングを正とする

## EventKitマーカー
アプリ作成イベントの識別に`Constants.eventMarker(for:)`を使う。
EKEvent.notesに`<!-- wasure-bou:{UUID} -->`を埋め込むことで同期対象を限定し、他カレンダーのノイズを完全排除する。

## 音声ファイル管理
- 格納先: `Library/Sounds/WasurebuAlarms/{alarmID}.caf`
- アラーム削除時は.cafも必ず削除する（VoiceFileGenerator.deleteAudio）
- テンプレート: 「お時間です。あと{X}分で{タイトル}のご予定ですよ。」

## ビジネスモデル
- **無料版**: マナーモード貫通アラーム（回数無制限）・デフォルトカレンダー固定・事前通知1回
- **PRO版**: カレンダー選択・事前通知複数回・全テーマ・全音声キャラ
- **鉄則**: コア機能（アラームが鳴る）は絶対に課金壁にしない
