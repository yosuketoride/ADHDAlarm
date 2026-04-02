import UIKit
import SwiftUI

/// UIWindowの最前面にToastを表示するマネージャー
/// .fullScreenCover（RingingView）の上にも表示できる
@MainActor
final class ToastWindowManager {
    static let shared = ToastWindowManager()
    private var toastWindow: UIWindow?
    private var currentHideTask: Task<Void, Never>?

    private init() {}

    /// Toastを表示する（同時1件制限・前のToastがあれば即座に切り替え）
    func show(_ toast: ToastMessage) {
        // 前のToastを消す
        currentHideTask?.cancel()
        dismissWindow()

        guard let scene = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first(where: { $0.activationState == .foregroundActive })
        else { return }

        let window = UIWindow(windowScene: scene)
        window.windowLevel = .alert + 1
        window.backgroundColor = .clear
        window.isUserInteractionEnabled = toast.style != .owlTip  // エラー/成功はタップで消せる

        let host = UIHostingController(rootView: ToastBannerView(message: toast))
        host.view.backgroundColor = .clear
        window.rootViewController = host
        window.makeKeyAndVisible()
        toastWindow = window

        let duration: Double
        switch toast.style {
        case .owlTip:  duration = 3.0
        case .error:   duration = 3.0
        case .success: duration = 2.0
        }

        currentHideTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(duration))
            guard !Task.isCancelled else { return }
            await MainActor.run { self?.dismissWindow() }
        }
    }

    /// 現在表示中のToastを即座に消す
    func dismiss() {
        currentHideTask?.cancel()
        currentHideTask = nil
        dismissWindow()
    }

    private func dismissWindow() {
        toastWindow?.isHidden = true
        toastWindow = nil
    }
}
