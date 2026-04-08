# Phase V16-1：UIWindowレベル Toast システム（P-7-1）

## 担当: Claude
## 難易度: 中（UIKit + SwiftUI 混在・アーキテクチャ変更）

---

## 概要
現在 Toast は各View の `.overlay` や `AppState.globalToast`（ADHDAlarmApp の `.overlay(alignment: .top)`) で表示している。
`.fullScreenCover` (RingingView) が表示中は、その裏側に Toast が隠れてしまう問題がある。
`ToastWindowManager` を作成し、UIWindowの最前面に Toast をオーバーレイすることで、
どの画面・シートが表示されていても Toast が見えるようにする。

---

## 現状の Toast 表示箇所（全て移行対象）

| 箇所 | 現状の実装 | 移行方法 |
|------|----------|--------|
| `ADHDAlarmApp.swift` L214 | `appState.globalToast` を `.overlay(alignment: .top)` で表示 | `ToastWindowManager.show()` に移行し、overlay 削除 |
| `PersonHomeView.swift` L52 | `viewModel.confirmationMessage` を `.overlay` で表示 | `ToastWindowManager.show()` を呼ぶ |
| `PersonHomeViewModel.swift` L64 | `showShakeToast` / `shakeMessage` 状態変数 | `ToastWindowManager.show()` で代替 |

---

## ToastMessage モデル（新規作成）

仕様書 01_Screen_Flow.md 15-6 より:

```swift
// ADHDAlarm/Models/ToastMessage.swift
import Foundation

struct ToastMessage: Identifiable {
    let id = UUID()
    let text: String
    let style: ToastStyle
}

enum ToastStyle {
    case owlTip   // 画面下部・3秒・.regularMaterial背景
    case error    // 画面上部・3秒・.statusDanger背景
    case success  // 画面下部・2秒・.statusSuccess背景
}
```

---

## ToastWindowManager（新規作成）

```swift
// ADHDAlarm/Services/ToastWindowManager.swift
import UIKit
import SwiftUI

@MainActor
final class ToastWindowManager {
    static let shared = ToastWindowManager()
    private var toastWindow: UIWindow?

    func show(_ toast: ToastMessage) {
        // 既存の Toast Window があれば閉じる（同時1件制限）
        dismiss()
        
        // 最前面のWindowSceneを取得
        guard let scene = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first(where: { $0.activationState == .foregroundActive }) else { return }
        
        let window = UIWindow(windowScene: scene)
        window.windowLevel = .alert + 1  // アラートよりも前面
        window.backgroundColor = .clear
        window.isUserInteractionEnabled = false
        
        let toastView = UIHostingController(rootView: ToastBannerView(message: toast))
        toastView.view.backgroundColor = .clear
        window.rootViewController = toastView
        window.makeKeyAndVisible()
        toastWindow = window
        
        // 自動閉じ
        let duration: Double = toast.style == .owlTip ? 3.0 : (toast.style == .error ? 3.0 : 2.0)
        Task {
            try? await Task.sleep(for: .seconds(duration))
            dismiss()
        }
    }
    
    func dismiss() {
        toastWindow?.isHidden = true
        toastWindow = nil
    }
}
```

---

## ToastBannerView（新規作成）

```swift
// ADHDAlarm/Views/Shared/ToastBannerView.swift
import SwiftUI

struct ToastBannerView: View {
    let message: ToastMessage
    @State private var appeared = false

    var body: some View {
        VStack {
            if message.style == .error {
                // 画面上部から降りてくる
                toastContent
                    .transition(.move(edge: .top).combined(with: .opacity))
                Spacer()
            } else {
                // 画面下部から上がってくる（FABの上）
                Spacer()
                toastContent
                    .padding(.bottom, ComponentSize.fab + Spacing.md)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .padding(.horizontal, Spacing.md)
        .opacity(appeared ? 1 : 0)
        .onAppear {
            withAnimation(.spring(response: 0.4)) { appeared = true }
        }
    }

    private var toastContent: some View {
        Text(message.style == .owlTip ? "🦉 \(message.text)" : message.text)
            .font(.callout.weight(.medium))
            .foregroundStyle(message.style == .owlTip ? .primary : .white)
            .padding(.horizontal, Spacing.md)
            .padding(.vertical, Spacing.sm)
            .background(toastBackground)
            .clipShape(RoundedRectangle(cornerRadius: CornerRadius.md))
            .shadow(color: .black.opacity(0.12), radius: 8, y: 4)
    }

    @ViewBuilder
    private var toastBackground: some View {
        switch message.style {
        case .owlTip:     Color.clear.background(.regularMaterial)
        case .error:      Color.statusDanger
        case .success:    Color.statusSuccess
        }
    }
}
```

---

## 既存コードの移行

### ADHDAlarmApp.swift
削除: `appState.globalToast` の `.overlay` ブロック（L213〜L233）
代替: 各呼び出し箇所で `ToastWindowManager.shared.show(ToastMessage(text: ..., style: .error))` を呼ぶ

### PersonHomeView.swift
削除: `viewModel.confirmationMessage` の `.overlay` ブロック
ViewModel側で `ToastWindowManager.shared.show(ToastMessage(text: msg, style: .owlTip))` を呼ぶように変更

### PersonHomeViewModel.swift
削除: `showShakeToast` / `shakeMessage` 状態変数
代替: シェイク時に `ToastWindowManager.shared.show(ToastMessage(text: msg, style: .owlTip))` を直接呼ぶ

---

## 注意事項

- `ToastWindowManager` は UIKit 依存のため `@MainActor` 必須
- `window.windowLevel = .alert + 1` で RingingView (.fullScreenCover) の上にも表示できる
- `isUserInteractionEnabled = false` にしてToast表示中も背景操作を妨げない
- `AppState.globalToast: String?` プロパティは削除してよい（移行後は不要）

---

## 完成確認

- [ ] RingingView（フルスクリーン）表示中にもToastが見える
- [ ] PersonHomeView でのふくろうタップ反応Toast が正常表示される
- [ ] シェイクToastが正常表示される
- [ ] バッテリー警告Toast が正常表示される
- [ ] Toast が3秒後に自動消去される
- [ ] 既存の `.overlay` ベースToastコードが残っていない
- [ ] ビルドエラーゼロ
