# Phase: フクロウ感情表現 + ウィジェット画像対応

## 担当: Claude または Codex
## 難易度: 低〜中（既存コードへの差し込みのみ・新規ロジックなし）
## 依存: Phase_OwlAssets 完了済み（owl_stage0〜3 の登録が前提）

---

## 背景と現状

### 現状
| 場所 | ふくろうの表示方法 |
|------|-----------------|
| PersonHomeView | `owl_stage0〜3` の画像アセット（XP連動、実装済み） |
| RingingView | `OwlIcon` 固定（感情なし） |
| ウィジェット Small/Medium/Large | 絵文字固定（`🦉` / `🦉💤` / `🦉👀`） |

### 用意されている画像アセット
`imageforapp/owl_stage2/` に以下が確認済み（stage0〜3 × 6感情 = 24枚想定）：

| ファイル名パターン | 感情 |
|-----------------|------|
| `owl_stageN_normal.png` | 通常 |
| `owl_stageN_happy.png` | 喜び（完了・XP獲得時） |
| `owl_stageN_worried.png` | 心配（10分以内に予定が迫っている） |
| `owl_stageN_sleepy.png` | 眠い（予定なし・深夜帯） |
| `owl_stageN_surprised.png` | 驚き（アラーム発火・RingingView） |
| `owl_stageN_sunglasses.png` | 得意顔（PRO加入・特別イベント） |

※ Nは 0〜3（ステージ番号）

---

## 感情の判定ロジック（全画面共通）

```
XP → ステージ番号 N (0〜3)
状況 → 感情 emotion

アセット名 = "owl_stage{N}_{emotion}"
フォールバック = "owl_stage{N}_normal" → "OwlIcon"
```

### ステージ判定（既存ロジック・変更なし）
| XP | N |
|----|---|
| 0〜99 | 0 |
| 100〜499 | 1 |
| 500〜999 | 2 |
| 1000以上 | 3 |

### 感情判定（新規）

| 感情 | 条件 |
|------|------|
| `surprised` | RingingView が表示中（アラーム発火時） |
| `worried` | 次の予定まで10分未満 |
| `happy` | 完了アニメーション中（`completionState == .celebrating`） |
| `sleepy` | 次の予定まで60分以上、または予定なし |
| `sunglasses` | PRO加入済み かつ 全予定完了済み（今日の締め） |
| `normal` | 上記以外 |

---

## 変更ファイル一覧

| # | ファイル | 変更内容 |
|---|---------|---------|
| 1 | `ADHDAlarm/ViewModels/PersonHomeViewModel.swift` | `owlImageName` を感情対応に拡張 |
| 2 | `ADHDAlarm/Views/Dashboard/PersonHomeView.swift` | `owlImage` の感情パラメータを渡す |
| 3 | `ADHDAlarm/Views/Alarm/RingingView.swift` | `OwlIcon` 固定 → `surprised` 感情画像に差し替え |
| 4 | `ADHDAlarmWidget/ADHDAlarmWidget.swift` | 絵文字 → 画像アセットに差し替え |

---

## 実装詳細

---

### 変更1: PersonHomeViewModel.swift

`owlImageName` プロパティ（line 495〜502）を感情対応に拡張する。
感情を引数で受け取り、アセット名を組み立てて返す。

```swift
/// XP × 感情に応じたふくろうアセット名を返す
/// アセットが存在しない場合は normal → OwlIcon の順でフォールバック
func owlImageName(emotion: String = "normal") -> String {
    let stage: Int
    switch appState?.owlXP ?? 0 {
    case 0..<100:    stage = 0
    case 100..<500:  stage = 1
    case 500..<1000: stage = 2
    default:         stage = 3
    }
    let name = "owl_stage\(stage)_\(emotion)"
    if UIImage(named: name) != nil { return name }
    // フォールバック1: normal
    let normal = "owl_stage\(stage)_normal"
    if UIImage(named: normal) != nil { return normal }
    // フォールバック2: OwlIcon
    return "OwlIcon"
}
```

既存の `var owlImageName: String` は削除してこのメソッドに統一する。

---

### 変更2: PersonHomeView.swift

`owlImage` の computed property（line 281〜）を以下のように書き換える。

感情の判定を PersonHomeView 内で行い、ViewModel に渡す。

```swift
@ViewBuilder
private var owlImage: some View {
    // 感情判定（優先順）
    let emotion: String = {
        if viewModel.completionState == .celebrating {
            return "happy"
        }
        // 次の予定までの残り時間で判定
        if let nextAlarm = viewModel.events.filter({ !$0.isToDo && $0.fireDate > Date() }).min(by: { $0.fireDate < $1.fireDate }) {
            let minutes = Int(nextAlarm.fireDate.timeIntervalSinceNow / 60)
            if minutes < 10 { return "worried" }
            if minutes > 60 { return "sleepy" }
        } else {
            return "sleepy" // 予定なし
        }
        return "normal"
    }()

    let imageName = viewModel.owlImageName(emotion: emotion)
    Image(imageName)
        .resizable()
        .renderingMode(.original)
        .scaledToFit()
}
```

