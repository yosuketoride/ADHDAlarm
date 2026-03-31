import SwiftUI

// MARK: - シェイク検知

/// デバイスを振ったことを View に通知する modifier
/// 使い方: .onShake { ... }
extension View {
    func onShake(_ action: @escaping () -> Void) -> some View {
        modifier(ShakeDetector(action: action))
    }
}

private struct ShakeDetector: ViewModifier {
    let action: () -> Void

    func body(content: Content) -> some View {
        content
            .background(ShakeDetectorRepresentable(action: action))
    }
}

/// UIKit の motionBegan をブリッジする UIView
private struct ShakeDetectorRepresentable: UIViewRepresentable {
    let action: () -> Void

    func makeUIView(context: Context) -> ShakeView {
        let view = ShakeView()
        view.action = action
        return view
    }

    func updateUIView(_ uiView: ShakeView, context: Context) {
        uiView.action = action
    }
}

final class ShakeView: UIView {
    var action: (() -> Void)?
    // レビュー指摘: becomeFirstResponder をキーボード表示中も呼び続けると
    // TextField のフォーカスを奪いキーボードが閉じるバグを引き起こす。
    // キーボード出現/消滅の通知を監視してファーストレスポンダーを一時的に解放する。
    private var keyboardObservers: [NSObjectProtocol] = []

    override var canBecomeFirstResponder: Bool { true }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        if window != nil {
            becomeFirstResponder()
            let showObs = NotificationCenter.default.addObserver(
                forName: UIResponder.keyboardWillShowNotification,
                object: nil, queue: .main
            ) { [weak self] _ in self?.resignFirstResponder() }
            let hideObs = NotificationCenter.default.addObserver(
                forName: UIResponder.keyboardWillHideNotification,
                object: nil, queue: .main
            ) { [weak self] _ in self?.becomeFirstResponder() }
            keyboardObservers = [showObs, hideObs]
        } else {
            keyboardObservers.forEach { NotificationCenter.default.removeObserver($0) }
            keyboardObservers = []
        }
    }

    override func motionBegan(_ motion: UIEvent.EventSubtype, with event: UIEvent?) {
        if motion == .motionShake {
            action?()
        }
    }
}
