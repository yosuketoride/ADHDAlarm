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
