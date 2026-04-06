import UIKit
import SwiftUI

struct ToastQueueState {
    private(set) var current: ToastMessage?
    private(set) var pending: [ToastMessage] = []
    private var lastEnqueueDateByText: [String: Date] = [:]

    /// トーストをキューに積む。true のときは直ちに表示を開始する。
    mutating func enqueue(_ toast: ToastMessage, now: Date) -> Bool {
        if let lastDate = lastEnqueueDateByText[toast.text],
           now.timeIntervalSince(lastDate) < 2 {
            return false
        }
        lastEnqueueDateByText[toast.text] = now

        if current == nil {
            current = toast
            return true
        }

        pending.append(toast)
        return false
    }

    /// 現在のトーストを消し、次のトーストを先頭に出す
    mutating func advance() -> ToastMessage? {
        if pending.isEmpty {
            current = nil
            return nil
        }
        current = pending.removeFirst()
        return current
    }

    mutating func clearAll() {
        current = nil
        pending.removeAll()
        lastEnqueueDateByText.removeAll()
    }
}

/// UIWindowの最前面にToastを表示するマネージャー
/// .fullScreenCover（RingingView）の上にも表示できる
@MainActor
final class ToastWindowManager {
    static let shared = ToastWindowManager()
    private var toastWindow: UIWindow?
    private var currentHideTask: Task<Void, Never>?
    private var queueState = ToastQueueState()

    private init() {}

    /// テスト用に現在のキュー状態を参照する
    var currentToastForTesting: ToastMessage? { queueState.current }
    var pendingToastsForTesting: [ToastMessage] { queueState.pending }

    /// Toastを表示する（同時1件制限・前のToastが消えてから次を表示）
    func show(_ toast: ToastMessage) {
        let shouldPresentImmediately = queueState.enqueue(toast, now: Date())
        guard shouldPresentImmediately else { return }
        presentCurrentToast()
    }

    private func presentCurrentToast() {
        guard let toast = queueState.current else { return }
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
            await MainActor.run { self?.dismissAndAdvanceQueue() }
        }
    }

    /// 現在表示中のToastを即座に消す
    func dismiss() {
        currentHideTask?.cancel()
        currentHideTask = nil
        queueState.clearAll()
        dismissWindow()
    }

    private func dismissAndAdvanceQueue() {
        dismissWindow()
        _ = queueState.advance()
        presentCurrentToast()
    }

    private func dismissWindow() {
        toastWindow?.isHidden = true
        toastWindow = nil
    }
}
