import SwiftUI
import MessageUI

/// iMessageを送信するための UIViewControllerRepresentable ラッパー
///
/// RingingView がエスカレーション（SOS）を発動したときに sheet として表示する。
struct MessageComposeView: UIViewControllerRepresentable {

    let recipients: [String]
    let body: String
    var onDismiss: (MessageComposeResult) -> Void

    func makeUIViewController(context: Context) -> MFMessageComposeViewController {
        // レビュー指摘: SMS未設定端末・シミュレーター・iPadでは canSendText() が false になり
        // 表示すると真っ白フリーズが起きる。呼び出し元で必ず確認すること:
        //   guard MFMessageComposeViewController.canSendText() else { /* フォールバック */ }
        assert(
            MFMessageComposeViewController.canSendText(),
            "[MessageComposeView] canSendText() が false の状態で表示されました。呼び出し元でチェックしてください。"
        )
        let vc = MFMessageComposeViewController()
        vc.recipients = recipients
        vc.body = body
        vc.messageComposeDelegate = context.coordinator
        return vc
    }

    func updateUIViewController(_ uiViewController: MFMessageComposeViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onDismiss: onDismiss)
    }

    // MARK: - Coordinator

    final class Coordinator: NSObject, MFMessageComposeViewControllerDelegate {
        let onDismiss: (MessageComposeResult) -> Void

        init(onDismiss: @escaping (MessageComposeResult) -> Void) {
            self.onDismiss = onDismiss
        }

        func messageComposeViewController(
            _ controller: MFMessageComposeViewController,
            didFinishWith result: MessageComposeResult
        ) {
            controller.dismiss(animated: true)
            onDismiss(result)
        }
    }
}
