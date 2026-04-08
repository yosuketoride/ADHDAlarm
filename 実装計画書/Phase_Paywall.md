# Phase: PaywallView 全面書き換え

## 担当: Claude
## 難易度: 中（UI書き換え・StoreKit連携は既存を使用）

---

## 概要
既存の `PaywallView.swift`（約605行・v1デザイン）を v2 デザイントークンで全面書き換え。
**課金ロジック（StoreKit）は変更しない。UIのみ書き換え。**

---

## 前提確認（変更前に必ずファイルを読む）

- `ADHDAlarm/Views/Paywall/PaywallView.swift` — 現在のUIを把握する
- `ADHDAlarm/ViewModels/PaywallViewModel.swift` — 利用可能なプロパティ・メソッドを確認する
- `ADHDAlarm/Services/StoreKitService.swift` — 課金フローを変更しないため参照のみ

---

## v2 UIレイアウト仕様

### 全体構造
```
NavigationStack または VStack (ScrollView)
  ├─ 閉じるボタン（右上 .xmark、skipで戻る想定）
  ├─ ヒーロービジュアル
  │   ├─ ふくろう画像（OwlIcon・120pt）
  │   └─ 「7日間無料でお試しできます」バッジ（.owlAmber 背景・pill形状）
  ├─ タイトル「もっと便利に、もっと安心に」（.title2.bold）
  ├─ 機能比較テーブル
  ├─ 価格カード（月額 / 年額）
  ├─ 購入ボタン（ComponentSize.primary・.owlAmber）
  ├─ 「すでに購入済みの方はこちら」（リストア）
  └─ フッター（利用規約・プライバシーポリシー）
```

---

## 機能比較テーブル

| 機能 | 無料 | PRO |
|------|------|-----|
| マナーモード貫通アラーム | ✅ | ✅ |
| カレンダー選択 | ─ | ✅ |
| 事前通知を複数回設定 | ─ | ✅ |
| 音声キャラの切り替え | ─ | ✅ |
| 聞き取りやすいこえ | ─ | ✅ |

表示ルール:
- ✅ → `Image(systemName: "checkmark.circle.fill")` .statusSuccess色
- ─ → `Image(systemName: "minus")` .secondary色

---

## 価格カード

StoreKit 2 の `displayPrice` を必ず使う（ハードコード禁止）:

```swift
// PaywallViewModel からの取得想定
var monthlyPrice: String   // e.g. "¥880"
var yearlyPrice: String    // e.g. "¥7,800"
var yearlyMonthlyCost: String  // e.g. "月あたり¥650"
```

```
┌────────────────────────┐    ┌────────────────────────┐
│ 月額プラン              │    │ 年額プラン（おすすめ）   │
│ ¥880/月                │    │ ¥7,800/年              │
│                        │    │ 月あたり約¥650          │
│ いつでもキャンセル可     │    │ 2ヶ月分お得 ✨         │
└────────────────────────┘    └────────────────────────┘
```

---

## 購入ボタン

```swift
Button {
    Task { await viewModel.purchase(selectedPlan) }
} label: {
    Group {
        if viewModel.isPurchasing {
            ProgressView()
                .tint(.white)
        } else {
            Text("7日間無料でお試しする")
        }
    }
    .frame(maxWidth: .infinity)
    .frame(height: ComponentSize.primary)
}
.buttonStyle(.large(background: .owlAmber))
.disabled(viewModel.isPurchasing)
```

---

## デザイントークン使用ルール

**使用するトークン（マジックナンバー禁止）:**
- `Spacing.xs/sm/md/lg/xl`
- `ComponentSize.primary`（56pt）/ `.small`
- `CornerRadius.md/lg/pill`
- `Color.owlAmber` / `.statusSuccess` / `.secondary`
- `.regularMaterial`（ガラス素材）

---

## PaywallViewModel のメソッド（変更しない）

```swift
// 既存の呼び出しパターンを確認して維持する
viewModel.purchase(.monthly)    // 購入
viewModel.restore()             // 復元
viewModel.isPurchasing: Bool    // 購入中フラグ
viewModel.isPro: Bool           // PRO状態
viewModel.monthlyProduct        // StoreKit Product
viewModel.yearlyProduct         // StoreKit Product
```

---

## フッター

```swift
HStack(spacing: Spacing.md) {
    Link("利用規約", destination: URL(string: Constants.LegalURL.terms)!)
    Text("・")
    Link("プライバシー", destination: URL(string: Constants.LegalURL.privacy)!)
}
.font(.caption)
.foregroundStyle(.secondary)
```

---

## 完成確認

- [ ] ビルドエラーゼロ
- [ ] v2 デザイントークンのみ使用（マジックナンバーなし）
- [ ] 価格が StoreKit displayPrice から表示される（ハードコードなし）
- [ ] 購入フローが正常動作する（Sandbox テスト）
- [ ] 復元フローが正常動作する
- [ ] 閉じるボタンで閉じられる
- [ ] PRO 購入後に appState.subscriptionTier == .pro になる
