# Phase: フクロウ成長アセット追加

## 担当: 手動作業のみ（Codexもコード変更も不要）
## 難易度: なし（画像追加のみ）

---

## 重要：コードはすでに完成している

`PersonHomeViewModel.owlImageName`（line 478〜484）と
`PersonHomeView.owlImage`（line 263〜266）は**すでに実装済み**。
XPに応じた画像名の返却・フォールバック（OwlIcon）も実装済み。

**必要な作業は画像ファイルをAssets.xcassetsに追加するだけ。**

---

## XPとステージの対応

| ステージ | 必要XP | アセット名 |
|---------|--------|----------|
| 0 | 0〜99 | `owl_stage0` |
| 1 | 100〜499 | `owl_stage1` |
| 2 | 500〜999 | `owl_stage2` |
| 3 | 1000以上 | `owl_stage3` |

---

## 手順

1. Xcodeで `ADHDAlarm/Assets.xcassets` を開く
2. 空き領域を右クリック → **「New Image Set」** を4回繰り返す
3. 各Image Setの名前を以下の通り設定（大文字・小文字・アンダースコアを正確に）：
   - `owl_stage0`
   - `owl_stage1`
   - `owl_stage2`
   - `owl_stage3`
4. 各Image Setに対応する画像ファイルをドラッグ＆ドロップ（1x / 2x / 3x に対応したサイズを用意）
5. ビルドして PersonHomeView でふくろうが正しいステージの画像で表示されることを確認

---

## 確認方法

1. デバッグで `appState.owlXP` を手動で 0 / 100 / 500 / 1000 に設定
2. PersonHomeView のふくろうアイコンが owl_stage0〜3 で切り替わることを確認
3. アセットが存在しない場合のフォールバック（OwlIcon）が動作することも確認