---

### 変更3: RingingView.swift

`owlWithRipple` の `Image("OwlIcon")` 2か所（line 248・489）を感情 `surprised` に差し替える。

RingingView は `AppState` を `@Environment` で受け取っている（または渡されている）ので、
XPからステージ番号を計算して画像名を組み立てる。

```swift
// RingingView 内に追加するヘルパー
private func owlImageName(appState: AppState) -> String {
    let stage: Int
    switch appState.owlXP {
    case 0..<100:    stage = 0
    case 100..<500:  stage = 1
    case 500..<1000: stage = 2
    default:         stage = 3
    }
    let name = "owl_stage\(stage)_surprised"
    if UIImage(named: name) != nil { return name }
    let normal = "owl_stage\(stage)_normal"
    if UIImage(named: normal) != nil { return normal }
    return "OwlIcon"
}
```

`Image("OwlIcon")` の2か所を `Image(owlImageName(appState: appState))` に変える。

---

### 変更4: ADHDAlarmWidget.swift

#### 4-1. `getOwlEmoji()` を削除し `owlImageName()` に置き換え

```swift
/// XP × 感情に応じたふくろう画像名を返す（ウィジェット用）
/// ウィジェットは UIImage() チェックができないため、常に名前を返しSwiftUIのフォールバックに委ねる
private func owlImageName(for alarm: WidgetAlarmEvent?) -> String {
    let stage: Int
    switch owlXP {
    case 0..<100:    stage = 0
    case 100..<500:  stage = 1
    case 500..<1000: stage = 2
    default:         stage = 3
    }
    guard let alarm = alarm else {
        return "owl_stage\(stage)_sleepy"
    }
    let minutes = Int(alarm.fireDate.timeIntervalSinceNow / 60)
    let emotion: String
    if minutes < 10 {
        emotion = "worried"
    } else if minutes > 60 {
        emotion = "sleepy"
    } else {
        emotion = "normal"
    }
    return "owl_stage\(stage)_\(emotion)"
}
```

#### 4-2. `owlRoomView` の Layer 3 を絵文字 → Image に変更

```swift
// 変更前
Text(getOwlEmoji(for: alarm))
    .font(.system(size: 44))
    .offset(x: isWorried ? -8 : 0, y: 10)

// 変更後
Image(owlImageName(for: alarm))
    .resizable()
    .scaledToFit()
    .frame(width: 60, height: 60)
    .offset(x: isWorried ? -8 : 0, y: 10)
```

#### 4-3. `smallView` の絵文字も Image に変更

```swift
// 変更前
Text(getOwlEmoji(for: alarm))
    .font(.title2)

// 変更後
Image(owlImageName(for: alarm))
    .resizable()
    .scaledToFit()
    .frame(width: 28, height: 28)
```

#### 4-4. ウィジェットの Assets.xcassets について

✅ **登録済み**（スクリプトで自動生成済み）。
`ADHDAlarmWidget/Assets.xcassets` に24枚の imageset フォルダが作成されており、
Xcode が自動認識する。手動作業は不要。

---

## 画像ファイル登録チェックリスト

Assets.xcassets に追加が必要な Image Set 一覧（24枚）：

```
owl_stage0_normal   owl_stage1_normal   owl_stage2_normal   owl_stage3_normal
owl_stage0_happy    owl_stage1_happy    owl_stage2_happy    owl_stage3_happy
owl_stage0_worried  owl_stage1_worried  owl_stage2_worried  owl_stage3_worried
owl_stage0_sleepy   owl_stage1_sleepy   owl_stage2_sleepy   owl_stage3_sleepy
owl_stage0_surprised owl_stage1_surprised owl_stage2_surprised owl_stage3_surprised
owl_stage0_sunglasses owl_stage1_sunglasses owl_stage2_sunglasses owl_stage3_sunglasses
```

現状 `imageforapp/owl_stage2/` に stage2 の6種類のみ確認済み。
stage0 / 1 / 3 の画像も同様に用意してから実装を進めること。

---

## 完成確認

- [ ] PersonHomeView のふくろうが状況（完了・心配・眠い・通常）に応じた感情画像になる
- [ ] RingingView のふくろうが `surprised` 画像になる
- [ ] ウィジェット Small のふくろうアイコンが絵文字でなく画像になる
- [ ] ウィジェット Medium の owlRoomView のふくろうが画像になる
- [ ] アセットが存在しない感情の場合は normal → OwlIcon にフォールバックする
- [ ] XP が 0/100/500/1000 の各境界でステージが正しく切り替わる
- [ ] ウィジェット Extension の Target Membership に画像が含まれており、ウィジェットで表示される
