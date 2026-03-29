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

    override var canBecomeFirstResponder: Bool { true }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        becomeFirstResponder()
    }

    override func motionBegan(_ motion: UIEvent.EventSubtype, with event: UIEvent?) {
        if motion == .motionShake {
            action?()
        }
    }
}
